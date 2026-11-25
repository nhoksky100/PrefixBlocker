import Foundation
import CallKit

final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // 1. Chỉ xóa danh sách cũ khi iOS chạy ở chế độ cập nhật tăng dần (isIncremental == true)
        if context.isIncremental {
            context.removeAllBlockingEntries()
        }

        // 2. Đọc danh sách số an toàn, không ném lỗi cancelRequest nếu App Group bị giới hạn bởi AltStore
        var rawNumbers: [Int64] = []
        if SharedStorage.hasSharedAppGroupAccess,
           let store = try? SharedStorage.load(),
           let built = try? SharedStorage.buildBlockingNumbers(from: store.rules) {
            rawNumbers = built
        }

        // 3. Lọc số dương, loại trùng và sắp xếp tăng dần nghiêm ngặt theo chuẩn CallKit
        let sortedUniqueNumbers = Array(Set(rawNumbers.filter { $0 > 0 })).sorted()

        var previousNumber: Int64 = 0
        for number in sortedUniqueNumbers where number > previousNumber {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
            previousNumber = number
        }

        // 4. Luôn báo hoàn tất để iOS cho phép bật công tắc trong Cài đặt
        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("Call Directory request failed: %@", error.localizedDescription)
    }
}