import SwiftUI
import CallKit
import UIKit

private enum ContentField: Hashable {
    case profileName
    case profilePhone
    case ruleValue
    case rangeEnd
    case phoneToCheck
}

struct ContentView: View {
    private var extensionBundleID: String {
        "\(Bundle.main.bundleIdentifier ?? "com.nhoksky100.ChanSoRac").CallBlockerExtension"
    }

    @State private var store = DirectoryData.empty
    @State private var selectedProfileID: UUID?
    @State private var profileName = ""
    @State private var profilePhone = ""
    @State private var ruleValue = ""
    @State private var rangeEnd = ""
    @State private var phoneToCheck = ""
    @State private var ruleKind: RuleKind = .prefix
    @State private var selectedCategory: PhoneCategory = .spam
    @State private var checkMatches: [ManagedRule] = []
    @State private var hasCheckedPhone = false
    @State private var profileFeedback = ""
    @State private var ruleFeedback = ""
    @State private var checkFeedback = ""
    @State private var syncFeedback = "Đang tải dữ liệu..."
    @State private var callKitStatusText = "Chưa kiểm tra trạng thái CallKit"
    @State private var isReloading = false
    @State private var storageReady = true
    @State private var hasLoadedStore = false
    @FocusState private var focusedField: ContentField?

    private let paper = Color(red: 0.96, green: 0.93, blue: 0.86)
    private let ink = Color(red: 0.17, green: 0.17, blue: 0.14)
    private let olive = Color(red: 0.31, green: 0.36, blue: 0.25)
    private let rust = Color(red: 0.57, green: 0.25, blue: 0.19)
    private let ruleLine = Color(red: 0.70, green: 0.65, blue: 0.54)

    private var selectedProfile: ManagedProfile? {
        store.profiles.first { $0.id == selectedProfileID }
    }

    private var callKitNumberCountLabel: String {
        do {
            let count = try SharedStorage.buildBlockingNumbers(from: store.rules).count
            return "\(count) số đầy đủ sẽ được nạp • giới hạn an toàn \(SharedStorage.maximumCallKitEntries.formatted())"
        } catch {
            return "Danh sách không hợp lệ: \(error.localizedDescription)"
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    masthead
                    callKitCard
                    profileCard
                    ruleEditorCard
                    quickCheckCard
                    managedRulesCard
                    systemNote
                }
                .padding(16)
            }
            .background(paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong") {
                    dismissKeyboard()
                }
                .foregroundColor(olive)
            }
        }
        .onAppear(perform: loadStore)
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CHAN SỐ RÁC")
                .font(.system(size: 28, weight: .black, design: .serif))
                .tracking(1.4)
                .foregroundColor(ink)
            HStack {
                Text("SỔ TAY QUẢN LÝ CUỘC GỌI")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(2)
                Spacer()
                Text(Date().formatted(date: .long, time: .omitted).uppercased())
                    .font(.system(size: 9, weight: .medium, design: .serif))
            }
            .foregroundColor(olive)
            Rectangle().fill(ink).frame(height: 1)
            Text("Hồ sơ, quy tắc và danh sách số được lưu riêng trên thiết bị.")
                .font(.system(size: 13, design: .serif))
                .foregroundColor(ink.opacity(0.75))
        }
    }

    private var callKitCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("ĐỒNG BỘ CALLKIT", number: "01")
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isReloading ? "arrow.triangle.2.circlepath" : "checkmark.shield")
                    .foregroundColor(isReloading ? rust : olive)
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text(callKitStatusText)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(ink)
                    Text(callKitNumberCountLabel)
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(ink.opacity(0.7))
                }
            }
            Button(action: syncCallDirectory) {
                HStack {
                    if isReloading { ProgressView().tint(paper) }
                    Text(isReloading ? "ĐANG ĐỒNG BỘ…" : "ĐỒNG BỘ DANH SÁCH SỐ")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .tracking(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(olive)
                .foregroundColor(paper)
            }
            feedbackLabel(syncFeedback)
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8).allowsHitTesting(false))
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeading("HỒ SƠ CẦN BẢO VỆ", number: "02")
            if store.profiles.isEmpty {
                Text("Tạo hồ sơ trước khi gán quy tắc. Hồ sơ là nhãn quản lý; CallKit áp dụng danh sách trên toàn thiết bị.")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(ink.opacity(0.75))
            } else {
                Picker("Chọn hồ sơ", selection: $selectedProfileID) {
                    Text("Chọn hồ sơ").tag(Optional<UUID>.none)
                    ForEach(store.profiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .tint(olive)

                if let profile = selectedProfile {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.system(size: 15, weight: .bold, design: .serif))
                            Text(profile.targetPhone.isEmpty
                                 ? "Chưa khai báo số đích"
                                 : (VietnamPhoneNumber.normalize(profile.targetPhone).map { "+\($0)" } ?? profile.targetPhone))
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(ink.opacity(0.7))
                        }
                        Spacer()
                        Button("XÓA") { deleteProfile(profile) }
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .foregroundColor(rust)
                    }
                    .padding(10)
                    .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.7).allowsHitTesting(false))
                }
            }

            TextField("Tên hồ sơ (để trống sẽ tự đặt tên)", text: $profileName)
                .focused($focusedField, equals: .profileName)
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            TextField("Số điện thoại đích (không bắt buộc)", text: $profilePhone)
                .keyboardType(.phonePad)
                .focused($focusedField, equals: .profilePhone)
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            Button(action: addProfile) {
                Text("TẠO HỒ SƠ")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(olive, lineWidth: 1).allowsHitTesting(false))
                    .foregroundColor(olive)
            }
            feedbackLabel(profileFeedback)
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8).allowsHitTesting(false))
    }

    private var ruleEditorCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeading("GÁN QUY TẮC CHO HỒ SƠ", number: "03")
            if selectedProfile == nil {
                Text("Hãy chọn hoặc tạo hồ sơ trước.")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(rust)
            }
            Picker("Loại quy tắc", selection: $ruleKind) {
                ForEach(RuleKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            TextField(rulePlaceholder, text: $ruleValue)
                .keyboardType(.phonePad)
                .focused($focusedField, equals: .ruleValue)
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            if ruleKind == .range {
                TextField("Đến số (ví dụ: 0912345699)", text: $rangeEnd)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .rangeEnd)
                    .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            }
            HStack {
                Text("Phân loại")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(ink)
                Spacer()
                Picker("Phân loại", selection: $selectedCategory) {
                    ForEach(PhoneCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .tint(olive)
            }
            if ruleKind == .prefix {
                Text("Đầu số chỉ dùng để đối chiếu trong ứng dụng; CallKit không hỗ trợ chặn wildcard.")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(rust)
            } else if ruleKind == .range {
                Text("Dải được liệt kê thành số đầy đủ; tối đa 10.000 số cho mỗi dải.")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(ink.opacity(0.7))
            }
            Button(action: addRule) {
                Text("LƯU QUY TẮC VÀO HỒ SƠ")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(rust)
                    .foregroundColor(paper)
            }
            feedbackLabel(ruleFeedback)
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8).allowsHitTesting(false))
    }

    private var quickCheckCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("TRA CỨU NHANH", number: "04")
            TextField("Nhập số cần kiểm tra", text: $phoneToCheck)
                .keyboardType(.phonePad)
                .focused($focusedField, equals: .phoneToCheck)
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
                .onChange(of: phoneToCheck) { _ in
                    hasCheckedPhone = false
                    checkFeedback = ""
                }
            Button(action: checkPhone) {
                Text("KIỂM TRA SỐ")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(olive, lineWidth: 1).allowsHitTesting(false))
                    .foregroundColor(olive)
            }
            if hasCheckedPhone {
                if checkMatches.isEmpty {
                    Text("Không khớp quy tắc đang bật • phân loại: Số lạ")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(olive)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Khớp \(checkMatches.count) quy tắc:")
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .foregroundColor(ink)
                        ForEach(checkMatches) { rule in
                            Text("\(rule.category.rawValue) • \(rule.displayValue) • \(profileName(for: rule.profileID))")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(rule.category == .spam ? rust : olive)
                            Text(callKitDisposition(for: rule))
                                .font(.system(size: 10, design: .serif))
                                .foregroundColor(ink.opacity(0.65))
                        }
                    }
                }
            }
            feedbackLabel(checkFeedback)
            Text("Mỗi lần tra cứu khớp sẽ tăng bộ đếm của quy tắc tương ứng.")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(ink.opacity(0.65))
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8).allowsHitTesting(false))
    }

    private var managedRulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("SỔ QUY TẮC ĐÃ QUẢN LÝ", number: "05")
            if store.rules.isEmpty {
                Text("Chưa có quy tắc nào.")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(ink.opacity(0.7))
            } else {
                ForEach(store.rules.sorted(by: { $0.lastUpdated > $1.lastUpdated })) { rule in
                    ruleRow(rule)
                }
            }
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8).allowsHitTesting(false))
    }

    private var systemNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("GHI CHÚ KỸ THUẬT")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundColor(rust)
            Text("iOS không cho ứng dụng bên thứ ba đọc nhật ký cuộc gọi đến hoặc xác nhận những cuộc gọi thực tế đã bị CallKit chặn. Bộ đếm trong sổ chỉ ghi nhận thao tác quản lý và tra cứu trong ứng dụng.")
                .font(.system(size: 11, design: .serif))
                .foregroundColor(ink.opacity(0.82))
        }
        .padding(12)
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8).allowsHitTesting(false))
    }

    private var rulePlaceholder: String {
        switch ruleKind {
        case .prefix: return "Đầu số (ví dụ: +8423, 023, 8423)"
        case .exact: return "Số đầy đủ (ví dụ: 0912345678)"
        case .range: return "Từ số (ví dụ: 0912345600)"
        }
    }

    private func sectionHeading(_ title: String, number: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(rust)
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .serif))
                .tracking(0.7)
                .foregroundColor(ink)
            Rectangle().fill(ruleLine).frame(height: 0.7)
        }
    }

    private func ruleRow(_ rule: ManagedRule) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.displayValue)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(ink)
                    Text("\(rule.kind.rawValue) • \(rule.category.rawValue) • \(profileName(for: rule.profileID))")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(rule.category == .spam ? rust : olive)
                }
                Spacer()
                Button(action: { deleteRule(rule) }) {
                    Image(systemName: "trash")
                        .foregroundColor(rust)
                }
                .accessibilityLabel("Xóa quy tắc")
            }
            HStack {
                Text("Ghi nhận/tra cứu: \(rule.recordCount)")
                Spacer()
                Text(rule.lastUpdated.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.system(size: 10, design: .serif))
            .foregroundColor(ink.opacity(0.65))
            HStack {
                Text(rule.isEnabled ? "ĐANG BẬT" : "ĐANG TẮT")
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .tracking(0.8)
                    .foregroundColor(rule.isEnabled ? olive : rust)
                Spacer()
                Toggle("Bật quy tắc", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { setRuleEnabled(rule.id, enabled: $0) }
                ))
                .labelsHidden()
                .tint(olive)
                .scaleEffect(0.85, anchor: .trailing)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .overlay(Rectangle().stroke(ruleLine.opacity(0.8), lineWidth: 0.6).allowsHitTesting(false))
    }

    private func loadStore() {
        guard !hasLoadedStore else { return }
        hasLoadedStore = true
        do {
            store = try SharedStorage.load()
            selectedProfileID = store.profiles.first?.id
            storageReady = true
            syncFeedback = "\(SharedStorage.storageModeMessage) Đã tải \(store.profiles.count) hồ sơ và \(store.rules.count) quy tắc."
            refreshCallKitStatus()
        } catch {
            storageReady = false
            syncFeedback = "Lỗi tải App Group: \(error.localizedDescription)"
        }
    }

    private func addProfile() {
        dismissKeyboard()
        profileFeedback = ""

        let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneInput = profilePhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPhone = VietnamPhoneNumber.normalize(phoneInput) ?? phoneInput

        let profileName = name.isEmpty ? "Hồ sơ \(store.profiles.count + 1)" : name
        let profile = ManagedProfile(name: profileName, targetPhone: savedPhone)
        var updatedStore = store
        updatedStore.profiles.append(profile)

        do {
            try SharedStorage.save(updatedStore)
            store = updatedStore
            selectedProfileID = profile.id
            self.profileName = ""
            profilePhone = ""
            profileFeedback = "Đã tạo và chọn “\(profile.name)” (\(store.profiles.count) hồ sơ). \(SharedStorage.storageModeMessage)"
            storageReady = true
        } catch {
            profileFeedback = "Lỗi lưu hồ sơ: \(error.localizedDescription)"
        }
    }

    private func addRule() {
        dismissKeyboard()
        ruleFeedback = ""

        guard let profile = selectedProfile else {
            ruleFeedback = "Lỗi: Hãy tạo hoặc chọn hồ sơ trước khi lưu quy tắc."
            return
        }

        let value: String
        var endValue = ""
        switch ruleKind {
        case .prefix:
            guard let normalized = VietnamPhoneNumber.normalizePrefix(ruleValue) else {
                ruleFeedback = "Lỗi: Đầu số chưa hợp lệ. Ví dụ đúng: +8423, 023 hoặc 8423."
                return
            }
            value = normalized
        case .exact:
            guard let normalized = VietnamPhoneNumber.normalize(ruleValue),
                  VietnamPhoneNumber.isCompleteSubscriberNumber(normalized) else {
                ruleFeedback = "Lỗi: Hãy nhập số điện thoại Việt Nam đầy đủ."
                return
            }
            value = normalized
        case .range:
            guard let start = VietnamPhoneNumber.normalize(ruleValue),
                  let end = VietnamPhoneNumber.normalize(rangeEnd),
                  VietnamPhoneNumber.isCompleteSubscriberNumber(start),
                  VietnamPhoneNumber.isCompleteSubscriberNumber(end),
                  start.count == end.count,
                  let startNumber = Int64(start),
                  let endNumber = Int64(end),
                  endNumber >= startNumber else {
                ruleFeedback = "Lỗi: Hãy nhập dải số hợp lệ, cùng độ dài và số cuối không nhỏ hơn số đầu."
                return
            }
            guard endNumber - startNumber + 1 <= SharedStorage.maximumRangeEntries else {
                ruleFeedback = "Lỗi: Mỗi dải CallKit tối đa 10.000 số."
                return
            }
            value = start
            endValue = end
        }

        let rule = ManagedRule(
            profileID: profile.id,
            kind: ruleKind,
            value: value,
            rangeEnd: endValue,
            category: selectedCategory
        )
        var updatedStore = store
        updatedStore.rules.append(rule)
        do {
            _ = try SharedStorage.buildBlockingNumbers(from: updatedStore.rules)
            try SharedStorage.save(updatedStore)
            store = updatedStore
            ruleValue = ""
            rangeEnd = ""
            ruleFeedback = "Đã lưu \(rule.kind.rawValue.lowercased()) \(rule.displayValue) vào “\(profile.name)”. Tổng \(store.rules.count) quy tắc."
            storageReady = true
            syncCallDirectory()
        } catch {
            ruleFeedback = "Lỗi lưu quy tắc: \(error.localizedDescription)"
        }
    }

    private func checkPhone() {
        dismissKeyboard()
        hasCheckedPhone = false
        checkMatches = []
        checkFeedback = ""

        guard storageReady else {
            checkFeedback = "Lỗi: Không đọc được dữ liệu App Group để tra cứu."
            return
        }
        guard let number = VietnamPhoneNumber.normalize(phoneToCheck),
              VietnamPhoneNumber.isCompleteSubscriberNumber(number) else {
            checkFeedback = "Lỗi: Hãy nhập số Việt Nam đầy đủ rồi bấm kiểm tra."
            return
        }
        let matches = SharedStorage.matchingRules(for: number, in: store.rules)
        checkMatches = matches
        hasCheckedPhone = true
        guard !matches.isEmpty else {
            checkFeedback = "Đã kiểm tra +\(number): không khớp quy tắc đang bật; phân loại Số lạ."
            return
        }

        let matchedIDs = Set(matches.map(\.id))
        var updatedStore = store
        updatedStore.rules = updatedStore.rules.map { rule in
            guard matchedIDs.contains(rule.id) else { return rule }
            var updated = rule
            updated.recordCount += 1
            updated.lastUpdated = Date()
            return updated
        }
        do {
            try SharedStorage.save(updatedStore)
            store = updatedStore
            checkFeedback = "Đã kiểm tra +\(number): khớp \(matches.count) quy tắc; bộ đếm đã cập nhật."
        } catch {
            checkFeedback = "Đã khớp \(matches.count) quy tắc nhưng không lưu được bộ đếm: \(error.localizedDescription)"
        }
    }

    private func setRuleEnabled(_ id: UUID, enabled: Bool) {
        guard let index = store.rules.firstIndex(where: { $0.id == id }) else { return }
        var updatedStore = store
        updatedStore.rules[index].isEnabled = enabled
        updatedStore.rules[index].lastUpdated = Date()
        do {
            _ = try SharedStorage.buildBlockingNumbers(from: updatedStore.rules)
            try SharedStorage.save(updatedStore)
            store = updatedStore
            ruleFeedback = "Đã \(enabled ? "bật" : "tắt") quy tắc \(updatedStore.rules[index].displayValue)."
            syncCallDirectory()
        } catch {
            ruleFeedback = "Lỗi cập nhật quy tắc: \(error.localizedDescription)"
        }
    }

    private func deleteRule(_ rule: ManagedRule) {
        var updatedStore = store
        updatedStore.rules.removeAll { $0.id == rule.id }
        do {
            try SharedStorage.save(updatedStore)
            store = updatedStore
            ruleFeedback = "Đã xóa quy tắc \(rule.displayValue). Còn \(store.rules.count) quy tắc."
            syncCallDirectory()
        } catch {
            ruleFeedback = "Lỗi xóa quy tắc: \(error.localizedDescription)"
        }
    }

    private func deleteProfile(_ profile: ManagedProfile) {
        var updatedStore = store
        updatedStore.profiles.removeAll { $0.id == profile.id }
        updatedStore.rules.removeAll { $0.profileID == profile.id }
        do {
            try SharedStorage.save(updatedStore)
            store = updatedStore
            selectedProfileID = store.profiles.first?.id
            profileFeedback = "Đã xóa hồ sơ “\(profile.name)” và các quy tắc thuộc hồ sơ."
            syncCallDirectory()
        } catch {
            profileFeedback = "Lỗi xóa hồ sơ: \(error.localizedDescription)"
        }
    }

    private func syncCallDirectory() {
        dismissKeyboard()
        guard !isReloading else {
            syncFeedback = "Đang có yêu cầu đồng bộ CallKit chạy; vui lòng đợi hoàn tất."
            return
        }
        do {
            _ = try SharedStorage.buildBlockingNumbers(from: store.rules)
        } catch {
            syncFeedback = "Lỗi tạo danh sách CallKit: \(error.localizedDescription)"
            return
        }

        isReloading = true
        syncFeedback = "Đang yêu cầu extension nạp \(callKitNumberCountLabel). \(SharedStorage.storageModeMessage)"
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionBundleID) { error in
            DispatchQueue.main.async {
                isReloading = false
                if let error = error {
                    let callKitError = error as NSError
                    syncFeedback = "Lỗi CallKit [\(callKitError.domain):\(callKitError.code)]: \(callKitError.localizedDescription)"
                } else {
                    syncFeedback = "Đồng bộ thành công \(callKitNumberCountLabel) lúc \(Date().formatted(date: .omitted, time: .shortened))."
                    refreshCallKitStatus()
                }
            }
        }
    }

    private func refreshCallKitStatus() {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionBundleID) { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    callKitStatusText = "Không đọc được trạng thái: \(error.localizedDescription)"
                    return
                }
                switch status {
                case .enabled:
                    callKitStatusText = "Call Directory đang bật trên iPhone"
                case .disabled:
                    callKitStatusText = "Extension chưa được bật trong Cài đặt iPhone"
                case .unknown:
                    callKitStatusText = "Trạng thái extension chưa xác định"
                @unknown default:
                    callKitStatusText = "Trạng thái CallKit không xác định"
                }
            }
        }
    }

    private func profileName(for id: UUID) -> String {
        store.profiles.first(where: { $0.id == id })?.name ?? "Hồ sơ đã xóa"
    }

    private func callKitDisposition(for rule: ManagedRule) -> String {
        guard rule.category == .spam else {
            return "Chỉ phân loại trong ứng dụng; không bị CallKit chặn"
        }
        switch rule.kind {
        case .prefix:
            return "Khớp đầu số trong ứng dụng; CallKit không chặn wildcard"
        case .exact, .range:
            return "Số đầy đủ có trong danh sách CallKit sau khi đồng bộ"
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private func feedbackLabel(_ message: String) -> some View {
        if !message.isEmpty {
            Text(message)
                .font(.system(size: 11, design: .serif))
                .foregroundColor(
                    message.hasPrefix("Lỗi") || message.contains("không lưu được")
                        ? rust
                        : olive
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ClassicTextFieldStyle: TextFieldStyle {
    let paper: Color
    let ink: Color
    let line: Color

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13, design: .serif))
            .foregroundColor(ink)
            .padding(10)
            .background(paper)
            .overlay(Rectangle().stroke(line, lineWidth: 0.7).allowsHitTesting(false))
    }
}
