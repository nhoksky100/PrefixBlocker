public struct SharedStorage {
    public static func save(prefixes: [String]) {
        // Đảm bảo dùng chung App Group Suite Name
        let defaults = UserDefaults(suiteName: "group.com.nhoksky100.PrefixBlocker")
        defaults?.set(prefixes, forKey: "blockedPrefixes")
    }
    
    public static func load() -> [String] {
        let defaults = UserDefaults(suiteName: "group.com.nhoksky100.PrefixBlocker")
        return defaults?.stringArray(forKey: "blockedPrefixes") ?? []
    }
}