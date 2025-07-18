import Foundation

/// 字符串扩展工具
extension String {
    /// 将字符串转换为Double，处理可能的格式错误
    var doubleValue: Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.number(from: self)?.doubleValue
    }
    
    /// 检查字符串是否为有效的数字
    var isValidNumber: Bool {
        return Double(self) != nil
    }
}