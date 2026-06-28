# 花名册核对

一个 macOS App，用于将公司花名册（Excel）与 Contact List（PDF）进行自动比对，找出信息不一致之处。

## 功能

- 以 Contact List PDF 为答案基准，逐人比对手机号、直拨电话
- 自动识别号码格式差异（横线、空格、国家区号、深圳分机号等）
- 直拨电话优先对照 Direct Line，若无则对照 Mobile
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

1. 用 Xcode 打开 `RosterChecker.xcodeproj`
2. 按 `⌘R` 运行
3. 选择 Contact List PDF 和花名册 Excel
4. 点击「开始核对」
5. 查看结果，可切换 Tab 查看不同类别
6. 点击「导出 Excel」保存核对报告

## 也可单独使用命令行脚本

```bash
python3 RosterChecker/verify_roster.py "Contact List.pdf" "花名册.xlsx"
```

加 `--json` 参数输出 JSON 格式：

```bash
python3 RosterChecker/verify_roster.py "Contact List.pdf" "花名册.xlsx" --json
```

## 核对规则

| 花名册字段 | 对照规则 |
|-----------|---------|
| `直拨电话/移动电话` | 优先对照 CL 的 Direct Line；若无 Direct Line → 对照 CL 的 Mobile |
| `手机号码` | 对照 CL 的 Mobile |
| `工作邮箱` | 作为匹配键（忽略大小写） |

## 输出 Excel 结构

- **Sheet 1「信息不一致」**：姓名、邮箱、部门、直拨电话(花名册)、直拨电话(CL)、手机(花名册)、手机(CL)
- **Sheet 2「花名册独有(CL无)」**：花名册有但 ContactList 无的人员
- **Sheet 3「ContactList独有(花名册无)」**：ContactList 有但花名册无的人员
