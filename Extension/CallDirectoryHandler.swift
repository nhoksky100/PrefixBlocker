import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // Luôn xóa dữ liệu cũ trước khi nạp lại danh sách đã sắp xếp tăng dần
        context.removeAllBlockingEntries()

        let rules = SharedStorage.loadRules()
        let phoneNumbers = SharedStorage.buildBlockingNumbers(from: rules)

        for number in phoneNumbers where number > 0 {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }

        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("CallDirectory request failed: %@", error.localizedDescription)
    }
}