import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data Models

struct ErrorItem: Codable, Identifiable {
    var id: String { email }
    let name: String
    let email: String
    let dept: String
    let dl_excel: String
    let dl_cl: String
    let mob_excel: String
    let mob_cl: String
    let en_excel: String
    let en_expected: String
}

struct RosterOnlyItem: Codable, Identifiable {
    var id: String { email }
    let name: String
    let email: String
    let dept: String
    let direct_line: String
    let mobile: String
}

struct CLOnlyItem: Codable, Identifiable {
    var id: String { email }
    let name: String
    let email: String
    let direct_line: String
    let mobile: String
}

struct VerifySummary: Codable {
    let cl_count: Int
    let roster_count: Int
    let error_count: Int
    let only_roster_count: Int
    let only_cl_count: Int
}

struct VerifyResult: Codable {
    let summary: VerifySummary
    let errors: [ErrorItem]
    let only_roster: [RosterOnlyItem]
    let only_cl: [CLOnlyItem]
}

enum VerifyState: Equatable {
    case idle
    case running
    case done
    case error(String)
}

// MARK: - ViewModel

class RosterViewModel: ObservableObject {
    @Published var pdfURL: URL?
    @Published var xlsxURL: URL?
    @Published var state: VerifyState = .idle
    @Published var result: VerifyResult?
    @Published var selectedTab = 0

    var canVerify: Bool { pdfURL != nil && xlsxURL != nil }

    func verify() {
        guard let pdf = pdfURL, let xlsx = xlsxURL else { return }
        state = .running

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let scriptPath = Bundle.main.path(forResource: "verify_roster", ofType: "py")!
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [scriptPath, pdf.path, xlsx.path, "--json"]
            process.currentDirectoryURL = FileManager.default.temporaryDirectory

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    if let jsonData = output.data(using: .utf8),
                       let result = try? JSONDecoder().decode(VerifyResult.self, from: jsonData) {
                        DispatchQueue.main.async {
                            self.result = result
                            self.state = .done
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.state = .error("解析结果失败")
                        }
                    }
                } else {
                    let errPipe = process.standardError as! Pipe
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8) ?? output
                    DispatchQueue.main.async {
                        self.state = .error(errMsg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func exportExcel() {
        guard let pdf = pdfURL, let xlsx = xlsxURL else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "导出核对结果"
        savePanel.nameFieldStringValue = "核对结果.xlsx"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!]

        savePanel.begin { response in
            guard response == .OK, let outputURL = savePanel.url else { return }

            let scriptPath = Bundle.main.path(forResource: "verify_roster", ofType: "py")!
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [scriptPath, pdf.path, xlsx.path, "--output", outputURL.path]

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                    }
                } catch { }
            }
        }
    }

    func selectPDF() {
        selectFile(title: "选择 Contact List PDF", types: [.pdf]) { [weak self] in
            self?.pdfURL = $0
        }
    }

    func selectXLSX() {
        selectFile(title: "选择花名册 Excel", types: [UTType(filenameExtension: "xlsx")!]) { [weak self] in
            self?.xlsxURL = $0
        }
    }

    private func selectFile(title: String, types: [UTType], handler: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            handler(response == .OK ? panel.url : nil)
        }
    }
}
