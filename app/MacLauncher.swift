import AppKit
import Foundation

/// Finder-friendly native entry point. The actual AIMP player runs in bundled Wine.
/// The launcher has no install prerequisite and no Terminal window.
@main
struct AIMPMontereyLauncher {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        guard let script = Bundle.main.path(forResource: "launch-standalone", ofType: "sh") else {
            showError("Не найден встроенный скрипт запуска.")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script] + Array(CommandLine.arguments.dropFirst())
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                showError("AIMP не запустился. Диагностика: ~/Library/Logs/AIMP Monterey/launcher.log")
            }
        } catch {
            showError("Ошибка запуска AIMP: \(error.localizedDescription)")
        }
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
