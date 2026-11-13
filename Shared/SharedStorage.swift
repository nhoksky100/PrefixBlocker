import Foundation

class SharedStorage {
    static let suiteName = "group.com.yourname.PrefixBlocker"
    static let prefixesKey = "blocked_prefixes"
    
    static func savePrefixes(_ prefixes: [String]) {
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.set(prefixes, forKey: prefixesKey)
            defaults.synchronize()
        }
    }
    
    static func getPrefixes() -> [String] {
        if let defaults = UserDefaults(suiteName: suiteName) {
            return defaults.stringArray(forKey: prefixesKey) ?? ["+8423", "+8425"]
        }
        return ["+8423", "+8425"]
    }
}