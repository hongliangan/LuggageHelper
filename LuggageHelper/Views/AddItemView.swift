import SwiftUI

/// 添加新物品页面
/// 用户可输入物品名称、重量、体积等信息，并关联到指定行李
struct AddItemView: View {
    @Environment(\.dismiss) var dismiss
    let luggage: Luggage
    @ObservedObject var viewModel: LuggageViewModel
    
    @State private var name = ""
    @State private var weight = ""
    @State private var volume = ""
    @State private var location = ""
    @State private var note = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("物品名称", text: $name)
                    TextField("重量 (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("体积 (L)", text: $volume)
                        .keyboardType(.decimalPad)
                    TextField("存放位置", text: $location)
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
            .navigationTitle("添加物品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveItem()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    /// 判断是否可以保存物品
    private var canSave: Bool {
        !name.isEmpty && !weight.isEmpty && !volume.isEmpty
    }
    
    /// 保存新物品到数据模型
    // 替换第85-90行的saveItem函数
    private func saveItem() {
        guard let weightValue = weight.doubleValue,
              let volumeValue = volume.doubleValue else { 
            return 
        }
        
        var imagePath: String? = nil
        if let selectedImage = selectedImage {
            imagePath = saveImageToDocuments(image: selectedImage)
        }
        
        let newItem = LuggageItem(
            name: name,
            volume: volumeValue,
            weight: weightValue,
            imagePath: imagePath,
            location: location.isEmpty ? luggage.name : location,
            note: note.isEmpty ? nil : note
        )
        
        viewModel.addItem(newItem, to: luggage.id)
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