#!/bin/bash
set -euxo pipefail

##############################################################################
##
##  Travis CI test script
##
##############################################################################

mvn -q -pl models install
mvn -q package

oc login -u system:admin
oc new-project guide

oc new-app bitnami/zookeeper:3 \
  -l name=kafka \
  -e ALLOW_ANONYMOUS_LOGIN=yes

oc new-app bitnami/kafka:2 \
  -l name=kafka \
  -e KAFKA_CFG_ZOOKEEPER_CONNECT=zookeeper:2181 \
  -e ALLOW_PLAINTEXT_LISTENER=yes \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092

oc process -f build.yaml -p APP_NAME=system | oc create -f -
oc process -f build.yaml -p APP_NAME=inventory | oc create -f -

oc start-build system-buildconfig --from-dir=system/.
oc start-build inventory-buildconfig --from-dir=inventory/.

sleep 30

oc get all

oc apply -f deploy.yaml