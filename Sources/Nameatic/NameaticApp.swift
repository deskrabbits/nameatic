import SwiftUI
import AppKit
import Sparkle

@main
struct NameaticApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private var store = BatchStore.shared
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    var body: some Scene {
        Window("Nameatic", id: "main") {
            RootView()
                .environment(store)
                .onOpenURL { store.add(urls: [$0]) }
        }
        .handlesExternalEvents(matching: ["*"])
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 840, height: 410)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

/// Files arrive here from Finder ("Open With", Dock drops) and from
/// command-line arguments, which AppKit converts to open-file events.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        BatchStore.shared.add(urls: urls)
    }

    @MainActor
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename).standardizedFileURL
        guard BatchStore.isVideo(url) else { return false }
        BatchStore.shared.add(urls: [url])
        return true
    }
}
