# 花名册核对 — 项目记忆

## 代理规则

1. 重要变更后自动更新 memory.md 并 push
2. 会话压缩前询问是否更新
3. 记录使用的 skill / mode

## 目标

构建一个 macOS App，自动比对公司花名册（Excel）与 Contact List（PDF），找出手机号、直拨号、邮箱等信息不一致，输出差异 Excel。

## 关键决策

- **架构**：SwiftUI macOS App + Python 脚本（通过 Process 调用）
- **Python 库**：pdfplumber（解析 PDF）、openpyxl（读写 Excel）
- **比对逻辑**：以工作邮箱为匹配键；直拨电话优先对照 CL Direct Line，若无则对照 CL Mobile；CL 无手机号不报错
- **号码匹配**：去空格/横线/国家区号后比较，支持后缀匹配（如深圳分机号 +86 755 XXXX vs XXXX）
- **输出形式**：App 内表格展示 + 一键导出带格式 Excel
- **Skill 化**：核对脚本已封装为 `roster-verification` skill（`~/.codex/skills/roster-verification/`）
- **Git**：HTTPS 推送，remote = `https://github.com/John-Guo6/RosterChecker.git`

## 当前数据

- Contact List PDF 格式：逐行文本，英文名+中文名+电话+邮箱
- 花名册 Excel：Sheet「在职人员」，列：姓名、工作邮箱、直拨电话/移动电话、手机号码、部门、人员状态
- 跳过部门邮箱（allstaff@、staff@、finance@ 等）

## 文件清单

- `RosterChecker.xcodeproj/` — Xcode 项目
- `RosterChecker/RosterCheckerApp.swift` — App 入口
- `RosterChecker/ContentView.swift` — UI（文件选择、结果表格、导出按钮）
- `RosterChecker/RosterViewModel.swift` — 核心逻辑（Process 调用、JSON 解析）
- `RosterChecker/verify_roster.py` — 核对脚本（支持 --json / --output）
- `RosterChecker/Info.plist` — App 元数据
- `RosterChecker/Assets.xcassets/` — 资源目录
- `generate_project.py` — 项目文件生成器
- `README.md` — 使用说明

## GitHub

- 仓库：https://github.com/John-Guo6/RosterChecker
- 分支：main

## 已完成的里程碑

- [x] 手动分析花名册 × ContactList 差异
- [x] 创建 roster-verification skill（Python 脚本 + SKILL.md）
- [x] 构建 SwiftUI macOS App
- [x] GitHub 仓库 + README

## 待办

- [ ] 修复 Xcode 编译错误（已修复部分，待用户验证最终编译）
- [ ] Token 已暴露，需撤销重新生成

## 会话记录

| 日期 | Mode/Skill | 变更摘要 |
|------|-----------|---------|
| 2026-06-24 | 手动分析 | 对比花名册与 Contact List，发现 4 人手机号错误 + 1 人邮箱少 .hk |
| 2026-06-24 | writing-skills, skill-creator | 创建 roster-verification skill（SKILL.md + verify_roster.py） |
| 2026-06-24 | brainstorming, 编码 | 构建 RosterChecker SwiftUI macOS App（文件选择 → Process 调用 Python → 表格展示） |
| 2026-06-28 | GitHub | 初始化 git、创建仓库、推送代码、添加 README |
| 2026-06-28 | memory-recorder | 创建 memory.md |

| 2026-06-28 | 编码 | 添加英文名核对功能：从邮箱前缀推导英文名，对照花名册「英文名」列 |
| 2026-06-28 | memory-recorder, error-recorder | 创建 AGENTS.md 记录 SwiftUI 编译错误；更新 memory.md |
| 2026-07-06 | 编码 | 分离完整核对/仅英文名核对模式；修复飞书模版兼容、拼音误报等问题 |
