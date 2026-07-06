import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data Models
struct ErrorItem: Codable, Identifiable {
    var id: String { email }
    let name: String; let email: String; let dept: String
    let dl_excel: String; let dl_cl: String
    let mob_excel: String; let mob_cl: String
    let en_excel: String; let en_expected: String
}
struct RosterOnlyItem: Codable, Identifiable {
    var id: String { email }
    let name: String; let email: String; let dept: String
    let direct_line: String; let mobile: String
}
struct CLOnlyItem: Codable, Identifiable {
    var id: String { email }
    let name: String; let email: String
    let direct_line: String; let mobile: String
}
struct VerifySummary: Codable {
    let cl_count: Int; let roster_count: Int
    let error_count: Int; let only_roster_count: Int; let only_cl_count: Int
}
struct VerifyResult: Codable {
    let summary: VerifySummary
    let errors: [ErrorItem]; let only_roster: [RosterOnlyItem]; let only_cl: [CLOnlyItem]
}
enum VerifyMode { case full, englishOnly }

enum VerifyState: Equatable {
    case idle; case running; case done; case error(String)
}

// MARK: - ViewModel
class RosterViewModel: ObservableObject {
    @Published var pdfURL: URL?; @Published var xlsxURL: URL?
    @Published var state: VerifyState = .idle
    @Published var result: VerifyResult?; @Published var selectedTab = 0
    @Published var verifyMode: VerifyMode = .full
    var canVerify: Bool { pdfURL != nil && xlsxURL != nil }

    func findPython() -> String? {
        for c in ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
            if FileManager.default.isExecutableFile(atPath: c) { return c }
        }
        return nil
    }

    func verify() {
        guard let pdf = pdfURL, let xlsx = xlsxURL, let python = findPython() else {
            state = .error("找不到 Python3，请确保已安装: brew install python3"); return
        }
        state = .running

        // Write embedded script to temp file
        let tmpDir = FileManager.default.temporaryDirectory
        let scriptURL = tmpDir.appendingPathComponent("verify_roster.py")
        do {
            try EmbeddedScript.verifyRosterPy.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            state = .error("写入脚本失败: \(error.localizedDescription)"); return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = [scriptURL.path, pdf.path, xlsx.path, "--json"] + (["--english-only"] if self.verifyMode == .englishOnly else [])
            process.currentDirectoryURL = pdf.deletingLastPathComponent()
            let outPipe = Pipe(); let errPipe = Pipe()
            process.standardOutput = outPipe; process.standardError = errPipe

            do {
                try process.run(); process.waitUntilExit()
                let outStr = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    if let data = outStr.data(using: .utf8),
                       let res = try? JSONDecoder().decode(VerifyResult.self, from: data) {
                        DispatchQueue.main.async { self.result = res; self.state = .done }
                    } else {
                        DispatchQueue.main.async {
                            self.state = .error("JSON 解析失败\n\(outStr.prefix(300))")
                        }
                    }
                } else {
                    let msg = errStr.isEmpty ? outStr : errStr
                    DispatchQueue.main.async {
                        self.state = .error("脚本错误 (exit \(process.terminationStatus))\n\(msg.prefix(400))")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .error("启动 Python 失败: \(error.localizedDescription)")
                }
            }
        }
    }

    func exportExcel() {
        guard let pdf = pdfURL, let xlsx = xlsxURL, let python = findPython() else { return }
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "核对结果.xlsx"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!]
        savePanel.begin { response in
            guard response == .OK, let out = savePanel.url else { return }
            let tmpDir = FileManager.default.temporaryDirectory
            let scriptURL = tmpDir.appendingPathComponent("verify_roster.py")
            try? EmbeddedScript.verifyRosterPy.write(to: scriptURL, atomically: true, encoding: .utf8)
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: python)
                p.arguments = [scriptURL.path, pdf.path, xlsx.path, "--output", out.path]
                do { try p.run(); p.waitUntilExit()
                    if p.terminationStatus == 0 { NSWorkspace.shared.activateFileViewerSelecting([out]) }
                } catch {}
            }
        }
    }

    func selectPDF() { pickFile("选择 Contact List PDF", [.pdf]) { [weak self] in self?.pdfURL = $0 } }
    func selectXLSX() { pickFile("选择花名册 Excel", [UTType(filenameExtension: "xlsx")!]) { [weak self] in self?.xlsxURL = $0 } }
    private func pickFile(_ title: String, _ types: [UTType], handler: @escaping (URL?) -> Void) {
        let p = NSOpenPanel(); p.title = title; p.allowedContentTypes = types
        p.allowsMultipleSelection = false; p.canChooseDirectories = false
        p.begin { handler($0 == .OK ? p.url : nil) }
    }
}
