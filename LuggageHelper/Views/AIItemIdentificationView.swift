import SwiftUI

/// AI 物品识别视图
/// 提供基于 AI 的物品识别功能，包括名称和照片识别
struct AIItemIdentificationView: View {
    @StateObject private var aiViewModel = AIViewModel()
    @StateObject private var searchService = ItemSearchService()
    
    @State private var itemName = ""
    @State private var itemModel = ""
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var capturedImage: UIImage? = nil
    @State private var showConfirmation = false
    @State private var showAlternatives = false
    @State private var showSearchResults = false
    @State private var searchResults: [ItemSearchService.ItemSearchResult] = []
    @State private var isSearching = false
    @State private var selectedTab = 0 // 0: 名称识别, 1: 照片识别, 2: 高级识别
    @State private var showAdvancedOptions = false
    @State private var useHighAccuracy = true
    @State private var showHistory = false
    @State private var recognitionHistory: [ItemInfo] = []
    
    // 回调函数，用于将识别结果传递给父视图
    var onItemIdentified: (ItemInfo) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题和选项卡
            VStack(spacing: 0) {
                titleSection
                
                Picker("识别方式", selection: $selectedTab) {
                    Text("名称识别").tag(0)
                    Text("照片识别").tag(1)
                    Text("高级识别").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(UIColor.systemBackground))
            
            // 主内容区域
            ScrollView {
                VStack(spacing: 16) {
                    if aiViewModel.isLoading || isSearching {
                        loadingSection()
                    } else if let error = aiViewModel.errorMessage {
                        errorSection(error)
                    } else if let item = aiViewModel.identifiedItem {
                        resultSection(item)
                    } else if showSearchResults && !searchResults.isEmpty {
                        searchResultsSection()
                    } else {
                        // 根据选项卡显示不同的输入界面
                        switch selectedTab {
                        case 0:
                            nameInputSection()
                        case 1:
                            photoInputSection()
                        case 2:
                            advancedInputSection()
                        default:
                            nameInputSection()
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $capturedImage, onImageCaptured: handleCapturedImage)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(image: $capturedImage)
        }
        .sheet(isPresented: $showAlternatives) {
            if let item = aiViewModel.identifiedItem {
                alternativesView(for: item)
            }
        }
        .sheet(isPresented: $showHistory) {
            historyView()
        }
        .alert("确认使用识别结果?", isPresented: $showConfirmation) {
            Button("确认") {
                if let item = aiViewModel.identifiedItem {
                    // 添加到历史记录
                    recognitionHistory.insert(item, at: 0)
                    if recognitionHistory.count > 10 {
                        recognitionHistory.removeLast()
                    }
                    
                    onItemIdentified(item)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let item = aiViewModel.identifiedItem {
                Text("物品: \(item.name)\n类别: \(item.category.displayName)\n重量: \(String(format: "%.2f", item.weight/1000))kg\n体积: \(String(format: "%.2f", item.volume/1000))L")
            }
        }
    }
    
    // MARK: - View Components
    
    private var titleSection: some View {
        HStack {
            Text("AI 物品识别")
                .font(.headline)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .disabled(recognitionHistory.isEmpty)
                
                if aiViewModel.identifiedItem != nil {
                    Button("重置") {
                        resetState()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    private func nameInputSection() -> some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("通过名称识别")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // 输入区域
            VStack(spacing: 12) {
                TextField("物品名称", text: $itemName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        identifyByName()
                    }
                
                TextField("型号（可选）", text: $itemModel)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    identifyByName()
                } label: {
                    Label("识别物品", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(itemName.isEmpty)
                .padding(.top, 8)
            }
            
            // 提示信息
            Text("输入物品名称和型号（可选），AI 将自动识别物品的重量、体积和类别")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            // 搜索按钮
            Button {
                searchItemInfo()
            } label: {
                Label("使用本地数据库搜索", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func photoInputSection() -> some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("通过照片识别")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // 照片区域
            VStack(spacing: 16) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    
                    HStack {
                        Button("重新选择") {
                            capturedImage = nil
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("识别物品") {
                            handleCapturedImage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    HStack(spacing: 20) {
                        Button {
                            showCamera = true
                        } label: {
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 32))
                                Text("拍照")
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 100)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Button {
                            showPhotoLibrary = true
                        } label: {
                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 32))
                                Text("相册")
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 100)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            // 提示信息
            Text("拍摄物品照片或从相册选择，AI 将自动识别物品的名称、重量、体积和类别")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            // 高级照片识别按钮
            Button {
                showAdvancedPhotoIdentification()
            } label: {
                Label("使用高级照片识别", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    /// 显示高级照片识别视图
    private func showAdvancedPhotoIdentification() {
        // 创建并显示高级照片识别视图
        let photoIdentificationView = UIHostingController(
            rootView: AIPhotoIdentificationView { itemInfo in
                self.aiViewModel.identifiedItem = itemInfo
            }
        )
        
        // 获取当前视图控制器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // 如果当前有呈现的视图控制器，则从它呈现
            if let presentedViewController = rootViewController.presentedViewController {
                presentedViewController.present(photoIdentificationView, animated: true)
            } else {
                rootViewController.present(photoIdentificationView, animated: true)
            }
        }
    }
    
    private func advancedInputSection() -> some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("高级识别")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // 输入区域
            VStack(spacing: 12) {
                TextField("物品名称", text: $itemName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("型号（可选）", text: $itemModel)
                    .textFieldStyle(.roundedBorder)
                
                // 高级选项
                DisclosureGroup("高级选项", isExpanded: $showAdvancedOptions) {
                    VStack(spacing: 12) {
                        Toggle("使用高精度模式", isOn: $useHighAccuracy)
                        
                        Divider()
                        
                        Text("高精度模式会使用更复杂的模型进行识别，准确度更高但速度较慢")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Button {
                    identifyByNameAdvanced()
                } label: {
                    Label("开始高级识别", systemImage: "sparkles.rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(itemName.isEmpty)
                .padding(.top, 8)
            }
            
            // 提示信息
            Text("高级识别模式提供更精确的物品信息，包括详细的尺寸、材质和替代品建议")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func searchResultsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("搜索结果")
                    .font(.headline)
                Spacer()
                Text("\(searchResults.count) 个结果")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            ForEach(searchResults) { result in
                Button {
                    // 将搜索结果转换为 ItemInfo
                    let itemInfo = result.toItemInfo()
                    aiViewModel.identifiedItem = itemInfo
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            if let weight = result.weight {
                                Text("\(String(format: "%.2f", weight)) kg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let volume = result.volume {
                                Text("\(String(format: "%.2f", volume)) L")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let category = result.category {
                                Text(category.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("来源: \(result.source) | 置信度: \(Int(result.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Button("清除搜索结果") {
                showSearchResults = false
                searchResults = []
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func historyView() -> some View {
        NavigationStack {
            List {
                Section(header: Text("最近识别的物品")) {
                    if recognitionHistory.isEmpty {
                        Text("暂无识别历史")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recognitionHistory) { item in
                            Button {
                                aiViewModel.identifiedItem = item
                                showHistory = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text("\(String(format: "%.2f", item.weight/1000)) kg")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(String(format: "%.2f", item.volume/1000)) L")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(item.category.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if !recognitionHistory.isEmpty {
                    Section {
                        Button("清除历史记录", role: .destructive) {
                            recognitionHistory = []
                        }
                    }
                }
            }
            .navigationTitle("识别历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        showHistory = false
                    }
                }
            })
        }
    }
    
    private func loadingSection() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在识别物品信息...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("重试") {
                resetState()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func resultSection(_ item: ItemInfo) -> some View {
        AIItemInfoCard(
            item: item,
            onUse: {
                showConfirmation = true
            },
            onViewAlternatives: {
                showAlternatives = true
            }
        )
    }
    
    private func alternativesView(for item: ItemInfo) -> some View {
        NavigationStack {
            List {
                Section(header: Text("替代品建议")) {
                    ForEach(item.alternatives) { alternative in
                        Button {
                            aiViewModel.identifiedItem = alternative
                            showAlternatives = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alternative.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("\(String(format: "%.2f", alternative.weight/1000)) kg")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(String(format: "%.2f", alternative.volume/1000)) L")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("替代品选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        showAlternatives = false
                    }
                }
            })
        }
    }
    
    // MARK: - Helper Methods
    
    /// 通过名称识别物品
    private func identifyByName() {
        guard !itemName.isEmpty else { return }
        
        Task {
            await aiViewModel.identifyItem(name: itemName, model: itemModel.isEmpty ? nil : itemModel)
        }
    }
    
    /// 通过名称进行高级识别
    private func identifyByNameAdvanced() {
        guard !itemName.isEmpty else { return }
        
        // 在高级模式下，我们可以使用更复杂的提示和参数
        Task {
            // 这里可以添加高级识别的逻辑，例如使用不同的模型或参数
            // 目前简单调用标准识别方法
            await aiViewModel.identifyItem(name: itemName, model: itemModel.isEmpty ? nil : itemModel)
        }
    }
    
    /// 处理拍摄的图片
    private func handleCapturedImage() {
        guard let image = capturedImage, let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        Task {
            await aiViewModel.identifyItemFromPhoto(imageData)
        }
    }
    
    /// 使用本地数据库搜索物品
    private func searchItemInfo() {
        guard !itemName.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        Task {
            let results = await searchService.searchItemInfo(itemName: itemName)
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
                self.showSearchResults = true
            }
        }
    }
    
    /// 重置状态
    private func resetState() {
        aiViewModel.resetAllStates()
        itemName = ""
        itemModel = ""
        capturedImage = nil
        showSearchResults = false
        searchResults = []
    }
}

#if DEBUG
struct AIItemIdentificationView_Previews: PreviewProvider {
    static var previews: some View {
        AIItemIdentificationView { _ in }
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif