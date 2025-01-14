/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2020-2021 Datadog, Inc.
 */

@testable import DatadogSDKTesting
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

struct FixtureError: Error, CustomStringConvertible {
    let description: String
}

class DDEnvironmentValuesTests: XCTestCase {
    var testEnvironment = [String: String]()
    var previousEnvironment = [String: String]()

    var tracerProvider = OpenTelemetrySDK.instance.tracerProvider
    var tracerSdk: Tracer!

    override func setUp() {
        testEnvironment = [String: String]()
        previousEnvironment = DDEnvironmentValues.environment
        DDEnvironmentValues.environment = [String: String]()
        tracerSdk = tracerProvider.get(instrumentationName: "SpanBuilderSdkTest")
    }

    override func tearDown() {
        DDEnvironmentValues.environment = previousEnvironment
    }

    private func setEnvVariables() {
        DDEnvironmentValues.environment = testEnvironment
        DDEnvironmentValues.environment["DD_DONT_EXPORT"] = "true"
        testEnvironment = [String: String]()
    }

    func testWhenDatadogEnvironmentAreSet_TheyAreStoredCorrectly() {
        testEnvironment["DATADOG_CLIENT_TOKEN"] = "token5a101f16"
        testEnvironment["DD_SERVICE"] = "testService"
        testEnvironment["DD_ENV"] = "testEnv"

        setEnvVariables()

        let env = DDEnvironmentValues()
        XCTAssertEqual(env.ddClientToken, "token5a101f16")
        XCTAssertEqual(env.ddEnvironment, "testEnv")
        XCTAssertEqual(env.ddService, "testService")
    }

    func testWhenNoConfigurationEnvironmentAreSet_DefaultValuesAreUsed() {
        let env = DDEnvironmentValues()
        XCTAssertEqual(env.disableNetworkInstrumentation, false)
        XCTAssertEqual(env.disableStdoutInstrumentation, false)
        XCTAssertEqual(env.disableStderrInstrumentation, false)
        XCTAssertEqual(env.disableHeadersInjection, false)
        XCTAssertEqual(env.extraHTTPHeaders, nil)
        XCTAssertEqual(env.excludedURLS, nil)
        XCTAssertEqual(env.enableRecordPayload, false)
        XCTAssertEqual(env.disableCrashHandler, false)
    }

    func testWhenConfigurationEnvironmentAreSet_TheyAreStoredCorrectly() {
        testEnvironment["DD_DISABLE_NETWORK_INSTRUMENTATION"] = "1"
        testEnvironment["DD_DISABLE_STDOUT_INSTRUMENTATION"] = "yes"
        testEnvironment["DD_DISABLE_STDERR_INSTRUMENTATION"] = "true"
        testEnvironment["DD_DISABLE_HEADERS_INJECTION"] = "YES"
        testEnvironment["DD_INSTRUMENTATION_EXTRA_HEADERS"] = "header1,header2;header3 header4"
        testEnvironment["DD_EXCLUDED_URLS"] = "http://www.google"
        testEnvironment["DD_ENABLE_RECORD_PAYLOAD"] = "true"
        testEnvironment["DD_DISABLE_CRASH_HANDLER"] = "true"

        setEnvVariables()

        let env = DDEnvironmentValues()
        XCTAssertEqual(env.disableNetworkInstrumentation, true)
        XCTAssertEqual(env.disableStdoutInstrumentation, true)
        XCTAssertEqual(env.disableStderrInstrumentation, true)
        XCTAssertEqual(env.disableHeadersInjection, true)
        XCTAssertEqual(env.extraHTTPHeaders?.count, 4)
        XCTAssertEqual(env.excludedURLS?.count, 1)
        XCTAssertEqual(env.enableRecordPayload, true)
        XCTAssertEqual(env.disableCrashHandler, true)
    }

    func testAddsTagsToSpan() {
        testEnvironment["JENKINS_URL"] = "http://jenkins.com/"
        testEnvironment["GIT_URL"] = "/test/repo"
        testEnvironment["GIT_COMMIT"] = "37e376448b0ac9b7f54404"
        testEnvironment["WORKSPACE"] = "/build"
        testEnvironment["BUILD_TAG"] = "pipeline1"
        testEnvironment["BUILD_NUMBER"] = "45"
        testEnvironment["BUILD_URL"] = "http://jenkins.com/build"
        testEnvironment["GIT_BRANCH"] = "/origin/develop"
        testEnvironment["JOB_NAME"] = "job1"

        setEnvVariables()

        let span = createSimpleSpan()
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, 1)
        XCTAssertEqual(spanData.attributes["_dd.origin"]?.description, "ciapp-test")

        let env = DDEnvironmentValues()
        env.addTagsToSpan(span: span)

        spanData = span.toSpanData()

        XCTAssertEqual(spanData.attributes["ci.provider.name"]?.description, "jenkins")
        XCTAssertEqual(spanData.attributes["git.repository_url"]?.description, "/test/repo")
        XCTAssertEqual(spanData.attributes["git.commit.sha"]?.description, "37e376448b0ac9b7f54404")
        XCTAssertEqual(spanData.attributes["ci.workspace_path"]?.description, "/build")
        XCTAssertEqual(spanData.attributes["ci.pipeline.id"]?.description, "pipeline1")
        XCTAssertEqual(spanData.attributes["ci.pipeline.number"]?.description, "45")
        XCTAssertEqual(spanData.attributes["ci.pipeline.url"]?.description, "http://jenkins.com/build")
        XCTAssertEqual(spanData.attributes["ci.pipeline.name"]?.description, "job1")
        XCTAssertEqual(spanData.attributes["git.branch"]?.description, "develop")
    }

    func testWhenNotRunningInCI_CITagsAreNotAdded() {
        setEnvVariables()

        let span = createSimpleSpan()
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, 1)
        XCTAssertEqual(spanData.attributes["_dd.origin"]?.description, "ciapp-test")

        let env = DDEnvironmentValues()
        env.addTagsToSpan(span: span)

        spanData = span.toSpanData()
        XCTAssertNotNil(spanData.attributes[DDCITags.ciWorkspacePath])
        XCTAssertNil(spanData.attributes[DDCITags.ciProvider])
    }

    func testAddCustomTagsWithDDTags() {
        testEnvironment["DD_TAGS"] = "key1:value1 key2:value2 key3:value3 keyFoo:$FOO keyFooFoo:$FOOFOO keyMix:$FOO-v1"
        testEnvironment["FOO"] = "BAR"
        setEnvVariables()

        let span = createSimpleSpan()
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, 1)
        XCTAssertEqual(spanData.attributes["_dd.origin"]?.description, "ciapp-test")

        let env = DDEnvironmentValues()
        env.addTagsToSpan(span: span)

        spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes["key1"]?.description, "value1")
        XCTAssertEqual(spanData.attributes["key2"]?.description, "value2")
        XCTAssertEqual(spanData.attributes["key3"]?.description, "value3")
        XCTAssertEqual(spanData.attributes["keyFoo"]?.description, "BAR")
        XCTAssertEqual(spanData.attributes["keyFooFoo"]?.description, "$FOOFOO")
        XCTAssertEqual(spanData.attributes["keyMix"]?.description, "BAR-v1")
        XCTAssertNotNil(spanData.attributes[DDCITags.ciWorkspacePath])
    }

    private func createSimpleSpan() -> RecordEventsReadableSpan {
        return tracerSdk.spanBuilder(spanName: "spanName").startSpan() as! RecordEventsReadableSpan
    }

    func testRepositoryName() {
        testEnvironment["GITHUB_WORKSPACE"] = "/tmp/folder"
        testEnvironment["GITHUB_REPOSITORY"] = "therepo"

        setEnvVariables()
        let env = DDEnvironmentValues()

        XCTAssertEqual(env.repository, "https://github.com/therepo.git")
        XCTAssertEqual(env.getRepositoryName(), "therepo")
    }

    func testIfCommitHashFromEnvironmentIsNotSetGitFolderIsEvaluated() {
        testEnvironment["GITHUB_WORKSPACE"] = "/tmp/folder"
        testEnvironment["GITHUB_SHA"] = nil

        setEnvVariables()
        let env = DDEnvironmentValues()

        XCTAssertNotNil(env.commitMessage)
    }

    func testIfCommitHashFromEnvironmentIsSetAndDifferentFromGitFolderThenGitFolderIsNotEvaluated() {
        testEnvironment["GITHUB_WORKSPACE"] = "/tmp/folder"
        testEnvironment["GITHUB_SHA"] = "environmentSHA"

        setEnvVariables()
        let env = DDEnvironmentValues()

        XCTAssertNil(env.commitMessage)
        XCTAssertEqual(env.commit, "environmentSHA")
    }

    func testIfCommitHashFromEnvironmentIsSetAndEqualsFromGitFolderThenGitFolderIsEvaluated() {
        let gitInfo = DDEnvironmentValues.gitInfoAt(startingPath: #file)

        testEnvironment["GITHUB_WORKSPACE"] = "/tmp/folder"
        testEnvironment["GITHUB_SHA"] = gitInfo?.commit

        setEnvVariables()
        let env = DDEnvironmentValues()

        XCTAssertNotNil(env.commitMessage)
    }

    func testGitInfoIsNilWhenNotGitFolderExists() {
        let gitInfo = DDEnvironmentValues.gitInfoAt(startingPath: "/Users/")
        XCTAssertNil(gitInfo)
    }

    func testSpecs() throws {
        let bundle = Bundle(for: type(of: self))
        let fixturesURL = bundle.resourceURL!.appendingPathComponent("ci")
        let fileEnumerator = FileManager.default.enumerator(at: fixturesURL, includingPropertiesForKeys: nil)!

        var numTestedFiles = 0
        for case let fileURL as URL in fileEnumerator {
            if fileURL.pathExtension == "json" {
                numTestedFiles += 1
                print("validating \(fileURL.lastPathComponent)")
                do {
                    try validateSpec(file: fileURL)
                } catch {
                    print("[FixtureError] JSON serialization failed on file: \(fileURL)")
                    let content = try String(contentsOf: fileURL)
                    if content.isEmpty {
                        print("[FixtureError] File is empty" + content)
                    } else {
                        print("[FixtureError] content:\n" + content)
                    }
                    throw error
                }
            }
        }
        XCTAssertGreaterThan(numTestedFiles, 0)
    }

    private func validateSpec(file: URL) throws {
        let data = try Data(contentsOf: file)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] else { throw FixtureError(description: "[FixtureError] JSON serialization failed on file: \(file)") }
        try json.forEach { specVal in
            DDEnvironmentValues.environment = [String: String]()
            guard let spec = specVal as? [[String: String]] else { throw FixtureError(description: "[FixtureError] spec invalid: \(specVal)") }
            spec[0].forEach {
                testEnvironment[$0.key] = $0.value
            }

            setEnvVariables()
            let span = createSimpleSpan()
            var spanData = span.toSpanData()
            let env = DDEnvironmentValues()
            env.addTagsToSpan(span: span)
            spanData = span.toSpanData()

            spec[1].forEach {
                XCTAssertEqual(spanData.attributes[$0.key]?.description, $0.value, "\($0.key) != \($0.value)")
            }
        }
    }
}
