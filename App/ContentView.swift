import SwiftUI
import CallKit

struct ContentView: View {
    private let extensionBundleID = "com.nhoksky100.ChanSoRac.CallBlockerExtension"

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
    @State private var statusText = "Đang tải dữ liệu..."
    @State private var callKitStatusText = "Chưa kiểm tra trạng thái CallKit"
    @State private var isReloading = false
    @State private var storageReady = true

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
            .disabled(isReloading || !storageReady)
            Text(statusText)
                .font(.system(size: 11, design: .serif))
                .foregroundColor(statusText.hasPrefix("Lỗi") ? rust : ink.opacity(0.7))
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8))
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
                            Text(profile.targetPhone.isEmpty ? "Chưa khai báo số đích" : "+\(profile.targetPhone)")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(ink.opacity(0.7))
                        }
                        Spacer()
                        Button("XÓA") { deleteProfile(profile) }
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .foregroundColor(rust)
                    }
                    .padding(10)
                    .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.7))
                }
            }

            TextField("Tên hồ sơ (ví dụ: Điện thoại cá nhân)", text: $profileName)
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            TextField("Số điện thoại đích (ví dụ: 0912345678)", text: $profilePhone)
                .keyboardType(.phonePad)
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            Button(action: addProfile) {
                Text("TẠO HỒ SƠ")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(olive, lineWidth: 1))
                    .foregroundColor(olive)
            }
            .disabled(!storageReady)
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8))
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
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            if ruleKind == .range {
                TextField("Đến số (ví dụ: 0912345699)", text: $rangeEnd)
                    .keyboardType(.phonePad)
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
            .disabled(selectedProfile == nil || !storageReady)
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8))
    }

    private var quickCheckCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("TRA CỨU NHANH", number: "04")
            TextField("Nhập số cần kiểm tra", text: $phoneToCheck)
                .keyboardType(.phonePad)
                .textFieldStyle(ClassicTextFieldStyle(paper: paper, ink: ink, line: ruleLine))
            Button(action: checkPhone) {
                Text("KIỂM TRA SỐ")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(olive, lineWidth: 1))
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
            Text("Mỗi lần tra cứu khớp sẽ tăng bộ đếm của quy tắc tương ứng.")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(ink.opacity(0.65))
        }
        .padding(14)
        .background(paper.opacity(0.8))
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8))
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
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8))
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
        .overlay(Rectangle().stroke(ruleLine, lineWidth: 0.8))
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
        .overlay(Rectangle().stroke(ruleLine.opacity(0.8), lineWidth: 0.6))
    }

    private func loadStore() {
        do {
            store = try SharedStorage.load()
            selectedProfileID = store.profiles.first?.id
            storageReady = true
            statusText = "Dữ liệu App Group đã tải."
            refreshCallKitStatus()
        } catch {
            storageReady = false
            statusText = "Lỗi dữ liệu: \(error.localizedDescription)"
        }
    }

    private func addProfile() {
        let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusText = "Lỗi: Hãy nhập tên hồ sơ."
            return
        }
        guard let phone = VietnamPhoneNumber.normalize(profilePhone),
              VietnamPhoneNumber.isCompleteSubscriberNumber(phone) else {
            statusText = "Lỗi: Hãy nhập số điện thoại đích đầy đủ."
            return
        }
        let profile = ManagedProfile(name: name, targetPhone: phone)
        store.profiles.append(profile)
        selectedProfileID = profile.id
        profileName = ""
        profilePhone = ""
        saveStore(reloadExtension: false)
    }

    private func addRule() {
        guard let profile = selectedProfile else {
            statusText = "Lỗi: Hãy chọn hồ sơ trước."
            return
        }

        let value: String
        var endValue = ""
        switch ruleKind {
        case .prefix:
            guard let normalized = VietnamPhoneNumber.normalizePrefix(ruleValue) else {
                statusText = "Lỗi: Đầu số chưa hợp lệ."
                return
            }
            value = normalized
        case .exact:
            guard let normalized = VietnamPhoneNumber.normalize(ruleValue),
                  VietnamPhoneNumber.isCompleteSubscriberNumber(normalized) else {
                statusText = "Lỗi: Hãy nhập số đầy đủ hợp lệ."
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
                statusText = "Lỗi: Dải số không hợp lệ."
                return
            }
            guard endNumber - startNumber + 1 <= SharedStorage.maximumRangeEntries else {
                statusText = "Lỗi: Mỗi dải CallKit tối đa 10.000 số."
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
        let candidateRules = store.rules + [rule]
        do {
            _ = try SharedStorage.buildBlockingNumbers(from: candidateRules)
        } catch {
            statusText = "Lỗi: \(error.localizedDescription)"
            return
        }
        store.rules.append(rule)
        ruleValue = ""
        rangeEnd = ""
        saveStore(reloadExtension: true)
    }

    private func checkPhone() {
        guard let number = VietnamPhoneNumber.normalize(phoneToCheck),
              VietnamPhoneNumber.isCompleteSubscriberNumber(number) else {
            hasCheckedPhone = false
            statusText = "Lỗi: Hãy nhập số Việt Nam đầy đủ để tra cứu."
            return
        }
        let matches = SharedStorage.matchingRules(for: number, in: store.rules)
        checkMatches = matches
        hasCheckedPhone = true
        guard !matches.isEmpty else { return }

        let matchedIDs = Set(matches.map(\.id))
        store.rules = store.rules.map { rule in
            guard matchedIDs.contains(rule.id) else { return rule }
            var updated = rule
            updated.recordCount += 1
            updated.lastUpdated = Date()
            return updated
        }
        saveStore(reloadExtension: false)
    }

    private func setRuleEnabled(_ id: UUID, enabled: Bool) {
        guard let index = store.rules.firstIndex(where: { $0.id == id }) else { return }
        let previousRule = store.rules[index]
        store.rules[index].isEnabled = enabled
        store.rules[index].lastUpdated = Date()
        do {
            _ = try SharedStorage.buildBlockingNumbers(from: store.rules)
            saveStore(reloadExtension: true)
        } catch {
            store.rules[index] = previousRule
            statusText = "Lỗi: \(error.localizedDescription)"
        }
    }

    private func deleteRule(_ rule: ManagedRule) {
        store.rules.removeAll { $0.id == rule.id }
        saveStore(reloadExtension: true)
    }

    private func deleteProfile(_ profile: ManagedProfile) {
        store.profiles.removeAll { $0.id == profile.id }
        store.rules.removeAll { $0.profileID == profile.id }
        selectedProfileID = store.profiles.first?.id
        saveStore(reloadExtension: true)
    }

    private func saveStore(reloadExtension: Bool) {
        guard storageReady else { return }
        do {
            try SharedStorage.save(store)
            statusText = "Đã lưu dữ liệu hồ sơ."
            if reloadExtension { syncCallDirectory() }
        } catch {
            statusText = "Lỗi lưu dữ liệu: \(error.localizedDescription)"
        }
    }

    private func syncCallDirectory() {
        guard storageReady else { return }
        do {
            _ = try SharedStorage.buildBlockingNumbers(from: store.rules)
        } catch {
            statusText = "Lỗi: \(error.localizedDescription)"
            return
        }

        isReloading = true
        statusText = "Đang yêu cầu extension nạp danh sách..."
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionBundleID) { error in
            DispatchQueue.main.async {
                isReloading = false
                if let error = error {
                    statusText = "Lỗi CallKit: \(error.localizedDescription)"
                } else {
                    statusText = "Đã yêu cầu CallKit cập nhật lúc \(Date().formatted(date: .omitted, time: .shortened))."
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
            .overlay(Rectangle().stroke(line, lineWidth: 0.7))
    }
}
