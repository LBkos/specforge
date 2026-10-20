import AppKit
import SwiftUI

@main
struct SpecForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1060, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1240, height: 840)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            SpecForgeCommands()
        }
    }
}

struct AppModelFocusedValueKey: FocusedValueKey {
    typealias Value = AppModel
}

extension FocusedValues {
    var appModel: AppModel? {
        get { self[AppModelFocusedValueKey.self] }
        set { self[AppModelFocusedValueKey.self] = newValue }
    }
}

struct SpecForgeCommands: Commands {
    @FocusedValue(\.appModel) private var model

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Specification…") {
                model?.openSpecificationFile()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(model == nil)

            Button("Load Example") {
                model?.loadExample()
            }
            .disabled(model == nil)

            Divider()

            Button("Generate Swift Client") {
                model?.generate()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(model == nil)

            Button("Export Swift Package…") {
                model?.export()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(model == nil)

            Divider()

            Button("Back to Specification") {
                model?.goToInput()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(model == nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(red: 0.040, green: 0.043, blue: 0.055, alpha: 1)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
