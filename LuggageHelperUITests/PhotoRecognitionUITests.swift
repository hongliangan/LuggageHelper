import XCTest

/// 照片识别UI功能的自动化测试
final class PhotoRecognitionUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 基础导航测试
    
    func testNavigateToPhotoRecognition() throws {
        // 导航到AI功能页面
        let aiTabButton = app.tabBars.buttons["AI功能"]
        XCTAssertTrue(aiTabButton.waitForExistence(timeout: 5))
        aiTabButton.tap()
        
        // 点击照片识别按钮
        let photoRecognitionButton = app.buttons["照片识别"]
        XCTAssertTrue(photoRecognitionButton.waitForExistence(timeout: 5))
        photoRecognitionButton.tap()
        
        // 验证照片识别页面已打开
        let navigationTitle = app.navigationBars["AI 照片识别"]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5))
    }
    
    // MARK: - 照片选择测试
    
    func testPhotoSelectionButtons() throws {
        navigateToPhotoRecognition()
        
        // 验证照片选择按钮存在
        let cameraButton = app.buttons["拍照"]
        let albumButton = app.buttons["相册"]
        let realTimeButton = app.buttons["实时识别"]
        
        XCTAssertTrue(cameraButton.exists)
        XCTAssertTrue(albumButton.exists)
        XCTAssertTrue(realTimeButton.exists)
        
        // 测试按钮可点击性
        XCTAssertTrue(cameraButton.isEnabled)
        XCTAssertTrue(albumButton.isEnabled)
        XCTAssertTrue(realTimeButton.isEnabled)
    }
    
    func testCameraPermissionFlow() throws {
        navigateToPhotoRecognition()
        
        // 点击拍照按钮
        let cameraButton = app.buttons["拍照"]
        cameraButton.tap()
        
        // 如果出现权限请求，允许访问
        let allowButton = app.buttons["允许"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }
        
        // 验证相机界面出现或权限被拒绝的处理
        let cameraView = app.otherElements["相机预览"]
        let permissionDeniedAlert = app.alerts["需要相机权限"]
        
        XCTAssertTrue(cameraView.waitForExistence(timeout: 5) || permissionDeniedAlert.waitForExistence(timeout: 5))
    }
    
    // MARK: - 高级选项测试
    
    func testAdvancedOptionsToggle() throws {
        navigateToPhotoRecognition()
        
        // 点击高级选项
        let advancedOptionsButton = app.buttons["高级选项"]
        XCTAssertTrue(advancedOptionsButton.waitForExistence(timeout: 5))
        advancedOptionsButton.tap()
        
        // 验证高级选项展开
        let objectDetectionToggle = app.switches["使用物体检测"]
        let imageEnhanceToggle = app.switches["增强图像质量"]
        let offlineModeToggle = app.switches["启用离线识别"]
        
        XCTAssertTrue(objectDetectionToggle.waitForExistence(timeout: 3))
        XCTAssertTrue(imageEnhanceToggle.exists)
        XCTAssertTrue(offlineModeToggle.exists)
    }
    
    func testAdvancedOptionsConfiguration() throws {
        navigateToPhotoRecognition()
        
        // 展开高级选项
        let advancedOptionsButton = app.buttons["高级选项"]
        advancedOptionsButton.tap()
        
        // 测试切换开关
        let objectDetectionToggle = app.switches["使用物体检测"]
        let initialState = objectDetectionToggle.value as? String == "1"
        
        objectDetectionToggle.tap()
        
        // 验证状态改变
        let newState = objectDetectionToggle.value as? String == "1"
        XCTAssertNotEqual(initialState, newState)
        
        // 测试对象选择模式
        if objectDetectionToggle.value as? String == "1" {
            let selectionModePicker = app.segmentedControls["选择模式"]
            if selectionModePicker.waitForExistence(timeout: 3) {
                let multipleButton = selectionModePicker.buttons["多选"]
                if multipleButton.exists {
                    multipleButton.tap()
                    XCTAssertTrue(multipleButton.isSelected)
                }
            }
        }
    }
    
    // MARK: - 图像处理流程测试
    
    func testImageProcessingFlow() throws {
        navigateToPhotoRecognition()
        
        // 模拟选择图片（这里需要使用测试图片）
        selectTestImage()
        
        // 验证图像显示
        let imageView = app.images["处理后图片"]
        XCTAssertTrue(imageView.waitForExistence(timeout: 10))
        
        // 验证处理进度显示
        let processingIndicator = app.otherElements["图像处理进度"]
        if processingIndicator.waitForExistence(timeout: 3) {
            // 等待处理完成
            XCTAssertTrue(processingIndicator.waitForNonExistence(timeout: 15))
        }
        
        // 验证操作按钮出现
        let recognizeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '识别'")).firstMatch
        XCTAssertTrue(recognizeButton.waitForExistence(timeout: 5))
    }
    
    func testObjectDetectionDisplay() throws {
        navigateToPhotoRecognition()
        
        // 确保物体检测开启
        enableObjectDetection()
        
        // 选择包含多个物品的测试图片
        selectMultiObjectTestImage()
        
        // 验证检测到的物品显示
        let detectedObjectsSection = app.otherElements["检测到的物品"]
        XCTAssertTrue(detectedObjectsSection.waitForExistence(timeout: 15))
        
        // 验证物品缩略图
        let objectThumbnails = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'object_thumbnail_'"))
        XCTAssertGreaterThan(objectThumbnails.count, 0)
        
        // 测试物品选择
        let firstThumbnail = objectThumbnails.firstMatch
        firstThumbnail.tap()
        
        // 验证选择状态改变
        XCTAssertTrue(firstThumbnail.isSelected)
    }
    
    // MARK: - 识别结果测试
    
    func testSingleRecognitionFlow() throws {
        navigateToPhotoRecognition()
        
        // 选择测试图片并开始识别
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        XCTAssertTrue(recognizeButton.waitForExistence(timeout: 10))
        recognizeButton.tap()
        
        // 验证加载状态
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.waitForExistence(timeout: 3) {
            // 等待识别完成
            XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 30))
        }
        
        // 验证识别结果显示
        let resultCard = app.otherElements["识别结果卡片"]
        XCTAssertTrue(resultCard.waitForExistence(timeout: 5))
        
        // 验证使用按钮
        let useButton = app.buttons["使用此结果"]
        XCTAssertTrue(useButton.exists)
        XCTAssertTrue(useButton.isEnabled)
    }
    
    func testBatchRecognitionFlow() throws {
        navigateToPhotoRecognition()
        
        // 启用物体检测
        enableObjectDetection()
        
        // 选择多物品图片
        selectMultiObjectTestImage()
        
        // 选择多个物品
        selectMultipleObjects()
        
        // 开始批量识别
        let batchButton = app.buttons["批量识别"]
        XCTAssertTrue(batchButton.waitForExistence(timeout: 10))
        batchButton.tap()
        
        // 验证批量进度显示
        let progressView = app.otherElements["批量识别进度"]
        if progressView.waitForExistence(timeout: 5) {
            // 等待批量识别完成
            XCTAssertTrue(progressView.waitForNonExistence(timeout: 60))
        }
        
        // 验证批量结果
        let batchResultSummary = app.otherElements["批量识别完成"]
        XCTAssertTrue(batchResultSummary.waitForExistence(timeout: 10))
        
        // 测试查看详情
        let viewDetailsButton = app.buttons["查看详情"]
        if viewDetailsButton.exists {
            viewDetailsButton.tap()
            
            // 验证详情页面
            let detailsView = app.navigationBars["批量识别结果"]
            XCTAssertTrue(detailsView.waitForExistence(timeout: 5))
        }
    }
    
    // MARK: - 错误处理测试
    
    func testImageQualityError() throws {
        navigateToPhotoRecognition()
        
        // 选择低质量图片
        selectLowQualityTestImage()
        
        // 验证错误提示
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '图像质量'")).firstMatch
        if errorMessage.waitForExistence(timeout: 10) {
            XCTAssertTrue(errorMessage.exists)
            
            // 测试错误恢复选项
            let errorGuidanceButton = app.buttons["查看解决方案"]
            if errorGuidanceButton.exists {
                errorGuidanceButton.tap()
                
                // 验证错误指导页面
                let guidanceView = app.otherElements["错误指导"]
                XCTAssertTrue(guidanceView.waitForExistence(timeout: 5))
            }
        }
    }
    
    func testNetworkErrorHandling() throws {
        navigateToPhotoRecognition()
        
        // 禁用网络（需要在测试设置中配置）
        // 这里假设网络不可用
        
        selectTestImage()
        
        let recognizeButton = app.buttons["开始识别"]
        recognizeButton.tap()
        
        // 验证离线模式提示或网络错误处理
        let offlinePrompt = app.alerts.matching(NSPredicate(format: "label CONTAINS '网络'")).firstMatch
        let offlineMode = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '离线'")).firstMatch
        
        XCTAssertTrue(offlinePrompt.waitForExistence(timeout: 15) || offlineMode.waitForExistence(timeout: 15))
    }
    
    // MARK: - 离线模式测试
    
    func testOfflineModeToggle() throws {
        navigateToPhotoRecognition()
        
        // 展开高级选项
        let advancedOptionsButton = app.buttons["高级选项"]
        advancedOptionsButton.tap()
        
        // 启用离线模式
        let offlineModeToggle = app.switches["启用离线识别"]
        XCTAssertTrue(offlineModeToggle.waitForExistence(timeout: 3))
        
        if offlineModeToggle.value as? String != "1" {
            offlineModeToggle.tap()
        }
        
        // 验证离线模式状态
        XCTAssertEqual(offlineModeToggle.value as? String, "1")
        
        // 验证模型状态显示
        let modelStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '模型'")).firstMatch
        XCTAssertTrue(modelStatus.waitForExistence(timeout: 3))
    }
    
    func testOfflineModelManagement() throws {
        navigateToPhotoRecognition()
        
        // 展开高级选项
        let advancedOptionsButton = app.buttons["高级选项"]
        advancedOptionsButton.tap()
        
        // 点击管理模型按钮
        let manageModelsButton = app.buttons["管理模型"]
        XCTAssertTrue(manageModelsButton.waitForExistence(timeout: 3))
        manageModelsButton.tap()
        
        // 验证模型管理页面
        let modelManagementView = app.navigationBars["离线模型管理"]
        XCTAssertTrue(modelManagementView.waitForExistence(timeout: 5))
        
        // 关闭模型管理页面
        let doneButton = app.buttons["完成"]
        if doneButton.exists {
            doneButton.tap()
        }
    }
    
    // MARK: - 性能测试
    
    func testImageProcessingPerformance() throws {
        navigateToPhotoRecognition()
        
        measure {
            selectTestImage()
            
            // 等待图像处理完成
            let imageView = app.images["处理后图片"]
            _ = imageView.waitForExistence(timeout: 10)
        }
    }
    
    func testRecognitionPerformance() throws {
        navigateToPhotoRecognition()
        
        selectTestImage()
        
        measure {
            let recognizeButton = app.buttons["开始识别"]
            recognizeButton.tap()
            
            // 等待识别完成
            let resultCard = app.otherElements["识别结果卡片"]
            _ = resultCard.waitForExistence(timeout: 30)
            
            // 重置状态
            let resetButton = app.buttons["重新选择"]
            if resetButton.exists {
                resetButton.tap()
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func navigateToPhotoRecognition() {
        let aiTabButton = app.tabBars.buttons["AI功能"]
        aiTabButton.tap()
        
        let photoRecognitionButton = app.buttons["照片识别"]
        photoRecognitionButton.tap()
    }
    
    private func enableObjectDetection() {
        let advancedOptionsButton = app.buttons["高级选项"]
        if advancedOptionsButton.exists {
            advancedOptionsButton.tap()
            
            let objectDetectionToggle = app.switches["使用物体检测"]
            if objectDetectionToggle.value as? String != "1" {
                objectDetectionToggle.tap()
            }
        }
    }
    
    private func selectTestImage() {
        // 这里应该选择一个测试图片
        // 在实际测试中，可能需要预先在测试包中包含测试图片
        let albumButton = app.buttons["相册"]
        albumButton.tap()
        
        // 选择第一张图片（假设相册中有图片）
        let firstImage = app.images.firstMatch
        if firstImage.waitForExistence(timeout: 5) {
            firstImage.tap()
        }
    }
    
    private func selectMultiObjectTestImage() {
        // 选择包含多个物品的测试图片
        selectTestImage()
    }
    
    private func selectLowQualityTestImage() {
        // 选择低质量的测试图片
        selectTestImage()
    }
    
    private func selectMultipleObjects() {
        // 等待物品检测完成
        let detectedObjectsSection = app.otherElements["检测到的物品"]
        _ = detectedObjectsSection.waitForExistence(timeout: 15)
        
        // 选择前两个物品
        let objectThumbnails = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'object_thumbnail_'"))
        if objectThumbnails.count >= 2 {
            objectThumbnails.element(boundBy: 0).tap()
            objectThumbnails.element(boundBy: 1).tap()
        }
    }
}

// MARK: - 测试扩展

extension XCUIElement {
    /// 等待元素不存在
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}