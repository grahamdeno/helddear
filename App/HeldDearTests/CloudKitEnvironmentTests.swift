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

    func testARecordTypeMessageReadsAsNotReady() {
        let message = NSError(domain: CKErrorDomain, code: CKError.serverRejectedRequest.rawValue,
                              userInfo: [NSLocalizedDescriptionKey: "Did not find record type: CD_Person"])
        XCTAssertTrue(ICloudSync.isSchemaNotReady(message), "a server rejected request that names a record type")
        let alone = NSError(domain: NSCocoaErrorDomain, code: 134404, userInfo: [NSLocalizedDescriptionKey: "Unknown record type CD_Wish"])
        XCTAssertTrue(ICloudSync.isSchemaNotReady(alone), "the wording alone, whatever the code")
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134060, userInfo: [NSUnderlyingErrorKey: message])
        XCTAssertTrue(ICloudSync.isSchemaNotReady(wrapped), "found under another error")
        let partial = NSError(domain: CKErrorDomain, code: CKError.partialFailure.rawValue,
                              userInfo: [CKPartialErrorsByItemIDKey: ["zone": message]])
        XCTAssertTrue(ICloudSync.isSchemaNotReady(partial), "found in a partial failure")
    }

    func testAPlainUnknownItemErrorIsNotReadAsNotReady() {
        let unknown = NSError(domain: CKErrorDomain, code: CKError.unknownItem.rawValue)
        XCTAssertFalse(ICloudSync.isSchemaNotReady(unknown), "an unknown item can be anything: a record, a zone, a share")
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134060, userInfo: [NSUnderlyingErrorKey: unknown])
        XCTAssertFalse(ICloudSync.isSchemaNotReady(wrapped))
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
        let notFound = NSError(domain: CKErrorDomain, code: CKError.serverRejectedRequest.rawValue,
                               userInfo: [NSLocalizedDescriptionKey: "Did not find record type: CD_Person"])
        XCTAssertEqual(ICloudSync.problemLine("Sent didn't finish", notFound), ICloudSync.notReadyLine)
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
        XCTAssertFalse(yml.contains("save-token"), "the token comes from the environment of each step")
        XCTAssertEqual(yml.components(separatedBy: "CLOUDKIT_MANAGEMENT_TOKEN: ${{ secrets.CLOUDKIT_MANAGEMENT_TOKEN }}").count - 1, 3,
                       "validate, import and export each take the token as environment")
        XCTAssertTrue(yml.contains("export-schema"), "the schema is exported after the import")
        XCTAssertTrue(yml.contains("exported.ckdb"))
        XCTAssertFalse(yml.lowercased().contains("pro" + "duction"))
    }
}
