## 错误记录

| # | 日期 | 错误表象 | 根因 | 修复方式 |
|---|------|---------|------|---------|
| 1 | 2026-06-28 | `Value of type 'WindowGroup<some View>' has no member 'windowTitle'` | `.windowTitle()` 在 SwiftUI macOS 中不存在，窗口标题来自 `Info.plist` 的 `CFBundleName` | 移除 `.windowTitle()`，改用 `.windowResizability(.contentSize)` |
| 2 | 2026-06-28 | `Cannot convert value of type 'VerifyState' to expected argument type 'ScrollPhase'` / `Referencing operator function '==' on 'Equatable' requires that 'VerifyState' conform to 'Equatable'` | Swift enum 用 `==` 对比需要显式声明 `Equatable`；`if case .error(let msg)` 和 `switch` 混用导致编译器困惑 | enum 加 `: Equatable`；body 改用 `@ViewBuilder` + `switch` 统一控制流 |
| 3 | 2026-06-28 | `Function declares an opaque return type, but has no return statements in its body from which to infer an underlying type` | SwiftUI `body` 中 `if/else if/else` 链每分支返回不同类型，编译器无法推断 `some View` | 用 `@ViewBuilder` 计算属性 + `switch` 替代 `if/else` 链；或用 `Group` 包裹条件表格 |
