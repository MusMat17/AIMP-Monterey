import AppKit
import Foundation

/// macOS 12 Intel entry point. Log is created BEFORE spawning Bash/Wine.
/// This captures launch failures that previously left no launcher.log.
@main
struct AIMPMontereyLauncher {
    static var progressWindow: NSWindow?
    static var monitor: Timer?

    static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/AIMP Monterey/launcher.log")

    static func log(_ message: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: logURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true, attributes: nil)
        let line = "[native] \(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        if !fm.fileExists(atPath: logURL.path) {
            fm.createFile(atPath: logURL.path, contents: Data(), attributes: nil)
        }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) { handle.write(data) }
            handle.closeFile()
        }
    }

    static func main() {
        log("AIMP Monterey native entry point started. OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        guard let script = Bundle.main.path(forResource: "launch-standalone", ofType: "sh") else {
            log("ERROR: launch-standalone.sh missing from Contents/Resources")
            showError("Внутри приложения отсутствует скрипт запуска.", details: nil)
            return
        }
        log("Launch script found: \(script)")

        let appExe = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AIMP Monterey/AIMP/AIMP.exe")
        if !FileManager.default.fileExists(atPath: appExe.path) {
            showProgress()
            monitor = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if FileManager.default.fileExists(atPath: appExe.path) {
                    dismissProgress()
                }
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script] + Array(CommandLine.arguments.dropFirst())

        // Capture shell stderr even when Bash exits before its own log initialization.
        let stderrHandle = try? FileHandle(forWritingTo: logURL)
        stderrHandle?.seekToEndOfFile()
        if let stderrHandle = stderrHandle {
            process.standardError = stderrHandle
        }

        process.terminationHandler = { finished in
            DispatchQueue.main.async {
                stderrHandle?.closeFile()
                dismissProgress()
                log("Launcher exited with status \(finished.terminationStatus), reason \(finished.terminationReason.rawValue)")
                if finished.terminationStatus != 0 {
                    let message = "Не удалось запустить AIMP (код \(finished.terminationStatus))."
                    showError(message, details: lastLogLines())
                }
                NSApp.terminate(nil)
            }
        }

        do {
            try process.run()
            log("Bash child process started, PID \(process.processIdentifier)")
            app.run()
        } catch {
            stderrHandle?.closeFile()
            dismissProgress()
            log("ERROR: unable to start /bin/bash: \(error.localizedDescription)")
            showError("Ошибка запуска: \(error.localizedDescription)", details: nil)
        }
    }

    static func lastLogLines() -> String {
        guard let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
            return "(Не удалось прочитать журнал)"
        }
        return contents.components(separatedBy: .newlines).suffix(14).joined(separator: "\n")
    }

    static func showProgress() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 132),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "AIMP Monterey"
        window.center()
        window.isReleasedWhenClosed = false

        let spinner = NSProgressIndicator(frame: NSRect(x: 23, y: 44, width: 32, height: 32))
        spinner.style = .spinning
        spinner.startAnimation(nil)

        let title = NSTextField(labelWithString: "Подготовка AIMP к первому запуску…")
        title.frame = NSRect(x: 74, y: 58, width: 350, height: 22)
        title.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        let hint = NSTextField(labelWithString: "Загружается оригинальная версия с aimp.ru")
        hint.frame = NSRect(x: 74, y: 32, width: 345, height: 22)
        hint.textColor = .secondaryLabelColor

        window.contentView?.addSubview(spinner)
        window.contentView?.addSubview(title)
        window.contentView?.addSubview(hint)
        progressWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    static func dismissProgress() {
        monitor?.invalidate()
        monitor = nil
        progressWindow?.orderOut(nil)
        progressWindow = nil
    }

    static func showError(_ message: String, details: String?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "AIMP Monterey — ошибка запуска"
        alert.informativeText = message + "\n\nЖурнал: " + logURL.path +
            "\nНажми «Скопировать отчёт» и пришли текст в чат."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Скопировать отчёт")
        alert.addButton(withTitle: "Закрыть")
        if alert.runModal() == .alertFirstButtonReturn {
            let report = "AIMP Monterey diagnostic report\n" +
                "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n" +
                "Error: \(message)\nLog path: \(logURL.path)\n" +
                (details ?? lastLogLines())
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report, forType: .string)
        }
    }
}
