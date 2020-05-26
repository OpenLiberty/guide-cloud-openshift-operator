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

# Verifies that the system/inventory apps are functional
mvn verify