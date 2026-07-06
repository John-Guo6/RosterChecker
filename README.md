# 花名册核对

一个 macOS App，用于将公司花名册（Excel）与 Contact List（PDF）进行自动比对，找出信息不一致之处。

## 功能

- **完整核对**：比对手机号、直拨电话、英文名（适配原始花名册格式）
- **仅英文名核对**：单独检查英文名是否正确（适配飞书导出模版）
- 自动识别号码格式差异（横线、空格、国家区号、深圳分机号等）
- 直拨电话优先对照 Direct Line，若无则对照 Mobile
- 从邮箱前缀自动推导预期英文名，跳过拼音误报
- 结果分三类展示：信息不一致 / 花名册独有 / ContactList 独有
- 一键导出核对结果 Excel

## 运行环境

- macOS 14.0+
- Python 3（需安装 `pdfplumber` 和 `openpyxl`）
- Xcode 15+

## 安装依赖

```bash
pip3 install pdfplumber openpyxl
```

## 使用方式

### App（推荐）

1. 用 Xcode 打开 `RosterChecker.xcodeproj`
2. 按 `⌘R` 运行
3. 顶部选择核对模式：完整核对 / 仅英文名
4. 选择 Contact List PDF 和对应的 Excel 文件
5. 点击「开始核对」
6. 切换 Tab 查看不同类别结果
7. 点击「导出 Excel」保存核对报告

### 命令行

完整核对（原始花名册）：
```bash
python3 RosterChecker/verify_roster.py "Contact List.pdf" "花名册.xlsx"
```

仅英文名核对（飞书模版）：
```bash
python3 RosterChecker/verify_roster.py "Contact List.pdf" "通讯录-导出.xlsx" --english-only
```

加 `--json` 参数输出 JSON 格式：
```bash
python3 RosterChecker/verify_roster.py "Contact List.pdf" "花名册.xlsx" --json
```

## 核对规则

| 花名册字段 | 对照规则 |
|-----------|---------|
| `直拨电话/移动电话` | 优先对照 CL Direct Line；若无 → 对照 CL Mobile |
| `手机号码` | 对照 CL Mobile（CL 无值不报错） |
| `英文名` | 从邮箱前缀推导：去掉姓氏拼音后剩余部分；拼音长度 < 姓氏时不报错 |
| `工作邮箱` | 作为匹配键（忽略大小写） |

## 英文名推导逻辑

```
邮箱 prefix: johnguo → CL 姓氏: guo → john → 英文名: John
邮箱 prefix: sunqing → CL 姓氏: sun → 剩余 qing 比 sun 短 → 拼音，跳过
```

## 输出 Excel 结构

### 完整核对

- **Sheet 1「信息不一致」**：姓名、邮箱、部门、直拨电话(花名册)、直拨电话(CL)、手机(花名册)、手机(CL)、英文名(花名册)、英文名(预期)
- **Sheet 2「花名册独有(CL无)」**：花名册有但 ContactList 无的人员
- **Sheet 3「ContactList独有(花名册无)」**：ContactList 有但花名册无的人员

### 仅英文名核对

- **Sheet「英文名核对」**：姓名、邮箱、部门、英文名(Excel)、英文名(预期)
