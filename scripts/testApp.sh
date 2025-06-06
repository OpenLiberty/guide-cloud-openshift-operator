#!/bin/bash
set -euxo pipefail
./mvnw -version

# Package the system/ and inventory/ apps
./mvnw -ntp -q -pl models install
./mvnw -ntp -Dhttp.keepAlive=false \
    -Dmaven.wagon.http.pool=false \
    -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 \
    -q clean package

# Verifies that the system/inventory apps are functional
./mvnw -ntp -pl system verify
./mvnw -ntp -pl inventory verify

# Delete m2 cache after completion
rm -rf ~/.m2
