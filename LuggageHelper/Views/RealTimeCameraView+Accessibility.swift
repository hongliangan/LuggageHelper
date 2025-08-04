import SwiftUI
import AVFoundation

// MARK: - RealTimeCameraView Accessibility Extension

extension RealTimeCameraView {
    
    /// Configures accessibility support for the view.
    func configureAccessibility() -> some View {
        self
            .onAppear {
                setupCamera()
                setupAccessibilityForCamera()
            }
            .onChange(of: cameraManager.detectedObjects) { objects in
                announceObjectDetection(objects)
            }
            .onChange(of: recognitionResult) { result in
                if let result = result {
                    AccessibilityService.shared.announceRecognitionResult(result)
                }
            }
            .onChange(of: errorMessage) { error in
                if let error = error {
                    AccessibilityService.shared.announceRecognitionError(error)
                }
            }
    }
    
    private func setupAccessibilityForCamera() {
        AccessibilityService.shared.announcePageChange("实时相机识别")
        
        checkCameraPermission { granted in
            if granted {
                AccessibilityService.shared.announceCameraReady()
            } else {
                errorMessage = "需要相机权限才能使用此功能"
                if let errorMessage = errorMessage {
                    AccessibilityService.shared.announceRecognitionError(errorMessage)
                }
            }
        }
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func announceObjectDetection(_ objects: [RealTimeDetection]) {
        if !objects.isEmpty {
            AccessibilityService.shared.announceObjectDetection(count: objects.count)
            
            if AccessibilityService.shared.isVoiceOverEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let description = objects.enumerated().map { index, object in
                        "第\(index + 1)个物品，置信度\(Int(object.confidence * 100))%"
                    }.joined(separator: "，")
                    
                    AccessibilityService.shared.speak(description, priority: .low)
                }
            }
        }
    }
    
    // MARK: - Accessible UI Components
    
    /// An enhanced top control bar with accessibility features.
    var accessibleTopControlBar: some View {
        HStack {
            AccessibleCameraButton(icon: "xmark.circle.fill", title: "关闭", subtitle: nil, isEnabled: true) {
                dismiss()
            }
            .accessibilityLabel("关闭相机")
            .accessibilityHint("返回上一页面")
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(cameraManager.isDetecting ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                
                Text(cameraManager.isDetecting ? "检测中" : "已暂停")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .accessibilityLabel(cameraManager.isDetecting ? "物品检测已启动" : "物品检测已暂停")
            }
            
            Spacer()
            
            AccessibleCameraButton(icon: "gear", title: "设置", subtitle: nil, isEnabled: true) {
                showSettings = true
            }
            .accessibilityLabel("相机设置")
            .accessibilityHint("调整相机和识别设置")
        }
    }
    
    /// An enhanced bottom control bar with accessibility features.
    var accessibleBottomControlBar: some View {
        HStack(spacing: 30) {
            AccessibleCameraButton(
                icon: cameraManager.isDetecting ? "pause.circle.fill" : "play.circle.fill",
                title: cameraManager.isDetecting ? "暂停" : "开始",
                subtitle: "检测",
                isEnabled: true
            ) {
                if cameraManager.isDetecting {
                    cameraManager.stopDetection()
                    AccessibilityService.shared.announceButtonAction("已暂停物品检测")
                } else {
                    cameraManager.startDetection()
                    AccessibilityService.shared.announceButtonAction("已开始物品检测")
                }
                AccessibilityService.shared.provideFeedback(.selection)
            }
            .accessibilityLabel(cameraManager.isDetecting ? "暂停物品检测" : "开始物品检测")
            
            AccessibleCameraButton(
                icon: "camera.circle.fill",
                title: "拍照",
                subtitle: "识别",
                isEnabled: !isRecognizing
            ) {
                captureAndRecognizeWithCountdown()
            }
            .accessibilityLabel("拍照识别")
            .accessibilityHint("拍摄当前画面并识别物品")
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    /// An enhanced detection overlay with accessibility features.
    var accessibleDetectionOverlay: some View {
        GeometryReader { geometry in
            ForEach(cameraManager.detectedObjects.indices, id: \.self) { index in
                let object = cameraManager.detectedObjects[index]
                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: object.boundingBox.width * geometry.size.width, height: object.boundingBox.height * geometry.size.height)
                    .position(x: object.boundingBox.midX * geometry.size.width, y: object.boundingBox.midY * geometry.size.height)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("检测到的物品 \(index + 1)，置信度 \(Int(object.confidence * 100))%")
                    .accessibilityHint("双击立即识别此物品")
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture {
                        recognizeObject(at: index)
                    }
            }
        }
    }
    
    /// An enhanced recognition result overlay with accessibility features.
    func accessibleRecognitionResultOverlay(_ result: ItemInfo) -> some View {
        VStack(spacing: 16) {
            Text("识别结果")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .accessibilityAddTraits(.isHeader)
            
            accessibleResultCard(result)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
    }
    
    private func accessibleResultCard(_ result: ItemInfo) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(result.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(Int(result.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            Text(result.category.displayName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                AccessibleButton(title: "选择", accessibilityHint: "选择此物品并返回") {
                    onItemIdentified(result)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                AccessibleButton(title: "继续", accessibilityHint: "继续识别其他物品") {
                    recognitionResult = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("识别结果：\(result.name)，类别：\(result.category.displayName)，置信度：\(Int(result.confidence * 100))%")
    }
    
    /// An enhanced error overlay with accessibility features.
    func accessibleErrorOverlay(_ error: String) -> some View {
        AccessibleErrorView(
            error: error,
            suggestion: getErrorSuggestion(for: error),
            onRetry: {
                errorMessage = nil
                // Consider adding a retry mechanism if applicable
            },
            onDismiss: {
                errorMessage = nil
            }
        )
        .padding()
    }
    
    /// An enhanced loading overlay with accessibility features.
    var accessibleLoadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("正在识别...")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在识别物品，请稍候")
        .onAppear {
            AccessibilityService.shared.speak("正在识别物品", priority: .normal)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func captureAndRecognizeWithCountdown() {
        AccessibilityService.shared.announceButtonAction("开始拍照识别")
        AccessibilityService.shared.provideFeedback(.medium)
        
        var countdown = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                AccessibilityService.shared.announceCameraCountdown(countdown)
                countdown -= 1
            } else {
                timer.invalidate()
                performCapture()
            }
        }
    }
    
    private func performCapture() {
        AccessibilityService.shared.announceCameraCapture()
        
        Task {
            isRecognizing = true
            captureAndRecognize()
            isRecognizing = false
        }
    }
    
    private func recognizeObject(at index: Int) {
        guard index < cameraManager.detectedObjects.count else { return }
        
        let object = cameraManager.detectedObjects[index]
        AccessibilityService.shared.announceButtonAction("开始识别第\(index + 1)个物品")
        AccessibilityService.shared.provideFeedback(.medium)
        
        selectedDetectionBox = index
        
        Task {
            isRecognizing = true
            recognizeDetectedObject(object)
            isRecognizing = false
            selectedDetectionBox = nil
        }
    }
    
    private func getErrorSuggestion(for error: String) -> String? {
        if error.contains("网络") {
            return "请检查网络连接"
        } else if error.contains("权限") {
            return "请在设置中允许相机权限"
        } else if error.contains("光线") {
            return "请在光线充足的环境中使用"
        }
        return nil
    }
}



