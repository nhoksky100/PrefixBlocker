import Foundation

enum PhoneCategory: String, Codable, CaseIterable, Identifiable {
    case spam = "Số rác"
    case trusted = "Số chính chủ"
    case unknown = "Số lạ"

    var id: String { rawValue }
}

enum RuleKind: String, Codable, CaseIterable, Identifiable {
    case prefix = "Đầu số"
    case exact = "Số đầy đủ"
    case range = "Dải số"

    var id: String { rawValue }
}

struct ManagedProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var targetPhone: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, targetPhone: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.targetPhone = targetPhone
        self.createdAt = createdAt
    }
}

struct ManagedRule: Codable, Identifiable, Equatable {
    var id: UUID
    var profileID: UUID
    var kind: RuleKind
    var value: String
    var rangeEnd: String
    var category: PhoneCategory
    var isEnabled: Bool
    var recordCount: Int
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        profileID: UUID,
        kind: RuleKind,
        value: String,
        rangeEnd: String = "",
        category: PhoneCategory,
        isEnabled: Bool = true,
        recordCount: Int = 1,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.profileID = profileID
        self.kind = kind
        self.value = value
        self.rangeEnd = rangeEnd
        self.category = category
        self.isEnabled = isEnabled
        self.recordCount = recordCount
        self.lastUpdated = lastUpdated
    }

    var displayValue: String {
        if kind == .range {
            return "+\(value) – +\(rangeEnd)"
        }
        return "+\(value)"
    }
}

struct DirectoryData: Codable {
    var profiles: [ManagedProfile]
    var rules: [ManagedRule]

    static var empty: DirectoryData {
        DirectoryData(profiles: [], rules: [])
    }
}

enum PhoneNumberError: LocalizedError {
    case invalidPhone
    case invalidPrefix
    case invalidRange
    case rangeTooLarge
    case tooManyEntries
    case appGroupUnavailable
    case unreadableData

    var errorDescription: String? {
        switch self {
        case .invalidPhone:
            return "Số điện thoại không hợp lệ. Hãy nhập số Việt Nam đầy đủ."
        case .invalidPrefix:
            return "Đầu số không hợp lệ. Hãy nhập ít nhất mã quốc gia và một chữ số, ví dụ +8423 hoặc 023."
        case .invalidRange:
            return "Dải số không hợp lệ hoặc hai đầu mút khác độ dài."
        case .rangeTooLarge:
            return "Mỗi dải CallKit tối đa 10.000 số."
        case .tooManyEntries:
            return "Tổng danh sách CallKit vượt giới hạn an toàn 10.000 số. Hãy thu hẹp hoặc tắt bớt dải."
        case .appGroupUnavailable:
            return "Không truy cập được App Group. Hãy kiểm tra cấu hình ký ứng dụng và extension."
        case .unreadableData:
            return "Dữ liệu đã lưu không đọc được. Hãy sao lưu hoặc xóa dữ liệu ứng dụng trước khi tiếp tục."
        }
    }
}

enum VietnamPhoneNumber {
    static func normalize(_ raw: String) -> String? {
        let allowedPunctuation: Set<UInt32> = [43, 45, 40, 41, 46]
        guard raw.unicodeScalars.allSatisfy({ scalar in
            (scalar.value >= 48 && scalar.value <= 57)
                || allowedPunctuation.contains(scalar.value)
                || CharacterSet.whitespacesAndNewlines.contains(scalar)
        }) else {
            return nil
        }

        let digits = raw.unicodeScalars
            .filter { $0.value >= 48 && $0.value <= 57 }
            .map { String($0) }
            .joined()

        guard !digits.isEmpty else { return nil }

        if digits.hasPrefix("0084") {
            return "84" + String(digits.dropFirst(4))
        }
        if digits.hasPrefix("0") {
            return "84" + String(digits.dropFirst())
        }
        if digits.hasPrefix("84") {
            return digits
        }
        if digits.count == 9 {
            return "84" + digits
        }
        return nil
    }

    static func isCompleteSubscriberNumber(_ digits: String) -> Bool {
        guard digits.hasPrefix("84") else { return false }
        let subscriberLength = digits.count - 2
        return subscriberLength == 9 || subscriberLength == 10
    }

    static func normalizePrefix(_ raw: String) -> String? {
        guard let digits = normalize(raw),
              digits.hasPrefix("84"),
              digits.count >= 3,
              digits.count < 13 else {
            return nil
        }
        return digits
    }
}

enum SharedStorage {
    static let suiteName = "group.com.nhoksky100.ChanSoRac"
    static let teamScopedSuiteName = "group.com.nhoksky100.ChanSoRac.68977G9KU3"
    private static let suiteNames = [teamScopedSuiteName, suiteName]
    private static let storeFileName = "chan_so_rac_store_v2.json"
    private static let storeDataKey = "chan_so_rac_store_v2_data"
    private static let legacyRulesKey = "chan_so_rac_rules_v1"
    static let maximumCallKitEntries = 10_000
    static let maximumRangeEntries = 10_000

    private static var appGroupContainerURLs: [URL] {
        suiteNames.compactMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    }

    private static var appGroupDefaults: [UserDefaults] {
        suiteNames.compactMap { UserDefaults(suiteName: $0) }
    }

    static var hasSharedAppGroupAccess: Bool {
        !appGroupContainerURLs.isEmpty || !appGroupDefaults.isEmpty
    }

    static var isUsingFallbackStorage: Bool {
        !hasSharedAppGroupAccess
    }

    static var storageModeMessage: String {
        isUsingFallbackStorage
            ? "App Group không khả dụng; dữ liệu đang lưu trong UserDefaults/Documents riêng của ứng dụng. Call Directory extension không thể đọc kho dự phòng này."
            : "Đang dùng App Group để chia sẻ dữ liệu với Call Directory extension."
    }

    private struct LegacyRule: Decodable {
        var targetPhone: String
        var prefix: String
        var category: PhoneCategory
        var isEnabled: Bool
        var hitCount: Int
        var lastUpdated: Date
    }

    static func load() throws -> DirectoryData {
        let groupURLs = appGroupContainerURLs
        for containerURL in groupURLs {
            let fileURL = containerURL.appendingPathComponent(storeFileName, isDirectory: false)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return try decodeStore(at: fileURL)
            }
        }

        let groupDefaults = appGroupDefaults
        for defaults in groupDefaults {
            if let data = defaults.data(forKey: storeDataKey) {
                return try decodeStore(data)
            }
        }

        for defaults in groupDefaults {
            if let legacyData = defaults.data(forKey: legacyRulesKey) {
                let migrated = try decodeLegacyRules(legacyData)
                try save(migrated)
                return migrated
            }
        }

        if !isUsingFallbackStorage {
            return .empty
        }

        if let fallbackURL = fallbackFileURL(),
           FileManager.default.fileExists(atPath: fallbackURL.path) {
            return try decodeStore(at: fallbackURL)
        }

        let standardDefaults = UserDefaults.standard
        if let data = standardDefaults.data(forKey: storeDataKey) {
            return try decodeStore(data)
        }
        if let legacyData = standardDefaults.data(forKey: legacyRulesKey) {
            let migrated = try decodeLegacyRules(legacyData)
            try save(migrated)
            return migrated
        }

        return .empty
    }

    static func save(_ store: DirectoryData) throws {
        let data = try JSONEncoder().encode(store)
        let groupURLs = appGroupContainerURLs
        let groupDefaults = appGroupDefaults

        if let containerURL = groupURLs.first {
            let fileURL = containerURL.appendingPathComponent(storeFileName, isDirectory: false)
            try write(data, to: fileURL)
            return
        }

        if let defaults = groupDefaults.first {
            defaults.set(data, forKey: storeDataKey)
            _ = defaults.synchronize()
            return
        }

        guard let fallbackURL = fallbackFileURL() else {
            throw PhoneNumberError.appGroupUnavailable
        }
        UserDefaults.standard.set(data, forKey: storeDataKey)
        do {
            try write(data, to: fallbackURL)
        } catch {
            NSLog("Fallback Documents write failed; UserDefaults.standard has the store: %@", error.localizedDescription)
        }
    }

    private static func decodeStore(at url: URL) throws -> DirectoryData {
        do {
            return try decodeStore(Data(contentsOf: url))
        } catch let error as PhoneNumberError {
            throw error
        } catch {
            throw PhoneNumberError.unreadableData
        }
    }

    private static func decodeStore(_ data: Data) throws -> DirectoryData {
        do {
            return try JSONDecoder().decode(DirectoryData.self, from: data)
        } catch {
            throw PhoneNumberError.unreadableData
        }
    }

    private static func decodeLegacyRules(_ data: Data) throws -> DirectoryData {
        guard let legacyRules = try? JSONDecoder().decode([LegacyRule].self, from: data) else {
            throw PhoneNumberError.unreadableData
        }
        return migrate(legacyRules)
    }

    private static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    private static func fallbackFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(storeFileName, isDirectory: false)
    }

    static func buildBlockingNumbers(from rules: [ManagedRule]) throws -> [Int64] {
        var numbers = Set<Int64>()

        for rule in rules where rule.isEnabled && rule.category == .spam {
            switch rule.kind {
            case .prefix:
                // Call Directory has no wildcard support. Prefixes remain app-side matching rules.
                continue
            case .exact:
                guard VietnamPhoneNumber.isCompleteSubscriberNumber(rule.value),
                      let number = Int64(rule.value) else {
                    continue
                }
                numbers.insert(number)
            case .range:
                guard VietnamPhoneNumber.isCompleteSubscriberNumber(rule.value),
                      VietnamPhoneNumber.isCompleteSubscriberNumber(rule.rangeEnd),
                      rule.value.count == rule.rangeEnd.count,
                      let start = Int64(rule.value),
                      let end = Int64(rule.rangeEnd),
                      end >= start else {
                    continue
                }

                let count = end - start + 1
                guard count <= maximumRangeEntries else {
                    throw PhoneNumberError.rangeTooLarge
                }
                var number = start
                while number <= end {
                    numbers.insert(number)
                    number += 1
                }
            }

            guard numbers.count <= maximumCallKitEntries else {
                throw PhoneNumberError.tooManyEntries
            }
        }

        return numbers.sorted()
    }

    static func matchingRules(for phone: String, in rules: [ManagedRule]) -> [ManagedRule] {
        guard let digits = VietnamPhoneNumber.normalize(phone),
              VietnamPhoneNumber.isCompleteSubscriberNumber(digits) else {
            return []
        }

        return rules.filter { rule in
            guard rule.isEnabled else { return false }
            switch rule.kind {
            case .prefix:
                return digits.hasPrefix(rule.value)
            case .exact:
                return digits == rule.value
            case .range:
                guard let number = Int64(digits),
                      let start = Int64(rule.value),
                      let end = Int64(rule.rangeEnd) else { return false }
                return number >= start && number <= end
            }
        }.sorted { lhs, rhs in
            let leftLength = lhs.value.count
            let rightLength = rhs.value.count
            if leftLength != rightLength { return leftLength > rightLength }
            return lhs.lastUpdated > rhs.lastUpdated
        }
    }

    private static func migrate(_ legacyRules: [LegacyRule]) -> DirectoryData {
        var profiles: [ManagedProfile] = []
        var rules: [ManagedRule] = []

        for oldRule in legacyRules {
            let name = oldRule.targetPhone.isEmpty || oldRule.targetPhone == "Chính"
                ? "Hồ sơ chính"
                : oldRule.targetPhone
            let profile: ManagedProfile
            if let existing = profiles.first(where: { $0.name == name }) {
                profile = existing
            } else {
                let target = VietnamPhoneNumber.normalize(oldRule.targetPhone)
                profile = ManagedProfile(name: name, targetPhone: target ?? "")
                profiles.append(profile)
            }

            guard let prefix = VietnamPhoneNumber.normalizePrefix(oldRule.prefix) else { continue }
            rules.append(ManagedRule(
                profileID: profile.id,
                kind: .prefix,
                value: prefix,
                category: oldRule.category,
                isEnabled: oldRule.isEnabled,
                recordCount: max(0, oldRule.hitCount),
                lastUpdated: oldRule.lastUpdated
            ))
        }

        return DirectoryData(profiles: profiles, rules: rules)
    }
}
