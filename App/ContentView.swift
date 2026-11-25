import SwiftUI
import CallKit

struct ContentView: View {
    @State private var rules: [BlockedRule] = SharedStorage.loadRules()
    @State private var targetPhone: String = ""
    @State private var prefixInput: String = ""
    @State private var selectedCategory: PhoneCategory = .spam
    @State private var statusText: String = "Sẵn sàng"
    @State private var isReloading: Bool = false

    let extensionBundleID = "com.nhoksky100.ChanSoRac.CallBlockerExtension"

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    TextField("Số điện thoại / hồ sơ cần chặn (VD: 0912345678)", text: $targetPhone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        TextField("Cụm đầu số chặn (VD: +8423)", text: $prefixInput)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)

                        Picker("Loại", selection: $selectedCategory) {
                            ForEach(PhoneCategory.allCases, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Button("Thêm quy tắc", action: addRule)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                List {
                    ForEach(rules) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Đầu số: \(rule.prefix)")
                                    .font(.headline)
                                Spacer()
                                Text(rule.category.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(6)
                            }

                            Text("Số đích: \(rule.targetPhone.isEmpty ? "Mặc định" : rule.targetPhone)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Lượt ghi nhận: \(rule.hitCount) • \(rule.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            incrementHit(for: rule.id)
                        }
                    }
                    .onDelete(perform: deleteRule)
                }

                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button(action: syncCallDirectory) {
                    if isReloading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Text("Đồng bộ CallKit")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .disabled(isReloading)
            }
            .navigationTitle("ChanSoRac (Logic)")
        }
    }

    private func addRule() {
        let cleanPrefix = prefixInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrefix.isEmpty else { return }

        let cleanTarget = targetPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetDisplay = cleanTarget.isEmpty ? "Chính" : cleanTarget

        if let idx = rules.firstIndex(where: { $0.prefix == cleanPrefix && $0.targetPhone == targetDisplay }) {
            rules[idx].category = selectedCategory
            rules[idx].isEnabled = true
            rules[idx].hitCount += 1
            rules[idx].lastUpdated = Date()
        } else {
            let item = BlockedRule(
                targetPhone: targetDisplay,
                prefix: cleanPrefix,
                category: selectedCategory,
                isEnabled: true,
                hitCount: 1,
                lastUpdated: Date()
            )
            rules.insert(item, at: 0)
        }

        SharedStorage.saveRules(rules)
        prefixInput = ""
        syncCallDirectory()
    }

    private func incrementHit(for id: UUID) {
        guard let idx = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[idx].hitCount += 1
        rules[idx].lastUpdated = Date()
        SharedStorage.saveRules(rules)
    }

    private func deleteRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        SharedStorage.saveRules(rules)
        syncCallDirectory()
    }

    private func syncCallDirectory() {
        isReloading = true
        statusText = "Đang cập nhật extension..."
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionBundleID) { error in
            DispatchQueue.main.async {
                isReloading = false
                if let error = error {
                    statusText = "Lỗi CallKit: \(error.localizedDescription)"
                } else {
                    statusText = "Đã đồng bộ thành công (\(Date().formatted(date: .omitted, time: .shortened)))."
                }
            }
        }
    }
}