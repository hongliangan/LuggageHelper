import SwiftUI
import AVFoundation
import Vision
import UIKit

/// 实时相机识别视图
/// 提供实时预览和物品检测功能，支持点击检测框立即识别
struct RealTimeCameraView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject internal var cameraManager = RealTimeCameraManager()
    @StateObject private var aiViewModel = AIViewModel()
    
    // 回调函数
    let onItemIdentified: (ItemInfo) -> Void
    
    // 状态管理
    @State internal var isRecognizing = false
    @State internal var recognitionResult: ItemInfo?
    @State internal var errorMessage: String?
    @State internal var showSettings = false
    @State internal var selectedDetectionBox: Int?
    
    init(onItemIdentified: @escaping (ItemInfo) -> Void) {
        self.onItemIdentified = onItemIdentified
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 相机预览层
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                // 检测框覆盖层 - 使用无障碍增强版本
                accessibleDetectionOverlay
                
                // 控制界面 - 使用无障碍增强版本
                VStack {
                    // 顶部控制栏
                    accessibleTopControlBar
                    
                    Spacer()
                    
                    // 底部控制栏
                    accessibleBottomControlBar
                }
                .padding()
                
                // 识别结果弹窗 - 使用无障碍增强版本
                if let result = recognitionResult {
                    accessibleRecognitionResultOverlay(result)
                }
                
                // 错误提示 - 使用无障碍增强版本
                if let error = errorMessage {
                    accessibleErrorOverlay(error)
                }
                
                // 加载指示器 - 使用无障碍增强版本
                if isRecognizing {
                    accessibleLoadingOverlay
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupCamera()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
            .sheet(isPresented: $showSettings) {
                RealTimeCameraSettingsView(cameraManager: cameraManager)
            }
        }
        .accessibilityLabel("实时相机视图")
        .accessibilityHint("用于实时识别物品的相机界面")
    }
    
    // MARK: - View Components
    
    private var topControlBar: some View {
        HStack {
            // 关闭按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // 检测状态指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(cameraManager.isDetecting ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(cameraManager.isDetecting ? "检测中" : "已暂停")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5))
            .cornerRadius(15)
            
            Spacer()
            
            // 设置按钮
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
    }
    
    private var bottomControlBar: some View {
        HStack(spacing: 20) {
            // 切换检测按钮
            Button {
                cameraManager.toggleDetection()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: cameraManager.isDetecting ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                    Text(cameraManager.isDetecting ? "暂停" : "开始")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            // 检测到的物品数量
            VStack(spacing: 4) {
                Text("\(cameraManager.detectedObjects.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("物品")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(12)
            
            Spacer()
            
            // 拍照识别按钮
            Button {
                captureAndRecognize()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.circle.fill")
                        .font(.title)
                    Text("拍照")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
            .disabled(isRecognizing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }
    
    private var detectionOverlay: some View {
        GeometryReader { geometry in
            ForEach(Array(cameraManager.detectedObjects.enumerated()), id: \.offset) { index, detection in
                let isSelected = selectedDetectionBox == index
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.blue : Color.green,
                        lineWidth: isSelected ? 3 : 2
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                    )
                    .frame(
                        width: detection.boundingBox.width * geometry.size.width,
                        height: detection.boundingBox.height * geometry.size.height
                    )
                    .position(
                        x: detection.boundingBox.midX * geometry.size.width,
                        y: detection.boundingBox.midY * geometry.size.height
                    )
                    .overlay(
                        // 置信度标签
                        VStack {
                            HStack {
                                Text("\(Int(detection.confidence * 100))%")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(4)
                                Spacer()
                            }
                            Spacer()
                        }
                        .frame(
                            width: detection.boundingBox.width * geometry.size.width,
                            height: detection.boundingBox.height * geometry.size.height
                        )
                        .position(
                            x: detection.boundingBox.midX * geometry.size.width,
                            y: detection.boundingBox.midY * geometry.size.height
                        )
                    )
                    .onTapGesture {
                        selectedDetectionBox = index
                        recognizeDetectedObject(detection)
                    }
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
    }
    
    private func recognitionResultOverlay(_ result: ItemInfo) -> some View {
        VStack(spacing: 16) {
            Text("识别结果")
                .font(.headline)
                .foregroundColor(.white)
            
            AIItemInfoCard(
                item: result,
                onUse: {
                    onItemIdentified(result)
                    dismiss()
                }
            )
            
            HStack(spacing: 16) {
                Button("重新识别") {
                    recognitionResult = nil
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
                
                Button("使用此结果") {
                    onItemIdentified(result)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .padding()
    }
    
    private func errorOverlay(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)
            
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Button("重试") {
                errorMessage = nil
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .padding()
    }
    
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("正在识别...")
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
    
    // MARK: - Methods
    
    func setupCamera() {
        Task {
            await cameraManager.requestPermission()
            if cameraManager.hasPermission {
                await cameraManager.startSession()
            } else {
                errorMessage = "需要相机权限才能使用实时识别功能"
            }
        }
    }
    
    func captureAndRecognize() {
        guard !isRecognizing else { return }
        
        isRecognizing = true
        errorMessage = nil
        recognitionResult = nil
        
        Task {
            do {
                if let image = await cameraManager.capturePhoto() {
                    let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
                    await aiViewModel.identifyItemFromPhoto(imageData)
                    
                    await MainActor.run {
                        if let identifiedItem = aiViewModel.identifiedItem {
                            recognitionResult = identifiedItem
                        } else {
                            errorMessage = "未能识别出物品，请重试"
                        }
                        isRecognizing = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "识别失败: \(error.localizedDescription)"
                    isRecognizing = false
                }
            }
        }
    }
    
    func recognizeDetectedObject(_ detection: RealTimeDetection) {
        guard !isRecognizing else { return }
        
        isRecognizing = true
        errorMessage = nil
        recognitionResult = nil
        
        Task {
            do {
                if let croppedImage = await cameraManager.cropDetectedObject(detection) {
                    let imageData = croppedImage.jpegData(compressionQuality: 0.8) ?? Data()
                    await aiViewModel.identifyItemFromPhoto(imageData)
                    
                    await MainActor.run {
                        if let identifiedItem = aiViewModel.identifiedItem {
                            recognitionResult = identifiedItem
                        } else {
                            errorMessage = "未能识别出选中的物品，请重试"
                        }
                        isRecognizing = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "识别失败: \(error.localizedDescription)"
                    isRecognizing = false
                }
            }
        }
    }
}

// MARK: - Camera Preview View

/// 相机预览视图
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: RealTimeCameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // 设置预览层
        let previewLayer = cameraManager.previewLayer
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新预览层frame
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Settings View

/// 实时相机设置视图
struct RealTimeCameraSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cameraManager: RealTimeCameraManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section("检测设置") {
                    HStack {
                        Text("检测间隔")
                        Spacer()
                        Text("\(String(format: "%.1f", cameraManager.detectionInterval))秒")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $cameraManager.detectionInterval,
                        in: 0.5...3.0,
                        step: 0.1
                    )
                    
                    HStack {
                        Text("最小置信度")
                        Spacer()
                        Text("\(Int(cameraManager.minimumConfidence * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $cameraManager.minimumConfidence,
                        in: 0.3...0.9,
                        step: 0.05
                    )
                    
                    Toggle("显示低置信度检测", isOn: $cameraManager.showLowConfidenceDetections)
                }
                
                Section("相机设置") {
                    Toggle("自动对焦", isOn: $cameraManager.autoFocusEnabled)
                    Toggle("自动曝光", isOn: $cameraManager.autoExposureEnabled)
                    
                    if cameraManager.hasFlash {
                        Picker("闪光灯", selection: $cameraManager.flashMode) {
                            Text("关闭").tag(AVCaptureDevice.FlashMode.off)
                            Text("自动").tag(AVCaptureDevice.FlashMode.auto)
                            Text("开启").tag(AVCaptureDevice.FlashMode.on)
                        }
                    }
                }
                
                Section("性能") {
                    Toggle("节能模式", isOn: $cameraManager.powerSavingMode)
                    
                    Text("节能模式会降低检测频率以节省电量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("相机设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RealTimeCameraView { item in
        print("识别到物品: \(item.name)")
    }
}