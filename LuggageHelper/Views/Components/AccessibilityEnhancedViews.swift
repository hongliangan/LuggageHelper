import SwiftUI

// MARK: - 无障碍增强的UI组件

/// 无障碍增强的按钮
struct AccessibleButton: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let action: () -> Void
    let accessibilityHint: String?
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            accessibilityService.provideFeedback(.selection)
            accessibilityService.announceButtonAction(title)
            action()
        }) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
                
                Spacer()
            }
            .foregroundColor(.primary)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint ?? subtitle ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

/// 无障碍增强的图像预览
struct AccessibleImagePreview: View {
    let image: UIImage
    let detectedObjects: [DetectedObject]
    let selectedIndices: Set<Int>
    let onObjectTap: (Int) -> Void
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("照片预览")
                .accessibilityHint("包含 \(detectedObjects.count) 个检测到的物品")
            
            // 检测对象覆盖层
            GeometryReader { geometry in
                ForEach(detectedObjects.indices, id: \.self) { index in
                    let object = detectedObjects[index]
                    let isSelected = selectedIndices.contains(index)
                    
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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("物品 \(index + 1)")
                        .accessibilityHint(isSelected ? "已选择，双击取消选择" : "未选择，双击选择")
                        .accessibilityAddTraits(.isButton)
                        .onTapGesture {
                            accessibilityService.announceObjectSelection(index: index, total: detectedObjects.count)
                            onObjectTap(index)
                        }
                }
            }
        }
    }
}

/// 无障碍增强的进度指示器
struct AccessibleProgressView: View {
    let progress: Double
    let title: String
    let subtitle: String?
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    @State private var lastAnnouncedProgress: Int = -1
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，进度 \(Int(progress * 100))%")
        .accessibilityHint(subtitle ?? "")
        .onChange(of: progress) { newProgress in
            let currentProgress = Int(newProgress * 100)
            if currentProgress != lastAnnouncedProgress && currentProgress % 25 == 0 {
                accessibilityService.announceRecognitionProgress(currentProgress)
                lastAnnouncedProgress = currentProgress
            }
        }
    }
}

/// 无障碍增强的识别结果卡片
struct AccessibleRecognitionResultCard: View {
    let result: ItemInfo
    let onSelect: () -> Void
    let onEdit: (() -> Void)?
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 主要信息
            VStack(alignment: .leading, spacing: 8) {
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
                        .background(confidenceColor.opacity(0.2))
                        .foregroundColor(confidenceColor)
                        .cornerRadius(8)
                }
                
                Text(result.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 描述信息已移除，因为 ItemInfo 没有 description 属性
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("选择此物品") {
                    accessibilityService.provideFeedback(.success)
                    accessibilityService.announceButtonAction("选择物品", result: result.name)
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("将此物品添加到行李清单")
                
                if let onEdit = onEdit {
                    Button("编辑信息") {
                        accessibilityService.provideFeedback(.selection)
                        accessibilityService.announceButtonAction("编辑物品信息")
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("修改物品的名称或描述")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("识别结果：\(result.name)，类别：\(result.category.displayName)，置信度：\(Int(result.confidence * 100))%")
        .accessibilityHint("双击查看操作选项")
    }
    
    private var confidenceColor: Color {
        if result.confidence >= 0.8 {
            return .green
        } else if result.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

/// 无障碍增强的相机控制按钮
struct AccessibleCameraButton: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isEnabled: Bool
    let action: () -> Void
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            accessibilityService.provideFeedback(.medium)
            accessibilityService.announceButtonAction(title)
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isEnabled ? .white : .gray)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .white : .gray)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(isEnabled ? .white.opacity(0.8) : .gray)
                }
            }
            .frame(width: 80, height: 80)
            .background(
                Circle()
                    .fill(isEnabled ? Color.blue : Color.gray.opacity(0.3))
            )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isEnabled ? [] : .isButton)
    }
}

/// 无障碍增强的错误提示
struct AccessibleErrorView: View {
    let error: String
    let suggestion: String?
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("出现错误")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if let suggestion = suggestion {
                    Text(suggestion)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
            }
            
            HStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button("重试") {
                        accessibilityService.provideFeedback(.selection)
                        accessibilityService.announceButtonAction("重试操作")
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("重新尝试刚才的操作")
                }
                
                Button("关闭") {
                    accessibilityService.provideFeedback(.light)
                    accessibilityService.announceButtonAction("关闭错误提示")
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("关闭此错误提示")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("错误提示：\(error)")
        .accessibilityHint(suggestion ?? "")
        .onAppear {
            accessibilityService.announceRecognitionError(error)
        }
    }
}

/// 无障碍增强的设置切换行
struct AccessibleSettingToggle: View {
    let title: String
    let subtitle: String?
    let icon: String
    @Binding var isOn: Bool
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
        .accessibilityValue(isOn ? "已开启" : "已关闭")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            isOn.toggle()
            accessibilityService.provideFeedback(.selection)
            accessibilityService.announceButtonAction(
                isOn ? "开启\(title)" : "关闭\(title)"
            )
        }
    }
}

// MARK: - 相机引导覆盖层

/// 相机拍照引导覆盖层
struct CameraGuidanceOverlay: View {
    let isVisible: Bool
    let message: String
    let onDismiss: () -> Void
    
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        if isVisible {
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("我知道了") {
                    accessibilityService.provideFeedback(.selection)
                    accessibilityService.announceButtonAction("关闭引导")
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.white)
                .accessibilityHint("关闭拍照引导提示")
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("拍照引导：\(message)")
            .onAppear {
                accessibilityService.speak(message, priority: .high)
            }
        }
    }
}