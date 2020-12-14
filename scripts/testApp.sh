#!/bin/bash
set -euxo pipefail

# Package the system/ and inventory/ apps
mvn -q -pl models install
mvn -q package

# Verifies that the system/inventory apps are functional
mvn -pl system verify
mvn -pl inventory verify

# Delete m2 cache after completion
rm -rf ~/.m2
