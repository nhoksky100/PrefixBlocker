import Foundation

enum PhoneCategory: String, Codable, CaseIterable {
    case spam = "Số rác"
    case trusted = "Số chính chủ"
    case unknown = "Số lạ"
}

struct BlockedRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var targetPhone: String          // Số điện thoại đích / hồ sơ cần áp dụng cụm chặn
    var prefix: String               // Cụm đầu số chặn, VD: "+8423" hoặc "8423"
    var category: PhoneCategory      // Phân loại: Số rác / Số chính chủ / Số lạ
    var isEnabled: Bool = true
    var hitCount: Int = 1            // Số lần ghi nhận / kiểm tra trong app
    var lastUpdated: Date = Date()   // Thời gian cập nhật / ghi nhận gần nhất
}

struct SharedStorage {
    static let suiteName = "group.com.nhoksky100.ChanSoRac"
    static let rulesKey = "chan_so_rac_rules_v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func defaultRules() -> [BlockedRule] {
        let now = Date()
        return [
            BlockedRule(targetPhone: "Chính", prefix: "+8423", category: .spam, isEnabled: true, hitCount: 1, lastUpdated: now),
            BlockedRule(targetPhone: "Chính", prefix: "+8424", category: .spam, isEnabled: true, hitCount: 1, lastUpdated: now),
            BlockedRule(targetPhone: "Chính", prefix: "+8425", category: .spam, isEnabled: true, hitCount: 1, lastUpdated: now)
        ]
    }

    static func loadRules() -> [BlockedRule] {
        guard let data = defaults?.data(forKey: rulesKey),
              let decoded = try? JSONDecoder().decode([BlockedRule].self, from: data),
              !decoded.isEmpty else {
            let initial = defaultRules()
            saveRules(initial)
            return initial
        }
        return decoded
    }

    static func saveRules(_ rules: [BlockedRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults?.set(data, forKey: rulesKey)
        defaults?.synchronize()
    }

    /// Chuẩn hóa chuỗi số thành số nguyên dương hợp lệ cho CallKit (không dấu +, bỏ số 0 đầu nếu có dạng 0xxx -> 84xxx)
    static func normalizePhoneNumber(_ raw: String) -> Int64? {
        var digits = raw.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        if digits.hasPrefix("0") && digits.count >= 9 {
            digits = "84" + String(digits.dropFirst())
        }
        return Int64(digits)
    }

    /// Sinh danh sách số điện thoại hợp lệ, tăng dần tuyệt đối để nạp vào CallKit
    static func buildBlockingNumbers(from rules: [BlockedRule]) -> [Int64] {
        var uniqueNumbers = Set<Int64>()

        for rule in rules where rule.isEnabled && rule.category == .spam {
            guard let base = normalizePhoneNumber(rule.prefix), base > 0 else { continue }

            // Nếu người dùng nhập đầu số ngắn (ví dụ 8423), mở rộng theo các đuôi phổ biến có kiểm soát
            // tránh tạo hàng trăm triệu số gây đứng extension
            if base < 100_000 {
                uniqueNumbers.insert(base)
                // Sinh các số mẫu 10-11 chữ số theo đầu số (ví dụ 8423xxxxxxxx)
                let scale: Int64 = base < 10_000 ? 100_000_000 : 10_000_000
                let start = base * scale
                // Giới hạn tối đa 20.000 số mỗi đầu số để đảm bảo reload nhanh trên iOS
                let limit = min(scale, 20_000)
                for offset in 0..<limit {
                    uniqueNumbers.insert(start + offset)
                }
            } else {
                uniqueNumbers.insert(base)
            }
        }

        return uniqueNumbers.sorted()
    }
}