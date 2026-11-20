import SwiftUI

@main
struct Mbox2DriverHostApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Mbox 2 Driver")
                    .font(.title)

                Text("DriverKit host application")
                    .foregroundStyle(.secondary)

                Text("Driver activation will be added in a later stage.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(minWidth: 380, minHeight: 200)
        }
    }
}
