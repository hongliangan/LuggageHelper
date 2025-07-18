import SwiftUI

/// 添加新行李页面
/// 用户可输入行李名称、容量、空箱重量等信息
struct AddLuggageView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: LuggageViewModel
    
    @State private var name = ""
    @State private var capacity = ""
    @State private var emptyWeight = ""
    @State private var note = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称", text: $name)
                    TextField("容量 (L)", text: $capacity)
                        .keyboardType(.decimalPad)
                    TextField("空箱重量 (kg)", text: $emptyWeight)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("备注")) {
                    TextField("备注信息", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("图片")) {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .onTapGesture { showImagePicker = true }
                    } else {
                        Button("选择图片") {
                            showImagePicker = true
                        }
                    }
                }
            }
            .navigationTitle("添加行李")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveLuggage()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    /// 判断是否可以保存行李
    private var canSave: Bool {
        !name.isEmpty && !capacity.isEmpty && !emptyWeight.isEmpty
    }
    
    /// 保存新行李到数据模型
    private func saveLuggage() {
        guard let capacityValue = Double(capacity),
              let emptyWeightValue = Double(emptyWeight) else { return }
        
        var imagePath: String? = nil
        if let selectedImage {
            imagePath = saveImageToDocuments(image: selectedImage)
        }
        
        let newLuggage = Luggage(
            name: name,
            capacity: capacityValue,
            emptyWeight: emptyWeightValue,
            imagePath: imagePath,
            items: [],
            note: note
        )
        viewModel.addLuggage(newLuggage)
        dismiss()
    }
    
    /// 将 UIImage 保存到沙盒并返回路径
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? data.write(to: url)
        return url.path
    }
}