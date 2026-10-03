import CloudKit
import Foundation

struct CloudDataService {
    private enum RecordType {
        static let sharedBellSchedule = "SharedBellSchedule"
        static let timetableBackup = "TimetableBackup"
    }

    private enum Field {
        static let payload = "payload"
        static let updatedAt = "updatedAt"
    }

    private static let sharedPrefix = "bell-schedule-"
    private static let backupRecordName = "personal-timetable-backup-v1"
    private static let maximumCodeGenerationAttempts = 10

    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    func accountIsAvailable() async throws -> Bool {
        try await container.accountStatus() == .available
    }

    func publish(_ site: BellSite) async throws -> String {
        let payload = try JSONEncoder().encode(SharedBellSchedule(site: site))

        for _ in 0..<Self.maximumCodeGenerationAttempts {
            let code = ShareCodeGenerator.generate()
            let recordID = CKRecord.ID(recordName: Self.sharedPrefix + code)

            guard try await !recordExists(recordID) else { continue }

            let record = CKRecord(
                recordType: RecordType.sharedBellSchedule,
                recordID: recordID
            )
            record[Field.payload] = payload as NSData
            record[Field.updatedAt] = Date.now as NSDate

            do {
                _ = try await container.publicCloudDatabase.save(record)
                return code
            } catch let error as CKError where error.code == .serverRecordChanged {
                // Un autre utilisateur a pu réserver le même code entre la vérification
                // et l'écriture. Un nouveau code est alors généré.
                continue
            }
        }

        throw CloudDataError.invalidShareCode
    }

    func sharedSchedule(for rawCode: String) async throws -> SharedBellSchedule {
        let code = normalizedShareCode(rawCode)
        guard ShareCodeGenerator.isValid(code) || UUID(uuidString: code) != nil else {
            throw CloudDataError.invalidShareCode
        }

        let recordID = CKRecord.ID(recordName: Self.sharedPrefix + code.lowercased())
        let record = try await container.publicCloudDatabase.record(for: recordID)
        guard let data = record[Field.payload] as? Data else {
            throw CloudDataError.invalidPayload
        }
        return try JSONDecoder().decode(SharedBellSchedule.self, from: data)
    }

    func saveBackup(_ backup: TimetableBackup) async throws {
        let recordID = CKRecord.ID(recordName: Self.backupRecordName)
        let record: CKRecord

        do {
            record = try await container.privateCloudDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: RecordType.timetableBackup, recordID: recordID)
        }

        let payload = try JSONEncoder().encode(backup)
        record.encryptedValues[Field.payload] = payload as NSData
        record[Field.updatedAt] = backup.savedAt as NSDate
        _ = try await container.privateCloudDatabase.save(record)
    }

    func fetchBackup() async throws -> TimetableBackup {
        let recordID = CKRecord.ID(recordName: Self.backupRecordName)
        let record = try await container.privateCloudDatabase.record(for: recordID)
        guard let data = record.encryptedValues[Field.payload] as? Data else {
            throw CloudDataError.invalidPayload
        }
        return try JSONDecoder().decode(TimetableBackup.self, from: data)
    }

    private func normalizedShareCode(_ rawCode: String) -> String {
        rawCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: Self.sharedPrefix, with: "", options: .caseInsensitive)
            .lowercased()
    }

    private func recordExists(_ recordID: CKRecord.ID) async throws -> Bool {
        do {
            _ = try await container.publicCloudDatabase.record(for: recordID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        }
    }
}

enum ShareCodeGenerator {
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
    static let length = 6

    static func generate() -> String {
        String((0..<length).map { _ in
            alphabet[Int.random(in: alphabet.indices)]
        })
    }

    static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }
}

enum CloudDataError: LocalizedError {
    case invalidShareCode
    case invalidPayload
    case siteLimitReached

    var errorDescription: String? {
        switch self {
        case .invalidShareCode:
            L("Le code de partage n’est pas valide.")
        case .invalidPayload:
            L("Les données iCloud reçues sont illisibles.")
        case .siteLimitReached:
            L("Supprimez un établissement avant d’en importer un autre.")
        }
    }
}
