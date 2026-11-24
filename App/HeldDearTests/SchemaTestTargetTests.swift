import XCTest
@testable import HeldDear

/// The Schema Test app (target HeldDearSchemaTest) shares the app sources but must never change the real app: same
/// bundle ID, container, group and entitlements as before, and none of the test app's code inside it.
final class SchemaTestTargetTests: XCTestCase {
    private static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func plist(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Self.repo.appendingPathComponent(path))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func text(_ path: String) throws -> String {
        try String(contentsOf: Self.repo.appendingPathComponent(path), encoding: .utf8)
    }

    /// The part of project.yml for one target: from its heading to the next target's heading (or the schemes).
    private func block(_ target: String, in yml: String) throws -> String {
        let lines = yml.components(separatedBy: "\n")
        let start = try XCTUnwrap(lines.firstIndex(of: "  \(target):"), "target \(target)")
        var out: [String] = []
        for line in lines[(start + 1)...] {
            if (line.hasPrefix("  ") && !line.hasPrefix("   ") && line.hasSuffix(":") && !line.hasPrefix("  #")) || line.hasPrefix("schemes:") { break }
            out.append(line)
        }
        return out.joined(separator: "\n")
    }

    // MARK: the real app is unchanged

    func testTheRealAppRunsWithItsOwnBundleIDContainerAndGroup() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.grahamdeno.helddear")
        XCTAssertEqual(ICloudSync.containerID, "iCloud.com.grahamdeno.helddear")
        XCTAssertEqual(AppGroup.identifier, "group.com.grahamdeno.helddear")
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "HeldDearCloudKitContainer"), "only the Schema Test app sets it")
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "HeldDearAppGroup"), "only the Schema Test app sets it")
    }

    func testTheRealEntitlementsAreUnchanged() throws {
        let e = try plist("Config/HeldDear.entitlements")
        XCTAssertEqual(e["com.apple.security.application-groups"] as? [String], ["group.com.grahamdeno.helddear"])
        XCTAssertEqual(e["com.apple.developer.icloud-container-identifiers"] as? [String], ["iCloud.com.grahamdeno.helddear"])
        XCTAssertEqual(e["com.apple.developer.icloud-services"] as? [String], ["CloudKit"])
        XCTAssertEqual(e["com.apple.developer.icloud-container-environment"] as? String, "$(HELDDEAR_CLOUDKIT_ENVIRONMENT)")
        XCTAssertEqual(e["aps-environment"] as? String, "production")
        XCTAssertEqual(e["com.apple.developer.ubiquity-kvstore-identifier"] as? String, "$(TeamIdentifierPrefix)$(CFBundleIdentifier)")
        XCTAssertEqual(e["com.apple.developer.in-app-payments"] as? [String], ["merchant.com.grahamdeno.helddear"])
        XCTAssertEqual(Set(e.keys).count, 7, "no entitlement was added or removed")
    }

    func testTheRealTargetInProjectYmlIsUnchanged() throws {
        let real = try block("HeldDear", in: try text("project.yml"))
        XCTAssertTrue(real.contains("PRODUCT_BUNDLE_IDENTIFIER: com.grahamdeno.helddear\n"))
        XCTAssertTrue(real.contains("CODE_SIGN_ENTITLEMENTS: Config/HeldDear.entitlements\n"))
        XCTAssertTrue(real.contains("INFOPLIST_FILE: Config/Info.plist\n"))
        XCTAssertTrue(real.contains("INFOPLIST_KEY_CFBundleDisplayName: Held Dear\n"))
        XCTAssertTrue(real.contains("- target: HeldDearShare"))
        XCTAssertTrue(real.contains("- target: HeldDearWidgets"))
        XCTAssertTrue(real.contains("- App/HeldDear\n"))
        XCTAssertTrue(real.contains("- App/Shared\n"))
        XCTAssertFalse(real.contains("HeldDearSchemaTest"), "the test app's folder is not a source of the real app")
        XCTAssertFalse(real.contains("SCHEMA_TEST"), "the real app never sets the flag")
        XCTAssertFalse(real.contains("HELDDEAR_CLOUDKIT_CONTAINER"))
        XCTAssertFalse(real.contains("HELDDEAR_APP_GROUP"))
    }

    func testTheRealInfoPlistHasNoTestAppKeys() throws {
        let info = try plist("Config/Info.plist")
        XCTAssertNil(info["HeldDearCloudKitContainer"])
        XCTAssertNil(info["HeldDearAppGroup"])
        XCTAssertEqual(info["HeldDearCloudKitEnvironment"] as? String, "$(HELDDEAR_CLOUDKIT_ENVIRONMENT)")
    }

    func testTheExtensionsKeepTheRealGroup() throws {
        for file in ["Config/HeldDearShare.entitlements", "Config/HeldDearWidgets.entitlements"] {
            let e = try plist(file)
            XCTAssertEqual(e["com.apple.security.application-groups"] as? [String], ["group.com.grahamdeno.helddear"], file)
        }
    }

    func testNoneOfTheTestAppsCodeIsInTheRealApp() {
        XCTAssertNil(NSClassFromString("HeldDear.SchemaTestRunner"))
        XCTAssertNil(NSClassFromString("HeldDearSchemaTest.SchemaTestRunner"))
    }

    // MARK: the test app is separate

    func testTheTestAppHasItsOwnBundleIDNameContainerGroupAndNoExtensions() throws {
        let yml = try text("project.yml")
        let test = try block("HeldDearSchemaTest", in: yml)
        XCTAssertTrue(test.contains("PRODUCT_BUNDLE_IDENTIFIER: com.grahamdeno.helddear.schematest\n"))
        XCTAssertTrue(test.contains("INFOPLIST_KEY_CFBundleDisplayName: Schema Test\n"))
        XCTAssertTrue(test.contains("CODE_SIGN_ENTITLEMENTS: Config/HeldDearSchemaTest.entitlements\n"))
        XCTAssertTrue(test.contains("HELDDEAR_CLOUDKIT_CONTAINER: iCloud.com.grahamdeno.helddear.schematest\n"))
        XCTAssertTrue(test.contains("HELDDEAR_APP_GROUP: group.com.grahamdeno.helddear.schematest\n"))
        XCTAssertTrue(test.contains("SCHEMA_TEST"))
        XCTAssertTrue(test.contains("- App/HeldDearSchemaTest\n"))
        XCTAssertFalse(test.contains("HeldDearShare"), "no share extension")
        XCTAssertFalse(test.contains("HeldDearWidgets"), "no widget")
        XCTAssertFalse(test.contains("dependencies"))
        XCTAssertTrue(test.contains("Release:\n          HELDDEAR_CLOUDKIT_ENVIRONMENT: Production"), "Release builds use the Production environment")
        XCTAssertFalse(try block("HeldDearTests", in: yml).contains("SCHEMA_TEST"))
        XCTAssertFalse(try block("HeldDearShare", in: yml).contains("SCHEMA_TEST"))
        XCTAssertFalse(try block("HeldDearWidgets", in: yml).contains("SCHEMA_TEST"))
    }

    func testTheTestAppEntitlementsNameOnlyItsOwnContainerAndGroup() throws {
        let e = try plist("Config/HeldDearSchemaTest.entitlements")
        XCTAssertEqual(e["com.apple.security.application-groups"] as? [String], ["$(HELDDEAR_APP_GROUP)"])
        XCTAssertEqual(e["com.apple.developer.icloud-container-identifiers"] as? [String], ["$(HELDDEAR_CLOUDKIT_CONTAINER)"])
        XCTAssertEqual(e["com.apple.developer.icloud-services"] as? [String], ["CloudKit"])
        XCTAssertEqual(e["com.apple.developer.icloud-container-environment"] as? String, "$(HELDDEAR_CLOUDKIT_ENVIRONMENT)")
        XCTAssertEqual(e["aps-environment"] as? String, "production")
        XCTAssertNil(e["com.apple.developer.in-app-payments"], "no Apple Pay")
        XCTAssertNil(e["com.apple.developer.ubiquity-kvstore-identifier"], "no key-value store")
        XCTAssertEqual(Set(e.keys), ["com.apple.security.application-groups", "aps-environment",
                                     "com.apple.developer.icloud-container-identifiers", "com.apple.developer.icloud-services",
                                     "com.apple.developer.icloud-container-environment"])
        let raw = try text("Config/HeldDearSchemaTest.entitlements")
        XCTAssertFalse(raw.contains("group.com.grahamdeno.helddear\n"))
    }

    func testTheTestAppInfoPlistSetsTheContainerAndGroupFromBuildSettings() throws {
        let info = try plist("Config/SchemaTest-Info.plist")
        XCTAssertEqual(info["HeldDearCloudKitContainer"] as? String, "$(HELDDEAR_CLOUDKIT_CONTAINER)")
        XCTAssertEqual(info["HeldDearAppGroup"] as? String, "$(HELDDEAR_APP_GROUP)")
        XCTAssertEqual(info["HeldDearCloudKitEnvironment"] as? String, "$(HELDDEAR_CLOUDKIT_ENVIRONMENT)")
    }

    func testTheTestAppsCodeSitsOnlyInItsOwnFolderAndIsWrappedInTheFlag() throws {
        let folder = Self.repo.appendingPathComponent("App/HeldDearSchemaTest")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".swift") }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertTrue(source.hasPrefix("#if SCHEMA_TEST"), file)
            XCTAssertTrue(source.hasSuffix("#endif"), file)
        }
    }

    /// Build 2 deadlocked: no observer on the main queue, and iCloud record IDs only off the main thread.
    func testTheTestAppNeverObservesOnTheMainQueueOrReadsRecordIDsOnTheMainThread() throws {
        let source = try text("App/HeldDearSchemaTest/SchemaTest.swift")
        XCTAssertFalse(source.contains("queue: .main"))
        XCTAssertFalse(source.contains("OperationQueue.main"))
        XCTAssertFalse(source.contains("addObserver(forName"), "observers are added through SeedObserver, which has no queue")
        XCTAssertTrue(source.contains("SeedObserver.add("))
        for line in source.components(separatedBy: "\n") where line.contains("recordIDs(for") {
            XCTAssertTrue(line.contains("SeedThread.offMain"), "recordIDs(for:) must run off the main thread: \(line)")
        }
        XCTAssertTrue(source.contains("did not finish within 60 seconds"), "the first save waits for the setup event, at most 60 seconds")
    }

    // MARK: the two workflows

    func testTheTestWorkflowsNameOnlyTheTestContainerAndRunByHandOnly() throws {
        for file in [".github/workflows/cloudkit-schema-test.yml", ".github/workflows/schematest-testflight.yml"] {
            let yml = try text(file)
            XCTAssertTrue(yml.contains("workflow_dispatch:"), file)
            XCTAssertFalse(yml.contains("\n  push:"), "\(file) never runs on a push")
            XCTAssertFalse(yml.contains("\n  pull_request:"), file)
            XCTAssertFalse(yml.contains("\n  schedule:"), file)
            XCTAssertFalse(yml.lowercased().contains("--environment production"), file)
        }
        let schema = try text(".github/workflows/cloudkit-schema-test.yml")
        XCTAssertEqual(schema.components(separatedBy: "--container-id iCloud.com.grahamdeno.helddear.schematest").count - 1, 3,
                       "validate, import and export all name the test container")
        XCTAssertEqual(schema.components(separatedBy: "--environment development").count - 1, 3)
        XCTAssertTrue(schema.contains("cloudkit_env_guard.py container"))
    }
}
