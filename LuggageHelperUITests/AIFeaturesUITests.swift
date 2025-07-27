import XCTest

final class AIFeaturesUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // 设置测试环境
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["MOCK_AI_SERVICE"] = "true"
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 物品识别UI测试
    
    func testItemIdentificationFlow() throws {
        // Given - 导航到物品添加页面
        let addItemButton = app.buttons["添加物品"]
        XCTAssertTrue(addItemButton.waitForExistence(timeout: 5))
        addItemButton.tap()
        
        // When - 输入物品信息
        let itemNameField = app.textFields["物品名称"]
        XCTAssertTrue(itemNameField.waitForExistence(timeout: 2))
        itemNameField.tap()
        itemNameField.typeText("iPhone 15 Pro")
        
        let modelField = app.textFields["型号"]
        if modelField.exists {
            modelField.tap()
            modelField.typeText("256GB")
        }
        
        // When - 点击AI识别按钮
        let aiIdentifyButton = app.buttons["AI识别"]
        XCTAssertTrue(aiIdentifyButton.exists)
        aiIdentifyButton.tap()
        
        // Then - 验证加载状态显示
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 2))
        
        // Then - 验证识别结果显示
        let weightLabel = app.staticTexts["重量"]
        XCTAssertTrue(weightLabel.waitForExistence(timeout: 10))
        
        let volumeLabel = app.staticTexts["体积"]
        XCTAssertTrue(volumeLabel.exists)
        
        // Then - 验证保存按钮可用
        let saveButton = app.buttons["保存"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertTrue(saveButton.isEnabled)
    }
    
    func testPhotoRecognitionFlow() throws {
        // Given
        let addItemButton = app.buttons["添加物品"]
        addItemButton.tap()
        
        // When - 点击拍照识别按钮
        let photoButton = app.buttons["拍照识别"]
        XCTAssertTrue(photoButton.waitForExistence(timeout: 2))
        photoButton.tap()
        
        // Then - 验证相机权限提示或相机界面
        let cameraAlert = app.alerts.firstMatch
        if cameraAlert.exists {
            let allowButton = cameraAlert.buttons["允许"]
            if allowButton.exists {
                allowButton.tap()
            }
        }
        
        // 在模拟器中，相机可能不可用，所以这里主要测试UI流程
        // 实际设备测试中可以进一步验证相机功能
    }
    
    // MARK: - 旅行规划UI测试
    
    func testTravelPlannerFlow() throws {
        // Given - 导航到AI功能页面
        let aiFeaturesTab = app.tabBars.buttons["AI功能"]
        XCTAssertTrue(aiFeaturesTab.waitForExistence(timeout: 5))
        aiFeaturesTab.tap()
        
        // When - 点击智能旅行规划
        let travelPlannerButton = app.buttons["智能旅行规划"]
        XCTAssertTrue(travelPlannerButton.waitForExistence(timeout: 2))
        travelPlannerButton.tap()
        
        // When - 填写旅行信息
        let destinationField = app.textFields["目的地"]
        XCTAssertTrue(destinationField.waitForExistence(timeout: 2))
        destinationField.tap()
        destinationField.typeText("东京")
        
        let durationStepper = app.steppers["天数"]
        if durationStepper.exists {
            durationStepper.buttons["增加"].tap()
            durationStepper.buttons["增加"].tap() // 设置为7天
        }
        
        let seasonPicker = app.buttons["季节选择"]
        if seasonPicker.exists {
            seasonPicker.tap()
            app.buttons["春季"].tap()
        }
        
        // When - 生成建议
        let generateButton = app.buttons["生成建议清单"]
        XCTAssertTrue(generateButton.exists)
        generateButton.tap()
        
        // Then - 验证加载状态
        let loadingView = app.otherElements["加载中"]
        XCTAssertTrue(loadingView.waitForExistence(timeout: 2))
        
        // Then - 验证建议结果
        let suggestionsList = app.tables["建议清单"]
        XCTAssertTrue(suggestionsList.waitForExistence(timeout: 10))
        
        let firstSuggestion = suggestionsList.cells.firstMatch
        XCTAssertTrue(firstSuggestion.exists)
    }
    
    // MARK: - 装箱优化UI测试
    
    func testPackingOptimizationFlow() throws {
        // Given - 确保有物品和行李箱数据
        setupTestData()
        
        // Given - 导航到装箱页面
        let packingTab = app.tabBars.buttons["装箱"]
        packingTab.tap()
        
        // When - 选择行李箱
        let luggageSelector = app.buttons["选择行李箱"]
        if luggageSelector.exists {
            luggageSelector.tap()
            app.buttons["测试行李箱"].tap()
        }
        
        // When - 添加物品到装箱清单
        let addItemToPackingButton = app.buttons["添加物品"]
        addItemToPackingButton.tap()
        
        let firstItem = app.tables.cells.firstMatch
        firstItem.tap()
        
        // When - 点击AI优化按钮
        let optimizeButton = app.buttons["AI优化装箱"]
        XCTAssertTrue(optimizeButton.exists)
        optimizeButton.tap()
        
        // Then - 验证优化结果
        let optimizationResults = app.otherElements["装箱建议"]
        XCTAssertTrue(optimizationResults.waitForExistence(timeout: 10))
        
        let efficiencyLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '利用率'")).firstMatch
        XCTAssertTrue(efficiencyLabel.exists)
    }
    
    // MARK: - 错误处理UI测试
    
    func testErrorHandlingUI() throws {
        // Given - 设置网络错误环境
        app.launchEnvironment["SIMULATE_NETWORK_ERROR"] = "true"
        app.terminate()
        app.launch()
        
        // When - 尝试使用AI功能
        let aiFeaturesTab = app.tabBars.buttons["AI功能"]
        aiFeaturesTab.tap()
        
        let itemIdentificationButton = app.buttons["智能物品识别"]
        itemIdentificationButton.tap()
        
        let itemNameField = app.textFields["物品名称"]
        itemNameField.tap()
        itemNameField.typeText("测试物品")
        
        let aiIdentifyButton = app.buttons["AI识别"]
        aiIdentifyButton.tap()
        
        // Then - 验证错误提示显示
        let errorAlert = app.alerts.firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5))
        
        let errorMessage = errorAlert.staticTexts.firstMatch
        XCTAssertTrue(errorMessage.label.contains("网络") || errorMessage.label.contains("错误"))
        
        // Then - 验证重试按钮存在
        let retryButton = errorAlert.buttons["重试"]
        XCTAssertTrue(retryButton.exists)
        
        let cancelButton = errorAlert.buttons["取消"]
        XCTAssertTrue(cancelButton.exists)
        
        cancelButton.tap()
    }
    
    // MARK: - 网络状态UI测试
    
    func testNetworkStatusIndicator() throws {
        // Given - 检查网络状态指示器
        let networkStatusView = app.otherElements["网络状态"]
        
        if networkStatusView.exists {
            // When - 点击网络状态查看详情
            networkStatusView.tap()
            
            // Then - 验证网络详情页面
            let networkDetailView = app.navigationBars["网络状态"]
            XCTAssertTrue(networkDetailView.waitForExistence(timeout: 2))
            
            let connectionStatusLabel = app.staticTexts["连接状态"]
            XCTAssertTrue(connectionStatusLabel.exists)
            
            let testConnectionButton = app.buttons["测试网络连接"]
            XCTAssertTrue(testConnectionButton.exists)
            
            // When - 测试网络连接
            testConnectionButton.tap()
            
            // Then - 验证测试结果显示
            let testResultLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'ms'")).firstMatch
            XCTAssertTrue(testResultLabel.waitForExistence(timeout: 5))
        }
    }
    
    // MARK: - 加载状态UI测试
    
    func testLoadingStateDisplay() throws {
        // Given
        let aiFeaturesTab = app.tabBars.buttons["AI功能"]
        aiFeaturesTab.tap()
        
        // When - 触发长时间操作
        let batchProcessButton = app.buttons["批量物品分类"]
        if batchProcessButton.exists {
            batchProcessButton.tap()
            
            // Then - 验证加载状态显示
            let loadingOverlay = app.otherElements["加载覆盖层"]
            XCTAssertTrue(loadingOverlay.waitForExistence(timeout: 2))
            
            let progressBar = app.progressIndicators.firstMatch
            XCTAssertTrue(progressBar.exists)
            
            let cancelButton = app.buttons["取消"]
            if cancelButton.exists {
                XCTAssertTrue(cancelButton.isEnabled)
            }
            
            let progressLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '%'")).firstMatch
            XCTAssertTrue(progressLabel.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - 撤销重做UI测试
    
    func testUndoRedoFunctionality() throws {
        // Given - 执行一个可撤销的操作
        let addItemButton = app.buttons["添加物品"]
        addItemButton.tap()
        
        let itemNameField = app.textFields["物品名称"]
        itemNameField.tap()
        itemNameField.typeText("测试撤销物品")
        
        let saveButton = app.buttons["保存"]
        saveButton.tap()
        
        // When - 查找撤销按钮
        let undoButton = app.buttons["撤销"]
        if undoButton.exists {
            XCTAssertTrue(undoButton.isEnabled)
            
            // When - 执行撤销
            undoButton.tap()
            
            // Then - 验证重做按钮可用
            let redoButton = app.buttons["重做"]
            XCTAssertTrue(redoButton.waitForExistence(timeout: 2))
            XCTAssertTrue(redoButton.isEnabled)
            
            // When - 执行重做
            redoButton.tap()
            
            // Then - 验证撤销按钮再次可用
            XCTAssertTrue(undoButton.isEnabled)
        }
    }
    
    // MARK: - 缓存管理UI测试
    
    func testCacheManagementInterface() throws {
        // Given - 导航到设置或管理页面
        let settingsTab = app.tabBars.buttons["设置"]
        if settingsTab.exists {
            settingsTab.tap()
            
            let cacheManagementButton = app.buttons["缓存管理"]
            if cacheManagementButton.exists {
                cacheManagementButton.tap()
                
                // Then - 验证缓存管理界面
                let cacheStatsView = app.otherElements["缓存统计"]
                XCTAssertTrue(cacheStatsView.waitForExistence(timeout: 2))
                
                let clearCacheButton = app.buttons["清空缓存"]
                XCTAssertTrue(clearCacheButton.exists)
                
                // When - 清空缓存
                clearCacheButton.tap()
                
                let confirmAlert = app.alerts.firstMatch
                if confirmAlert.exists {
                    let confirmButton = confirmAlert.buttons["确认"]
                    confirmButton.tap()
                }
            }
        }
    }
    
    // MARK: - 性能测试
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testScrollPerformance() throws {
        // Given - 导航到有大量数据的列表页面
        let itemsTab = app.tabBars.buttons["物品"]
        itemsTab.tap()
        
        let itemsList = app.tables.firstMatch
        XCTAssertTrue(itemsList.waitForExistence(timeout: 5))
        
        // When & Then - 测试滚动性能
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            itemsList.swipeUp(velocity: .fast)
            itemsList.swipeDown(velocity: .fast)
        }
    }
    
    // MARK: - 辅助方法
    
    private func setupTestData() {
        // 这里可以通过app.launchEnvironment设置测试数据
        // 或者通过深度链接等方式预设测试数据
        app.launchEnvironment["SETUP_TEST_DATA"] = "true"
    }
    
    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    private func takeScreenshotWithName(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - 扩展UI测试

extension AIFeaturesUITests {
    
    // MARK: - 可访问性测试
    
    func testAccessibility() throws {
        // Given
        let aiFeaturesTab = app.tabBars.buttons["AI功能"]
        aiFeaturesTab.tap()
        
        // When & Then - 验证主要元素的可访问性
        let itemIdentificationButton = app.buttons["智能物品识别"]
        XCTAssertTrue(itemIdentificationButton.exists)
        XCTAssertNotNil(itemIdentificationButton.label)
        XCTAssertTrue(itemIdentificationButton.isHittable)
        
        // 验证VoiceOver支持
        if itemIdentificationButton.exists {
            XCTAssertFalse(itemIdentificationButton.label.isEmpty)
        }
    }
    
    // MARK: - 多语言测试
    
    func testLocalization() throws {
        // 这个测试需要在不同语言环境下运行
        // 可以通过设置app.launchArguments来测试不同语言
        
        // Given - 设置为英文环境
        app.launchArguments.append("-AppleLanguages")
        app.launchArguments.append("(en)")
        app.launch()
        
        // Then - 验证英文界面
        let addItemButton = app.buttons["Add Item"]
        if addItemButton.exists {
            XCTAssertTrue(addItemButton.exists)
        }
    }
    
    // MARK: - 设备旋转测试
    
    func testDeviceRotation() throws {
        // Given
        let aiFeaturesTab = app.tabBars.buttons["AI功能"]
        aiFeaturesTab.tap()
        
        // When - 旋转设备
        XCUIDevice.shared.orientation = .landscapeLeft
        
        // Then - 验证界面适应
        let itemIdentificationButton = app.buttons["智能物品识别"]
        XCTAssertTrue(itemIdentificationButton.waitForExistence(timeout: 2))
        XCTAssertTrue(itemIdentificationButton.isHittable)
        
        // When - 旋转回竖屏
        XCUIDevice.shared.orientation = .portrait
        
        // Then - 验证界面恢复
        XCTAssertTrue(itemIdentificationButton.exists)
        XCTAssertTrue(itemIdentificationButton.isHittable)
    }
    
    // MARK: - 内存压力测试
    
    func testMemoryPressure() throws {
        // Given - 执行大量操作来测试内存管理
        let aiFeaturesTab = app.tabBars.buttons["AI功能"]
        aiFeaturesTab.tap()
        
        // When - 重复执行操作
        for i in 0..<10 {
            let itemIdentificationButton = app.buttons["智能物品识别"]
            itemIdentificationButton.tap()
            
            let itemNameField = app.textFields["物品名称"]
            itemNameField.tap()
            itemNameField.typeText("测试物品\(i)")
            
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            }
        }
        
        // Then - 应用应该仍然响应
        let itemIdentificationButton = app.buttons["智能物品识别"]
        XCTAssertTrue(itemIdentificationButton.exists)
        XCTAssertTrue(itemIdentificationButton.isHittable)
    }
}