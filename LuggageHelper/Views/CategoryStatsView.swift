import SwiftUI

/// 分类统计视图
/// 显示物品分类统计和准确性数据
struct CategoryStatsView: View {
    // MARK: - 属性
    
    /// 类别统计数据
    let stats: [ItemListView.CategoryStat]
    
    /// 准确性统计数据
    let accuracyStats: [String: Any]
    
    /// 分类管理器
    private let categoryManager = AIItemCategoryManager.shared
    
    /// 显示的标签页
    @State private var selectedTab = 0
    
    // MARK: - 视图
    
    var body: some View {
        NavigationStack {
            VStack {
                // 标签选择器
                Picker("统计类型", selection: $selectedTab) {
                    Text("分类统计").tag(0)
                    Text("准确性").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 内容
                if selectedTab == 0 {
                    categoryStatsView
                } else {
                    accuracyStatsView
                }
                
                Spacer()
            }
            .navigationTitle("分类统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("重置学习数据") {
                        resetLearningData()
                    }
                    .foregroundColor(.red)
                }
            })
        }
    }
    
    // MARK: - 分类统计视图
    
    private var categoryStatsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("物品分类统计")
                .font(.headline)
                .padding(.horizontal)
            
            // 分类饼图
            if !stats.isEmpty {
                CategoryPieChartView(stats: stats)
                    .frame(height: 200)
                    .padding()
            }
            
            // 分类列表
            List {
                ForEach(stats) { stat in
                    HStack {
                        Text(stat.category.icon)
                            .font(.title3)
                        
                        Text(stat.category.displayName)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("\(stat.count) 件")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("(\(String(format: "%.1f", calculatePercentage(stat.count)))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color(categoryColor(for: stat.category)).opacity(0.1))
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    // MARK: - 准确性统计视图
    
    private var accuracyStatsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类准确性统计")
                .font(.headline)
                .padding(.horizontal)
            
            // 准确性指标
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("总分类次数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(accuracyStats["totalClassifications"] as? Int ?? 0)")
                            .font(.title2)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("准确率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", (accuracyStats["accuracy"] as? Double ?? 0) * 100))%")
                            .font(.title2)
                            .foregroundColor(getAccuracyColor())
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("正确分类")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(accuracyStats["correctClassifications"] as? Int ?? 0)")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("用户纠正")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(accuracyStats["userCorrections"] as? Int ?? 0)")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
            .padding(.horizontal)
            
            // 最常被纠正的类别
            if let corrections = accuracyStats["mostCorrectedCategories"] as? [[String: Int]], !corrections.isEmpty {
                Text("最常被纠正的类别")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                List {
                    ForEach(0..<min(5, corrections.count), id: \.self) { index in
                        if let (categoryStr, count) = corrections[index].first {
                            if let category = ItemCategory(rawValue: categoryStr) {
                                HStack {
                                    Text(category.icon)
                                        .font(.title3)
                                    
                                    Text(category.displayName)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Text("\(count) 次纠正")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .listRowBackground(Color(categoryColor(for: category)).opacity(0.1))
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                Text("暂无分类纠正数据")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 计算百分比
    private func calculatePercentage(_ count: Int) -> Double {
        let total = stats.reduce(0) { $0 + $1.count }
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }
    
    /// 获取准确率颜色
    private func getAccuracyColor() -> Color {
        let accuracy = accuracyStats["accuracy"] as? Double ?? 0
        
        if accuracy >= 0.9 {
            return .green
        } else if accuracy >= 0.7 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    /// 获取类别颜色
    private func categoryColor(for category: ItemCategory) -> UIColor {
        switch category {
        case .clothing:
            return UIColor.systemBlue.withAlphaComponent(0.7)
        case .electronics:
            return UIColor.systemGray.withAlphaComponent(0.7)
        case .toiletries:
            return UIColor.systemGreen.withAlphaComponent(0.7)
        case .documents:
            return UIColor.systemOrange.withAlphaComponent(0.7)
        case .medicine:
            return UIColor.systemRed.withAlphaComponent(0.7)
        case .accessories:
            return UIColor.systemPurple.withAlphaComponent(0.7)
        case .shoes:
            return UIColor.systemBrown.withAlphaComponent(0.7)
        case .books:
            return UIColor.systemIndigo.withAlphaComponent(0.7)
        case .food:
            return UIColor.systemYellow.withAlphaComponent(0.7)
        case .sports:
            return UIColor.systemMint.withAlphaComponent(0.7)
        case .beauty:
            return UIColor.systemPink.withAlphaComponent(0.7)
        case .other:
            return UIColor.systemGray.withAlphaComponent(0.7)
        }
    }
    
    /// 重置学习数据
    private func resetLearningData() {
        categoryManager.resetLearningData()
    }
}

// MARK: - 分类饼图视图

struct CategoryPieChartView: View {
    let stats: [ItemListView.CategoryStat]
    
    var body: some View {
        ZStack {
            // 饼图
            GeometryReader { geometry in
                let radius = min(geometry.size.width, geometry.size.height) / 2 * 0.8
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ForEach(0..<stats.count, id: \.self) { index in
                    PieSliceView(
                        center: center,
                        radius: radius,
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        color: Color(categoryColor(for: stats[index].category))
                    )
                }
            }
            
            // 中心文本
            VStack {
                Text("\(totalItems)")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("总物品")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 总物品数
    private var totalItems: Int {
        stats.reduce(0) { $0 + $1.count }
    }
    
    // 计算起始角度
    private func startAngle(for index: Int) -> Double {
        let total = stats.reduce(0) { $0 + $1.count }
        let sumBefore = stats.prefix(index).reduce(0) { $0 + $1.count }
        return Double(sumBefore) / Double(total) * 360
    }
    
    // 计算结束角度
    private func endAngle(for index: Int) -> Double {
        let total = stats.reduce(0) { $0 + $1.count }
        let sumThrough = stats.prefix(index + 1).reduce(0) { $0 + $1.count }
        return Double(sumThrough) / Double(total) * 360
    }
    
    // 获取类别颜色
    private func categoryColor(for category: ItemCategory) -> UIColor {
        switch category {
        case .clothing:
            return UIColor.systemBlue.withAlphaComponent(0.7)
        case .electronics:
            return UIColor.systemGray.withAlphaComponent(0.7)
        case .toiletries:
            return UIColor.systemGreen.withAlphaComponent(0.7)
        case .documents:
            return UIColor.systemOrange.withAlphaComponent(0.7)
        case .medicine:
            return UIColor.systemRed.withAlphaComponent(0.7)
        case .accessories:
            return UIColor.systemPurple.withAlphaComponent(0.7)
        case .shoes:
            return UIColor.systemBrown.withAlphaComponent(0.7)
        case .books:
            return UIColor.systemIndigo.withAlphaComponent(0.7)
        case .food:
            return UIColor.systemYellow.withAlphaComponent(0.7)
        case .sports:
            return UIColor.systemMint.withAlphaComponent(0.7)
        case .beauty:
            return UIColor.systemPink.withAlphaComponent(0.7)
        case .other:
            return UIColor.systemGray.withAlphaComponent(0.7)
        }
    }
}

// MARK: - 饼图切片视图

struct PieSliceView: View {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Double
    let endAngle: Double
    let color: Color
    
    var body: some View {
        Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startAngle - 90),
                endAngle: .degrees(endAngle - 90),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(color)
    }
}

// MARK: - 预览

struct CategoryStatsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockStats = [
            ItemListView.CategoryStat(category: .clothing, count: 10),
            ItemListView.CategoryStat(category: .electronics, count: 8),
            ItemListView.CategoryStat(category: .toiletries, count: 5),
            ItemListView.CategoryStat(category: .accessories, count: 3)
        ]
        
        let mockAccuracyStats: [String: Any] = [
            "totalClassifications": 50,
            "correctClassifications": 42,
            "accuracy": 0.84,
            "userCorrections": 8,
            "mostCorrectedCategories": [
                ["electronics": 3],
                ["clothing": 2],
                ["toiletries": 1]
            ]
        ]
        
        return CategoryStatsView(
            stats: mockStats,
            accuracyStats: mockAccuracyStats
        )
    }
}