#!/bin/bash
set -euxo pipefail

# Package the system/ and inventory/ apps
mvn -q -pl models install -e
mvn -q clean package -e

# Verifies that the system/inventory apps are functional
mvn -pl system verify -e
mvn -pl inventory verify -e

# Delete m2 cache after completion
rm -rf ~/.m2
