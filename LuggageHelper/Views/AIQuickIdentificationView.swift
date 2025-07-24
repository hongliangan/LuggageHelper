import SwiftUI

/// AI 快速识别视图
/// 提供简洁的物品识别界面，可以作为弹窗或内嵌组件使用
struct AIQuickIdentificationView: View {
    @StateObject private var aiViewModel = AIViewModel()
    @State private var itemName = ""
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var capturedImage: UIImage? = nil
    @State private var selectedTab = 0 // 0: 名称识别, 1: 照片识别
    
    var onItemIdentified: (ItemInfo) -> Void
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题和关闭按钮
            if onDismiss != nil {
                HStack {
                    Text("AI 快速识别")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 选项卡
            Picker("识别方式", selection: $selectedTab) {
                Text("名称识别").tag(0)
                Text("照片识别").tag(1)
            }
            .pickerStyle(.segmented)
            
            // 输入区域
            if selectedTab == 0 {
                nameInputSection
            } else {
                photoInputSection
            }
            
            // 结果区域
            AIIdentificationResultView(
                aiViewModel: aiViewModel,
                onUseResult: { item in
                    onItemIdentified(item)
                    onDismiss?()
                },
                onReset: {
                    resetState()
                }
            )
        }
        .padding()
        .sheet(isPresented: $showCamera) {
            CameraView(image: $capturedImage, onImageCaptured: handleCapturedImage)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(image: $capturedImage)
        }
    }
    
    private var nameInputSection: some View {
        VStack(spacing: 12) {
            TextField("输入物品名称", text: $itemName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit {
                    identifyByName()
                }
            
            Button {
                identifyByName()
            } label: {
                Label("识别物品", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(itemName.isEmpty || aiViewModel.isLoading)
        }
    }
    
    private var photoInputSection: some View {
        VStack(spacing: 12) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                
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
                    .disabled(aiViewModel.isLoading)
                }
            } else {
                HStack(spacing: 16) {
                    Button {
                        showCamera = true
                    } label: {
                        VStack {
                            Image(systemName: "camera")
                                .font(.system(size: 24))
                            Text("拍照")
                                .font(.caption)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button {
                        showPhotoLibrary = true
                    } label: {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                            Text("相册")
                                .font(.caption)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 通过名称识别物品
    private func identifyByName() {
        guard !itemName.isEmpty else { return }
        
        Task {
            await aiViewModel.identifyItem(name: itemName)
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
    
    /// 重置状态
    private func resetState() {
        aiViewModel.resetAllStates()
        itemName = ""
        capturedImage = nil
    }
}

/// 相机视图
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageCaptured: () -> Void
    
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
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
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

/// AI 快速识别弹窗
/// 提供弹窗形式的快速识别界面
struct AIQuickIdentificationPopup: View {
    @Binding var isPresented: Bool
    var onItemIdentified: (ItemInfo) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            VStack {
                AIQuickIdentificationView(
                    onItemIdentified: onItemIdentified,
                    onDismiss: {
                        isPresented = false
                    }
                )
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding()
            }
        }
    }
}

#if DEBUG
struct AIQuickIdentificationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AIQuickIdentificationView { _ in }
                .previewDisplayName("Embedded")
            
            Color.gray
                .overlay(
                    AIQuickIdentificationPopup(
                        isPresented: .constant(true),
                        onItemIdentified: { _ in }
                    )
                )
                .previewDisplayName("Popup")
        }
    }
}
#endif