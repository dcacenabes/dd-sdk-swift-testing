/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

@testable import DatadogSDKTesting
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

internal class DDTestObserverTests: XCTestCase {
    var testObserver: DDTestObserver!

    override func setUp() {
        DDEnvironmentValues.environment["DATADOG_CLIENT_TOKEN"] = "fakeToken"
        testObserver = DDTestObserver(tracer: DDTracer())
        testObserver.startObserving()
    }

    override func tearDown() {
        XCTestObservationCenter.shared.removeTestObserver(testObserver)
        testObserver = nil
    }

    func testWhenTestBundleWillStartIsCalled_testBundleNameIsSet() {
        testObserver.testBundleWillStart(Bundle.main)

        XCTAssertFalse(testObserver.currentBundleName.isEmpty)
    }

    func testWhenTestCaseWillStartIsCalled_testSpanIsCreated() {
        testObserver.testCaseWillStart(self)

        let span = testObserver.tracer.tracerSdk.currentSpan as! RecordEventsReadableSpan
        let spanData = span.toSpanData()

        XCTAssertEqual(spanData.name, "-[DDTestObserverTests testWhenTestCaseWillStartIsCalled_testSpanIsCreated]")
        XCTAssertEqual(spanData.attributes.count, 6)
        XCTAssertEqual(spanData.attributes[DDTestTags.type]?.description, DDTestTags.typeTest)
        XCTAssertEqual(spanData.attributes[DDTestTags.testName]?.description, "testWhenTestCaseWillStartIsCalled_testSpanIsCreated")
        XCTAssertEqual(spanData.attributes[DDTestTags.testSuite]?.description, "DDTestObserverTests")
        XCTAssertEqual(spanData.attributes[DDTestTags.testFramework]?.description, "XCTest")
        XCTAssertEqual(spanData.attributes[DDTestTags.testBundle]?.description, testObserver.currentBundleName)
        XCTAssertEqual(spanData.attributes[DDTestTags.testType]?.description, DDTestTags.typeTest)

        testObserver.testCaseDidFinish(self)
    }

    func testWhenTestCaseDidFinishIsCalled_testStatusIsSet() {
        testObserver.testCaseWillStart(self)
        let testSpan = testObserver.tracer.tracerSdk.currentSpan as! RecordEventsReadableSpan
        var spanData = testSpan.toSpanData()
        XCTAssertNil(spanData.attributes[DDTestTags.testStatus])

        testObserver.testCaseDidFinish(self)
        spanData = testSpan.toSpanData()
        XCTAssertNotNil(spanData.attributes[DDTestTags.testStatus])
    }

    func testWhenTestCaseDidFailWithDescriptionIsCalled_testStatusIsSet() {

        testObserver.testCaseWillStart(self)
        testObserver.testCase(self, didFailWithDescription: "descrip", inFile: "samplefile", atLine: 239)

        let testSpan = testObserver.tracer.tracerSdk.currentSpan as! RecordEventsReadableSpan
        let spanData = testSpan.toSpanData()

        XCTAssertNotNil(spanData.attributes[DDTags.errorType])
        XCTAssertNotNil(spanData.attributes[DDTags.errorMessage])
        XCTAssertNotNil(spanData.attributes[DDTags.errorStack])

        testObserver.testCaseDidFinish(self)
    }

    func testWhenTestCaseDidFinishIsCalledAndTheTestIsABenchmark_benchmarkTagsAreAdded() {
        testObserver.testCaseWillStart(self)
        let testSpan = testObserver.tracer.tracerSdk.currentSpan as! RecordEventsReadableSpan
        let perfMetric = XCTPerformanceMetric.wallClockTime
        self.setValue([perfMetric], forKey: "_activePerformanceMetricIDs")
        self.setValue([perfMetric: ["measurements" : [1,2,3,4,5]]], forKey: "_perfMetricsForID")

        testObserver.testCaseDidFinish(self)
        
        let spanData = testSpan.toSpanData()
        XCTAssertEqual(spanData.attributes[DDTestTags.testType]?.description, DDTestTags.typeBenchmark)
        XCTAssertEqual(spanData.attributes[DDBenchmarkTags.durationMean]?.description, "3000000000.0")
        XCTAssertEqual(spanData.attributes[DDBenchmarkTags.statisticsN]?.description, "5")
        XCTAssertEqual(spanData.attributes[DDBenchmarkTags.statisticsMin]?.description, "1000000000.0")
        XCTAssertEqual(spanData.attributes[DDBenchmarkTags.statisticsMax]?.description, "5000000000.0")
        XCTAssertEqual(spanData.attributes[DDBenchmarkTags.statisticsMedian]?.description, "3000000000.0")

        self.setValue(nil, forKey: "_activePerformanceMetricIDs")
        self.setValue(nil, forKey: "_perfMetricsForID")
    }
}
