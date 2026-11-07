import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Cap launched, version \(AppInfo.version, privacy: .public)")
        menuBarController = MenuBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.info("Cap terminating")
    }
}
