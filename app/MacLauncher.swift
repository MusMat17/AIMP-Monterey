import AppKit
import Foundation

/// Intel macOS 12 native launch shim for a bundled Wine application.
/// No user-visible Terminal or separate Wine installation required.
@main
struct AIMPMontereyLauncher {
    static var progressWindow: NSWindow?
    static var monitor: Timer?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        guard let launch = Bundle.main.path(forResource: "launch-standalone", ofType: "sh") else {
            showError("Файл запуска отсутствует в приложении.")
            return
        }

        let userData = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AIMP Monterey/AIMP/AIMP.exe")
        let firstLaunch = !FileManager.default.fileExists(atPath: userData.path)
        if firstLaunch {
            showProgress()
            monitor = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if FileManager.default.fileExists(atPath: userData.path) {
                    dismissProgress()
                }
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [launch] + Array(CommandLine.arguments.dropFirst())
        process.terminationHandler = { finished in
            DispatchQueue.main.async {
                dismissProgress()
                if finished.terminationStatus != 0 {
                    showError("AIMP не запустился. Отчёт находится в ~/Library/Logs/AIMP Monterey/launcher.log")
                }
                NSApp.terminate(nil)
            }
        }

        do {
            try process.run()
            app.run()
        } catch {
            dismissProgress()
            showError("Ошибка запуска: \(error.localizedDescription)")
        }
    }

    static func showProgress() {
        let rect = NSRect(x: 0, y: 0, width: 410, height: 125)
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "AIMP Monterey"
        window.center()
        window.isReleasedWhenClosed = false

        let spinner = NSProgressIndicator(frame: NSRect(x: 24, y: 42, width: 30, height: 30))
        spinner.style = .spinning
        spinner.startAnimation(nil)

        let title = NSTextField(labelWithString: "Подготовка AIMP к первому запуску…")
        title.frame = NSRect(x: 72, y: 55, width: 320, height: 22)
        title.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        let details = NSTextField(labelWithString: "Загружается оригинальный плеер с aimp.ru")
        details.frame = NSRect(x: 72, y: 30, width: 320, height: 20)
        details.textColor = .secondaryLabelColor

        window.contentView?.addSubview(spinner)
        window.contentView?.addSubview(title)
        window.contentView?.addSubview(details)
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

    static func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "AIMP Monterey"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
