import SwiftUI

/// 编辑现有行李页面
/// 用户可修改行李名称、容量、空箱重量等信息
struct EditLuggageView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LuggageViewModel
    
    @State private var name: String
    @State private var capacity: String
    @State private var emptyWeight: String
    @State private var note: String
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var luggageType: LuggageType
    @State private var selectedAirline: Airline?
    
    let luggage: Luggage // 接收要编辑的行李对象
    
    init(luggage: Luggage) {
        self.luggage = luggage
        _name = State(initialValue: luggage.name)
        _capacity = State(initialValue: String(luggage.capacity))
        _emptyWeight = State(initialValue: String(luggage.emptyWeight))
        _note = State(initialValue: luggage.note ?? "")
        _luggageType = State(initialValue: luggage.luggageType)
        _selectedAirline = State(initialValue: nil) // 初始值设为nil，在onAppear中加载
        
        // 异步加载图片
        _selectedImage = State(initialValue: nil)
        if let imagePath = luggage.imagePath {
            _selectedImage = State(initialValue: loadImageFromDocuments(imagePath: imagePath))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                luggageTypeSection
                airlineSection
                noteSection
                imageSection
            }
            .navigationTitle("编辑行李")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        updateLuggage()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                // 在视图出现时加载航空公司信息
                if let airlineId = luggage.selectedAirlineId {
                    selectedAirline = viewModel.airlines.first(where: { $0.id == airlineId })
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var basicInfoSection: some View {
        Section(header: Text("基本信息")) {
            TextField("名称", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("容量 (L)", text: $capacity)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            TextField("空箱重量 (kg)", text: $emptyWeight)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var luggageTypeSection: some View {
        Section(header: Text("行李类型")) {
            Picker("行李类型", selection: $luggageType) {
                ForEach(LuggageType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var airlineSection: some View {
        Section(header: Text("航空公司限制")) {
            Picker("选择航空公司", selection: $selectedAirline) {
                Text("未选择").tag(nil as Airline?)
                ForEach(viewModel.airlines) { airline in
                    Text("\(airline.name) (\(airline.code))").tag(airline as Airline?)
                }
            }
            
            if let airline = selectedAirline {
                airlineLimitInfo(airline: airline)
            }
        }
    }
    
    private func airlineLimitInfo(airline: Airline) -> some View {
        let weightLimit = luggageType == .carryOn ? airline.carryOnWeightLimit : airline.checkedBaggageWeightLimit
        let sizeLimit = luggageType == .carryOn ? airline.carryOnSizeLimit : airline.checkedBaggageSizeLimit
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("重量限制: \(String(format: "%.0f", weightLimit))kg")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("尺寸限制: \(sizeLimit)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var noteSection: some View {
        Section(header: Text("备注")) {
            TextField("备注信息", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var imageSection: some View {
        Section(header: Text("图片")) {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .onTapGesture { showImagePicker = true }
            } else {
                Button("选择图片") {
                    showImagePicker = true
                }
            }
        }
    }
    
    /// 判断是否可以保存行李
    private var canSave: Bool {
        !name.isEmpty && !capacity.isEmpty && !emptyWeight.isEmpty
    }
    
    /// 更新行李到数据模型
    private func updateLuggage() {
        guard let capacityValue = Double(capacity),
              let emptyWeightValue = Double(emptyWeight) else { return }
        
        var imagePath: String? = luggage.imagePath // 默认使用现有图片路径
        if let selectedImage {
            imagePath = saveImageToDocuments(image: selectedImage)
        } else if luggage.imagePath != nil && selectedImage == nil { // 如果之前有图片但现在移除了
            deleteImageFromDocuments(imagePath: luggage.imagePath!)
            imagePath = nil
        }
        
        let updatedLuggage = Luggage(
            id: luggage.id,
            name: name,
            capacity: capacityValue,
            emptyWeight: emptyWeightValue,
            imagePath: imagePath,
            items: luggage.items,
            note: note,
            luggageType: luggageType,
            selectedAirlineId: selectedAirline?.id
        )
        viewModel.updateLuggage(updatedLuggage)
        dismiss()
    }
    
    /// 将 UIImage 保存到沙盒并返回路径
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? data.write(to: url)
        return url.path
    }
    
    /// 从沙盒加载图片
    private func loadImageFromDocuments(imagePath: String) -> UIImage? {
        let url = URL(fileURLWithPath: imagePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    /// 从沙盒删除图片
    private func deleteImageFromDocuments(imagePath: String) {
        let url = URL(fileURLWithPath: imagePath)
        try? FileManager.default.removeItem(at: url)
    }
}