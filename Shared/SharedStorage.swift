import Foundation

struct SharedStorage {
    static let suiteName = "group.com.nhoksky100.ChanSoRac"
    static let key = "blocked_prefixes"
    
    static func getPrefixes() -> [String] {
        let defaults = UserDefaults(suiteName: suiteName)
        return defaults?.stringArray(forKey: key) ?? ["+8423", "+8424", "+8425", "+8426", "+8427", "+8428", "+8429"]
    }
    
    static func savePrefixes(_ prefixes: [String]) {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(prefixes, forKey: key)
    }
}