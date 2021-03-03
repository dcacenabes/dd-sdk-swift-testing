/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal enum SimpleSpanSerializer {
    static func serializeSpan(simpleSpan: SimpleSpanData) -> Data {
        var encodedData = Data()
        do {
            encodedData = try JSONEncoder().encode(simpleSpan)
        } catch {
            print("Failed encoding span: \(simpleSpan.name)")
        }
        return encodedData
    }

    static func deserializeSpan(data: Data) -> SimpleSpanData? {
        var spanData: SimpleSpanData?
        do {
            spanData = try JSONDecoder().decode(SimpleSpanData.self, from: data)
        } catch {
            print("Failed decoding span: \(data)")
        }
        return spanData
    }
}
