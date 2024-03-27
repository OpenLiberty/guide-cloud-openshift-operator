// tag::copyright[]
/*******************************************************************************
 * Copyright (c) 2020, 2024 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License 2.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *******************************************************************************/
// end::copyright[]
package io.openliberty.guides.models;

import java.util.Objects;

import jakarta.json.bind.Jsonb;
import jakarta.json.bind.JsonbBuilder;

import org.apache.kafka.common.serialization.Deserializer;
import org.apache.kafka.common.serialization.Serializer;

public class SystemLoad {

    private static final Jsonb JSONB = JsonbBuilder.create();

    public String hostId;
    public Double loadAverage;

    public SystemLoad(String hostId, Double cpuLoadAvg) {
        this.hostId = hostId;
        this.loadAverage = cpuLoadAvg;
    }

    public SystemLoad() {
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof SystemLoad)) {
            return false;
        }
        SystemLoad sl = (SystemLoad) o;
        return Objects.equals(hostId, sl.hostId)
                && Objects.equals(loadAverage, sl.loadAverage);
    }

    @Override
    public int hashCode() {
        return Objects.hash(hostId, loadAverage);
    }

    @Override
    public String toString() {
        return "CpuLoadAverage: " + JSONB.toJson(this);
    }

    // tag::SystemLoadSerializer[]
    public static class SystemLoadSerializer implements Serializer<Object> {
        @Override
        public byte[] serialize(String topic, Object data) {
          return JSONB.toJson(data).getBytes();
        }
    }
    // end::SystemLoadSerializer[]

    // tag::SystemLoadDeserializer[]
    public static class SystemLoadDeserializer implements Deserializer<SystemLoad> {
        @Override
        public SystemLoad deserialize(String topic, byte[] data) {
            if (data == null) {
                return null;
            }
            return JSONB.fromJson(new String(data), SystemLoad.class);
        }
    }
    // end::SystemLoadDeserializer[]
}
