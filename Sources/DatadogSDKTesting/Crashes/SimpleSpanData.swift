/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// This structs the minimum data we need from a Span to be serialized together with the crash if it happens,
/// so it can be reconstructed when processing the crash report
internal struct SimpleSpanData: Codable, Equatable {
    var traceIdHi: UInt64
    var traceIdLo: UInt64
    var spanId: UInt64
    var name: String
    var startEpochNanos: UInt64
    var stringAttributes = [String: String]()

    init(spanData: SpanData) {
        self.traceIdHi = spanData.traceId.rawHigherLong
        self.traceIdLo = spanData.traceId.rawLowerLong
        self.spanId = spanData.spanId.rawValue
        self.name = spanData.name
        self.startEpochNanos = spanData.startEpochNanos
        self.stringAttributes = spanData.attributes.mapValues { $0.description }
    }

    internal init(traceIdHi: UInt64, traceIdLo: UInt64, spanId: UInt64, name: String, startEpochNanos: UInt64, stringAttributes: [String: String] = [String: String]()) {
        self.traceIdHi = traceIdHi
        self.traceIdLo = traceIdLo
        self.spanId = spanId
        self.name = name
        self.startEpochNanos = startEpochNanos
        self.stringAttributes = stringAttributes
    }
}