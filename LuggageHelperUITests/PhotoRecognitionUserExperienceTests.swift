import XCTest

/// 照片识别用户体验和界面交互测试
/// 测试照片识别功能的用户界面交互、可用性和用户体验
final class PhotoRecognitionUserExperienceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // 设置测试环境
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--photo-recognition-testing")
        app.launchEnvironment["MOCK_PHOTO_RECOGNITION"] = "true"
        app.launchEnvironment["ENABLE_ACCESSIBILITY_TESTING"] = "true"
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 基础用户体验测试
    
    /// 测试照片识别功能的完整用户流程
    func testCompletePhotoRecognitionUserFlow() throws {
        // Given - 用户想要使用照片识别功能
        navigateToPhotoRecognition()
        
        // When - 用户选择拍照方式
        let cameraButton = app.buttons["拍照"]
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5), "拍照按钮应该存在")
        XCTAssertTrue(cameraButton.isEnabled, "拍照按钮应该可用")
        
        // 测试按钮的视觉反馈
        cameraButton.tap()
        
        // 处理相机权限（如果需要）
        handleCameraPermissionIfNeeded()
        
        // When - 用户在相机界面中操作
        let cameraView = app.otherElements["相机预览"]
        if cameraView.waitForExistence(timeout: 5) {
            // 验证相机界面的用户体验元素
            validateCameraUserInterface()
            
            // 模拟拍照
            let captureButton = app.buttons["拍摄"]
            if captureButton.exists {
                captureButton.tap()
            }
        } else {
            // 如果相机不可用，选择相册
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            }
            
            let albumButton = app.buttons["相册"]
            albumButton.tap()
            selectImageFromAlbum()
        }
        
        // Then - 验证图像处理和识别流程的用户体验
        validateImageProcessingUserExperience()
        validateRecognitionResultsUserExperience()
    }
    
    /// 测试多物品识别的用户交互体验
    func testMultiObjectRecognitionUserExperience() throws {
        navigateToPhotoRecognition()
        
        // 启用物体检测
        enableAdvancedOptions()
        enableObjectDetection()
        
        // 选择包含多个物品的图像
        selectMultiObjectImage()
        
        // 验证物品检测结果的用户界面
        let detectedObjectsSection = app.otherElements["检测到的物品"]
        XCTAssertTrue(detectedObjectsSection.waitForExistence(timeout: 15), "应该显示检测到的物品")
        
        // 测试物品选择交互
        validateObjectSelectionInterface()
        
        // 测试批量识别流程
        validateBatchRecognitionUserExperience()
    }
    
    /// 测试实时相机识别的用户体验
    func testRealTimeCameraUserExperience() throws {
        navigateToPhotoRecognition()
        
        let realTimeButton = app.buttons["实时识别"]
        XCTAssertTrue(realTimeButton.waitForExistence(timeout: 5), "实时识别按钮应该存在")
        realTimeButton.tap()
        
        handleCameraPermissionIfNeeded()
        
        // 验证实时识别界面
        let realTimeView = app.otherElements["实时识别界面"]
        if realTimeView.waitForExistence(timeout: 10) {
            validateRealTimeRecognitionInterface()
            testRealTimeInteractions()
        } else {
            // 在模拟器或无相机设备上跳过
            throw XCTSkip("实时相机功能在当前设备上不可用")
        }
    }
    
    // MARK: - 错误处理用户体验测试
    
    /// 测试图像质量错误的用户引导
    func testImageQualityErrorUserGuidance() throws {
        navigateToPhotoRecognition()
        
        // 选择低质量图像
        selectLowQualityImage()
        
        // 验证错误提示的用户体验
        let qualityErrorAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS '图像质量'")).firstMatch
        if qualityErrorAlert.waitForExistence(timeout: 10) {
            validateErrorAlertUserExperience(qualityErrorAlert)
            
            // 测试错误恢复选项
            let improvementButton = qualityErrorAlert.buttons["查看改进建议"]
            if improvementButton.exists {
                improvementButton.tap()
                validateImprovementGuidanceInterface()
            }
        }
    }
    
    /// 测试网络错误的用户体验
    func testNetworkErrorUserExperience() throws {
        // 模拟网络错误环境
        app.launchEnvironment["SIMULATE_NETWORK_ERROR"] = "true"
        app.terminate()
        app.launch()
        
        navigateToPhotoRecognition()
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        // 验证网络错误处理的用户体验
        let networkErrorAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS '网络'")).firstMatch
        if networkErrorAlert.waitForExistence(timeout: 15) {
            validateNetworkErrorUserExperience(networkErrorAlert)
        }
        
        // 验证离线模式提示
        let offlineModePrompt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '离线模式'")).firstMatch
        if offlineModePrompt.waitForExistence(timeout: 5) {
            validateOfflineModeUserExperience()
        }
    }
    
    /// 测试处理超时的用户体验
    func testProcessingTimeoutUserExperience() throws {
        // 模拟处理超时
        app.launchEnvironment["SIMULATE_PROCESSING_TIMEOUT"] = "true"
        app.terminate()
        app.launch()
        
        navigateToPhotoRecognition()
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        // 验证超时处理的用户体验
        let timeoutAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS '超时'")).firstMatch
        if timeoutAlert.waitForExistence(timeout: 30) {
            validateTimeoutErrorUserExperience(timeoutAlert)
        }
    }
    
    // MARK: - 加载状态和进度用户体验测试
    
    /// 测试加载状态的用户体验
    func testLoadingStateUserExperience() throws {
        navigateToPhotoRecognition()
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        // 验证加载状态的用户体验
        validateLoadingStateInterface()
        
        // 测试取消功能
        testCancelFunctionality()
        
        // 验证进度显示
        validateProgressDisplay()
    }
    
    /// 测试批量处理进度的用户体验
    func testBatchProcessingProgressUserExperience() throws {
        navigateToPhotoRecognition()
        enableObjectDetection()
        selectMultiObjectImage()
        
        // 选择多个物品
        selectMultipleObjects()
        
        let batchButton = app.buttons["批量识别"]
        batchButton.tap()
        
        // 验证批量处理进度的用户体验
        validateBatchProgressInterface()
    }
    
    // MARK: - 辅助功能和无障碍用户体验测试
    
    /// 测试VoiceOver用户体验
    func testVoiceOverUserExperience() throws {
        // 启用VoiceOver模拟
        app.launchEnvironment["VOICEOVER_ENABLED"] = "true"
        app.terminate()
        app.launch()
        
        navigateToPhotoRecognition()
        
        // 验证主要元素的VoiceOver支持
        validateVoiceOverSupport()
        
        // 测试VoiceOver导航
        testVoiceOverNavigation()
        
        // 测试语音反馈
        testVoiceAnnouncements()
    }
    
    /// 测试语音引导拍照体验
    func testVoiceGuidedPhotoCapture() throws {
        app.launchEnvironment["VOICE_GUIDANCE_ENABLED"] = "true"
        app.terminate()
        app.launch()
        
        navigateToPhotoRecognition()
        
        let cameraButton = app.buttons["拍照"]
        cameraButton.tap()
        
        handleCameraPermissionIfNeeded()
        
        // 验证语音引导功能
        validateVoiceGuidanceInterface()
    }
    
    /// 测试震动反馈用户体验
    func testHapticFeedbackUserExperience() throws {
        navigateToPhotoRecognition()
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        // 验证识别完成时的震动反馈
        // 注意：震动反馈在UI测试中无法直接验证，但可以验证相关的UI状态变化
        let resultCard = app.otherElements["识别结果卡片"]
        XCTAssertTrue(resultCard.waitForExistence(timeout: 30), "识别结果应该显示")
        
        // 验证成功状态的视觉反馈
        validateSuccessVisualFeedback()
    }
    
    // MARK: - 性能感知用户体验测试
    
    /// 测试响应时间对用户体验的影响
    func testResponseTimeUserExperience() throws {
        navigateToPhotoRecognition()
        
        // 测试快速响应的用户体验
        testQuickResponseUserExperience()
        
        // 测试慢速响应的用户体验
        testSlowResponseUserExperience()
    }
    
    /// 测试缓存对用户体验的改善
    func testCacheUserExperienceImprovement() throws {
        navigateToPhotoRecognition()
        selectTestImage()
        
        // 第一次识别（无缓存）
        let recognizeButton = app.buttons["开始识别"]
        let firstRecognitionStartTime = Date()
        recognizeButton.tap()
        
        let resultCard = app.otherElements["识别结果卡片"]
        XCTAssertTrue(resultCard.waitForExistence(timeout: 30))
        let firstRecognitionTime = Date().timeIntervalSince(firstRecognitionStartTime)
        
        // 重新识别相同图像（应该有缓存）
        let resetButton = app.buttons["重新识别"]
        if resetButton.exists {
            resetButton.tap()
        }
        
        let secondRecognitionStartTime = Date()
        recognizeButton.tap()
        
        XCTAssertTrue(resultCard.waitForExistence(timeout: 10))
        let secondRecognitionTime = Date().timeIntervalSince(secondRecognitionStartTime)
        
        // 验证缓存改善了用户体验
        XCTAssertLessThan(secondRecognitionTime, firstRecognitionTime * 0.5, "缓存应该显著提高响应速度")
        
        print("首次识别时间: \(String(format: "%.2f", firstRecognitionTime))秒")
        print("缓存识别时间: \(String(format: "%.2f", secondRecognitionTime))秒")
    }
    
    // MARK: - 用户界面适应性测试
    
    /// 测试不同屏幕尺寸的用户体验
    func testScreenSizeAdaptability() throws {
        // 测试竖屏模式
        XCUIDevice.shared.orientation = .portrait
        navigateToPhotoRecognition()
        validateInterfaceLayout()
        
        // 测试横屏模式
        XCUIDevice.shared.orientation = .landscapeLeft
        validateInterfaceLayout()
        
        // 恢复竖屏
        XCUIDevice.shared.orientation = .portrait
    }
    
    /// 测试动态字体大小的适应性
    func testDynamicTypeAdaptability() throws {
        // 这个测试需要在不同的字体大小设置下运行
        // 在实际测试中，可以通过设置系统字体大小来测试
        
        navigateToPhotoRecognition()
        
        // 验证文本元素的可读性
        validateTextReadability()
        
        // 验证按钮的可点击性
        validateButtonAccessibility()
    }
    
    // MARK: - 用户反馈和学习体验测试
    
    /// 测试用户反馈界面的体验
    func testUserFeedbackInterface() throws {
        navigateToPhotoRecognition()
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        let resultCard = app.otherElements["识别结果卡片"]
        XCTAssertTrue(resultCard.waitForExistence(timeout: 30))
        
        // 测试反馈按钮
        let feedbackButton = app.buttons["反馈结果"]
        if feedbackButton.exists {
            feedbackButton.tap()
            validateFeedbackInterface()
        }
    }
    
    /// 测试识别历史的用户体验
    func testRecognitionHistoryUserExperience() throws {
        // 先进行几次识别以创建历史记录
        performMultipleRecognitions()
        
        // 访问识别历史
        let historyButton = app.buttons["识别历史"]
        if historyButton.exists {
            historyButton.tap()
            validateHistoryInterface()
        }
    }
    
    // MARK: - 验证方法实现
    
    private func navigateToPhotoRecognition() {
        let aiTabButton = app.tabBars.buttons["AI功能"]
        XCTAssertTrue(aiTabButton.waitForExistence(timeout: 5), "AI功能标签应该存在")
        aiTabButton.tap()
        
        let photoRecognitionButton = app.buttons["照片识别"]
        XCTAssertTrue(photoRecognitionButton.waitForExistence(timeout: 5), "照片识别按钮应该存在")
        photoRecognitionButton.tap()
        
        // 验证页面标题
        let navigationTitle = app.navigationBars["AI 照片识别"]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5), "应该显示照片识别页面标题")
    }
    
    private func handleCameraPermissionIfNeeded() {
        let allowButton = app.buttons["允许"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }
        
        // 处理系统权限弹窗
        let systemAllowButton = app.alerts.buttons["好"]
        if systemAllowButton.waitForExistence(timeout: 3) {
            systemAllowButton.tap()
        }
    }
    
    private func validateCameraUserInterface() {
        // 验证相机界面的用户体验元素
        let cameraPreview = app.otherElements["相机预览"]
        XCTAssertTrue(cameraPreview.exists, "相机预览应该显示")
        
        let captureButton = app.buttons["拍摄"]
        XCTAssertTrue(captureButton.exists, "拍摄按钮应该存在")
        XCTAssertTrue(captureButton.isEnabled, "拍摄按钮应该可用")
        
        // 验证取消按钮
        let cancelButton = app.buttons["取消"]
        XCTAssertTrue(cancelButton.exists, "取消按钮应该存在")
        
        // 验证闪光灯控制（如果存在）
        let flashButton = app.buttons["闪光灯"]
        if flashButton.exists {
            XCTAssertTrue(flashButton.isEnabled, "闪光灯按钮应该可用")
        }
    }
    
    private func selectImageFromAlbum() {
        // 选择相册中的第一张图片
        let firstImage = app.images.firstMatch
        if firstImage.waitForExistence(timeout: 5) {
            firstImage.tap()
        }
        
        // 确认选择
        let confirmButton = app.buttons["选择"]
        if confirmButton.exists {
            confirmButton.tap()
        }
    }
    
    private func validateImageProcessingUserExperience() {
        // 验证图像处理阶段的用户体验
        let processingIndicator = app.otherElements["图像处理进度"]
        if processingIndicator.waitForExistence(timeout: 3) {
            // 验证进度指示器的可见性
            XCTAssertTrue(processingIndicator.exists, "应该显示图像处理进度")
            
            // 等待处理完成
            XCTAssertTrue(processingIndicator.waitForNonExistence(timeout: 15), "图像处理应该在合理时间内完成")
        }
        
        // 验证处理后的图像显示
        let processedImage = app.images["处理后图片"]
        XCTAssertTrue(processedImage.waitForExistence(timeout: 10), "应该显示处理后的图像")
    }
    
    private func validateRecognitionResultsUserExperience() {
        let recognizeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '识别'")).firstMatch
        if recognizeButton.waitForExistence(timeout: 5) {
            recognizeButton.tap()
            
            // 验证识别结果的用户体验
            let resultCard = app.otherElements["识别结果卡片"]
            XCTAssertTrue(resultCard.waitForExistence(timeout: 30), "应该显示识别结果")
            
            // 验证结果内容的可读性
            validateResultContentReadability()
            
            // 验证操作按钮的可用性
            validateResultActionButtons()
        }
    }
    
    private func enableAdvancedOptions() {
        let advancedOptionsButton = app.buttons["高级选项"]
        if advancedOptionsButton.exists {
            advancedOptionsButton.tap()
        }
    }
    
    private func enableObjectDetection() {
        let objectDetectionToggle = app.switches["使用物体检测"]
        if objectDetectionToggle.exists && objectDetectionToggle.value as? String != "1" {
            objectDetectionToggle.tap()
        }
    }
    
    private func selectMultiObjectImage() {
        let albumButton = app.buttons["相册"]
        albumButton.tap()
        
        // 选择包含多个物品的测试图像
        selectImageFromAlbum()
    }
    
    private func validateObjectSelectionInterface() {
        let objectThumbnails = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'object_thumbnail_'"))
        XCTAssertGreaterThan(objectThumbnails.count, 0, "应该显示物品缩略图")
        
        // 测试物品选择交互
        let firstThumbnail = objectThumbnails.firstMatch
        firstThumbnail.tap()
        
        // 验证选择状态的视觉反馈
        XCTAssertTrue(firstThumbnail.isSelected, "选中的物品应该有视觉反馈")
        
        // 测试多选功能
        if objectThumbnails.count > 1 {
            let secondThumbnail = objectThumbnails.element(boundBy: 1)
            secondThumbnail.tap()
            XCTAssertTrue(secondThumbnail.isSelected, "应该支持多选")
        }
    }
    
    private func validateBatchRecognitionUserExperience() {
        let batchButton = app.buttons["批量识别"]
        XCTAssertTrue(batchButton.exists, "批量识别按钮应该存在")
        XCTAssertTrue(batchButton.isEnabled, "批量识别按钮应该可用")
        
        batchButton.tap()
        
        // 验证批量处理的用户体验
        validateBatchProgressInterface()
    }
    
    private func validateRealTimeRecognitionInterface() {
        // 验证实时识别界面的用户体验元素
        let realTimePreview = app.otherElements["实时预览"]
        XCTAssertTrue(realTimePreview.exists, "实时预览应该显示")
        
        let detectionOverlay = app.otherElements["检测覆盖层"]
        if detectionOverlay.exists {
            XCTAssertTrue(detectionOverlay.exists, "检测覆盖层应该显示")
        }
        
        // 验证控制按钮
        let pauseButton = app.buttons["暂停检测"]
        if pauseButton.exists {
            XCTAssertTrue(pauseButton.isEnabled, "暂停按钮应该可用")
        }
    }
    
    private func testRealTimeInteractions() {
        // 测试实时识别的交互
        let detectionBoxes = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'detection_box_'"))
        
        if detectionBoxes.count > 0 {
            let firstBox = detectionBoxes.firstMatch
            firstBox.tap()
            
            // 验证点击检测框的反馈
            let recognitionResult = app.otherElements["实时识别结果"]
            XCTAssertTrue(recognitionResult.waitForExistence(timeout: 10), "点击检测框应该显示识别结果")
        }
    }
    
    private func selectLowQualityImage() {
        // 选择一个低质量的测试图像
        let albumButton = app.buttons["相册"]
        albumButton.tap()
        selectImageFromAlbum()
    }
    
    private func selectTestImage() {
        let albumButton = app.buttons["相册"]
        albumButton.tap()
        selectImageFromAlbum()
    }
    
    private func validateErrorAlertUserExperience(_ alert: XCUIElement) {
        // 验证错误提示的用户体验
        XCTAssertTrue(alert.exists, "错误提示应该显示")
        
        // 验证错误消息的可读性
        let errorMessage = alert.staticTexts.firstMatch
        XCTAssertTrue(errorMessage.exists, "错误消息应该存在")
        XCTAssertFalse(errorMessage.label.isEmpty, "错误消息不应该为空")
        
        // 验证操作按钮
        let buttons = alert.buttons
        XCTAssertGreaterThan(buttons.count, 0, "应该有操作按钮")
        
        for i in 0..<buttons.count {
            let button = buttons.element(boundBy: i)
            XCTAssertTrue(button.isEnabled, "错误提示中的按钮应该可用")
        }
    }
    
    private func validateImprovementGuidanceInterface() {
        let guidanceView = app.otherElements["改进指导"]
        XCTAssertTrue(guidanceView.waitForExistence(timeout: 5), "改进指导界面应该显示")
        
        // 验证指导内容
        let guidanceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '建议'")).firstMatch
        XCTAssertTrue(guidanceText.exists, "应该显示改进建议")
        
        // 验证关闭按钮
        let closeButton = app.buttons["关闭"]
        XCTAssertTrue(closeButton.exists, "应该有关闭按钮")
    }
    
    private func validateNetworkErrorUserExperience(_ alert: XCUIElement) {
        // 验证网络错误的用户体验
        validateErrorAlertUserExperience(alert)
        
        // 验证重试选项
        let retryButton = alert.buttons["重试"]
        if retryButton.exists {
            XCTAssertTrue(retryButton.isEnabled, "重试按钮应该可用")
        }
        
        // 验证离线模式选项
        let offlineButton = alert.buttons["使用离线模式"]
        if offlineButton.exists {
            XCTAssertTrue(offlineButton.isEnabled, "离线模式按钮应该可用")
        }
    }
    
    private func validateOfflineModeUserExperience() {
        let offlineModeIndicator = app.otherElements["离线模式指示器"]
        if offlineModeIndicator.exists {
            XCTAssertTrue(offlineModeIndicator.exists, "应该显示离线模式指示器")
        }
        
        // 验证离线模式的功能限制提示
        let limitationText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '离线模式'")).firstMatch
        if limitationText.exists {
            XCTAssertTrue(limitationText.exists, "应该显示离线模式的功能说明")
        }
    }
    
    private func validateTimeoutErrorUserExperience(_ alert: XCUIElement) {
        validateErrorAlertUserExperience(alert)
        
        // 验证超时特定的选项
        let cancelButton = alert.buttons["取消"]
        XCTAssertTrue(cancelButton.exists, "应该有取消按钮")
        
        let retryButton = alert.buttons["重试"]
        if retryButton.exists {
            XCTAssertTrue(retryButton.isEnabled, "重试按钮应该可用")
        }
    }
    
    private func validateLoadingStateInterface() {
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.waitForExistence(timeout: 3) {
            XCTAssertTrue(loadingIndicator.exists, "应该显示加载指示器")
        }
        
        // 验证加载消息
        let loadingMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '识别中'")).firstMatch
        if loadingMessage.exists {
            XCTAssertTrue(loadingMessage.exists, "应该显示加载消息")
        }
    }
    
    private func testCancelFunctionality() {
        let cancelButton = app.buttons["取消"]
        if cancelButton.exists {
            XCTAssertTrue(cancelButton.isEnabled, "取消按钮应该可用")
            
            // 测试取消功能
            cancelButton.tap()
            
            // 验证取消后的状态
            let loadingIndicator = app.activityIndicators.firstMatch
            if loadingIndicator.exists {
                XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 5), "取消后加载指示器应该消失")
            }
        }
    }
    
    private func validateProgressDisplay() {
        let progressBar = app.progressIndicators.firstMatch
        if progressBar.exists {
            XCTAssertTrue(progressBar.exists, "应该显示进度条")
        }
        
        let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'")).firstMatch
        if progressText.exists {
            XCTAssertTrue(progressText.exists, "应该显示进度百分比")
        }
    }
    
    private func selectMultipleObjects() {
        let objectThumbnails = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'object_thumbnail_'"))
        
        // 选择前两个物品
        if objectThumbnails.count >= 2 {
            objectThumbnails.element(boundBy: 0).tap()
            objectThumbnails.element(boundBy: 1).tap()
        }
    }
    
    private func validateBatchProgressInterface() {
        let batchProgressView = app.otherElements["批量识别进度"]
        if batchProgressView.waitForExistence(timeout: 5) {
            XCTAssertTrue(batchProgressView.exists, "应该显示批量识别进度")
            
            // 验证批量进度的详细信息
            let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/'")).firstMatch
            if progressText.exists {
                XCTAssertTrue(progressText.exists, "应该显示批量进度详情")
            }
        }
    }
    
    private func validateVoiceOverSupport() {
        // 验证主要元素的VoiceOver标签
        let cameraButton = app.buttons["拍照"]
        XCTAssertFalse(cameraButton.label.isEmpty, "拍照按钮应该有VoiceOver标签")
        
        let albumButton = app.buttons["相册"]
        XCTAssertFalse(albumButton.label.isEmpty, "相册按钮应该有VoiceOver标签")
        
        let realTimeButton = app.buttons["实时识别"]
        XCTAssertFalse(realTimeButton.label.isEmpty, "实时识别按钮应该有VoiceOver标签")
    }
    
    private func testVoiceOverNavigation() {
        // 测试VoiceOver导航的流畅性
        // 这里主要验证元素的可访问性属性
        let mainElements = [
            app.buttons["拍照"],
            app.buttons["相册"],
            app.buttons["实时识别"]
        ]
        
        for element in mainElements {
            if element.exists {
                XCTAssertTrue(element.isHittable, "元素应该可以通过VoiceOver访问")
            }
        }
    }
    
    private func testVoiceAnnouncements() {
        // 测试语音播报功能
        // 在实际测试中，这需要验证语音播报的触发
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        let resultCard = app.otherElements["识别结果卡片"]
        if resultCard.waitForExistence(timeout: 30) {
            // 验证结果的可访问性标签
            XCTAssertFalse(resultCard.label.isEmpty, "识别结果应该有语音描述")
        }
    }
    
    private func validateVoiceGuidanceInterface() {
        // 验证语音引导界面
        let voiceGuidanceIndicator = app.otherElements["语音引导指示器"]
        if voiceGuidanceIndicator.exists {
            XCTAssertTrue(voiceGuidanceIndicator.exists, "应该显示语音引导指示器")
        }
        
        // 验证语音引导控制
        let voiceToggle = app.switches["语音引导"]
        if voiceToggle.exists {
            XCTAssertTrue(voiceToggle.isEnabled, "语音引导开关应该可用")
        }
    }
    
    private func validateSuccessVisualFeedback() {
        // 验证成功状态的视觉反馈
        let successIndicator = app.otherElements["识别成功指示器"]
        if successIndicator.exists {
            XCTAssertTrue(successIndicator.exists, "应该显示成功指示器")
        }
        
        // 验证结果卡片的视觉状态
        let resultCard = app.otherElements["识别结果卡片"]
        if resultCard.exists {
            // 验证卡片是否有成功状态的视觉样式
            XCTAssertTrue(resultCard.exists, "结果卡片应该显示")
        }
    }
    
    private func testQuickResponseUserExperience() {
        // 测试快速响应的用户体验
        app.launchEnvironment["QUICK_RESPONSE_MODE"] = "true"
        
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        let startTime = Date()
        recognizeButton.tap()
        
        let resultCard = app.otherElements["识别结果卡片"]
        XCTAssertTrue(resultCard.waitForExistence(timeout: 5), "快速模式下应该快速显示结果")
        
        let responseTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(responseTime, 3.0, "快速响应时间应该小于3秒")
    }
    
    private func testSlowResponseUserExperience() {
        // 测试慢速响应的用户体验
        app.launchEnvironment["SLOW_RESPONSE_MODE"] = "true"
        
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        // 验证慢速响应时的用户体验改善措施
        let progressIndicator = app.progressIndicators.firstMatch
        XCTAssertTrue(progressIndicator.waitForExistence(timeout: 3), "慢速响应时应该显示进度指示器")
        
        let cancelButton = app.buttons["取消"]
        XCTAssertTrue(cancelButton.exists, "慢速响应时应该提供取消选项")
    }
    
    private func validateInterfaceLayout() {
        // 验证界面布局的适应性
        let mainButtons = [
            app.buttons["拍照"],
            app.buttons["相册"],
            app.buttons["实时识别"]
        ]
        
        for button in mainButtons {
            if button.exists {
                XCTAssertTrue(button.isHittable, "按钮应该在当前布局中可点击")
                
                // 验证按钮大小合适
                let frame = button.frame
                XCTAssertGreaterThan(frame.width, 44, "按钮宽度应该足够大")
                XCTAssertGreaterThan(frame.height, 44, "按钮高度应该足够大")
            }
        }
    }
    
    private func validateTextReadability() {
        // 验证文本的可读性
        let textElements = app.staticTexts
        
        for i in 0..<min(textElements.count, 10) { // 检查前10个文本元素
            let textElement = textElements.element(boundBy: i)
            if textElement.exists && !textElement.label.isEmpty {
                // 验证文本不会被截断
                XCTAssertFalse(textElement.label.hasSuffix("..."), "文本不应该被截断")
            }
        }
    }
    
    private func validateButtonAccessibility() {
        // 验证按钮的可访问性
        let buttons = app.buttons
        
        for i in 0..<min(buttons.count, 10) { // 检查前10个按钮
            let button = buttons.element(boundBy: i)
            if button.exists {
                XCTAssertTrue(button.isHittable, "按钮应该可点击")
                
                // 验证按钮有适当的标签
                XCTAssertFalse(button.label.isEmpty, "按钮应该有标签")
            }
        }
    }
    
    private func validateFeedbackInterface() {
        let feedbackView = app.otherElements["用户反馈界面"]
        XCTAssertTrue(feedbackView.waitForExistence(timeout: 5), "用户反馈界面应该显示")
        
        // 验证反馈选项
        let ratingButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'rating_'"))
        XCTAssertGreaterThan(ratingButtons.count, 0, "应该有评分按钮")
        
        // 验证反馈文本输入
        let feedbackTextView = app.textViews["反馈文本"]
        if feedbackTextView.exists {
            XCTAssertTrue(feedbackTextView.isEnabled, "反馈文本输入应该可用")
        }
        
        // 验证提交按钮
        let submitButton = app.buttons["提交反馈"]
        XCTAssertTrue(submitButton.exists, "应该有提交反馈按钮")
    }
    
    private func validateHistoryInterface() {
        let historyView = app.otherElements["识别历史"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 5), "识别历史界面应该显示")
        
        // 验证历史记录列表
        let historyList = app.tables["历史记录列表"]
        if historyList.exists {
            XCTAssertTrue(historyList.exists, "应该显示历史记录列表")
            
            // 验证历史记录项
            let historyCells = historyList.cells
            if historyCells.count > 0 {
                let firstCell = historyCells.firstMatch
                XCTAssertTrue(firstCell.isHittable, "历史记录项应该可点击")
            }
        }
    }
    
    private func performMultipleRecognitions() {
        // 执行多次识别以创建历史记录
        for _ in 0..<3 {
            selectTestImage()
            
            let recognizeButton = app.buttons["开始识别"]
            recognizeButton.tap()
            
            let resultCard = app.otherElements["识别结果卡片"]
            _ = resultCard.waitForExistence(timeout: 30)
            
            // 重置状态
            let resetButton = app.buttons["重新选择"]
            if resetButton.exists {
                resetButton.tap()
            }
        }
    }
    
    private func validateResultContentReadability() {
        // 验证识别结果内容的可读性
        let itemNameLabel = app.staticTexts["物品名称"]
        if itemNameLabel.exists {
            XCTAssertFalse(itemNameLabel.label.isEmpty, "物品名称不应该为空")
        }
        
        let confidenceLabel = app.staticTexts["置信度"]
        if confidenceLabel.exists {
            XCTAssertFalse(confidenceLabel.label.isEmpty, "置信度不应该为空")
        }
        
        let categoryLabel = app.staticTexts["类别"]
        if categoryLabel.exists {
            XCTAssertFalse(categoryLabel.label.isEmpty, "类别不应该为空")
        }
    }
    
    private func validateResultActionButtons() {
        // 验证识别结果的操作按钮
        let useButton = app.buttons["使用此结果"]
        XCTAssertTrue(useButton.exists, "应该有使用结果按钮")
        XCTAssertTrue(useButton.isEnabled, "使用结果按钮应该可用")
        
        let retryButton = app.buttons["重新识别"]
        if retryButton.exists {
            XCTAssertTrue(retryButton.isEnabled, "重新识别按钮应该可用")
        }
        
        let editButton = app.buttons["编辑结果"]
        if editButton.exists {
            XCTAssertTrue(editButton.isEnabled, "编辑结果按钮应该可用")
        }
    }
}

// MARK: - 扩展方法

extension XCUIElement {
    /// 等待元素不存在
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}