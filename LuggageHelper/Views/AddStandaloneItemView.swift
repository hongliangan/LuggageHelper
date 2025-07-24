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
    
    // AI 相关
    @State private var showAIIdentification = false
    @State private var showBatchIdentification = false
    @State private var category: ItemCategory = .other
    
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
                
                aiIdentificationSection
                
                categorySection
                
                noteSection
                
                imageSection
            }
            .navigationTitle("添加物品")
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveItem() }
                        .disabled(!canSave)
                }
            })
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showAIIdentification) {
                NavigationStack {
                    AIItemIdentificationView { itemInfo in
                        applyAIResult(itemInfo)
                        showAIIdentification = false
                    }
                    .padding()
                    .navigationTitle("AI 物品识别")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(content: {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showAIIdentification = false
                            }
                        }
                    })
                }
            }
            .sheet(isPresented: $showBatchIdentification) {
                AIItemBatchIdentificationView { items in
                    if let firstItem = items.first {
                        applyAIResult(firstItem)
                    }
                    // 这里可以添加批量添加物品的逻辑
                    // 目前只使用第一个识别结果
                }
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
                AddStandaloneItemSearchResultRow(result: searchResults[index]) { result in
                    applySearchResult(result)
                }
            }
        }
    }
    
    private var aiIdentificationSection: some View {
        Section {
            AIIdentificationButtonGroup(
                onNameIdentification: {
                    showAIIdentification = true
                },
                onPhotoIdentification: {
                    showAdvancedPhotoIdentification()
                },
                onBatchIdentification: {
                    showBatchIdentification = true
                },
                onAdvancedIdentification: {
                    showQuickIdentification()
                }
            )
        } header: {
            Text("AI 识别")
        } footer: {
            Text("AI 可以通过物品名称或照片自动识别物品的重量、体积和类别")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// 显示高级照片识别视图
    private func showAdvancedPhotoIdentification() {
        let photoIdentificationView = UIHostingController(
            rootView: AIPhotoIdentificationView { itemInfo in
                applyAIResult(itemInfo)
            }
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let presentedViewController = rootViewController.presentedViewController {
                presentedViewController.present(photoIdentificationView, animated: true)
            } else {
                rootViewController.present(photoIdentificationView, animated: true)
            }
        }
    }
    
    /// 显示快速识别弹窗
    private func showQuickIdentification() {
        let quickIdentificationView = UIHostingController(
            rootView: AIQuickIdentificationView { itemInfo in
                applyAIResult(itemInfo)
            }
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let presentedViewController = rootViewController.presentedViewController {
                presentedViewController.present(quickIdentificationView, animated: true)
            } else {
                rootViewController.present(quickIdentificationView, animated: true)
            }
        }
    }
    
    private var categorySection: some View {
        Section(header: Text("类别")) {
            Picker("物品类别", selection: $category) {
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    HStack {
                        Text(category.icon)
                        Text(category.displayName)
                    }
                    .tag(category)
                }
            }
            .pickerStyle(.navigationLink)
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
    
    /// 应用 AI 识别结果
    private func applyAIResult(_ itemInfo: ItemInfo) {
        self.name = itemInfo.name
        self.weight = String(format: "%.2f", itemInfo.weight / 1000) // 转换为 kg
        self.volume = String(format: "%.2f", itemInfo.volume / 1000) // 转换为 L
        self.category = itemInfo.category
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
            category: category,
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

/// 搜索结果行组件
struct AddStandaloneItemSearchResultRow: View {
    let result: ItemSearchService.ItemSearchResult
    let onSelect: (ItemSearchService.ItemSearchResult) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.name)
                .font(.headline)
            
            HStack {
                if let weight = result.weight {
                    Text("重量: \(weight, specifier: "%.2f")kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let volume = result.volume {
                    Text("体积: \(volume, specifier: "%.2f")L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("来源: \(result.source) | 置信度: \(Int(result.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(result)
        }
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