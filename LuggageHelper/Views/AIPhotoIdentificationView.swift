import SwiftUI
import PhotosUI
import Vision

/// AI 照片识别视图
/// 提供基于照片的物品识别功能，包括图像预处理和多物品识别
struct AIPhotoIdentificationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var aiViewModel: AIViewModel // No direct initialization here
    
    @State private var selectedImage: UIImage? = nil
    @State private var processedImage: UIImage? = nil
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var isProcessing = false
    @State private var detectedObjects: [DetectedObject] = []
    @State private var selectedObjectIndex: Int? = nil
    @State private var identifiedItems: [ItemInfo] = []
    @State private var errorMessage: String? = nil
    @State private var showAdvancedOptions = false
    @State private var useObjectDetection = true
    @State private var enhanceImage = true
    
    // 回调函数，用于将识别结果传递给父视图
    let onItemIdentified: (ItemInfo) -> Void // Required let

    init(onItemIdentified: @escaping (ItemInfo) -> Void) {
        self.onItemIdentified = onItemIdentified
        _aiViewModel = StateObject(wrappedValue: AIViewModel()) // Initialize StateObject
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // 照片选择区域
                    photoSelectionSection
                    
                    // 高级选项
                    advancedOptionsSection
                    
                    // 处理中状态
                    if isProcessing {
                        processingSection()
                    }
                    
                    // 错误信息
                    if let error = errorMessage {
                        errorSection(error)
                    }
                    
                    // 检测到的物体
                    if !detectedObjects.isEmpty && selectedImage != nil {
                        detectedObjectsSection
                    }
                    
                    // 识别结果
                    if !identifiedItems.isEmpty {
                        identifiedItemsSection
                    }
                }
                .padding()
            }
            .onChange(of: aiViewModel.identifiedItem) { newItem in
                if let item = newItem {
                    identifiedItems = [item]
                } else {
                    identifiedItems = []
                }
            }
            .navigationTitle("照片识别")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
    
    // MARK: - View Components
    
    private var photoSelectionSection: some View {
        VStack(spacing: 16) {
            if let image = processedImage ?? selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        objectDetectionOverlay
                    )
                
                HStack {
                    Button("重新选择") {
                        resetState()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("识别物品") {
                        if useObjectDetection && !detectedObjects.isEmpty {
                            identifySelectedObject()
                        } else {
                            identifyWholeImage()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
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
                        .frame(width: 120, height: 120)
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
                        .frame(width: 120, height: 120)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Text("拍摄物品照片或从相册选择，AI 将自动识别物品")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }
    
    private var objectDetectionOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // 绘制所有检测到的物体边界框
                ForEach(detectedObjects.indices, id: \.self) { index in
                    let object = detectedObjects[index]
                    let isSelected = index == selectedObjectIndex
                    
                    Rectangle()
                        .stroke(isSelected ? Color.blue : Color.green, lineWidth: isSelected ? 3 : 2)
                        .frame(
                            width: object.boundingBox.width * geometry.size.width,
                            height: object.boundingBox.height * geometry.size.height
                        )
                        .position(
                            x: object.boundingBox.midX * geometry.size.width,
                            y: object.boundingBox.midY * geometry.size.height
                        )
                        .onTapGesture {
                            selectedObjectIndex = index
                        }
                }
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup("高级选项", isExpanded: $showAdvancedOptions) {
                VStack(spacing: 12) {
                    Toggle("使用物体检测", isOn: $useObjectDetection)
                    Toggle("增强图像质量", isOn: $enhanceImage)
                    
                    Text("物体检测可以识别照片中的多个物品，增强图像质量可以提高识别准确度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func processingSection() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在处理图像...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
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
    
    private var detectedObjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("检测到的物体")
                .font(.headline)
            
            if detectedObjects.isEmpty {
                Text("未检测到物体，请尝试调整照片或关闭物体检测")
                    .foregroundColor(.secondary)
            } else {
                Text("点击选择要识别的物体")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(detectedObjects.indices, id: \.self) { index in
                            let object = detectedObjects[index]
                            let isSelected = index == selectedObjectIndex
                            
                            Button {
                                selectedObjectIndex = index
                            } label: {
                                VStack {
                                    if let thumbnail = object.thumbnail {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 80)
                                            .cornerRadius(8)
                                    }
                                    
                                    Text("物体 \(index + 1)")
                                        .font(.caption)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private var identifiedItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("识别结果")
                .font(.headline)
            
            ForEach(identifiedItems) { item in
                AIItemInfoCard(
                    item: item,
                    onUse: {
                        onItemIdentified(item)
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 处理图像
    private func processImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        detectedObjects = []
        selectedObjectIndex = nil
        identifiedItems = []
        
        Task {
            // 1. 图像预处理
            if enhanceImage {
                processedImage = await enhanceImageQuality(image)
            }
            
            // 2. 物体检测
            if useObjectDetection {
                detectedObjects = await detectObjects(in: processedImage ?? image)
                if !detectedObjects.isEmpty {
                    selectedObjectIndex = 0 // 默认选择第一个物体
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    /// 增强图像质量
    private func enhanceImageQuality(_ image: UIImage) async -> UIImage {
        // 这里可以添加图像增强的代码，如调整亮度、对比度等
        // 简单实现：调整大小和压缩
        let maxDimension: CGFloat = 1024
        let scale: CGFloat
        
        if image.size.width > image.size.height {
            scale = maxDimension / image.size.width
        } else {
            scale = maxDimension / image.size.height
        }
        
        if scale < 1 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            
            return resizedImage
        }
        
        return image
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
                        id: index,
                        boundingBox: boundingBox,
                        confidence: observation.confidence,
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
        guard let index = selectedObjectIndex,
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
        guard let image = processedImage ?? selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
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
    
    /// 重置状态
    private func resetState() {
        selectedImage = nil
        processedImage = nil
        isProcessing = false
        detectedObjects = []
        selectedObjectIndex = nil
        identifiedItems = []
        errorMessage = nil
    }
}

/// 检测到的物体
struct DetectedObject: Identifiable {
    let id: Int
    let boundingBox: CGRect
    let confidence: Float
    let thumbnail: UIImage?
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