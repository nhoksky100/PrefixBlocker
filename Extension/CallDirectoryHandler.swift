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

    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let suiteName = "group.com.yourname.PrefixBlocker"
        let rawPrefixes = UserDefaults(suiteName: suiteName)?.stringArray(forKey: "blocked_prefixes") ?? ["+8423", "+8425"]
        
        // 1. Làm sạch dấu '+' và chuyển thành số nguyên để sắp xếp tăng dần
        var numericPrefixes: [Int64] = []
        for item in rawPrefixes {
            let digitsOnly = item.replacingOccurrences(of: "+", with: "")
                                 .trimmingCharacters(in: .whitespacesAndNewlines)
            if let num = Int64(digitsOnly) {
                numericPrefixes.append(num)
            }
        }
        
        // BẮT BUỘC: Sắp xếp tăng dần tuyệt đối theo yêu cầu của Apple CallKit
        numericPrefixes.sort()

        // 2. Sinh danh sách số thuộc các đầu số đã chọn
        for basePrefix in numericPrefixes {
            // Ví dụ: +8423 -> basePrefix = 8423.
            // Số cố định VN sau 8423 có 8 chữ số nữa (tổng 12 chữ số: 8423xxxxxxxx)
            let multiplier: Int64 = 100_000_000 
            let startNumber = basePrefix * multiplier
            
            // Giới hạn 50.000 số mỗi đầu số để không vượt quá giới hạn RAM 6MB của Extension
            let limitCount: Int64 = 50_000 
            
            for i in 0..<limitCount {
                let phoneNumber: CXCallDirectoryPhoneNumber = startNumber + i
                context.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
            }
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        print("Lỗi CallKit: \(error.localizedDescription)")
    }
}