import SwiftUI
import CallKit

struct ContentView: View {
    // Danh sách mặc định theo yêu cầu của bạn
    @State private var prefixes: [String] = SharedStorage.getPrefixes()
    @State private var newPrefix: String = ""
    @State private var statusMessage: String = "Sẵn sàng cập nhật"
    @State private var isLoading: Bool = false

    let extensionBundleID = "com.yourname.PrefixBlocker.CallBlockerExtension"

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Ô nhập đầu số dạng +8423, +8425...
                HStack {
                    TextField("Nhập đầu số (VD: +8423)", text: $newPrefix)
                        .keyboardType(.phonePad) // Bàn phím có dấu +
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: addPrefix) {
                        Text("Thêm")
                            .bold()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(newPrefix.isEmpty)
                }
                .padding(.horizontal)

                // Hiển thị danh sách đầu số đang chặn
                List {
                    ForEach(prefixes, id: \.self) { prefix in
                        HStack {
                            Text("Đầu số: \(prefix)")
                                .font(.headline)
                            Spacer()
                            Text("Chặn")
                                .font(.caption)
                                .padding(4)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                    .onDelete(perform: deletePrefix)
                }

                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: reloadCallDirectory) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isLoading ? "Đang nạp vào iPhone..." : "Kích hoạt danh sách chặn")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(isLoading)
            }
            .navigationTitle("Chặn Đầu Số +84")
        }
    }

    private func addPrefix() {
        // Loại bỏ khoảng trắng thừa
        var cleaned = newPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Tự động chuẩn hóa: nếu nhập 023 -> chuyển thành +8423 cho đồng bộ giao diện
        if cleaned.hasPrefix("0") {
            cleaned = "+84" + cleaned.dropFirst()
        } else if cleaned.hasPrefix("84") {
            cleaned = "+" + cleaned
        }
        
        guard cleaned.hasPrefix("+84"), cleaned.count >= 4, !prefixes.contains(cleaned) else {
            statusMessage = "Vui lòng nhập đúng định dạng (VD: +8423 hoặc 023)"
            return
        }
        
        prefixes.append(cleaned)
        SharedStorage.savePrefixes(prefixes)
        newPrefix = ""
        statusMessage = "Đã thêm \(cleaned). Nhấn kích hoạt để áp dụng."
    }

    private func deletePrefix(at offsets: IndexSet) {
        prefixes.remove(atOffsets: offsets)
        SharedStorage.savePrefixes(prefixes)
    }

    private func reloadCallDirectory() {
        isLoading = true
        statusMessage = "Đang đồng bộ danh sách với hệ thống..."
        
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionBundleID) { error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    statusMessage = "Lỗi: \(error.localizedDescription)"
                } else {
                    statusMessage = "Thành công! Đã chặn các đầu số trong danh sách."
                }
            }
        }
    }
}