# 行李助手 - 修改功能开发计划

## 第一阶段：行李修改功能

- [x] **视图(View):** 创建 `EditLuggageView.swift`，用于编辑行李信息。
    - 界面应与 `AddLuggageView` 类似，但需预先填充所选行李的现有数据。
- [x] **视图(View):** 在 `LuggageListView` 或 `LuggageDetailView` 中添加入口按钮，以触发编辑��作。
    - 考虑在行李列表的滑动菜单或详情页的导航栏中添加“编辑”按钮。
- [x] **视图模型(ViewModel):** 在 `LuggageViewModel.swift` 中添加 `updateLuggage` 函数。
    - 此函数接收修改后的行李对象，并更新 `luggages` 数组。
- [x] **数据服务(Service):** 在 `LuggageDataService.swift` 中更新 `saveLuggages` 的逻辑，确保修改能被正确持久化。

## 第二阶段：物品修改功能

- [x] **视图(View):** 创建 `EditItemView.swift`，用于编辑物品信息。
    - 界面应与 `AddItemView` 类似，并预填充所选物品的数据。
- [x] **视图(View):** 在 `ItemRowView` 或 `ItemListView` 中添加入口，以触发物品编辑。
    - 建议在物品行��上下文菜单（context menu）中添加“编辑”选项。
- [x] **视图模型(ViewModel):** 在 `LuggageViewModel.swift` 中添加 `updateItem` 函数。
    - 此函数需要处理两种情况：修改独立物品和修改行李中的物品。
    - 更新后需要刷新相关的视图。
- [x] **数据服务(Service):** 确保 `LuggageDataService` 的保存逻辑能够正确处理物品信息的更新。

## 第三阶段：代码审查和测试

- [ ] **审查:** 回顾所有新添加和修改的代码，确保其遵循项目规范。
- [ ] **测试:** 手动测试修改功能，确保数据正确性、UI表现符合预期，并且没有引入新的bug。
