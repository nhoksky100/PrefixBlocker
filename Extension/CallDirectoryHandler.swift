import Foundation
import CallKit

final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        do {
            let store = try SharedStorage.load()
            let phoneNumbers = try SharedStorage.buildBlockingNumbers(from: store.rules)

            context.removeAllBlockingEntries()
            for number in phoneNumbers {
                context.addBlockingEntry(withNextSequentialPhoneNumber: number)
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
