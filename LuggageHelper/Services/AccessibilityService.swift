import Foundation
import AVFoundation
import UIKit

/// 无障碍服务
/// 提供语音播报、震动反馈和无障碍支持功能
class AccessibilityService: NSObject, ObservableObject {
    static let shared = AccessibilityService()
    
    // MARK: - 语音合成器
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    // MARK: - 设置
    @Published var isVoiceOverEnabled: Bool = false
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var speechVolume: Float = 1.0
    @Published var enableHapticFeedback: Bool = true
    @Published var enableVoiceGuidance: Bool = true
    
    override private init() {
        super.init()
        speechSynthesizer.delegate = self
        setupAccessibilityNotifications()
        updateVoiceOverStatus()
    }
    
    // MARK: - 无障碍状态监听
    private func setupAccessibilityNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func voiceOverStatusChanged() {
        updateVoiceOverStatus()
    }
    
    private func updateVoiceOverStatus() {
        DispatchQueue.main.async {
            self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }
    }
    
    // MARK: - 语音播报功能
    
    /// 播报文本内容
    /// - Parameters:
    ///   - text: 要播报的文本
    ///   - priority: 播报优先级
    ///   - interrupt: 是否中断当前播报
    func speak(_ text: String, priority: SpeechPriority = .normal, interrupt: Bool = false) {
        guard enableVoiceGuidance else { return }
        
        if interrupt {
            stopSpeaking()
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.volume = speechVolume
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        
        // 根据优先级调整语音参数
        switch priority {
        case .low:
            utterance.volume = speechVolume * 0.7
        case .normal:
            break
        case .high:
            utterance.volume = min(speechVolume * 1.2, 1.0)
            utterance.rate = speechRate * 0.9 // 稍慢一些，更清晰
        case .urgent:
            utterance.volume = 1.0
            utterance.rate = speechRate * 0.8
        }
        
        currentUtterance = utterance
        speechSynthesizer.speak(utterance)
    }
    
    /// 停止当前语音播报
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
    }
    
    /// 暂停语音播报
    func pauseSpeaking() {
        speechSynthesizer.pauseSpeaking(at: .immediate)
    }
    
    /// 继续语音播报
    func continueSpeaking() {
        speechSynthesizer.continueSpeaking()
    }
    
    // MARK: - 震动反馈
    
    /// 提供触觉反馈
    /// - Parameter type: 反馈类型
    func provideFeedback(_ type: HapticFeedbackType) {
        guard enableHapticFeedback else { return }
        
        switch type {
        case .success:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            
        case .warning:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)
            
        case .error:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
            
        case .selection:
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
            
        case .light:
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
            
        case .medium:
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            
        case .heavy:
            let feedback = UIImpactFeedbackGenerator(style: .heavy)
            feedback.impactOccurred()
            
        case .custom(let pattern):
            playCustomHapticPattern(pattern)
        }
    }
    
    private func playCustomHapticPattern(_ pattern: [HapticEvent]) {
        for (index, event) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + event.delay) {
                switch event.type {
                case .light:
                    let feedback = UIImpactFeedbackGenerator(style: .light)
                    feedback.impactOccurred(intensity: event.intensity)
                case .medium:
                    let feedback = UIImpactFeedbackGenerator(style: .medium)
                    feedback.impactOccurred(intensity: event.intensity)
                case .heavy:
                    let feedback = UIImpactFeedbackGenerator(style: .heavy)
                    feedback.impactOccurred(intensity: event.intensity)
                }
            }
        }
    }
    
    // MARK: - 照片识别专用语音引导
    
    /// 播报照片识别开始
    func announcePhotoRecognitionStart() {
        speak("开始识别照片中的物品", priority: .normal)
        provideFeedback(.light)
    }
    
    /// 播报识别进度
    /// - Parameter progress: 进度百分比 (0-100)
    func announceRecognitionProgress(_ progress: Int) {
        if progress % 25 == 0 { // 每25%播报一次
            speak("识别进度 \(progress)%", priority: .low)
        }
    }
    
    /// 播报识别结果
    /// - Parameter result: 识别结果
    func announceRecognitionResult(_ result: ItemInfo) {
        let announcement = """
        识别完成。物品名称：\(result.name)。
        类别：\(result.category.displayName)。
        置信度：\(Int(result.confidence * 100))%
        """
        
        speak(announcement, priority: .high)
        provideFeedback(.success)
    }
    
    /// 播报识别错误
    /// - Parameter error: 错误信息
    func announceRecognitionError(_ error: String) {
        let announcement = "识别失败：\(error)"
        speak(announcement, priority: .urgent)
        provideFeedback(.error)
    }
    
    /// 播报多物品检测结果
    /// - Parameter count: 检测到的物品数量
    func announceObjectDetection(count: Int) {
        let announcement = "检测到 \(count) 个物品。请选择要识别的物品。"
        speak(announcement, priority: .normal)
        provideFeedback(.medium)
    }
    
    /// 播报对象选择
    /// - Parameters:
    ///   - index: 对象索引
    ///   - total: 总数量
    func announceObjectSelection(index: Int, total: Int) {
        let announcement = "已选择第 \(index + 1) 个物品，共 \(total) 个物品"
        speak(announcement, priority: .low)
        provideFeedback(.selection)
    }
    
    // MARK: - 相机拍照引导
    
    /// 播报相机准备就绪
    func announceCameraReady() {
        speak("相机已准备就绪。请将物品放在取景框中央，然后点击拍照按钮。", priority: .normal)
        provideFeedback(.light)
    }
    
    /// 播报拍照倒计时
    /// - Parameter seconds: 剩余秒数
    func announceCameraCountdown(_ seconds: Int) {
        speak("\(seconds)", priority: .high)
        provideFeedback(.medium)
    }
    
    /// 播报拍照完成
    func announceCameraCapture() {
        speak("拍照完成", priority: .normal)
        provideFeedback(.heavy)
    }
    
    /// 播报图像质量检查结果
    /// - Parameter quality: 图像质量分数 (0-1)
    func announceImageQuality(_ quality: Double) {
        let qualityText: String
        if quality >= 0.8 {
            qualityText = "图像质量优秀"
        } else if quality >= 0.6 {
            qualityText = "图像质量良好"
        } else if quality >= 0.4 {
            qualityText = "图像质量一般，建议重新拍摄"
        } else {
            qualityText = "图像质量较差，请重新拍摄"
        }
        
        speak(qualityText, priority: .normal)
        provideFeedback(quality >= 0.6 ? .success : .warning)
    }
    
    // MARK: - 界面导航引导
    
    /// 播报界面元素获得焦点
    /// - Parameters:
    ///   - element: 元素名称
    ///   - description: 元素描述
    func announceElementFocus(_ element: String, description: String? = nil) {
        var announcement = element
        if let desc = description {
            announcement += "。\(desc)"
        }
        speak(announcement, priority: .low)
    }
    
    /// 播报按钮操作
    /// - Parameters:
    ///   - action: 操作名称
    ///   - result: 操作结果
    func announceButtonAction(_ action: String, result: String? = nil) {
        var announcement = "\(action)"
        if let result = result {
            announcement += "。\(result)"
        }
        speak(announcement, priority: .normal)
        provideFeedback(.selection)
    }
    
    /// 播报页面切换
    /// - Parameter pageName: 页面名称
    func announcePageChange(_ pageName: String) {
        speak("已切换到\(pageName)页面", priority: .normal)
        provideFeedback(.light)
    }
    
    // MARK: - 批量识别引导
    
    /// 播报批量识别开始
    /// - Parameter count: 要识别的物品数量
    func announceBatchRecognitionStart(count: Int) {
        speak("开始批量识别 \(count) 个物品", priority: .normal)
        provideFeedback(.medium)
    }
    
    /// 播报批量识别进度
    /// - Parameters:
    ///   - current: 当前进度
    ///   - total: 总数量
    func announceBatchRecognitionProgress(current: Int, total: Int) {
        if current % max(1, total / 4) == 0 { // 每25%播报一次
            let percentage = Int((Double(current) / Double(total)) * 100)
            speak("批量识别进度 \(percentage)%，已完成 \(current) 个，共 \(total) 个", priority: .low)
        }
    }
    
    /// 播报批量识别完成
    /// - Parameters:
    ///   - successCount: 成功识别数量
    ///   - totalCount: 总数量
    func announceBatchRecognitionComplete(successCount: Int, totalCount: Int) {
        let announcement = "批量识别完成。成功识别 \(successCount) 个物品，共 \(totalCount) 个物品。"
        speak(announcement, priority: .high)
        provideFeedback(.success)
    }
}

// MARK: - 支持类型定义

/// 语音播报优先级
enum SpeechPriority {
    case low        // 低优先级，可被打断
    case normal     // 正常优先级
    case high       // 高优先级，重要信息
    case urgent     // 紧急优先级，错误或警告
}

/// 触觉反馈类型
enum HapticFeedbackType {
    case success
    case warning
    case error
    case selection
    case light
    case medium
    case heavy
    case custom([HapticEvent])
}

/// 自定义触觉事件
struct HapticEvent {
    let type: HapticType
    let intensity: CGFloat
    let delay: TimeInterval
    
    enum HapticType {
        case light
        case medium
        case heavy
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AccessibilityService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // 语音开始播报
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentUtterance = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentUtterance = nil
    }
}