import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var vm: RosterViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            bodyContent
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    var bodyContent: some View {
        switch vm.state {
        case .idle:
            fileSelectionView
        case .running:
            Spacer()
            ProgressView("正在核对中...")
                .scaleEffect(1.2)
            Spacer()
        case .done:
            resultView
        case .error(let msg):
            errorView(msg)
        }
    }

    var headerView: some View {
        HStack {
            Image(systemName: "person.2.badge.gearshape")
                .font(.title2).foregroundColor(.blue)
            Text("花名册核对").font(.title2.bold())
            Spacer()
            if vm.state == .done {
                Button(action: { vm.exportExcel() }) {
                    Label("导出 Excel", systemImage: "square.and.arrow.up")
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    var fileSelectionView: some View {
        VStack(spacing: 24) {
            Spacer()
            Picker("核对模式", selection: $vm.verifyMode) {
                Text("完整核对").tag(VerifyMode.full)
                Text("仅英文名").tag(VerifyMode.englishOnly)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .padding(.bottom, 8)

            Text("选择文件开始核对").font(.title3).foregroundColor(.secondary)
            HStack(spacing: 40) {
                fileCard(title: "Contact List (PDF)", icon: "doc.richtext",
                         url: vm.pdfURL, action: { vm.selectPDF() })
                fileCard(title: "花名册 (Excel)", icon: "tablecells",
                         url: vm.xlsxURL, action: { vm.selectXLSX() })
            }
            Button(action: { vm.verify() }) {
                Label("开始核对", systemImage: "checkmark.circle").frame(width: 160)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).disabled(!vm.canVerify)
            Spacer()
        }.padding(20)
    }

    func fileCard(title: String, icon: String, url: URL?, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: url != nil ? "doc.fill" : icon)
                .font(.system(size: 40)).foregroundColor(url != nil ? .blue : .gray)
            Text(title).font(.headline)
            if let u = url {
                Text(u.lastPathComponent).font(.caption).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle).frame(maxWidth: 200)
            }
            Button(url != nil ? "重新选择" : "选择文件", action: action)
                .buttonStyle(.bordered).controlSize(.small)
        }
        .frame(width: 220, height: 180)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40)).foregroundColor(.orange)
            Text("核对失败").font(.title2.bold()).foregroundColor(.red)
            Text(msg).font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 500)
            Button("重试") { vm.state = .idle; vm.result = nil }.buttonStyle(.bordered)
            Spacer()
        }.padding(20)
    }

    var resultView: some View {
        VStack(spacing: 0) {
            if let r = vm.result {
                summaryBar(r.summary)
                Divider()
                Picker("", selection: $vm.selectedTab) {
                    Text("信息不一致 (\(r.summary.error_count))").tag(0)
                    Text("花名册独有 (\(r.summary.only_roster_count))").tag(1)
                    Text("ContactList独有 (\(r.summary.only_cl_count))").tag(2)
                }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 8)
                Group {
                    if vm.selectedTab == 0 { errorsTable(r.errors) }
                    else if vm.selectedTab == 1 { rosterOnlyTable(r.only_roster) }
                    else { clOnlyTable(r.only_cl) }
                }
            }
        }
    }

    func summaryBar(_ s: VerifySummary) -> some View {
        HStack(spacing: 30) {
            chip("ContactList", "\(s.cl_count)人", .blue)
            chip("花名册", "\(s.roster_count)人", .green)
            chip("差异", "\(s.error_count)处", s.error_count > 0 ? .red : .green)
            chip("花名册独有", "\(s.only_roster_count)人", .orange)
            chip("CL独有", "\(s.only_cl_count)人", .purple)
        }.padding(.horizontal, 20).padding(.vertical, 10)
    }

    func chip(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.caption.bold())
        }
    }

    func errorsTable(_ items: [ErrorItem]) -> some View {
        VStack(spacing: 0) {
            tableHeaderRow(["姓名", "部门", "直拨电话(花名册)", "直拨电话(CL)", "手机(花名册)", "手机(CL)", "英文名(花名册)", "英文名(预期)"])
            Divider()
            if items.isEmpty {
                emptyText("没有信息不一致的人员 ✓")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            dataRow([item.name, item.dept, item.dl_excel, item.dl_cl, item.mob_excel, item.mob_cl, item.en_excel, item.en_expected], highlight: true)
                        }
                    }
                }
            }
        }
    }

    func rosterOnlyTable(_ items: [RosterOnlyItem]) -> some View {
        VStack(spacing: 0) {
            tableHeaderRow(["姓名", "部门", "直拨电话", "手机号码"])
            Divider()
            if items.isEmpty { emptyText("没有花名册独有的人员 ✓") }
            else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            dataRow([item.name, item.dept, item.direct_line, item.mobile])
                        }
                    }
                }
            }
        }
    }

    func clOnlyTable(_ items: [CLOnlyItem]) -> some View {
        VStack(spacing: 0) {
            tableHeaderRow(["姓名(英文)", "邮箱", "直拨电话(CL)", "手机(CL)"])
            Divider()
            if items.isEmpty { emptyText("没有 ContactList 独有的人员 ✓") }
            else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            dataRow([item.name, item.email, item.direct_line, item.mobile])
                        }
                    }
                }
            }
        }
    }

    func tableHeaderRow(_ cols: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cols.enumerated()), id: \.offset) { i, col in
                Text(col).font(.caption.bold())
                    .frame(maxWidth: i == 0 ? nil : .infinity, alignment: .leading)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                if i != cols.count - 1 { Divider() }
            }
        }.background(Color(nsColor: .controlBackgroundColor))
    }

    func dataRow(_ cols: [String], highlight: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(cols.enumerated()), id: \.offset) { i, val in
                    HStack {
                        Text(val.isEmpty ? "-" : val)
                            .font(.caption)
                            .foregroundColor(highlight && !val.isEmpty && (i >= 3 && i <= 5 || i == 7) ? .red : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    if i != cols.count - 1 { Divider() }
                }
            }
            Divider()
        }
    }

    func emptyText(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text).font(.caption).foregroundColor(.secondary).padding(.vertical, 20)
            Spacer()
        }
    }
}
