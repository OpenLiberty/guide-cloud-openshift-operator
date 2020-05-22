#!/bin/bash
set -euxo pipefail

##############################################################################
##
##  Travis CI test script
##
##############################################################################

# Package the system/ and inventory/ apps
mvn -q -pl models install
mvn -q package

# Logging into the OKD cluster as admin + creating a project named 'guide'
oc login -u system:admin
oc new-project guide

# Fetch the latest release version of the Open Liberty Operator
LATEST_VERSION=$(curl -s https://api.github.com/repos/OpenLiberty/open-liberty-operator/releases/latest \
  | grep '"tag_name"' \
  | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 2-)
printf "Pulling Open Liberty Operator v"$LATEST_VERSION"\n"

# Installing the OL Operator to the OKD cluster
oc apply -f https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/$LATEST_VERSION/openliberty-app-crd.yaml
OPERATOR_NAMESPACE=guide
WATCH_NAMESPACE=guide
curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/$LATEST_VERSION/openliberty-app-operator.yaml \
      | sed -e "s/OPEN_LIBERTY_WATCH_NAMESPACE/${WATCH_NAMESPACE}/" \
      | oc apply -n ${OPERATOR_NAMESPACE} -f -

# View the installed resources
oc api-resources --api-group=openliberty.io

# Deploy zookeeper straight from DockerHub
oc new-app bitnami/zookeeper:3 \
  -l name=kafka \
  -e ALLOW_ANONYMOUS_LOGIN=yes

printf "\n======================  ZOOKEEPER DEPLOYED  ======================\n"

# Deploy Kafka straight from DockerHub
oc new-app bitnami/kafka:2 \
  -l name=kafka \
  -e KAFKA_CFG_ZOOKEEPER_CONNECT=zookeeper:2181 \
  -e ALLOW_PLAINTEXT_LISTENER=yes \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092

printf "\n======================  KAFKA DEPLOYED  ======================\n"

# Creating the templates
oc process -f build.yaml -p APP_NAME=system | oc create -f -
oc process -f build.yaml -p APP_NAME=inventory | oc create -f -

# Starting the builds that build and push the app images to OpenShift
oc start-build system-buildconfig --from-dir=system/.
oc start-build inventory-buildconfig --from-dir=inventory/.

# Initial sleep timer to give builds some time to finish
sleep 180

# Check status of builds
TIMEOUT=60
SYSTEM_BUILD_STATUS=$(oc get build/system-buildconfig-1 -o=jsonpath='{.status.phase}')
INVENTORY_BUILD_STATUS=$(oc get build/inventory-buildconfig-1 -o=jsonpath='{.status.phase}')

# Loop sleep until builds are complete or timed out
while [ "$SYSTEM_BUILD_STATUS" = "Running" ] || [ "$INVENTORY_BUILD_STATUS" = "Running" ]
do
  if [ "$TIMEOUT" = "0" ]; then
    printf "Test timed out while waiting for builds to complete\n";
    exit 1
  fi
  sleep 5;
  SYSTEM_BUILD_STATUS=$(oc get build/system-buildconfig-1 -o=jsonpath='{.status.phase}');
  INVENTORY_BUILD_STATUS=$(oc get build/inventory-buildconfig-1 -o=jsonpath='{.status.phase}');
  ((TIMEOUT--));
done

printf "\n======================  BUILDS COMPLETE  ======================\n"

# Uncomment for debugging purposes
# oc logs build/system-buildconfig-1
# oc logs build/inventory-buildconfig-1

# Uses the OL Operator to deploy the apps
oc apply -f deploy.yaml

# Gives time for the apps to become live
sleep 60

# Uncomment this for debugging purposes - Visits the endpoint
curl http://$INVENTORY_IP/inventory/systems

# Uncomment this for debugging purposes
# oc describe pods

# Pulls the inventory app IP
INVENTORY_IP=$(oc get route inventory -o=jsonpath='{.spec.host}')

# Checks health of inventory service by ensuring a 200 response code
RESPONSE=$(curl -I http://$INVENTORY_IP/inventory/systems 2>&1 | grep HTTP/1.1 | cut -d ' ' -f2)
TIMEOUT=30

# Loop sleep until inventory service is live or timed out
while [ "$RESPONSE" != "200" ]
do
  if [ "$TIMEOUT" = "0" ]; then
    printf "Test timed out while waiting for inventory service to become live\n";
    printf "expected HTTP response 200, received $RESPONSE\n"
    exit 1
  fi
  sleep 5;
  RESPONSE=$(curl -I http://$INVENTORY_IP/inventory/systems 2>&1 | grep HTTP/1.1 | cut -d ' ' -f2)
  ((TIMEOUT--));
done

printf "\n======================  INVENTORY LIVE  ======================\n"

# Uncomment this for debugging purposes - Visits the endpoint
curl http://$INVENTORY_IP/inventory/systems

# Checks if there is only 1 logged system in the inventory
NUM_OF_SYSTEMS=$(curl http://$INVENTORY_IP/inventory/systems | grep -o -i '"hostname"' | wc -l)
TIMEOUT=30

# Loop sleep until inventory populates or timed out
while [ "$NUM_OF_SYSTEMS" = "0" ]
do
  if [ "$TIMEOUT" = "0" ]; then
    printf "Test timed out while waiting for inventory service to become populated\n";
    printf "expected 1 entry, received $NUM_OF_SYSTEMS\n"
    exit 1
  fi
  sleep 5;
  NUM_OF_SYSTEMS=$(curl http://$INVENTORY_IP/inventory/systems | grep -o -i '"hostname"' | wc -l)
  ((TIMEOUT--));
done

# Continues test if correct, exits test with error if not
if [ "$NUM_OF_SYSTEMS" = "1" ]; then
  printf "Inventory service contains 1 entry\n"
else
  printf "Inventory service contains the wrong number of entries\n"
  printf "expected 1 entry, received $NUM_OF_SYSTEMS\n"
  exit 1
fi