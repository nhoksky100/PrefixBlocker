import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self
        
        if context.isIncremental {
            context.removeAllBlockingEntries()
        }
        
        addAllBlockingPhoneNumbers(to: context)
        context.completeRequest()
    }
    
    private func addAllBlockingPhoneNumbers(to: CXCallDirectoryExtensionContext) {
        let suiteName = "group.com.nhoksky100.ChanSoRac"
        let rawPrefixes = UserDefaults(suiteName: suiteName)?.stringArray(forKey: "blocked_prefixes") ?? ["+8423", "+8424", "+8425"]
        
        var numericPrefixes: [Int64] = []
        for item in rawPrefixes {
            let digitsOnly = item.replacingOccurrences(of: "+", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let num = Int64(digitsOnly) {
                numericPrefixes.append(num)
            }
        }
        
        numericPrefixes.sort()
        
        for basePrefix in numericPrefixes {
            let startNumber = basePrefix * 100_000_000
            let endNumber = startNumber + 99_999_999
            for phoneNumber in startNumber...endNumber {
                to.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
            }
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        print("CallDirectory request failed: \(error.localizedDescription)")
    }
}