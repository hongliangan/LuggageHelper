import XCTest

/// 无障碍功能UI测试
/// 测试VoiceOver支持、语音播报和键盘导航等无障碍功能
final class AccessibilityUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // 启用无障碍测试
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--accessibility-testing")
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - VoiceOver 支持测试
    
    func testVoiceOverSupportInPhotoIdentification() throws {
        // 导航到照片识别页面
        navigateToPhotoIdentification()
        
        // 测试页面标题的无障碍标签
        let navigationTitle = app.navigationBars["AI 照片识别"]
        XCTAssertTrue(navigationTitle.exists, "导航标题应该存在")
        
        // 测试照片选择按钮的无障碍属性
        let cameraButton = app.buttons["拍照"]
        XCTAssertTrue(cameraButton.exists, "拍照按钮应该存在")
        XCTAssertTrue(cameraButton.isAccessibilityElement, "拍照按钮应该是无障碍元素")
        XCTAssertEqual(cameraButton.accessibilityLabel, "拍照", "拍照按钮应该有正确的无障碍标签")
        XCTAssertNotNil(cameraButton.accessibilityHint, "拍照按钮应该有无障碍提示")
        
        let photoLibraryButton = app.buttons["相册"]
        XCTAssertTrue(photoLibraryButton.exists, "相册按钮应该存在")
        XCTAssertTrue(photoLibraryButton.isAccessibilityElement, "相册按钮应该是无障碍元素")
        XCTAssertEqual(photoLibraryButton.accessibilityLabel, "相册", "相册按钮应该有正确的无障碍标签")
        
        // 测试实时识别按钮
        let realTimeButton = app.buttons["实时识别"]
        XCTAssertTrue(realTimeButton.exists, "实时识别按钮应该存在")
        XCTAssertTrue(realTimeButton.isAccessibilityElement, "实时识别按钮应该是无障碍元素")
        XCTAssertEqual(realTimeButton.accessibilityLabel, "实时识别", "实时识别按钮应该有正确的无障碍标签")
    }
    
    func testVoiceOverSupportInRealTimeCamera() throws {
        // 导航到实时相机页面
        navigateToRealTimeCamera()
        
        // 测试相机控制按钮的无障碍属性
        let closeButton = app.buttons["关闭相机"]
        XCTAssertTrue(closeButton.exists, "关闭按钮应该存在")
        XCTAssertTrue(closeButton.isAccessibilityElement, "关闭按钮应该是无障碍元素")
        XCTAssertEqual(closeButton.accessibilityLabel, "关闭相机", "关闭按钮应该有正确的无障碍标签")
        
        let captureButton = app.buttons["拍照识别"]
        XCTAssertTrue(captureButton.exists, "拍照识别按钮应该存在")
        XCTAssertTrue(captureButton.isAccessibilityElement, "拍照识别按钮应该是无障碍元素")
        XCTAssertEqual(captureButton.accessibilityLabel, "拍照识别", "拍照识别按钮应该有正确的无障碍标签")
        
        let flashButton = app.buttons.matching(identifier: "闪光灯").firstMatch
        XCTAssertTrue(flashButton.exists, "闪光灯按钮应该存在")
        XCTAssertTrue(flashButton.isAccessibilityElement, "闪光灯按钮应该是无障碍元素")
    }
    
    // MARK: - 键盘导航测试
    
    func testKeyboardNavigationInPhotoIdentification() throws {
        navigateToPhotoIdentification()
        
        // 测试Tab键导航
        let firstFocusableElement = app.buttons["拍照"]
        firstFocusableElement.tap()
        
        // 模拟键盘导航
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        
        let secondFocusableElement = app.buttons["相册"]
        XCTAssertTrue(secondFocusableElement.hasFocus, "Tab键应该能够导航到下一个元素")
        
        // 测试Shift+Tab反向导航
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [.shift])
        XCTAssertTrue(firstFocusableElement.hasFocus, "Shift+Tab应该能够反向导航")
    }
    
    func testKeyboardNavigationInSettings() throws {
        navigateToPhotoIdentification()
        
        // 打开高级选项
        let advancedOptionsButton = app.buttons["高级选项"]
        advancedOptionsButton.tap()
        
        // 测试设置开关的键盘导航
        let objectDetectionToggle = app.switches["物体检测"]
        objectDetectionToggle.tap()
        
        // 使用空格键切换开关
        app.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        
        // 验证开关状态改变
        let toggleValue = objectDetectionToggle.value as? String
        XCTAssertNotNil(toggleValue, "开关应该有值")
    }
    
    // MARK: - 语音播报测试
    
    func testSpeechAnnouncementsForRecognitionResults() throws {
        navigateToPhotoIdentification()
        
        // 模拟选择照片
        let cameraButton = app.buttons["拍照"]
        cameraButton.tap()
        
        // 等待相机界面出现
        let cameraView = app.otherElements["相机预览"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: 5), "相机预览应该出现")
        
        // 模拟拍照
        let shutterButton = app.buttons["拍摄"]
        if shutterButton.exists {
            shutterButton.tap()
        }
        
        // 等待识别结果
        let resultCard = app.otherElements["识别结果卡片"]
        XCTAssertTrue(resultCard.waitForExistence(timeout: 10), "识别结果应该出现")
        
        // 验证结果卡片的无障碍属性
        XCTAssertTrue(resultCard.isAccessibilityElement, "识别结果卡片应该是无障碍元素")
        XCTAssertNotNil(resultCard.accessibilityLabel, "识别结果卡片应该有无障碍标签")
        XCTAssertTrue(resultCard.accessibilityLabel!.contains("识别结果"), "无障碍标签应该包含识别结果信息")
    }
    
    func testSpeechAnnouncementsForErrors() throws {
        navigateToPhotoIdentification()
        
        // 模拟触发错误（例如网络错误）
        app.launchArguments.append("--simulate-network-error")
        
        let cameraButton = app.buttons["拍照"]
        cameraButton.tap()
        
        // 等待错误提示出现
        let errorAlert = app.alerts.firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5), "错误提示应该出现")
        
        // 验证错误提示的无障碍属性
        XCTAssertTrue(errorAlert.isAccessibilityElement, "错误提示应该是无障碍元素")
        XCTAssertNotNil(errorAlert.accessibilityLabel, "错误提示应该有无障碍标签")
    }
    
    // MARK: - 触觉反馈测试
    
    func testHapticFeedbackForUserActions() throws {
        navigateToPhotoIdentification()
        
        // 测试按钮点击的触觉反馈
        let cameraButton = app.buttons["拍照"]
        cameraButton.tap()
        
        // 注意：触觉反馈在UI测试中无法直接验证，
        // 但可以验证相关的用户交互是否正常工作
        
        let cameraView = app.otherElements["相机预览"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: 5), "相机预览应该出现，表明按钮点击成功")
    }
    
    // MARK: - 多物品识别的无障碍支持测试
    
    func testMultiObjectSelectionAccessibility() throws {
        navigateToPhotoIdentification()
        
        // 模拟上传包含多个物品的照片
        app.launchArguments.append("--simulate-multi-object-photo")
        
        let photoLibraryButton = app.buttons["相册"]
        photoLibraryButton.tap()
        
        // 等待照片选择界面
        let photoLibrary = app.otherElements["照片库"]
        if photoLibrary.waitForExistence(timeout: 5) {
            let firstPhoto = app.images.firstMatch
            firstPhoto.tap()
        }
        
        // 等待对象检测完成
        let objectDetectionInfo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '检测到'")).firstMatch
        XCTAssertTrue(objectDetectionInfo.waitForExistence(timeout: 10), "应该显示检测到的物品信息")
        
        // 测试检测到的物品的无障碍属性
        let detectedObjects = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '物品'"))
        XCTAssertGreaterThan(detectedObjects.count, 0, "应该有检测到的物品按钮")
        
        let firstObject = detectedObjects.firstMatch
        XCTAssertTrue(firstObject.isAccessibilityElement, "检测到的物品应该是无障碍元素")
        XCTAssertNotNil(firstObject.accessibilityLabel, "检测到的物品应该有无障碍标签")
        XCTAssertNotNil(firstObject.accessibilityHint, "检测到的物品应该有无障碍提示")
    }
    
    // MARK: - 设置页面的无障碍测试
    
    func testAccessibilitySettingsPage() throws {
        navigateToPhotoIdentification()
        
        // 打开设置菜单
        let moreButton = app.buttons["更多选项"]
        moreButton.tap()
        
        let settingsButton = app.buttons["高级选项"]
        settingsButton.tap()
        
        // 测试各种设置开关的无障碍属性
        let toggles = [
            "物体检测",
            "图像增强",
            "智能选择",
            "启用离线识别"
        ]
        
        for toggleName in toggles {
            let toggle = app.switches[toggleName]
            if toggle.exists {
                XCTAssertTrue(toggle.isAccessibilityElement, "\(toggleName)开关应该是无障碍元素")
                XCTAssertEqual(toggle.accessibilityLabel, toggleName, "\(toggleName)开关应该有正确的无障碍标签")
                XCTAssertNotNil(toggle.accessibilityValue, "\(toggleName)开关应该有无障碍值")
            }
        }
    }
    
    // MARK: - 进度指示器的无障碍测试
    
    func testProgressIndicatorAccessibility() throws {
        navigateToPhotoIdentification()
        
        // 模拟长时间的识别过程
        app.launchArguments.append("--simulate-slow-recognition")
        
        let cameraButton = app.buttons["拍照"]
        cameraButton.tap()
        
        // 等待相机界面并拍照
        let cameraView = app.otherElements["相机预览"]
        if cameraView.waitForExistence(timeout: 5) {
            let shutterButton = app.buttons["拍摄"]
            if shutterButton.exists {
                shutterButton.tap()
            }
        }
        
        // 等待进度指示器出现
        let progressView = app.progressIndicators.firstMatch
        XCTAssertTrue(progressView.waitForExistence(timeout: 5), "进度指示器应该出现")
        
        // 验证进度指示器的无障碍属性
        XCTAssertTrue(progressView.isAccessibilityElement, "进度指示器应该是无障碍元素")
        XCTAssertNotNil(progressView.accessibilityLabel, "进度指示器应该有无障碍标签")
        XCTAssertNotNil(progressView.accessibilityValue, "进度指示器应该有无障碍值")
    }
    
    // MARK: - 辅助方法
    
    private func navigateToPhotoIdentification() {
        // 导航到AI功能页面
        let aiTabButton = app.tabBars.buttons["AI功能"]
        if aiTabButton.exists {
            aiTabButton.tap()
        }
        
        // 点击照片识别按钮
        let photoIdentificationButton = app.buttons["照片识别"]
        if photoIdentificationButton.exists {
            photoIdentificationButton.tap()
        }
        
        // 等待页面加载
        let navigationTitle = app.navigationBars["AI 照片识别"]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5), "照片识别页面应该加载")
    }
    
    private func navigateToRealTimeCamera() {
        navigateToPhotoIdentification()
        
        // 点击实时识别按钮
        let realTimeButton = app.buttons["实时识别"]
        realTimeButton.tap()
        
        // 等待相机页面加载
        let cameraView = app.otherElements["相机预览"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: 5), "实时相机页面应该加载")
    }
    
    // MARK: - 性能测试
    
    func testAccessibilityPerformance() throws {
        measure {
            navigateToPhotoIdentification()
            
            // 测试页面加载和无障碍元素识别的性能
            let buttons = app.buttons
            let _ = buttons.count
            
            let switches = app.switches
            let _ = switches.count
            
            let staticTexts = app.staticTexts
            let _ = staticTexts.count
        }
    }
    
    // MARK: - 边界情况测试
    
    func testAccessibilityWithVoiceOverEnabled() throws {
        // 模拟VoiceOver启用状态
        app.launchArguments.append("--voiceover-enabled")
        
        navigateToPhotoIdentification()
        
        // 验证在VoiceOver启用时的特殊行为
        let cameraButton = app.buttons["拍照"]
        XCTAssertTrue(cameraButton.exists, "在VoiceOver模式下，拍照按钮应该存在")
        
        // 测试双击激活
        cameraButton.doubleTap()
        
        let cameraView = app.otherElements["相机预览"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: 5), "双击应该能够激活按钮")
    }
    
    func testAccessibilityWithReducedMotionEnabled() throws {
        // 模拟减少动画设置
        app.launchArguments.append("--reduce-motion-enabled")
        
        navigateToPhotoIdentification()
        
        // 验证在减少动画模式下的行为
        let realTimeButton = app.buttons["实时识别"]
        realTimeButton.tap()
        
        // 页面切换应该仍然正常工作，但动画可能被简化
        let cameraView = app.otherElements["相机预览"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: 5), "在减少动画模式下，页面切换应该正常工作")
    }
}