import SwiftUI

/// AI 识别结果视图
/// 用于展示 AI 识别结果并提供操作按钮
struct AIIdentificationResultView: View {
    @ObservedObject var aiViewModel: AIViewModel
    var onUseResult: ((ItemInfo) -> Void)? = nil
    var onReset: (() -> Void)? = nil
    var onViewAlternatives: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            if aiViewModel.isLoading {
                loadingView
            } else if let error = aiViewModel.errorMessage {
                errorView(error)
            } else if let item = aiViewModel.identifiedItem {
                resultView(item)
            } else {
                emptyView
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在识别物品信息...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("重试") {
                onReset?()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func resultView(_ item: ItemInfo) -> some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("识别结果")
                    .font(.headline)
                
                Spacer()
                
                Button("重置") {
                    onReset?()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // 物品信息卡片
            AIItemInfoCard(
                item: item,
                onUse: {
                    onUseResult?(item)
                },
                onViewAlternatives: {
                    onViewAlternatives?()
                }
            )
            
            // 置信度指示器
            confidenceIndicator(item.confidence)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("请输入物品名称或上传照片进行识别")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func confidenceIndicator(_ confidence: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("识别置信度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(confidenceColor(confidence))
                        .frame(width: geometry.size.width * confidence, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            // 置信度说明
            Text(confidenceDescription(confidence))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .blue
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func confidenceDescription(_ confidence: Double) -> String {
        if confidence >= 0.9 {
            return "识别结果非常可靠"
        } else if confidence >= 0.7 {
            return "识别结果较为可靠"
        } else if confidence >= 0.5 {
            return "识别结果可能不够准确，请核对"
        } else {
            return "识别结果可能不准确，建议手动输入"
        }
    }
}

/// AI 识别结果弹窗
/// 用于在弹窗中展示 AI 识别结果
struct AIIdentificationResultPopup: View {
    @ObservedObject var aiViewModel: AIViewModel
    @Binding var isPresented: Bool
    var onUseResult: ((ItemInfo) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题栏
            HStack {
                Text("AI 识别结果")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            // 结果视图
            AIIdentificationResultView(
                aiViewModel: aiViewModel,
                onUseResult: { item in
                    onUseResult?(item)
                    isPresented = false
                },
                onReset: {
                    aiViewModel.resetAllStates()
                }
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }
}

#if DEBUG
struct AIIdentificationResultView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AIViewModel()
        
        return Group {
            // 加载中状态
            AIIdentificationResultView(aiViewModel: viewModel)
                .onAppear {
                    viewModel.isLoading = true
                }
                .previewDisplayName("Loading")
            
            // 错误状态
            AIIdentificationResultView(aiViewModel: viewModel)
                .onAppear {
                    viewModel.isLoading = false
                    viewModel.errorMessage = "识别失败，请重试"
                }
                .previewDisplayName("Error")
            
            // 结果状态
            AIIdentificationResultView(aiViewModel: viewModel)
                .onAppear {
                    viewModel.isLoading = false
                    viewModel.errorMessage = nil
                    viewModel.identifiedItem = ItemInfo(
                        name: "iPhone 15 Pro",
                        category: .electronics,
                        weight: 221,
                        volume: 150,
                        dimensions: Dimensions(length: 15, width: 7, height: 0.8),
                        confidence: 0.95,
                        source: "AI识别"
                    )
                }
                .previewDisplayName("Result")
            
            // 弹窗
            Color.gray.opacity(0.3)
                .overlay(
                    AIIdentificationResultPopup(
                        aiViewModel: viewModel,
                        isPresented: .constant(true)
                    )
                )
                .onAppear {
                    viewModel.isLoading = false
                    viewModel.errorMessage = nil
                    viewModel.identifiedItem = ItemInfo(
                        name: "iPhone 15 Pro",
                        category: .electronics,
                        weight: 221,
                        volume: 150,
                        dimensions: Dimensions(length: 15, width: 7, height: 0.8),
                        confidence: 0.95,
                        source: "AI识别"
                    )
                }
                .previewDisplayName("Popup")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif