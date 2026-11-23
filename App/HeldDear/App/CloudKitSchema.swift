#if DEBUG
import CoreData
import Foundation

/// Debug builds only (never in a release build). Two jobs for the CloudKit schema fix:
///
/// 1. `CloudKitSchema.ckdb(for:)` writes the CloudKit schema file (`cloudkit/schema.ckdb`) from `CoreStore.model`, using
///    Apple's documented Core Data to CloudKit mapping, so the file is generated and never written by hand.
/// 2. `SchemaProbe` is the launch argument `-printCloudKitSchema`: the app builds the CloudKit store from the model,
///    asks Core Data for a dry run that prints the schema Apple would create (`.dryRun`, `.printSchema`; nothing is
///    uploaded), writes "done" or the error to a file in its temp folder, and quits. CI runs it in the simulator.
enum CloudKitSchema {
    /// The mapping, one line per attribute and per to-one link:
    /// - a record type `CD_<Entity>` with `CD_entityName`;
    /// - a field `CD_<attribute>`: strings, UUIDs and URLs are STRING; integers and booleans INT64; doubles DOUBLE;
    ///   dates TIMESTAMP; binary BYTES; an attribute kept outside the database as a large file is `CD_<attribute>_ckAsset` ASSET;
    ///   an attribute that iCloud encrypts is ENCRYPTED STRING (or ENCRYPTED type);
    /// - a to-one link is `CD_<link>`, a STRING holding the other record's name. A to-many link has no field of its
    ///   own: its to-one inverse holds it.
    /// - every record type has the indexes recordName QUERYABLE and CD_entityName QUERYABLE.
    static func field(for attribute: NSAttributeDescription) -> (name: String, line: String) {
        if attribute.attributeType == .binaryDataAttributeType, attribute.allowsExternalBinaryDataStorage {
            let name = "CD_\(attribute.name)_ckAsset"
            return (name, "\"\(name)\" ASSET")
        }
        let type: String
        switch attribute.attributeType {
        case .stringAttributeType, .UUIDAttributeType, .URIAttributeType: type = "STRING"
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType, .booleanAttributeType: type = "INT64"
        case .doubleAttributeType, .floatAttributeType: type = "DOUBLE"
        case .dateAttributeType: type = "TIMESTAMP"
        default: type = "BYTES"
        }
        let name = "CD_\(attribute.name)"
        return (name, "\"\(name)\" \(attribute.allowsCloudEncryption ? "ENCRYPTED " : "")\(type)")
    }

    static func field(for relationship: NSRelationshipDescription) -> (name: String, line: String)? {
        guard !relationship.isToMany else { return nil }
        let name = "CD_\(relationship.name)"
        return (name, "\"\(name)\" STRING")
    }

    /// The fields of one record type, in name order.
    static func fields(of entity: NSEntityDescription) -> [(name: String, line: String)] {
        var list: [(name: String, line: String)] = []
        for (_, a) in entity.attributesByName { list.append(field(for: a)) }
        for (_, r) in entity.relationshipsByName { if let f = field(for: r) { list.append(f) } }
        return list.sorted { $0.name < $1.name }
    }

    static func ckdb(for model: NSManagedObjectModel) -> String {
        var out = "DEFINE SCHEMA\n"
        for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            var lines = [
                "\"___createTime\" TIMESTAMP",
                "\"___createdBy\" REFERENCE",
                "\"___etag\" STRING",
                "\"___modTime\" TIMESTAMP",
                "\"___modifiedBy\" REFERENCE",
                "\"___recordID\" REFERENCE QUERYABLE",
                "\"CD_entityName\" STRING QUERYABLE",
            ]
            lines += fields(of: entity).map(\.line)
            let grants = ["GRANT WRITE TO \"_creator\"", "GRANT CREATE TO \"_icloud\"", "GRANT READ TO \"_world\""]
            out += "\n    RECORD TYPE CD_\(entity.name ?? "") (\n"
            out += (lines.map { "        \($0)," } + grants.enumerated().map { "        \($1)\($0 == grants.count - 1 ? "" : ",")" })
                .joined(separator: "\n")
            out += "\n    );\n"
        }
        return out
    }
}

enum SchemaProbe {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-printCloudKitSchema") }

    /// Runs the dry run, records the result in the temp folder, and quits. Never returns.
    static func runAndQuit() -> Never {
        let dir = FileManager.default.temporaryDirectory
        let done = dir.appendingPathComponent("schema-probe-done.txt")
        try? CloudKitSchema.ckdb(for: CoreStore.model).write(to: dir.appendingPathComponent("generated.ckdb"), atomically: true, encoding: .utf8)
        do {
            let container = NSPersistentCloudKitContainer(name: "HeldDear", managedObjectModel: CoreStore.model)
            let description = NSPersistentStoreDescription(url: dir.appendingPathComponent("SchemaProbe.sqlite"))
            description.type = NSSQLiteStoreType
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: ICloudSync.containerID)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.shouldAddStoreAsynchronously = false
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema(options: [.dryRun, .printSchema])
            try "done".write(to: done, atomically: true, encoding: .utf8)
        } catch {
            try? "error: \(ICloudSync.reason(error as NSError))".write(to: done, atomically: true, encoding: .utf8)
        }
        exit(0)
    }
}
#endif
