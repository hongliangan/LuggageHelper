import SwiftUI
import PhotosUI
import Vision

// MARK: - 导入共享模型
// 使用 AIModels.swift 中定义的共享类型

/// Mock 错误恢复管理器
class MockPhotoRecognitionErrorRecoveryManager: ObservableObject {
    func clearRecoveryState() {
        // Mock implementation
    }
    
    func handlePhotoRecognitionError(_ error: PhotoRecognitionError, for image: UIImage) async -> RecoveryResult {
        // Mock implementation
        return .actionCompleted
    }
}

/// Mock 批量识别服务
class MockBatchRecognitionService {
    static let shared = MockBatchRecognitionService()
    
    func recognizeAllObjects(in image: UIImage, progressHandler: @escaping (BatchProgress) -> Void) async throws -> BatchRecognitionResult {
        // Mock implementation
        let mockItem = ItemInfo(name: "测试物品", category: .other, weight: 100, volume: 100)
        return BatchRecognitionResult(successful: [mockItem], failed: [], processingTime: 2.0)
    }
    
    func recognizeSelectedObjects(_ objects: [DetectedObject], from image: UIImage, progressHandler: @escaping (BatchProgress) -> Void) async throws -> BatchRecognitionResult {
        // Mock implementation
        let mockItem = ItemInfo(name: "选中物品", category: .other, weight: 100, volume: 100)
        return BatchRecognitionResult(successful: [mockItem], failed: [], processingTime: 1.5)
    }
    
    func cancelCurrentBatch() {
        // Mock implementation
    }
}

/// Mock 离线识别服务
class MockOfflineRecognitionService {
    static let shared = MockOfflineRecognitionService()
    
    func recognizeOffline(_ image: UIImage) async throws -> OfflineRecognitionResult {
        // Mock implementation
        return OfflineRecognitionResult(
            category: .other,
            confidence: 0.7,
            needsOnlineVerification: true,
            processingTime: 1.0
        )
    }
    
    func getAvailableCategories() -> [ItemCategory] {
        return [.clothing, .electronics, .other]
    }
}

/// Mock 图像预处理器
class MockImagePreprocessor {
    static let shared = MockImagePreprocessor()
    
    func validateImageQuality(_ image: UIImage) async -> ImageQualityResult {
        return ImageQualityResult(overallScore: 0.9, issues: [], recommendations: [], isAcceptable: true)
    }
    
    func normalizeImage(_ image: UIImage) async -> UIImage {
        return image
    }
}

// ImageQualityResult 现在在 AIModels.swift 中定义

// AIViewModel 现在在 ViewModels/AIViewModel.swift 中定义

// LoadingOverlayView 现在在 Components/LoadingStateView.swift 中定义

/// 相机视图
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImageCaptured: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImageCaptured()
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - 对象选择模式
enum ObjectSelectionMode: String, CaseIterable {
    case single = "single"
    case multiple = "multiple"
    case smart = "smart"
    
    var displayName: String {
        switch self {
        case .single: return "单选"
        case .multiple: return "多选"
        case .smart: return "智能选择"
        }
    }
    
    var icon: String {
        switch self {
        case .single: return "hand.tap"
        case .multiple: return "hand.tap.fill"
        case .smart: return "brain.head.profile"
        }
    }
}

/// AI 照片识别视图 - 增强版
/// 提供基于照片的物品识别功能，包括图像预处理、多物品识别和批量处理
struct AIPhotoIdentificationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var aiViewModel: AIViewModel
    @StateObject private var loadingManager = LoadingStateManager.shared
    
    // MARK: - 图像相关状态
    @State private var selectedImage: UIImage? = nil
    @State private var processedImage: UIImage? = nil
    @State private var imageProcessingProgress: Double = 0.0
    @State private var currentProcessingStep: String = ""
    
    // MARK: - UI 显示状态
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showRealTimeCamera = false
    @State private var showAdvancedOptions = false
    @State private var showOfflineSettings = false
    @State private var showErrorGuidance = false
    @State private var showBatchResults = false
    @State private var showImagePreview = false
    
    // MARK: - 处理状态
    @State private var isProcessing = false
    @State private var processingOperation: LoadingOperation? = nil
    @State private var errorMessage: String? = nil
    @State private var currentPhotoError: PhotoRecognitionError? = nil
    
    // MARK: - 对象检测相关
    @State private var detectedObjects: [DetectedObject] = []
    @State private var selectedObjectIndices: Set<Int> = []
    @State private var detectionResult: ObjectDetectionResult? = nil
    @State private var objectSelectionMode: ObjectSelectionMode = .single
    
    // MARK: - 识别结果
    @State private var identifiedItems: [ItemInfo] = []
    @State private var batchRecognitionResult: BatchRecognitionResult? = nil
    @State private var batchProgress: BatchProgress? = nil
    @State private var offlineResult: OfflineRecognitionResult? = nil
    
    // MARK: - 设置选项
    @State private var useObjectDetection = true
    @State private var enhanceImage = true
    @State private var useOfflineMode = false
    @State private var autoSelectBestObject = true
    @State private var showConfidenceThreshold = false
    @State private var confidenceThreshold: Double = 0.7
    
    // MARK: - 服务实例
    private let objectDetector = ObjectDetectionEngine.shared
    private let batchService = MockBatchRecognitionService.shared
    private let offlineService = MockOfflineRecognitionService.shared
    @StateObject private var errorRecoveryManager = MockPhotoRecognitionErrorRecoveryManager()
    
    // 回调函数，用于将识别结果传递给父视图
    let onItemIdentified: (ItemInfo) -> Void

    init(onItemIdentified: @escaping (ItemInfo) -> Void) {
        self.onItemIdentified = onItemIdentified
        _aiViewModel = StateObject(wrappedValue: AIViewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 主要内容
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        // 照片选择和预览区域
                        photoSelectionSection
                        
                        // 图像处理进度
                        if isProcessing && imageProcessingProgress > 0 {
                            imageProcessingProgressSection
                        }
                        
                        // 高级选项
                        advancedOptionsSection
                        
                        // 对象检测和选择区域
                        if !detectedObjects.isEmpty && selectedImage != nil {
                            objectDetectionSection
                        }
                        
                        // 识别结果区域
                        recognitionResultsSection
                        
                        // 错误信息
                        if let error = errorMessage {
                            errorSection(error)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // 全屏加载覆盖层
                if let operation = processingOperation {
                    LoadingOverlayView(operation: operation) {
                        cancelCurrentOperation()
                    }
                }
            }
            .navigationTitle("AI 照片识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showAdvancedOptions.toggle() }) {
                            Label("高级选项", systemImage: "gear")
                        }
                        
                        Button(action: { showOfflineSettings = true }) {
                            Label("离线模型", systemImage: "square.and.arrow.down")
                        }
                        
                        if !detectedObjects.isEmpty {
                            Divider()
                            
                            Button(action: { resetObjectSelection() }) {
                                Label("重置选择", systemImage: "arrow.counterclockwise")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onChange(of: aiViewModel.identifiedItem) { newItem in
                if let item = newItem {
                    identifiedItems = [item]
                } else {
                    identifiedItems = []
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $selectedImage) {
                    processImage()
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                PhotoPicker(image: $selectedImage, onImageSelected: {
                    processImage()
                })
            }
            .sheet(isPresented: $showOfflineSettings) {
                NavigationView {
                    VStack {
                        Text("离线模型管理")
                            .font(.title2)
                            .padding()
                        
                        Text("此功能正在开发中")
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Spacer()
                    }
                    .navigationTitle("离线模型")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                showOfflineSettings = false
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showRealTimeCamera) {
                NavigationView {
                    VStack {
                        Text("实时相机识别")
                            .font(.title2)
                            .padding()
                        
                        Text("此功能正在开发中")
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Spacer()
                        
                        Button("关闭") {
                            showRealTimeCamera = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .navigationTitle("实时识别")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .fullScreenCover(isPresented: $showImagePreview) {
                if let image = processedImage ?? selectedImage {
                    NavigationView {
                        VStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .overlay(
                                    objectDetectionOverlay
                                )
                            
                            Spacer()
                            
                            HStack {
                                Button("取消") {
                                    showImagePreview = false
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                Button("识别选中") {
                                    showImagePreview = false
                                    recognizeSelectedObjects(Array(selectedObjectIndices))
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(selectedObjectIndices.isEmpty)
                            }
                            .padding()
                        }
                        .navigationTitle("选择物品")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .sheet(isPresented: $showBatchResults) {
                if let result = batchRecognitionResult {
                    NavigationView {
                        VStack {
                            Text("批量识别结果")
                                .font(.title2)
                                .padding()
                            
                            List(result.successfulRecognitions) { item in
                                Button {
                                    onItemIdentified(item)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text(item.category.displayName)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showBatchResults = false
                                    batchRecognitionResult = nil
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showErrorGuidance) {
                VStack {
                    Text("识别错误")
                        .font(.title2)
                        .padding()
                    
                    if let error = errorMessage {
                        Text(error)
                            .padding()
                    }
                    
                    Button("重试") {
                        showErrorGuidance = false
                        processImage()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                    Button("取消") {
                        showErrorGuidance = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .accessibilityLabel("AI照片识别界面")
        .accessibilityHint("用于识别照片中物品的界面")
    }
    
    // MARK: - View Components
    
    private var recognitionActionButtons: some View {
        HStack(spacing: 8) {
            if !selectedObjectIndices.isEmpty {
                Button("识别选中") {
                    recognizeSelectedObjects(Array(selectedObjectIndices))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("识别全部") {
                    identifyWholeImage()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if detectedObjects.count > 1 {
                Button("批量识别") {
                    performBatchRecognition()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private var objectDetectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("检测到的物品")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(detectedObjects.count) 个")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if detectedObjects.isEmpty {
                EmptyObjectDetectionView()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(detectedObjects.indices, id: \.self) { index in
                        let object = detectedObjects[index]
                        let isSelected = selectedObjectIndices.contains(index)
                        
                        ObjectThumbnailCard(
                            object: object,
                            index: index,
                            isSelected: isSelected,
                            selectionMode: objectSelectionMode,
                            onTap: {
                                toggleObjectSelection(index)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var recognitionResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !identifiedItems.isEmpty {
                Text("识别结果")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach(identifiedItems) { item in
                    EnhancedItemInfoCard(
                        item: item,
                        showDetailedInfo: true,
                        onUse: {
                            onItemIdentified(item)
                            dismiss()
                        },
                        onViewAlternatives: item.alternatives.isEmpty ? nil : {
                            // 显示替代品
                        }
                    )
                }
            }
            
            if let result = offlineResult {
                OfflineResultCard(
                    result: result,
                    onUse: { item in
                        onItemIdentified(item)
                        dismiss()
                    },
                    onVerifyOnline: {
                        useOfflineMode = false
                        identifyWholeImage()
                    }
                )
            }
            
            if let result = batchRecognitionResult {
                BatchResultSummaryCard(result: result)
            }
        }
    }
    
    private var photoSelectionSection: some View {
        VStack(spacing: 20) {
            if let image = processedImage ?? selectedImage {
                // 图像预览卡片
                VStack(spacing: 16) {
                    // 图像显示区域
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 320)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .overlay(
                                objectDetectionOverlay
                            )
                            .onTapGesture {
                                if !detectedObjects.isEmpty {
                                    showImagePreview = true
                                }
                            }
                        
                        // 图像质量指示器
                        if let qualityScore = getImageQualityScore(image) {
                            VStack {
                                HStack {
                                    Spacer()
                                    ImageQualityIndicator(score: qualityScore)
                                        .padding(.top, 12)
                                        .padding(.trailing, 12)
                                }
                                Spacer()
                            }
                        }
                        
                        // 处理状态覆盖层
                        if isProcessing && imageProcessingProgress > 0 {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    ProcessingProgressOverlay(
                                        progress: imageProcessingProgress,
                                        step: currentProcessingStep
                                    )
                                    .padding(.bottom, 12)
                                    .padding(.trailing, 12)
                                }
                            }
                        }
                    }
                    
                    // 图像信息和操作
                    VStack(spacing: 12) {
                        // 图像信息
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("图像尺寸: \(Int(image.size.width)) × \(Int(image.size.height))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let processedImage = processedImage {
                                    Text("已处理 • 质量增强")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("原始图像")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if !detectedObjects.isEmpty {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("检测到 \(detectedObjects.count) 个物品")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    Text("\(selectedObjectIndices.count) 个已选择")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // 操作按钮
                        HStack(spacing: 12) {
                            Button("重新选择") {
                                resetState()
                            }
                            .buttonStyle(.bordered)
                            
                            if !detectedObjects.isEmpty {
                                Button("预览选择") {
                                    showImagePreview = true
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Spacer()
                            
                            recognitionActionButtons
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            } else {
                // 照片选择界面
                VStack(spacing: 24) {
                    // 选择方式
                    VStack(spacing: 16) {
                        Text("选择照片")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 20) {
                            PhotoSelectionButton(
                                icon: "camera.fill",
                                title: "拍照",
                                subtitle: "使用相机拍摄",
                                color: .blue
                            ) {
                                showCamera = true
                            }
                            
                            PhotoSelectionButton(
                                icon: "photo.on.rectangle.angled",
                                title: "相册",
                                subtitle: "从相册选择",
                                color: .purple
                            ) {
                                showPhotoLibrary = true
                            }
                        }
                    }
                    
                    // 分隔线
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("或")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // 实时识别按钮
                    Button {
                        showRealTimeCamera = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "video.fill")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("实时识别")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("使用相机实时识别物品")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .opacity(0.6)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    
                    // 提示信息
                    VStack(spacing: 8) {
                        Text("AI 照片识别功能")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• 支持多物品同时识别\n• 自动图像质量优化\n• 离线模式可用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(20)
            }
        }
    }
    
    private var objectDetectionOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // 绘制所有检测到的物体边界框
                ForEach(detectedObjects.indices, id: \.self) { index in
                    let object = detectedObjects[index]
                    let isSelected = selectedObjectIndices.contains(index)
                    
                    Rectangle()
                        .stroke(
                            isSelected ? Color.blue : Color.green.opacity(0.8),
                            lineWidth: isSelected ? 3 : 2
                        )
                        .frame(
                            width: object.boundingBox.width * geometry.size.width,
                            height: object.boundingBox.height * geometry.size.height
                        )
                        .position(
                            x: object.boundingBox.midX * geometry.size.width,
                            y: object.boundingBox.midY * geometry.size.height
                        )
                        .overlay(
                            // 选择指示器
                            VStack {
                                HStack {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .font(.caption)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(Color.green)
                                            .clipShape(Circle())
                                    }
                                    Spacer()
                                }
                                Spacer()
                            }
                            .frame(
                                width: object.boundingBox.width * geometry.size.width,
                                height: object.boundingBox.height * geometry.size.height
                            )
                            .position(
                                x: object.boundingBox.midX * geometry.size.width,
                                y: object.boundingBox.midY * geometry.size.height
                            )
                        )
                        .onTapGesture {
                            toggleObjectSelection(index)
                        }
                }
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DisclosureGroup("高级选项", isExpanded: $showAdvancedOptions) {
                VStack(spacing: 16) {
                    // 基础设置
                    VStack(alignment: .leading, spacing: 12) {
                        Text("识别设置")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        SettingToggleRow(
                            title: "物体检测",
                            subtitle: "自动检测照片中的多个物品",
                            icon: "viewfinder",
                            isOn: $useObjectDetection
                        )
                        
                        SettingToggleRow(
                            title: "图像增强",
                            subtitle: "自动优化图像质量以提高识别准确度",
                            icon: "wand.and.stars",
                            isOn: $enhanceImage
                        )
                        
                        SettingToggleRow(
                            title: "智能选择",
                            subtitle: "自动选择最佳识别对象",
                            icon: "brain.head.profile",
                            isOn: $autoSelectBestObject
                        )
                    }
                    
                    Divider()
                    
                    // 离线模式设置
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("离线模式")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("管理模型") {
                                showOfflineSettings = true
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        SettingToggleRow(
                            title: "启用离线识别",
                            subtitle: "在无网络时使用本地模型",
                            icon: "wifi.slash",
                            isOn: $useOfflineMode
                        )
                        
                        if useOfflineMode {
                            let availableCategories = offlineService.getAvailableCategories()
                            if availableCategories.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("没有可用的离线模型，请下载模型")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("可用模型:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Text(availableCategories.map { $0.displayName }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 对象选择模式
                    if useObjectDetection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("对象选择模式")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Picker("选择模式", selection: $objectSelectionMode) {
                                ForEach(ObjectSelectionMode.allCases, id: \.self) { mode in
                                    HStack {
                                        Image(systemName: mode.icon)
                                        Text(mode.displayName)
                                    }
                                    .tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    // 置信度阈值设置
                    VStack(alignment: .leading, spacing: 12) {
                        DisclosureGroup("置信度设置", isExpanded: $showConfidenceThreshold) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("最低置信度")
                                        .font(.caption)
                                    Spacer()
                                    Text("\(Int(confidenceThreshold * 100))%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Slider(value: $confidenceThreshold, in: 0.3...0.95, step: 0.05)
                                    .accentColor(.blue)
                                
                                Text("低于此置信度的识别结果将被标记为不确定")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - 图像处理进度显示
    private var imageProcessingProgressSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("图像处理中")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(currentProcessingStep)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Text("\(Int(imageProcessingProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: imageProcessingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            if imageProcessingProgress > 0.5 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("图像质量检测完成")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
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
                errorMessage = nil
                processImage()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // 重复的 recognitionActionButtons 定义已删除
    
    /// 离线识别结果显示
    private func offlineResultSection(_ result: OfflineRecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("离线识别结果")
                    .font(.headline)
                
                Spacer()
                
                Text("置信度: \(String(format: "%.1f%%", result.confidence * 100))")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(confidenceColor(result.confidence).opacity(0.2))
                    .foregroundColor(confidenceColor(result.confidence))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(result.category.icon)
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.category.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("基于本地模型识别")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if result.needsOnlineVerification {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("建议连接网络进行在线验证以获得更准确的结果")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                HStack {
                    Button("使用此结果") {
                        let itemInfo = ItemInfo(
                            name: result.category.displayName,
                            category: result.category,
                            weight: 100.0,
                            volume: 100.0,
                            confidence: result.confidence,
                            source: "离线识别"
                        )
                        onItemIdentified(itemInfo)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if !useOfflineMode {
                        Button("在线验证") {
                            useOfflineMode = false
                            identifyWholeImage()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    /// 根据置信度返回颜色
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    // 重复的 recognitionResultsSection 定义已删除
    
    /// 批量识别进度显示
    private func batchProgressSection(_ progress: BatchProgress) -> some View {
        VStack(spacing: 12) {
            Text("批量识别进行中...")
                .font(.headline)
            
            ProgressView(value: progress.overallProgress) {
                Text("\(progress.completedItems)/\(progress.totalItems) 已完成")
            }
            .progressViewStyle(LinearProgressViewStyle())
            
            if let estimatedTime = progress.estimatedTimeRemaining {
                Text("预计剩余时间: \(Int(estimatedTime))秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !progress.currentItem.isEmpty {
                Text("正在识别: \(progress.currentItem)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("取消") {
                batchService.cancelCurrentBatch()
                isProcessing = false
                batchProgress = nil
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    /// 批量识别结果显示
    private func batchResultsSection(_ result: BatchRecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            batchResultsHeader(result)
            batchResultsStats(result)
            batchSuccessfulItems(result)
            batchFailedItems(result)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func batchResultsHeader(_ result: BatchRecognitionResult) -> some View {
        HStack {
            Text("批量识别结果")
                .font(.headline)
            
            Spacer()
            
            Button("关闭") {
                showBatchResults = false
                batchRecognitionResult = nil
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func batchResultsStats(_ result: BatchRecognitionResult) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("成功: \(result.successfulRecognitions.count)")
                    .foregroundColor(.green)
                Text("失败: \(result.failedObjects.count)")
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("成功率: \(String(format: "%.1f", result.successRate * 100))%")
                Text("处理时间: \(String(format: "%.1f", result.processingTime))秒")
            }
        }
        .font(.caption)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func batchSuccessfulItems(_ result: BatchRecognitionResult) -> some View {
        Group {
            if !result.successfulRecognitions.isEmpty {
                Text("识别成功的物品")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(result.successfulRecognitions, id: \.id) { item in
                    batchItemCard(item)
                }
            }
        }
    }
    
    private func batchItemCard(_ item: ItemInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.headline)
            Text(item.category.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("使用此物品") {
                onItemIdentified(item)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func batchFailedItems(_ result: BatchRecognitionResult) -> some View {
        Group {
            if !result.failedObjects.isEmpty {
                Text("识别失败的物品")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                ForEach(result.failedObjects, id: \.id) { failedObject in
                    batchFailedItemCard(failedObject)
                }
            }
        }
    }
    
    private func batchFailedItemCard(_ failedObject: DetectedObject) -> some View {
        HStack {
            if let thumbnail = failedObject.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading) {
                Text("物品 \(failedObject.id.uuidString.prefix(8))")
                    .font(.caption)
                Text("置信度: \(String(format: "%.1f", failedObject.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("重试") {
                // 重试逻辑
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    /// 处理图像
    private func processImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        detectedObjects = []
        selectedObjectIndices.removeAll()
        identifiedItems = []
        batchRecognitionResult = nil
        detectionResult = nil
        currentPhotoError = nil
        imageProcessingProgress = 0.0
        currentProcessingStep = ""
        
        // 创建处理操作
        let operation = loadingManager.startOperation(
            id: "image_processing_\(UUID().uuidString)",
            type: .ai,
            title: "处理图像",
            description: "正在分析和优化图像质量...",
            canCancel: true,
            estimatedDuration: 8.0
        )
        
        processingOperation = operation
        
        Task {
            do {
                let preprocessor = MockImagePreprocessor.shared
                
                // 1. 图像质量验证
                await updateProcessingProgress(0.1, "验证图像质量...")
                let qualityResult = await preprocessor.validateImageQuality(image)
                
                if !qualityResult.isAcceptable {
                    // 创建图像质量错误
                    let photoError = PhotoRecognitionError.insufficientLighting
                    
                    await MainActor.run {
                        currentPhotoError = photoError
                        isProcessing = false
                        processingOperation = nil
                        loadingManager.failOperation(operationId: operation.id, error: photoError)
                    }
                    
                    // 使用错误恢复管理器处理错误
                    // _ = await errorRecoveryManager.handlePhotoRecognitionError(photoError, for: image)
                    
                    await MainActor.run {
                        showErrorGuidance = true
                    }
                    return
                }
                
                // 2. 图像预处理
                await updateProcessingProgress(0.3, "优化图像质量...")
                if enhanceImage {
                    processedImage = await enhanceImageQuality(image)
                } else {
                    // 即使不增强，也进行基本标准化
                    processedImage = await preprocessor.normalizeImage(image)
                }
                
                // 3. 对象检测
                if useObjectDetection {
                    await updateProcessingProgress(0.6, "检测物品...")
                    let result = await objectDetector.detectAndGroupObjects(in: processedImage ?? image)
                    
                    await MainActor.run {
                        detectionResult = result
                        detectedObjects = result.objects
                        
                        if detectedObjects.isEmpty {
                            // 没有检测到物品
                            let noObjectsError = PhotoRecognitionError.noObjectsDetected
                            currentPhotoError = noObjectsError
                            
                            // Task {
                            //     _ = await errorRecoveryManager.handlePhotoRecognitionError(noObjectsError, for: image)
                            //     await MainActor.run {
                            //         showErrorGuidance = true
                            //     }
                            // }
                        } else {
                            // 根据设置自动选择对象
                            if autoSelectBestObject {
                                performSmartSelection()
                            } else if detectedObjects.count == 1 {
                                selectedObjectIndices = [0]
                            }
                        }
                    }
                }
                
                await updateProcessingProgress(1.0, "处理完成")
                
                await MainActor.run {
                    isProcessing = false
                    processingOperation = nil
                    loadingManager.completeOperation(operationId: operation.id)
                }
                
            } catch {
                // 处理其他错误
                await MainActor.run {
                    let generalError = PhotoRecognitionError.recognitionServiceUnavailable
                    currentPhotoError = generalError
                    isProcessing = false
                    processingOperation = nil
                    loadingManager.failOperation(operationId: operation.id, error: error)
                }
                
                _ = await errorRecoveryManager.handlePhotoRecognitionError(currentPhotoError!, for: image)
                
                await MainActor.run {
                    showErrorGuidance = true
                }
            }
        }
    }
    
    /// 更新处理进度
    private func updateProcessingProgress(_ progress: Double, _ step: String) async {
        await MainActor.run {
            imageProcessingProgress = progress
            currentProcessingStep = step
            
            if let operation = processingOperation {
                operation.progress = progress
                operation.currentStep = step
            }
        }
    }
    
    /// 增强图像质量
    private func enhanceImageQuality(_ image: UIImage) async -> UIImage {
        // 使用新的 ImagePreprocessor 进行图像预处理
        let preprocessor = ImagePreprocessor.shared
        
        // 首先验证图像质量
        let qualityResult = await preprocessor.validateImageQuality(image)
        
        if qualityResult.isAcceptable {
            // 如果质量已经可接受，只进行标准化
            return await preprocessor.normalizeImage(image)
        } else {
            // 如果质量不佳，进行综合预处理
            let preprocessingResult = await preprocessor.preprocessImage(image, options: .default)
            return preprocessingResult.processedImage
        }
    }
    
    /// 检测图像中的物体
    private func detectObjects(in image: UIImage) async -> [DetectedObject] {
        guard let cgImage = image.cgImage else { return [] }
        
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.minimumSize = 0.1
        request.maximumObservations = 10
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results else {
                return []
            }
            
            var detectedObjects: [DetectedObject] = []
            
            for (index, observation) in results.enumerated() {
                let boundingBox = observation.boundingBox
                
                // 创建缩略图
                let thumbnail = cropImage(image, to: boundingBox)
                
                detectedObjects.append(
                    DetectedObject(
                        boundingBox: boundingBox,
                        confidence: Double(observation.confidence),
                        category: .other,
                        thumbnail: thumbnail
                    )
                )
            }
            
            return detectedObjects
            
        } catch {
            await MainActor.run {
                errorMessage = "物体检测失败: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    /// 裁剪图像
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        // 注意：Vision 的坐标系是左下角原点，UIKit 是左上角原点
        let flippedRect = CGRect(
            x: rect.minX,
            y: 1 - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: CGRect(
                x: flippedRect.minX * CGFloat(cgImage.width),
                y: flippedRect.minY * CGFloat(cgImage.height),
                width: flippedRect.width * CGFloat(cgImage.width),
                height: flippedRect.height * CGFloat(cgImage.height)
              )) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage)
    }
    
    /// 识别选中的物体
    private func identifySelectedObject() {
        guard let index = selectedObjectIndices.first,
              index < detectedObjects.count,
              let thumbnail = detectedObjects[index].thumbnail,
              let imageData = thumbnail.jpegData(compressionQuality: 0.8) else {
            identifyWholeImage()
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                await aiViewModel.identifyItemFromPhoto(imageData)
                
                // identifiedItems 的更新将通过 .onChange 监听 aiViewModel.identifiedItem 来完成
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "识别失败: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    /// 识别整个图像
    private func identifyWholeImage() {
        guard let image = processedImage ?? selectedImage else {
            return
        }
        
        isProcessing = true
        errorMessage = nil
        offlineResult = nil
        
        Task {
            do {
                if useOfflineMode {
                    // 使用离线识别
                    let result = try await offlineService.recognizeOffline(image)
                    
                    await MainActor.run {
                        offlineResult = result
                        
                        // 将离线识别结果转换为 ItemInfo
                        let itemInfo = ItemInfo(
                            name: result.category.displayName,
                            category: result.category,
                            weight: 100.0, // 默认重量
                            volume: 100.0, // 默认体积
                            confidence: result.confidence,
                            source: "离线识别"
                        )
                        
                        identifiedItems = [itemInfo]
                        isProcessing = false
                        
                        if result.needsOnlineVerification {
                            errorMessage = "离线识别置信度较低，建议连接网络进行在线验证"
                        }
                    }
                } else {
                    // 使用在线识别
                    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                        await MainActor.run {
                            errorMessage = "图像处理失败"
                            isProcessing = false
                        }
                        return
                    }
                    
                    await aiViewModel.identifyItemFromPhoto(imageData)
                    
                    // identifiedItems 的更新将通过 .onChange 监听 aiViewModel.identifiedItem 来完成
                    await MainActor.run {
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    if useOfflineMode {
                        errorMessage = "离线识别失败: \(error.localizedDescription)"
                        
                        // 如果离线识别失败，提示用户尝试在线识别
                        if let offlineError = error as? OfflineRecognitionError {
                            switch offlineError {
                            case .noModelAvailable:
                                errorMessage = "没有可用的离线模型，请下载模型或切换到在线模式"
                            case .modelNotAvailable:
                                errorMessage = "所需的离线模型不可用，请下载相应模型"
                            default:
                                errorMessage = "离线识别失败: \(error.localizedDescription)，建议尝试在线识别"
                            }
                        }
                    } else {
                        errorMessage = "识别失败: \(error.localizedDescription)"
                    }
                    isProcessing = false
                }
            }
        }
    }
    
    /// 执行批量识别
    private func performBatchRecognition() {
        guard let image = processedImage ?? selectedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        batchProgress = nil
        
        Task {
            do {
                let result = try await batchService.recognizeAllObjects(in: image) { progress in
                    Task { @MainActor in
                        self.batchProgress = progress
                    }
                }
                
                await MainActor.run {
                    batchRecognitionResult = result
                    showBatchResults = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "批量识别失败: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    /// 识别选定的多个物品
    private func recognizeSelectedObjects(_ objects: [DetectedObject]) {
        guard let image = processedImage ?? selectedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await batchService.recognizeSelectedObjects(objects, from: image) { progress in
                    Task { @MainActor in
                        self.batchProgress = progress
                    }
                }
                
                await MainActor.run {
                    batchRecognitionResult = result
                    showBatchResults = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "选定物品识别失败: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 重复的方法定义已删除
    
    /// 重置状态
    private func resetState() {
        selectedImage = nil
        processedImage = nil
        isProcessing = false
        imageProcessingProgress = 0.0
        currentProcessingStep = ""
        detectedObjects = []
        selectedObjectIndices.removeAll()
        identifiedItems = []
        errorMessage = nil
        batchRecognitionResult = nil
        showBatchResults = false
        batchProgress = nil
        detectionResult = nil
        offlineResult = nil
        processingOperation = nil
        
        // 取消当前批量任务
        batchService.cancelCurrentBatch()
        
        // 取消加载操作
        if let operation = processingOperation {
            loadingManager.cancelOperation(operationId: operation.id)
        }
    }
    
    /// 重置对象选择
    private func resetObjectSelection() {
        selectedObjectIndices.removeAll()
    }
    
    /// 切换对象选择
    private func toggleObjectSelection(_ index: Int) {
        switch objectSelectionMode {
        case .single:
            selectedObjectIndices = [index]
        case .multiple:
            if selectedObjectIndices.contains(index) {
                selectedObjectIndices.remove(index)
            } else {
                selectedObjectIndices.insert(index)
            }
        case .smart:
            performSmartSelection()
        }
    }
    
    /// 根据选择模式更新选择
    private func updateSelectionForMode() {
        switch objectSelectionMode {
        case .single:
            if selectedObjectIndices.count > 1 {
                selectedObjectIndices = Set([selectedObjectIndices.first!])
            }
        case .multiple:
            // 保持当前选择
            break
        case .smart:
            performSmartSelection()
        }
    }
    
    /// 执行智能选择
    private func performSmartSelection() {
        guard !detectedObjects.isEmpty else { return }
        
        // 根据置信度和大小选择最佳对象
        let sortedObjects = detectedObjects.enumerated().sorted { first, second in
            let firstScore = Double(first.element.confidence) * Double(first.element.boundingBox.width * first.element.boundingBox.height)
            let secondScore = Double(second.element.confidence) * Double(second.element.boundingBox.width * second.element.boundingBox.height)
            return firstScore > secondScore
        }
        
        if autoSelectBestObject {
            // 只选择最佳对象
            selectedObjectIndices = Set([sortedObjects.first!.offset])
        } else {
            // 选择前几个高质量对象
            let topObjects = sortedObjects.prefix(min(3, sortedObjects.count))
            selectedObjectIndices = Set(topObjects.map { $0.offset })
        }
    }
    
    /// 获取图像质量分数
    private func getImageQualityScore(_ image: UIImage) -> Double? {
        // 这里应该调用实际的图像质量评估服务
        // 暂时返回一个模拟值
        return 0.85
    }
    
    /// 取消当前操作
    private func cancelCurrentOperation() {
        isProcessing = false
        
        if let operation = processingOperation {
            loadingManager.cancelOperation(operationId: operation.id)
            processingOperation = nil
        }
        
        batchService.cancelCurrentBatch()
        imageProcessingProgress = 0.0
        currentProcessingStep = ""
    }
    
    /// 识别选定的对象
    private func recognizeSelectedObjects(_ indices: [Int]) {
        guard !indices.isEmpty else { return }
        
        if indices.count == 1 {
            // 单个对象识别
            let index = indices[0]
            guard index < detectedObjects.count,
                  let thumbnail = detectedObjects[index].thumbnail else {
                identifyWholeImage()
                return
            }
            
            isProcessing = true
            
            // 创建加载操作
            let operation = loadingManager.startOperation(
                id: "single_recognition_\(UUID().uuidString)",
                type: .ai,
                title: "识别物品",
                description: "正在分析选中的物品...",
                canCancel: true,
                estimatedDuration: 5.0
            )
            
            processingOperation = operation
            
            Task {
                do {
                    guard let imageData = thumbnail.jpegData(compressionQuality: 0.8) else {
                        throw PhotoRecognitionError.imageTooBig(currentSize: 0, maxSize: 10)
                    }
                    
                    await aiViewModel.identifyItemFromPhoto(imageData)
                    
                    await MainActor.run {
                        isProcessing = false
                        processingOperation = nil
                        loadingManager.completeOperation(operationId: operation.id)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "识别失败: \(error.localizedDescription)"
                        isProcessing = false
                        processingOperation = nil
                        loadingManager.failOperation(operationId: operation.id, error: error)
                    }
                }
            }
        } else {
            // 批量识别
            performBatchRecognition()
        }
    }
    
    // MARK: - 错误恢复处理
    
    /// 处理恢复结果
    private func handleRecoveryResult(_ result: RecoveryResult) {
        switch result {
        case .imageEnhanced(let enhancedImage):
            selectedImage = enhancedImage
            processedImage = enhancedImage
            processImage()
            
        case .imageCompressed(let compressedImage):
            selectedImage = compressedImage
            processedImage = compressedImage
            processImage()
            
        case .imageConverted(let convertedImage):
            selectedImage = convertedImage
            processedImage = convertedImage
            processImage()
            
        case .offlineModeActivated:
            useOfflineMode = true
            processImageOffline()
            
        case .modelDownloaded:
            // 模型下载完成，可以使用离线模式
            useOfflineMode = true
            processImageOffline()
            
        case .permissionResult(let granted):
            if granted {
                // 权限已授予，可以重新尝试相机功能
                showCamera = true
            } else {
                errorMessage = "需要相机权限才能使用拍照功能"
            }
            
        case .actionCompleted:
            // 通用完成操作，重新处理图像
            processImage()
        }
    }
    
    /// 离线模式处理图像
    private func processImageOffline() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        
        Task {
            do {
                let result = try await offlineService.recognizeOffline(image)
                
                await MainActor.run {
                    offlineResult = result
                    isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "离线识别失败：\(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}

/// 照片选择器
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageSelected: (() -> Void)? = nil
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    guard let self = self, let image = image as? UIImage else { return }
                    self.parent.image = image
                    self.parent.onImageSelected?()
                }
            }
        }
    }
}

// MARK: - 辅助UI组件

/// 照片选择按钮
struct PhotoSelectionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .opacity(0.7)
                }
            }
            .frame(width: 120, height: 100)
            .background(color.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 图像质量指示器
struct ImageQualityIndicator: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)
            
            Text(qualityText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(qualityColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(qualityColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var qualityColor: Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .orange }
        else { return .red }
    }
    
    private var qualityText: String {
        if score >= 0.8 { return "优秀" }
        else if score >= 0.6 { return "良好" }
        else { return "较差" }
    }
}

/// 处理进度覆盖层
struct ProcessingProgressOverlay: View {
    let progress: Double
    let step: String
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

/// 设置切换行
struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

/// 场景复杂度指示器
struct SceneComplexityIndicator: View {
    let complexity: SceneComplexity
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: complexity.icon)
                .foregroundColor(complexity.color)
                .font(.caption)
            
            Text("场景复杂度: \(complexity.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(complexity.color.opacity(0.1))
        .cornerRadius(8)
    }
}

/// 空对象检测视图
struct EmptyObjectDetectionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "viewfinder")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("未检测到物品")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("请尝试调整照片角度或光线，或关闭物体检测功能")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

/// 对象缩略图卡片
struct ObjectThumbnailCard: View {
    let object: DetectedObject
    let index: Int
    let isSelected: Bool
    let selectionMode: ObjectSelectionMode
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    if let thumbnail = object.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // 选择指示器
                    VStack {
                        HStack {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .font(.caption)
                            } else if selectionMode != .smart {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(4)
                }
                
                // 置信度指示器
                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)
                    
                    Text("\(Int(object.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(confidenceColor)
                }
            }
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                )
        )
    }
    
    private var confidenceColor: Color {
        if object.confidence >= 0.8 { return .green }
        else if object.confidence >= 0.6 { return .orange }
        else { return .red }
    }
}



/// 增强的物品信息卡片
struct EnhancedItemInfoCard: View {
    let item: ItemInfo
    let showDetailedInfo: Bool
    let onUse: () -> Void
    let onViewAlternatives: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    Text(item.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(item.category.icon)
                    .font(.system(size: 32))
            }
            
            if showDetailedInfo {
                Divider()
                
                // 详细信息网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    InfoGridItem(title: "重量", value: "\(String(format: "%.1f", item.weight/1000)) kg", icon: "scalemass")
                    InfoGridItem(title: "体积", value: "\(String(format: "%.1f", item.volume/1000)) L", icon: "cube")
                    
                    if let dimensions = item.dimensions {
                        InfoGridItem(title: "尺寸", value: dimensions.formatted, icon: "ruler")
                    }
                    
                    InfoGridItem(title: "来源", value: item.source, icon: "info.circle")
                }
            }
            
            Divider()
            
            // 操作按钮
            HStack(spacing: 12) {
                if let onViewAlternatives = onViewAlternatives, !item.alternatives.isEmpty {
                    Button {
                        onViewAlternatives()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("替代品")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button {
                    onUse()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                        Text("使用此结果")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

/// 信息网格项
struct InfoGridItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// 离线结果卡片
struct OfflineResultCard: View {
    let result: OfflineRecognitionResult
    let onUse: (ItemInfo) -> Void
    let onVerifyOnline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.category.icon)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.category.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("基于本地模型识别")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if result.needsOnlineVerification {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("建议连接网络进行在线验证以获得更准确的结果")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack(spacing: 12) {
                Button("使用此结果") {
                    let itemInfo = ItemInfo(
                        name: result.category.displayName,
                        category: result.category,
                        weight: 100.0,
                        volume: 100.0,
                        confidence: result.confidence,
                        source: "离线识别"
                    )
                    onUse(itemInfo)
                }
                .buttonStyle(.borderedProminent)
                
                Button("在线验证") {
                    onVerifyOnline()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
    }
}

/// 批量结果摘要卡片
struct BatchResultSummaryCard: View {
    let result: BatchRecognitionResult
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("成功识别")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(result.successfulRecognitions.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("识别失败")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(result.failedObjects.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("成功率")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(result.successRate * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#if DEBUG
struct AIPhotoIdentificationView_Previews: PreviewProvider {
    static let mockOnItemIdentified: (ItemInfo) -> Void = { itemInfo in
        print("Mock item identified: \(itemInfo.name)")
    }

    static var previews: some View {
        AIPhotoIdentificationView(onItemIdentified: mockOnItemIdentified)
    }
}
#endif