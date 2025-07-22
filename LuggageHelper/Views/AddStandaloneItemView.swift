import SwiftUI

/// 添加独立物品页面
/// 用户可添加不属于任何行李的独立物品
struct AddStandaloneItemView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LuggageViewModel
    
    // 物品属性
    @State private var name = ""
    @State private var volume = ""
    @State private var weight = ""
    @State private var location = ""
    @State private var note = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isSearching = false
    @State private var searchResults: [ItemSearchService.ItemSearchResult] = []
    @StateObject private var searchService = ItemSearchService()
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                
                if isSearching {
                    searchingSection
                }
                
                if !searchResults.isEmpty {
                    searchResultsSection
                }
                
                noteSection
                imageSection
            }
            .navigationTitle("添加物品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveItem() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var basicInfoSection: some View {
        Section(header: Text("基本信息")) {
            HStack {
                TextField("物品名称", text: $name)
                    .textFieldStyle(.roundedBorder)
                Button("搜索") {
                    searchItemInfo()
                }
                .disabled(name.isEmpty || isSearching)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            TextField("体积 (L)", text: $volume)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            TextField("重量 (kg)", text: $weight)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            TextField("存放位置", text: $location)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var searchingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("正在搜索物品信息...")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var searchResultsSection: some View {
        Section(header: Text("搜索结果")) {
            ForEach(searchResults.indices, id: \.self) { index in
                SearchResultRow(result: searchResults[index]) { result in
                    applySearchResult(result)
                }
            }
        }
    }
    
    private var noteSection: some View {
        Section(header: Text("备注")) {
            TextField("备注信息", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var imageSection: some View {
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
    
    // MARK: - Helper Methods
    
    /// 判断是否可以保存物品
    private var canSave: Bool {
        !name.isEmpty && !volume.isEmpty && !weight.isEmpty
    }
    
    /// 搜索物品信息
    private func searchItemInfo() {
        guard !name.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        Task {
            let results = await searchService.searchItemInfo(itemName: name)
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
    
    /// 应用搜索结果
    private func applySearchResult(_ result: ItemSearchService.ItemSearchResult) {
        if let weight = result.weight {
            self.weight = String(format: "%.2f", weight)
        }
        if let volume = result.volume {
            self.volume = String(format: "%.2f", volume)
        }
        // 清空搜索结果
        searchResults = []
    }
    
    /// 保存新物品到数据模型
    private func saveItem() {
        guard let volumeValue = Double(volume),
              let weightValue = Double(weight) else { return }
        
        var imagePath: String? = nil
        if let selectedImage = selectedImage {
            imagePath = saveImageToDocuments(image: selectedImage)
        }
        
        let newItem = LuggageItem(
            name: name,
            volume: volumeValue,
            weight: weightValue,
            imagePath: imagePath,
            location: location.isEmpty ? nil : location,
            note: note.isEmpty ? nil : note
        )
        
        // 添加为独立物品
        viewModel.addStandaloneItem(newItem)
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



#if DEBUG
struct AddStandaloneItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddStandaloneItemView()
            .environmentObject(LuggageViewModel())
    }
}
#endif