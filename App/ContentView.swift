import SwiftUI

struct ContentView: View {
    @State private var inputPrefix: String = ""
    @State private var blockedPrefixes: [String] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Chặn Cuộc Gọi Theo Đầu Số")
                    .font(.headline)
                    .padding(.top)

                // Ô nhập đầu số
                HStack {
                    TextField("Nhập đầu số (VD: +8423)", text: $inputPrefix)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)

                    Button(action: addPrefix) {
                        Text("Thêm")
                            .bold()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                // Danh sách các đầu số đang chặn
                List {
                    Section(header: Text("Danh sách đầu số đã thêm")) {
                        if blockedPrefixes.isEmpty {
                            Text("Chưa có đầu số nào được thêm.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(blockedPrefixes, id: \.self) { prefix in
                                Text(prefix)
                            }
                            .onDelete(perform: removePrefix)
                        }
                    }
                }

                // Nút kích hoạt cập nhật extension
                Button(action: saveAndReload) {
                    Text("Cập nhật danh sách chặn")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("PrefixBlocker")
            .onAppear(perform: loadPrefixes)
        }
    }

    // Thêm đầu số vào danh sách tạm
    func addPrefix() {
        let trimmed = inputPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !blockedPrefixes.contains(trimmed) {
            blockedPrefixes.append(trimmed)
            inputPrefix = ""
            SharedStorage.save(prefixes: blockedPrefixes)
        }
    }

    // Xóa đầu số
    func removePrefix(at offsets: IndexSet) {
        blockedPrefixes.remove(atOffsets: offsets)
        SharedStorage.save(prefixes: blockedPrefixes)
    }

    // Tải danh sách khi mở app
    func loadPrefixes() {
        blockedPrefixes = SharedStorage.load()
    }

    // Lưu và gọi reload extension
    func saveAndReload() {
        SharedStorage.save(prefixes: blockedPrefixes)
        // Gọi reload Call Directory Extension
        // CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: ...)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}