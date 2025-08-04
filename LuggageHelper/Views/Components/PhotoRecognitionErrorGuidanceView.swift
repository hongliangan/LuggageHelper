import SwiftUI

// MARK: - 照片识别错误引导视图
struct PhotoRecognitionErrorGuidanceView: View {
    @ObservedObject var errorRecoveryManager: PhotoRecognitionErrorRecoveryManager
    @State private var selectedObjectIndex: Int?
    @State private var isProcessingRecovery = false
    @State private var showingImagePreview = false
    @State private var previewImage: UIImage?
    
    let originalImage: UIImage?
    let onRecoveryCompleted: (RecoveryResult) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if let action = errorRecoveryManager.currentRecoveryAction {
                        recoveryActionView(for: action)
                    }
                    
                    if let progress = errorRecoveryManager.recoveryProgress {
                        recoveryProgressView(progress)
                    }
                }
                .padding()
            }
            .navigationTitle("识别问题解决")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showingImagePreview) {
            if let image = previewImage {
                ImagePreviewView(
                    image: image,
                    detectedObjects: [],
                    selectedIndices: .constant(Set<Int>()),
                    selectionMode: .single,
                    onDismiss: {
                        showingImagePreview = false
                    },
                    onRecognize: { _ in
                        showingImagePreview = false
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func recoveryActionView(for action: RecoveryAction) -> some View {
        switch action {
        case .enhanceImage(let title, let message, let enhancements, let showPreview, let fallbackSuggestions):
            enhanceImageView(title: title, message: message, enhancements: enhancements, showPreview: showPreview, fallbackSuggestions: fallbackSuggestions)
            
        case .suggestRetake(let title, let message, let issues, let guidance):
            suggestRetakeView(title: title, message: message, issues: issues, guidance: guidance)
            
        case .suggestManualInput(let title, let message, let suggestions, let alternativeActions):
            suggestManualInputView(title: title, message: message, suggestions: suggestions, alternativeActions: alternativeActions)
            
        case .showObjectSelection(let title, let message, let objects, let canSelectMultiple):
            objectSelectionView(title: title, message: message, objects: objects, canSelectMultiple: canSelectMultiple)
            
        case .fallbackToOffline(let title, let message, let capabilities, let limitations):
            offlineFallbackView(title: title, message: message, capabilities: capabilities, limitations: limitations)
            
        case .waitForNetwork(let title, let message, let suggestions, let canDownloadModel):
            networkWaitView(title: title, message: message, suggestions: suggestions, canDownloadModel: canDownloadModel)
            
        case .downloadOfflineModel(let title, let message, let modelInfo, let estimatedSize, let canSkip):
            downloadModelView(title: title, message: message, modelInfo: modelInfo, estimatedSize: estimatedSize, canSkip: canSkip)
            
        case .requestPermission(let title, let message, let permissionType, let settingsLink):
            permissionRequestView(title: title, message: message, permissionType: permissionType, settingsLink: settingsLink)
            
        default:
            genericRecoveryView(for: action)
        }
    }
    
    // MARK: - 具体恢复视图
    
    private func enhanceImageView(title: String, message: String, enhancements: [ImageEnhancement], showPreview: Bool, fallbackSuggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "wand.and.stars",
                title: title,
                message: message,
                iconColor: .blue
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("正在应用以下优化：")
                    .font(.headline)
                
                ForEach(enhancements.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(enhancements[index].description)
                            .font(.body)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if showPreview && originalImage != nil {
                Button("预览优化效果") {
                    showImagePreview()
                }
                .buttonStyle(.bordered)
            }
            
            if !fallbackSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("如果自动优化效果不佳，建议：")
                        .font(.headline)
                    
                    ForEach(fallbackSuggestions, id: \.self) { suggestion in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            Text(suggestion)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .background(Color(.systemYellow).opacity(0.1))
                .cornerRadius(12)
            }
            
            HStack(spacing: 16) {
                Button("应用优化") {
                    executeRecovery()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessingRecovery)
                
                Button("重新拍摄") {
                    // 触发重新拍摄
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func suggestRetakeView(title: String, message: String, issues: [String], guidance: RetakeGuidance) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "camera.fill",
                title: title,
                message: message,
                iconColor: .orange
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("检测到的问题：")
                    .font(.headline)
                
                ForEach(issues, id: \.self) { issue in
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text(issue)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(Color(.systemOrange).opacity(0.1))
            .cornerRadius(12)
            
            RetakeGuidanceView(guidance: guidance)
            
            HStack(spacing: 16) {
                Button("重新拍摄") {
                    // 触发重新拍摄
                }
                .buttonStyle(.borderedProminent)
                
                Button("手动输入") {
                    // 触发手动输入
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func suggestManualInputView(title: String, message: String, suggestions: [String], alternativeActions: [AlternativeAction]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "keyboard",
                title: title,
                message: message,
                iconColor: .blue
            )
            
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("建议输入:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            // 处理建议选择
                            executeRecovery()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            if !alternativeActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("其他选项:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(alternativeActions, id: \.self) { action in
                        Button(action.displayName) {
                            executeRecovery()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Button("手动输入") {
                executeRecovery()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessingRecovery)
        }
    }
    
    private func objectSelectionView(title: String, message: String, objects: [DetectedObjectInfo], canSelectMultiple: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "viewfinder",
                title: title,
                message: message,
                iconColor: .blue
            )
            
            if let image = originalImage {
                ObjectSelectionImageView(
                    image: image,
                    objects: objects,
                    selectedIndex: $selectedObjectIndex,
                    canSelectMultiple: canSelectMultiple
                )
                .frame(height: 300)
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("检测到的物品：")
                    .font(.headline)
                
                ForEach(objects.indices, id: \.self) { index in
                    ObjectInfoRow(
                        object: objects[index],
                        isSelected: selectedObjectIndex == index,
                        onTap: {
                            selectedObjectIndex = index
                        }
                    )
                }
            }
            
            HStack(spacing: 16) {
                Button("识别选中物品") {
                    if let selectedIndex = selectedObjectIndex {
                        recognizeSelectedObject(objects[selectedIndex])
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedObjectIndex == nil || isProcessingRecovery)
                
                Button("识别所有物品") {
                    recognizeAllObjects(objects)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessingRecovery)
            }
        }
    }
    
    private func offlineFallbackView(title: String, message: String, capabilities: [String], limitations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "wifi.slash",
                title: title,
                message: message,
                iconColor: .orange
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("离线模式功能：")
                    .font(.headline)
                
                ForEach(capabilities, id: \.self) { capability in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(capability)
                            .font(.body)
                    }
                }
            }
            .padding()
            .background(Color(.systemGreen).opacity(0.1))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("功能限制：")
                    .font(.headline)
                
                ForEach(limitations, id: \.self) { limitation in
                    HStack(alignment: .top) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text(limitation)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(Color(.systemBlue).opacity(0.1))
            .cornerRadius(12)
            
            HStack(spacing: 16) {
                Button("使用离线模式") {
                    executeRecovery()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessingRecovery)
                
                Button("等待网络") {
                    // 等待网络恢复
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func networkWaitView(title: String, message: String, suggestions: [String], canDownloadModel: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "wifi.exclamationmark",
                title: title,
                message: message,
                iconColor: .red
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("建议操作：")
                    .font(.headline)
                
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top) {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text(suggestion)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(Color(.systemOrange).opacity(0.1))
            .cornerRadius(12)
            
            VStack(spacing: 12) {
                Button("重试连接") {
                    executeRecovery()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessingRecovery)
                
                if canDownloadModel {
                    Button("下载离线模型") {
                        // 触发模型下载
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("手动输入物品信息") {
                    // 触发手动输入
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func downloadModelView(title: String, message: String, modelInfo: OfflineModelInfo, estimatedSize: String, canSkip: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "arrow.down.circle",
                title: title,
                message: message,
                iconColor: .blue
            )
            
            ModelInfoCard(modelInfo: modelInfo, estimatedSize: estimatedSize)
            
            VStack(spacing: 12) {
                Button("下载模型") {
                    executeRecovery()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessingRecovery)
                
                if canSkip {
                    Button("跳过下载") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private func permissionRequestView(title: String, message: String, permissionType: PermissionType, settingsLink: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "lock.fill",
                title: title,
                message: message,
                iconColor: .red
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("需要\(permissionType.displayName)权限来使用此功能")
                    .font(.body)
                
                Text("请在系统设置中允许应用访问\(permissionType.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemRed).opacity(0.1))
            .cornerRadius(12)
            
            VStack(spacing: 12) {
                Button("打开设置") {
                    if let url = URL(string: settingsLink) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("重新检查权限") {
                    executeRecovery()
                }
                .buttonStyle(.bordered)
                .disabled(isProcessingRecovery)
            }
        }
    }
    
    private func genericRecoveryView(for action: RecoveryAction) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorHeaderView(
                icon: "exclamationmark.triangle",
                title: "需要处理",
                message: "请选择处理方式",
                iconColor: .orange
            )
            
            Button("继续处理") {
                executeRecovery()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessingRecovery)
        }
    }
    
    // MARK: - 进度视图
    
    private func recoveryProgressView(_ progress: RecoveryProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressView(value: progress.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(progress.stage.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let error = progress.error {
                Text("错误：\(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    
    private func executeRecovery() {
        guard let action = errorRecoveryManager.currentRecoveryAction else { return }
        
        isProcessingRecovery = true
        
        Task {
            do {
                let result = try await errorRecoveryManager.executeRecoveryAction(action, with: originalImage)
                await MainActor.run {
                    isProcessingRecovery = false
                    onRecoveryCompleted(result)
                }
            } catch {
                await MainActor.run {
                    isProcessingRecovery = false
                    // 处理错误
                }
            }
        }
    }
    
    private func showImagePreview() {
        // 这里应该生成预览图像
        previewImage = originalImage
        showingImagePreview = true
    }
    
    private func recognizeSelectedObject(_ object: DetectedObjectInfo) {
        // 实现选中物品识别
        isProcessingRecovery = true
        
        Task {
            // 模拟识别过程
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                isProcessingRecovery = false
                onRecoveryCompleted(.actionCompleted)
            }
        }
    }
    
    private func recognizeAllObjects(_ objects: [DetectedObjectInfo]) {
        // 实现所有物品识别
        isProcessingRecovery = true
        
        Task {
            // 模拟批量识别过程
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            await MainActor.run {
                isProcessingRecovery = false
                onRecoveryCompleted(.actionCompleted)
            }
        }
    }
}

// MARK: - 辅助视图组件

struct ErrorHeaderView: View {
    let icon: String
    let title: String
    let message: String
    let iconColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RetakeGuidanceView: View {
    let guidance: RetakeGuidance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !guidance.tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("拍摄建议：")
                        .font(.headline)
                    
                    ForEach(guidance.tips, id: \.self) { tip in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            Text(tip)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            if !guidance.cameraSettings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("相机设置：")
                        .font(.headline)
                    
                    ForEach(guidance.cameraSettings, id: \.self) { setting in
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(setting)
                                .font(.body)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("理想条件：")
                    .font(.headline)
                
                ForEach(guidance.idealConditions, id: \.self) { condition in
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text(condition)
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ObjectSelectionImageView: View {
    let image: UIImage
    let objects: [DetectedObjectInfo]
    @Binding var selectedIndex: Int?
    let canSelectMultiple: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                ForEach(objects.indices, id: \.self) { index in
                    let object = objects[index]
                    let isSelected = selectedIndex == index
                    
                    Rectangle()
                        .stroke(isSelected ? Color.blue : Color.red, lineWidth: 2)
                        .background(
                            Rectangle()
                                .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                        )
                        .frame(
                            width: object.boundingBox.width * geometry.size.width,
                            height: object.boundingBox.height * geometry.size.height
                        )
                        .position(
                            x: (object.boundingBox.midX) * geometry.size.width,
                            y: (object.boundingBox.midY) * geometry.size.height
                        )
                        .onTapGesture {
                            selectedIndex = index
                        }
                }
            }
        }
    }
}

struct ObjectInfoRow: View {
    let object: DetectedObjectInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(object.category)
                    .font(.headline)
                
                Text(object.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("置信度：\(Int(object.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

struct ModelInfoCard: View {
    let modelInfo: OfflineModelInfo
    let estimatedSize: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(modelInfo.name)
                        .font(.headline)
                    
                    Text("版本 \(modelInfo.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(estimatedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("支持类别：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(modelInfo.categories, id: \.self) { category in
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            HStack {
                Text("准确度：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(modelInfo.accuracy * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// ImagePreviewView 已在单独的文件中定义

// MARK: - 扩展

extension ImageEnhancement {
    var description: String {
        switch self {
        case .adjustBrightness(let delta):
            return delta > 0 ? "增加亮度" : "降低亮度"
        case .increaseContrast:
            return "增强对比度"
        case .sharpen(let intensity):
            return "锐化处理（强度：\(Int(intensity * 100))%）"
        case .normalizeExposure:
            return "标准化曝光"
        case .backgroundBlur:
            return "背景模糊"
        case .reduceNoise:
            return "降噪处理"
        }
    }
}

extension RecoveryStage {
    var description: String {
        switch self {
        case .preparing:
            return "准备中..."
        case .processing:
            return "处理中..."
        case .completed:
            return "完成"
        case .failed:
            return "失败"
        }
    }
}

extension PermissionType {
    var displayName: String {
        switch self {
        case .camera:
            return "相机"
        case .photoLibrary:
            return "照片库"
        case .microphone:
            return "麦克风"
        }
    }
}