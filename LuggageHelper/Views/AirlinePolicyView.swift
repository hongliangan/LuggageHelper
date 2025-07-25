import SwiftUI

/// 航空公司政策查询视图
struct AirlinePolicyView: View {
    @StateObject private var llmService = LLMAPIService.shared
    @StateObject private var configManager = LLMConfigurationManager.shared
    
    @State private var selectedAirline = ""
    @State private var flightType = FlightType.international
    @State private var cabinClass = CabinClass.economy
    @State private var airlinePolicy: AirlineLuggagePolicy?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPolicyComparison = false
    @State private var comparisonPolicies: [AirlineLuggagePolicy] = []
    
    // 常用航空公司列表
    private let popularAirlines = [
        "中国国际航空", "中国东方航空", "中国南方航空", "海南航空",
        "厦门航空", "深圳航空", "四川航空", "山东航空",
        "新加坡航空", "国泰航空", "日本航空", "全日空",
        "大韩航空", "韩亚航空", "泰国航空", "马来西亚航空",
        "美国联合航空", "美国航空", "达美航空", "汉莎航空",
        "法国航空", "英国航空", "阿联酋航空", "卡塔尔航空"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 配置状态提示
                if !configManager.isConfigValid {
                    configurationBanner
                }
                
                // 查询表单
                queryForm
                
                // 结果显示
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let policy = airlinePolicy {
                    policyResultView(policy)
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
            .navigationTitle("航司政策查询")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("政策对比") {
                            showingPolicyComparison = true
                        }
                        
                        Button("刷新缓存") {
                            // 清除缓存逻辑
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingPolicyComparison) {
                AirlinePolicyComparisonView(
                    airlines: Array(popularAirlines.prefix(5)),
                    flightType: flightType,
                    cabinClass: cabinClass
                )
            }
        }
    }
    
    // MARK: - 子视图
    
    private var configurationBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text("请先配置LLM API以使用政策查询功能")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("配置") {
                // 跳转到配置页面
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemOrange).opacity(0.1))
    }
    
    private var queryForm: some View {
        VStack(spacing: 16) {
            // 航空公司选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择航空公司")
                    .font(.headline)
                
                HStack {
                    TextField("输入航空公司名称", text: $selectedAirline)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Menu {
                        ForEach(popularAirlines, id: \.self) { airline in
                            Button(airline) {
                                selectedAirline = airline
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // 航班类型和舱位选择
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("航班类型")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("航班类型", selection: $flightType) {
                        ForEach(FlightType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("舱位等级")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("舱位等级", selection: $cabinClass) {
                        ForEach(CabinClass.allCases, id: \.self) { cabin in
                            Text(cabin.displayName).tag(cabin)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            
            // 查询按钮
            Button("查询政策") {
                queryPolicy()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAirline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || !configManager.isConfigValid)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在查询\(selectedAirline)的行李政策...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("请稍候，AI正在获取最新的政策信息")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("查询航司政策")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("选择航空公司并查询最新的行李政策信息，包括重量限制、尺寸要求和特殊规定。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text("热门航空公司")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(popularAirlines.prefix(6), id: \.self) { airline in
                        Button(airline) {
                            selectedAirline = airline
                            queryPolicy()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("查询失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                queryPolicy()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func policyResultView(_ policy: AirlineLuggagePolicy) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 航空公司信息头部
                policyHeader(policy)
                
                // 行李限制信息
                luggageLimitsSection(policy)
                
                // 限制条款
                restrictionsSection(policy)
                
                // 更新信息
                updateInfoSection(policy)
            }
            .padding()
        }
    }
    
    private func policyHeader(_ policy: AirlineLuggagePolicy) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "airplane.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(policy.airline)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Text(flightType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(cabinClass.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func luggageLimitsSection(_ policy: AirlineLuggagePolicy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("行李限制")
                .font(.headline)
            
            HStack(spacing: 16) {
                // 手提行李
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bag.fill")
                            .foregroundColor(.blue)
                        Text("手提行李")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("重量：\(String(format: "%.0f", policy.carryOnWeight))kg")
                            .font(.body)
                        
                        Text("尺寸：\(Int(policy.carryOnDimensions.length))×\(Int(policy.carryOnDimensions.width))×\(Int(policy.carryOnDimensions.height))cm")
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // 托运行李
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "suitcase.fill")
                            .foregroundColor(.orange)
                        Text("托运行李")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("重量：\(String(format: "%.0f", policy.checkedWeight))kg")
                            .font(.body)
                        
                        Text("尺寸：\(Int(policy.checkedDimensions.length))×\(Int(policy.checkedDimensions.width))×\(Int(policy.checkedDimensions.height))cm")
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func restrictionsSection(_ policy: AirlineLuggagePolicy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("限制条款")
                .font(.headline)
            
            ForEach(policy.restrictions, id: \.self) { restriction in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(restriction)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func updateInfoSection(_ policy: AirlineLuggagePolicy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("政策信息")
                .font(.headline)
            
            HStack {
                Text("最后更新：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDate(policy.lastUpdated))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !policy.source.isEmpty {
                    Text("来源：\(policy.source)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("注意：政策信息可能随时变化，出行前请以航空公司官方信息为准")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - 方法
    
    private func queryPolicy() {
        guard configManager.isConfigValid else {
            errorMessage = "请先配置LLM API"
            return
        }
        
        guard !selectedAirline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请输入航空公司名称"
            return
        }
        
        isLoading = true
        errorMessage = nil
        airlinePolicy = nil
        
        Task {
            do {
                let policy = try await llmService.queryAirlinePolicy(
                    airline: selectedAirline,
                    flightType: flightType,
                    cabinClass: cabinClass
                )
                
                await MainActor.run {
                    self.airlinePolicy = policy
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 航空公司政策对比视图

struct AirlinePolicyComparisonView: View {
    let airlines: [String]
    let flightType: FlightType
    let cabinClass: CabinClass
    
    @StateObject private var llmService = LLMAPIService.shared
    @State private var policies: [AirlineLuggagePolicy] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if policies.isEmpty {
                    emptyStateView
                } else {
                    comparisonContent
                }
            }
            .navigationTitle("政策对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        loadPolicies()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if policies.isEmpty {
                    loadPolicies()
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在查询多个航空公司政策...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("开始对比")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("将查询并对比多个航空公司的行李政策")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("开始查询") {
                loadPolicies()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("查询失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                loadPolicies()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var comparisonContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 对比表格
                comparisonTable
                
                // 总结建议
                comparisonSummary
            }
            .padding()
        }
    }
    
    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("政策对比")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // 表头
                    HStack(spacing: 12) {
                        Text("航空公司")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 100, alignment: .leading)
                        
                        Text("手提重量")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 80, alignment: .center)
                        
                        Text("托运重量")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 80, alignment: .center)
                        
                        Text("手提尺寸")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 120, alignment: .center)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    
                    // 数据行
                    ForEach(policies, id: \.airline) { policy in
                        HStack(spacing: 12) {
                            Text(policy.airline)
                                .font(.body)
                                .frame(width: 100, alignment: .leading)
                            
                            Text("\(String(format: "%.0f", policy.carryOnWeight))kg")
                                .font(.body)
                                .frame(width: 80, alignment: .center)
                            
                            Text("\(String(format: "%.0f", policy.checkedWeight))kg")
                                .font(.body)
                                .frame(width: 80, alignment: .center)
                            
                            Text("\(Int(policy.carryOnDimensions.length))×\(Int(policy.carryOnDimensions.width))×\(Int(policy.carryOnDimensions.height))")
                                .font(.caption)
                                .frame(width: 120, alignment: .center)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var comparisonSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("对比总结")
                .font(.headline)
            
            let bestCarryOn = policies.max { $0.carryOnWeight < $1.carryOnWeight }
            let bestChecked = policies.max { $0.checkedWeight < $1.checkedWeight }
            
            if let bestCarryOn = bestCarryOn {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.gold)
                    Text("手提行李最宽松：\(bestCarryOn.airline) (\(String(format: "%.0f", bestCarryOn.carryOnWeight))kg)")
                        .font(.body)
                }
            }
            
            if let bestChecked = bestChecked {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.gold)
                    Text("托运行李最宽松：\(bestChecked.airline) (\(String(format: "%.0f", bestChecked.checkedWeight))kg)")
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func loadPolicies() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let policies = try await llmService.batchQueryAirlinePolicies(
                    airlines: airlines,
                    flightType: flightType,
                    cabinClass: cabinClass
                )
                
                await MainActor.run {
                    self.policies = policies
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - 扩展

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

// MARK: - 预览

struct AirlinePolicyView_Previews: PreviewProvider {
    static var previews: some View {
        AirlinePolicyView()
    }
}