## 错误记录

| # | 日期 | 错误表象 | 根因 | 修复方式 |
|---|------|---------|------|---------|
| 1 | 2026-06-28 | `Value of type 'WindowGroup<some View>' has no member 'windowTitle'` | `.windowTitle()` 在 SwiftUI macOS 中不存在，窗口标题来自 `Info.plist` 的 `CFBundleName` | 移除 `.windowTitle()`，改用 `.windowResizability(.contentSize)` |
| 2 | 2026-06-28 | `Cannot convert value of type 'VerifyState' to expected argument type 'ScrollPhase'` / `Referencing operator function '==' on 'Equatable' requires that 'VerifyState' conform to 'Equatable'` | Swift enum 用 `==` 对比需要显式声明 `Equatable`；`if case .error(let msg)` 和 `switch` 混用导致编译器困惑 | enum 加 `: Equatable`；body 改用 `@ViewBuilder` + `switch` 统一控制流 |
| 3 | 2026-06-28 | `Function declares an opaque return type, but has no return statements in its body from which to infer an underlying type` | SwiftUI `body` 中 `if/else if/else` 链每分支返回不同类型，编译器无法推断 `some View` | 用 `@ViewBuilder` 计算属性 + `switch` 替代 `if/else` 链；或用 `Group` 包裹条件表格 |
| 4 | 2026-07-06 | 脚本报 `KeyError: '在职人员'` | 飞书导出模版 Sheet 名是 `Sheet1` 非 `在职人员`，列结构也完全不同 | 创建独立的 `--english-only` 模式，自动查找"用户 ID"表头行并适配列名 |
| 5 | 2026-07-06 | 英文名模式报 `JSON 解析失败` | Python JSON 输出缺少 `only_roster_count` / `only_cl_count` 字段，Swift `VerifySummary` 解码失败 | 在英文名模式 JSON 输出中补上这两个字段（值为 0） |
| 6 | 2026-07-06 | 纯拼音邮箱误报英文名错误（如 `sunqing` → 预期 `Sun`） | 算法无法区分拼音姓氏和英文名，姓氏在前的邮箱都被错误推导出英文名 | 添加 `en_is_pinyin` 标记：英文部分比姓氏短即为拼音，Excel 为空时不报错 |
