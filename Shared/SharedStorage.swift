import Foundation

public struct SharedStorage {
    private static let suiteName = "group.com.nhoksky100.PrefixBlocker"
    private static let blockedPrefixesKey = "blockedPrefixes"

    // Hàm lưu danh sách đầu số (khớp với ContentView.swift)
    public static func savePrefixes(_ prefixes: [String]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        defaults.set(prefixes, forKey: blockedPrefixesKey)
        defaults.synchronize()
    }

    // Hàm đọc danh sách đầu số (khớp với ContentView.swift và CallDirectoryHandler.swift)
    public static func getPrefixes() -> [String] {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return []
        }
        return defaults.stringArray(forKey: blockedPrefixesKey) ?? []
    }
}