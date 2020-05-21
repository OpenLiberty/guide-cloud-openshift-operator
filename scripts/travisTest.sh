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
LATEST_VERSION=$(curl -s https://api.github.com/repos/OpenLiberty/open-liberty-operator/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 2-)
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

# Deploy Kafka straight from DockerHub
oc new-app bitnami/kafka:2 \
  -l name=kafka \
  -e KAFKA_CFG_ZOOKEEPER_CONNECT=zookeeper:2181 \
  -e ALLOW_PLAINTEXT_LISTENER=yes \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092

# Creating the templates
oc process -f build.yaml -p APP_NAME=system | oc create -f -
oc process -f build.yaml -p APP_NAME=inventory | oc create -f -

# Starting the builds that build and push the app images to OpenShift
oc start-build system-buildconfig --from-dir=system/.
oc start-build inventory-buildconfig --from-dir=inventory/.

sleep 30

oc get all

# Uses the OL Operator to deploy the apps
oc apply -f deploy.yaml

sleep 30

# Pulls the inventory app IP
INVENTORY_IP=`oc get route inventory -o=jsonpath='{.spec.host}'`

# Visits the endpoint
curl http://$INVENTORY_IP/inventory/systems

RESPONSE=$(curl -I http://$INVENTORY_IP/inventory/systems 2>&1 | grep HTTP/1.1 | cut -d ' ' -f2)

if [ "RESPONSE" == "200" ]; then
  printf "Inventory service is live\n"
else
  printf "Inventory service is not live\n"
  printf "expected HTTP response 200, received $RESPONSE\n"
  exit 1
fi