import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotKeyCenter: HotKeyCenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Cap launched, version \(AppInfo.version, privacy: .public)")
        menuBarController = MenuBarController()

        let hotKeyCenter = HotKeyCenter()
        hotKeyCenter.onTrigger = {
            Log.app.notice("⌘⇧2 action fired")
        }
        if !hotKeyCenter.register() {
            Log.app.error("Failed to register ⌘⇧2")
        }
        self.hotKeyCenter = hotKeyCenter
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyCenter?.unregister()
        Log.app.info("Cap terminating")
    }
}
