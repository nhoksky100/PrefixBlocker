import Foundation

public struct SharedStorage {
    // Tên App Group dùng chung giữa App chính và Extension
    private static let suiteName = "group.com.nhoksky100.PrefixBlocker"
    private static let blockedPrefixesKey = "blockedPrefixes"

    // Lưu danh sách đầu số cần chặn
    public static func save(prefixes: [String]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        defaults.set(prefixes, forKey: blockedPrefixesKey)
        defaults.synchronize()
    }

    // Đọc danh sách đầu số đã lưu
    public static func load() -> [String] {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return []
        }
        return defaults.stringArray(forKey: blockedPrefixesKey) ?? []
    }
}