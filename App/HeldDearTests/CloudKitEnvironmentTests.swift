import XCTest
import CloudKit
@testable import HeldDear

/// The CloudKit environment comes from a build setting, the app never makes the schema on Production, and a
/// "record type not found" error reads as one plain line on the You page.
final class CloudKitEnvironmentTests: XCTestCase {
    private static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func text(_ path: String) throws -> String {
        try String(contentsOf: Self.repo.appendingPathComponent(path), encoding: .utf8)
    }

    func testTheSchemaIsOnlyEverCreatedInDevelopment() {
        XCTAssertTrue(ICloudSync.canInitializeSchema(in: "Development"))
        XCTAssertFalse(ICloudSync.canInitializeSchema(in: "Production"))
        XCTAssertFalse(ICloudSync.canInitializeSchema(in: ""))
        XCTAssertFalse(ICloudSync.canInitializeSchema(in: "development"), "exactly Development, nothing near it")
    }

    func testAnUnknownEnvironmentReadsAsProduction() {
        // With no Info.plist value the app is treated as Production, so it never makes the schema.
        XCTAssertFalse(ICloudSync.canInitializeSchema(in: Bundle(for: Self.self).object(forInfoDictionaryKey: "HeldDearCloudKitEnvironment") as? String ?? "Production"))
    }

    func testEntitlementAndInfoPlistTakeTheEnvironmentFromTheBuildSetting() throws {
        XCTAssertTrue(try text("Config/HeldDear.entitlements").contains("<string>$(HELDDEAR_CLOUDKIT_ENVIRONMENT)</string>"))
        XCTAssertTrue(try text("Config/Info.plist").contains("<string>$(HELDDEAR_CLOUDKIT_ENVIRONMENT)</string>"))
    }

    func testDebugIsDevelopmentAndReleaseIsProduction() throws {
        let yml = try text("project.yml")
        XCTAssertTrue(yml.contains("Debug:\n          HELDDEAR_CLOUDKIT_ENVIRONMENT: Development"))
        XCTAssertTrue(yml.contains("Release:\n          HELDDEAR_CLOUDKIT_ENVIRONMENT: Production"))
    }

    func testRecordTypeNotFoundReadsAsNotReady() {
        let unknown = NSError(domain: CKErrorDomain, code: CKError.unknownItem.rawValue)
        XCTAssertTrue(ICloudSync.isSchemaNotReady(unknown))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134060, userInfo: [NSUnderlyingErrorKey: unknown])
        XCTAssertTrue(ICloudSync.isSchemaNotReady(wrapped), "found under another error")
        let partial = NSError(domain: CKErrorDomain, code: CKError.partialFailure.rawValue,
                              userInfo: [CKPartialErrorsByItemIDKey: ["zone": unknown]])
        XCTAssertTrue(ICloudSync.isSchemaNotReady(partial), "found in a partial failure")
        let message = NSError(domain: CKErrorDomain, code: CKError.serverRejectedRequest.rawValue,
                              userInfo: [NSLocalizedDescriptionKey: "Did not find record type: CD_Person"])
        XCTAssertTrue(ICloudSync.isSchemaNotReady(message), "found in the server's words")
    }

    func testOtherErrorsAreNotReadAsNotReady() {
        XCTAssertFalse(ICloudSync.isSchemaNotReady(NSError(domain: CKErrorDomain, code: CKError.networkUnavailable.rawValue)))
        XCTAssertFalse(ICloudSync.isSchemaNotReady(NSError(domain: CKErrorDomain, code: CKError.notAuthenticated.rawValue)))
        XCTAssertFalse(ICloudSync.isSchemaNotReady(NSError(domain: NSCocoaErrorDomain, code: 134400)))
        XCTAssertFalse(ICloudSync.isSchemaNotReady(NSError(domain: CKErrorDomain, code: CKError.quotaExceeded.rawValue,
                                                           userInfo: [NSLocalizedDescriptionKey: "Over quota"])))
    }

    func testTheYouPageLine() {
        XCTAssertEqual(ICloudSync.notReadyLine, "iCloud sync isn't ready yet. Everything is safe on this iPhone.")
        let unknown = NSError(domain: CKErrorDomain, code: CKError.unknownItem.rawValue)
        XCTAssertEqual(ICloudSync.problemLine("Sent didn't finish", unknown), ICloudSync.notReadyLine)
        let other = NSError(domain: CKErrorDomain, code: CKError.networkUnavailable.rawValue)
        XCTAssertTrue(ICloudSync.problemLine("Sent didn't finish", other).hasPrefix("Sent didn't finish: "), "other errors keep their reason")
    }

    func testTheSchemaWorkflowNamesOnlyDevelopment() throws {
        let yml = try text(".github/workflows/cloudkit-schema.yml")
        XCTAssertTrue(yml.contains("--environment development"))
        XCTAssertTrue(yml.contains("workflow_dispatch"))
        XCTAssertFalse(yml.contains("pull_request") || yml.contains("push:") || yml.contains("schedule:"), "started by hand only")
        XCTAssertTrue(yml.contains("CLOUDKIT_MANAGEMENT_TOKEN"))
        XCTAssertTrue(yml.contains("--validate"), "validated before the import")
        XCTAssertFalse(yml.lowercased().contains("pro" + "duction"))
    }
}
