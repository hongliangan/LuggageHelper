import SwiftUI

/// 统计概览页面
/// 显示行李和物品的统计信息
struct StatisticsView: View {
    @EnvironmentObject var viewModel: LuggageViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 总体统计卡片
                    overallStatsCard
                    
                    // 行李统计卡片
                    luggageStatsCard
                    
                    // 超重警告卡片
                    if hasOverweightLuggage {
                        overweightWarningCard
                    }
                    
                    // 清单完成度卡片
                    checklistProgressCard
                }
                .padding()
            }
            .navigationTitle("统计概览")
        }
    }
    
    /// 总体统计卡片
    private var overallStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总体统计")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(title: "行李数量", value: "\(viewModel.luggages.count)", icon: "suitcase", color: .blue)
                StatCard(title: "物品数量", value: "\(viewModel.allItems.count)", icon: "list.bullet", color: .green)
                StatCard(title: "总重量", value: String(format: "%.1fkg", totalWeight), icon: "scalemass", color: .orange)
                StatCard(title: "清单数量", value: "\(viewModel.checklists.count)", icon: "checklist", color: .purple)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// 行李统计卡片
    private var luggageStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行李详情")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(viewModel.luggages) { luggage in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(luggage.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("\(luggage.items.count) 件物品")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.1f", luggage.totalWeight))kg")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(luggage.selectedAirlineId != nil && 
                                               viewModel.getOverweightWarning(for: luggage) != nil ? .red : .primary)
                        }
                        
                        // 容量使用进度条
                        ProgressView(value: luggage.usedCapacity / luggage.capacity)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        
                        Text("容量: \(String(format: "%.1f", luggage.usedCapacity))/\(String(format: "%.1f", luggage.capacity))L")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                if luggage != viewModel.luggages.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// 超重警告卡片
    private var overweightWarningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("超重警告")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            ForEach(overweightLuggages, id: \.id) { luggage in
                if let warning = viewModel.getOverweightWarning(for: luggage) {
                    HStack {
                        Text(luggage.name)
                            .fontWeight(.medium)
                        Spacer()
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    /// 清单完成度卡片
    private var checklistProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("清单完成度")
                .font(.headline)
                .foregroundColor(.primary)
            
            if viewModel.checklists.isEmpty {
                Text("暂无清单")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.checklists) { checklist in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(checklist.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(checklist.completedCount)/\(checklist.items.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: checklist.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: checklist.isAllChecked ? .green : .blue))
                    }
                    .padding(.vertical, 4)
                    
                    if checklist != viewModel.checklists.last {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// 计算总重量
    private var totalWeight: Double {
        viewModel.luggages.reduce(0) { $0 + $1.totalWeight }
    }
    
    /// 是否有超重行李
    private var hasOverweightLuggage: Bool {
        !overweightLuggages.isEmpty
    }
    
    /// 超重的行李列表
    private var overweightLuggages: [Luggage] {
        viewModel.luggages.filter { luggage in
            viewModel.getOverweightWarning(for: luggage) != nil
        }
    }
}

/// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#if DEBUG
struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
            .environmentObject(LuggageViewModel())
    }
}
#endif