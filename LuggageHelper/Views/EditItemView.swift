import SwiftUI

/// 编辑现有物品页面
/// 用户可修改物品名称、体积、重量、放置位置、备注和图片
struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LuggageViewModel
    
    @State private var name: String
    @State private var volume: String
    @State private var weight: String
    @State private var location: String
    @State private var note: String
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isSearching = false
    @State private var searchResults: [ItemSearchService.ItemSearchResult] = []
    @StateObject private var searchService = ItemSearchService()
    
    let item: LuggageItem // 接收要编辑的物品对象
    let luggageId: UUID? // 如果物品在行李中，则传入行李ID
    
    init(item: LuggageItem, luggageId: UUID?) {
        self.item = item
        self.luggageId = luggageId
        _name = State(initialValue: item.name)
        _volume = State(initialValue: String(item.volume))
        _weight = State(initialValue: String(item.weight))
        _location = State(initialValue: item.location ?? "")
        _note = State(initialValue: item.note ?? "")
        
        // 异步加载图片
        _selectedImage = State(initialValue: nil)
        if let imagePath = item.imagePath {
            _selectedImage = State(initialValue: loadImageFromDocuments(imagePath: imagePath))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                    TextField("放置位置", text: $location)
                        .textFieldStyle(.roundedBorder)
                }
                
                if isSearching {
                    Section {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在搜索物品信息...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !searchResults.isEmpty {
                    searchResultsSection
                }
                Section(header: Text("备注")) {
                    TextField("备注信息", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
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
            .navigationTitle("编辑物品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { updateItem() }
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
        !name.isEmpty && !volume.isEmpty && !weight.isEmpty
    }
    
    /// 更新物品到数据模型
    private func updateItem() {
        guard let volumeValue = Double(volume),
              let weightValue = Double(weight) else { return }
        
        var imagePath: String? = item.imagePath // 默认使用现有图片路径
        if let selectedImage {
            imagePath = saveImageToDocuments(image: selectedImage)
        } else if item.imagePath != nil && selectedImage == nil { // 如果之前有图片但现在移除了
            deleteImageFromDocuments(imagePath: item.imagePath!)
            imagePath = nil
        }
        
        let updatedItem = LuggageItem(
            id: item.id,
            name: name,
            volume: volumeValue,
            weight: weightValue,
            imagePath: imagePath,
            location: location.isEmpty ? nil : location,
            note: note.isEmpty ? nil : note
        )
        
        if let luggageId = luggageId {
            viewModel.updateItem(updatedItem, in: luggageId)
        } else {
            viewModel.updateStandaloneItem(updatedItem)
        }
        dismiss()
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
    
    /// 搜索结果部分
    private var searchResultsSection: some View {
        Section(header: Text("搜索结果")) {
            ForEach(searchResults.indices, id: \.self) { index in
                AddItemSearchResultRow(result: searchResults[index]) { result in
                    applySearchResult(result)
                }
            }
        }
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
    
    /// 从沙盒加载图片
    private func loadImageFromDocuments(imagePath: String) -> UIImage? {
        let url = URL(fileURLWithPath: imagePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    /// 从沙盒删除图片
    private func deleteImageFromDocuments(imagePath: String) {
        let url = URL(fileURLWithPath: imagePath)
        try? FileManager.default.removeItem(at: url)
    }
}