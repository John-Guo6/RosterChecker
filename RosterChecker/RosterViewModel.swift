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
    let errors: [ErrorItem]
    let only_roster: [RosterOnlyItem]
    let only_cl: [CLOnlyItem]
}

enum VerifyState: Equatable {
    case idle; case running; case done; case error(String)
}

// MARK: - ViewModel

class RosterViewModel: ObservableObject {
    @Published var pdfURL: URL?
    @Published var xlsxURL: URL?
    @Published var state: VerifyState = .idle
    @Published var result: VerifyResult?
    @Published var selectedTab = 0

    var canVerify: Bool { pdfURL != nil && xlsxURL != nil }

    func findScript() -> String? {
        if let path = Bundle.main.path(forResource: "verify_roster", ofType: "py"),
           FileManager.default.fileExists(atPath: path) { return path }
        let srcPath = "/Users/guozikang/Desktop/国富量子创新有限公司/花名册核对/花名册核对程序/RosterChecker/verify_roster.py"
        if FileManager.default.fileExists(atPath: srcPath) { return srcPath }
        return nil
    }

    func findPython() -> String? {
        let candidates = ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]
        for c in candidates {
            if FileManager.default.isExecutableFile(atPath: c) { return c }
        }
        return "/usr/bin/env python3"
    }

    func verify() {
        guard let pdf = pdfURL, let xlsx = xlsxURL else { return }
        state = .running

        guard let scriptPath = findScript() else {
            state = .error("找不到 verify_roster.py 脚本"); return
        }

        let pythonPath = findPython()!

        // Log for debugging
        print("[RosterChecker] Python: \(pythonPath)")
        print("[RosterChecker] Script: \(scriptPath)")
        print("[RosterChecker] PDF: \(pdf.path)")
        print("[RosterChecker] XLSX: \(xlsx.path)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath, pdf.path, xlsx.path, "--json"]
            process.currentDirectoryURL = pdf.deletingLastPathComponent()

            let outPipe = Pipe(); let errPipe = Pipe()
            process.standardOutput = outPipe; process.standardError = errPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""
                let errMsg = String(data: errData, encoding: .utf8) ?? ""

                print("[RosterChecker] Exit code: \(process.terminationStatus)")
                if !errMsg.isEmpty { print("[RosterChecker] Stderr: \(errMsg.prefix(300))") }
                if !output.isEmpty { print("[RosterChecker] Stdout: \(output.prefix(200))") }

                if process.terminationStatus == 0 {
                    if let jsonData = output.data(using: .utf8),
                       let res = try? JSONDecoder().decode(VerifyResult.self, from: jsonData) {
                        DispatchQueue.main.async { self.result = res; self.state = .done }
                    } else {
                        DispatchQueue.main.async {
                            self.state = .error("JSON 解析失败\n前200字符: \(String(output.prefix(200)))")
                        }
                    }
                } else {
                    let detail = errMsg.isEmpty ? output : errMsg
                    DispatchQueue.main.async {
                        self.state = .error("脚本错误 (exit \(process.terminationStatus))\n\(detail.prefix(300))")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .error("启动失败: \(error.localizedDescription)")
                }
            }
        }
    }

    func exportExcel() {
        guard let pdf = pdfURL, let xlsx = xlsxURL,
              let scriptPath = findScript() else { return }
        let savePanel = NSSavePanel()
        savePanel.title = "导出核对结果"
        savePanel.nameFieldStringValue = "核对结果.xlsx"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!]
        savePanel.begin { response in
            guard response == .OK, let out = savePanel.url else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: self.findPython()!)
                p.arguments = [scriptPath, pdf.path, xlsx.path, "--output", out.path]
                do { try p.run(); p.waitUntilExit()
                    if p.terminationStatus == 0 { NSWorkspace.shared.activateFileViewerSelecting([out]) }
                } catch {}
            }
        }
    }

    func selectPDF() {
        selectFile(title: "选择 Contact List PDF", types: [.pdf]) { [weak self] in self?.pdfURL = $0 }
    }
    func selectXLSX() {
        selectFile(title: "选择花名册 Excel", types: [UTType(filenameExtension: "xlsx")!]) { [weak self] in self?.xlsxURL = $0 }
    }
    private func selectFile(title: String, types: [UTType], handler: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = title; panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.begin { response in handler(response == .OK ? panel.url : nil) }
    }
}
