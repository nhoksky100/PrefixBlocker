import Foundation
import CallKit

final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        do {
            guard SharedStorage.hasSharedAppGroupAccess else {
                throw PhoneNumberError.appGroupUnavailable
            }
            let store = try SharedStorage.load()
            let phoneNumbers = try SharedStorage.buildBlockingNumbers(from: store.rules)
            let sortedUniqueNumbers = Array(Set(phoneNumbers.filter { $0 > 0 })).sorted()

            context.removeAllBlockingEntries()
            var previousNumber: Int64 = 0
            for number in sortedUniqueNumbers where number > previousNumber {
                context.addBlockingEntry(withNextSequentialPhoneNumber: number)
                previousNumber = number
            }
            context.completeRequest()
        } catch {
            NSLog("Call Directory update failed: %@", error.localizedDescription)
            context.cancelRequest(withError: error)
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("Call Directory request failed: %@", error.localizedDescription)
    }
}
