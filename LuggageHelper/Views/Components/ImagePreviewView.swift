import SwiftUI

/// 图像预览视图 - 用于详细查看和选择检测到的对象
struct ImagePreviewView: View {
    let image: UIImage
    let detectedObjects: [DetectedObject]
    @Binding var selectedIndices: Set<Int>
    let selectionMode: ObjectSelectionMode
    let onDismiss: () -> Void
    let onRecognize: (Set<Int>) -> Void
    
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var showObjectInfo = false
    @State private var selectedObjectForInfo: DetectedObject?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(imageScale)
                                .offset(imageOffset)
                                .overlay(
                                    objectOverlay(in: geometry)
                                )
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    imageScale = max(0.5, min(3.0, value))
                                },
                            DragGesture()
                                .onChanged { value in
                                    imageOffset = value.translation
                                }
                        )
                    )
                }
                
                // 底部控制栏
                VStack {
                    Spacer()
                    bottomControlBar
                }
            }
            .navigationTitle("选择物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("重置") {
                        imageScale = 1.0
                        imageOffset = .zero
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showObjectInfo) {
            if let object = selectedObjectForInfo {
                ObjectInfoSheet(object: object) {
                    showObjectInfo = false
                }
            }
        }
    }
    
    private func objectOverlay(in geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(detectedObjects.indices, id: \.self) { index in
                let object = detectedObjects[index]
                let isSelected = selectedIndices.contains(index)
                
                Rectangle()
                    .stroke(
                        isSelected ? Color.blue : Color.green.opacity(0.8),
                        lineWidth: isSelected ? 3 : 2
                    )
                    .frame(
                        width: object.boundingBox.width * geometry.size.width * imageScale,
                        height: object.boundingBox.height * geometry.size.height * imageScale
                    )
                    .position(
                        x: (object.boundingBox.midX * geometry.size.width * imageScale) + imageOffset.width,
                        y: (object.boundingBox.midY * geometry.size.height * imageScale) + imageOffset.height
                    )
                    .overlay(
                        objectLabel(for: object, index: index, isSelected: isSelected)
                            .position(
                                x: (object.boundingBox.midX * geometry.size.width * imageScale) + imageOffset.width,
                                y: (object.boundingBox.minY * geometry.size.height * imageScale) + imageOffset.height - 20
                            )
                    )
                    .onTapGesture {
                        toggleSelection(index)
                    }
                    .onLongPressGesture {
                        selectedObjectForInfo = object
                        showObjectInfo = true
                    }
            }
        }
    }
    
    private func objectLabel(for object: DetectedObject, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
            } else {
                Text("\(index + 1)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.green)
                    .clipShape(Circle())
            }
            
            Text("\(Int(object.confidence * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
    
    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            // 选择信息
            HStack {
                Text("已选择 \(selectedIndices.count) / \(detectedObjects.count) 个物品")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(selectionMode.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            
            // 操作按钮
            HStack(spacing: 16) {
                Button("全选") {
                    selectedIndices = Set(0..<detectedObjects.count)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.white)
                .disabled(selectedIndices.count == detectedObjects.count)
                
                Button("清除") {
                    selectedIndices.removeAll()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.white)
                .disabled(selectedIndices.isEmpty)
                
                Spacer()
                
                Button("开始识别") {
                    onRecognize(selectedIndices)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIndices.isEmpty)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    private func toggleSelection(_ index: Int) {
        switch selectionMode {
        case .single:
            selectedIndices = [index]
        case .multiple:
            if selectedIndices.contains(index) {
                selectedIndices.remove(index)
            } else {
                selectedIndices.insert(index)
            }
        case .smart:
            // 智能选择模式下，点击切换选择状态
            if selectedIndices.contains(index) {
                selectedIndices.remove(index)
            } else {
                selectedIndices.insert(index)
            }
        }
    }
}

/// 对象信息表单
struct ObjectInfoSheet: View {
    let object: DetectedObject
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 对象缩略图
                if let thumbnail = object.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                // 对象信息
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(title: "对象ID", value: object.id.uuidString.prefix(8).description)
                    InfoRow(title: "置信度", value: "\(String(format: "%.1f", object.confidence * 100))%")
                    InfoRow(title: "类型", value: object.category.displayName)
                    InfoRow(title: "边界框", value: boundingBoxDescription)
                    InfoRow(title: "面积占比", value: "\(String(format: "%.1f", areaPercentage))%")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("对象详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var boundingBoxDescription: String {
        let box = object.boundingBox
        return "(\(String(format: "%.2f", box.minX)), \(String(format: "%.2f", box.minY))) - (\(String(format: "%.2f", box.maxX)), \(String(format: "%.2f", box.maxY)))"
    }
    
    private var areaPercentage: Double {
        return object.boundingBox.width * object.boundingBox.height * 100
    }
}

/// 信息行组件
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

#if DEBUG
struct ImagePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let mockObjects = [
            DetectedObject(
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.4),
                confidence: 0.85,
                category: .other,
                thumbnail: UIImage(systemName: "photo")
            ),
            DetectedObject(
                boundingBox: CGRect(x: 0.5, y: 0.2, width: 0.4, height: 0.3),
                confidence: 0.92,
                category: .electronics,
                thumbnail: UIImage(systemName: "photo")
            )
        ]
        
        ImagePreviewView(
            image: UIImage(systemName: "photo.fill") ?? UIImage(),
            detectedObjects: mockObjects,
            selectedIndices: .constant([0]),
            selectionMode: .multiple,
            onDismiss: {},
            onRecognize: { _ in }
        )
    }
}
#endif