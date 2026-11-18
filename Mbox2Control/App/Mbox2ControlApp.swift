
import SwiftUI

@main
struct Mbox2ControlApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .toolbar(.hidden)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About mBox 2 Control") {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                }
            }
        }
    }
}
