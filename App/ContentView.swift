import SwiftUI
import CallKit

struct ContentView: View {
    @State private var prefixes: [String] = SharedStorage.getPrefixes()
    @State private var newPrefix: String = ""
    @State private var statusMessage: String = "Sẵn sàng cập nhật"
    @State private var isLoading: Bool = false
    
    let extensionBundleID = "com.nhoksky100.ChanSoRac.CallBlockerExtension"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack {
                    TextField("Nhập đầu số (VD: +8423)", text: $newPrefix)
                        .keyboardType(.phonePad)
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
                
                List {
                    ForEach(prefixes, id: \.self) { prefix in
                        Text(prefix)
                            .font(.headline)
                    }
                    .onDelete(perform: deletePrefix)
                }
                
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                Button(action: reloadExtension) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Cập nhật danh sách chặn")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .disabled(isLoading)
            }
            .navigationTitle("Chặn Số Rác")
        }
    }
    
    private func addPrefix() {
        let cleaned = newPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !prefixes.contains(cleaned) else { return }
        prefixes.append(cleaned)
        SharedStorage.savePrefixes(prefixes)
        newPrefix = ""
        reloadExtension()
    }
    
    private func deletePrefix(at offsets: IndexSet) {
        prefixes.remove(atOffsets: offsets)
        SharedStorage.savePrefixes(prefixes)
        reloadExtension()
    }
    
    private func reloadExtension() {
        isLoading = true
        statusMessage = "Đang đồng bộ với hệ thống..."
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionBundleID) { error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    statusMessage = "Lỗi: \(error.localizedDescription)"
                } else {
                    statusMessage = "Đã cập nhật thành công!"
                }
            }
        }
    }
}