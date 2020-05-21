#!/bin/bash
set -euxo pipefail

##############################################################################
##
##  Travis CI test script
##
##############################################################################

mvn -pl models install
mvn package

oc project -q

docker build -t `oc registry info`/`oc project -q`/system:test system/.
docker build -t `oc registry info`/`oc project -q`/inventory:test inventory/.

oc apply -f ../scripts/test.yaml

sleep 60

oc get pods

oc describe pods

oc get routes

SYSTEM_IP=`oc get route system-route -o=jsonpath='{.spec.host}'`
INVENTORY_IP=`oc get route inventory-route -o=jsonpath='{.spec.host}'`

curl http://$SYSTEM_IP/system/properties
curl http://$INVENTORY_IP/inventory/systems/system-service

mvn verify -Ddockerfile.skip=true -Dsystem.ip=$SYSTEM_IP -Dinventory.ip=$INVENTORY_IP

oc logs $(oc get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep system)
oc logs $(oc get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep inventory)