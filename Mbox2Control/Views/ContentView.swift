import SwiftUI
import AppKit

struct ContentView: View {

    @State private var device = Mbox2Device()

    // MARK: - Hardware Image

    private var mboxImage: NSImage? {
        let url =
            Bundle.main.url(forResource: "Mbox2", withExtension: "png")
            ?? Bundle.main.url(
                forResource: "Mbox2",
                withExtension: "png",
                subdirectory: "Resources"
            )

        guard let url else { return nil }
        return NSImage(contentsOf: url)
    }

    // MARK: - Main Window

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hardwarePanel

                    HStack(alignment: .top, spacing: 16) {
                        audioPanel
                        clockPanel
                    }

                    diagnosticsPanel
                }
                .padding(24)
            }

            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Hardware

    private var hardwarePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(
                "Hardware",
                subtitle: "Connected audio interface"
            )

            HStack(spacing: 18) {
                Group {
                    if let image = mboxImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "waveform")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 176, height: 100)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 7) {
                    Text(device.identity.name)
                        .font(.title3.weight(.semibold))

                    Text("USB Audio Interface")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    statusIndicator(
                        title: "Connection",
                        state: device.connectionState.rawValue,
                        color: connectionColor
                    )

                    statusIndicator(
                        title: "USB Interface",
                        state: device.usbState.rawValue,
                        color: usbColor
                    )

                    statusIndicator(
                        title: "Driver",
                        state: device.driverState.rawValue,
                        color: driverColor
                    )
                }
            }

            Divider()

            HStack {
                Button {
                    device.checkUSBConnection()
                } label: {
                    Label("Check USB Connection", systemImage: "cable.connector")
                }

                Spacer()
            }

            Text(device.usbCheckMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(panelBackground)
    }

    // MARK: - Audio Configuration

    private var audioPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading(
                "Audio Configuration",
                subtitle: "Hardware operating format"
            )

            Picker("", selection: $device.selectedSampleRate) {
                ForEach(Mbox2SampleRate.allCases, id: \.self) { rate in
                    Text(rate.rawValue).tag(rate)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Picker("", selection: $device.selectedBitDepth) {
                ForEach(Mbox2BitDepth.allCases, id: \.self) { depth in
                    Text(depth.rawValue).tag(depth)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text("Preview controls only. Hardware changes are not yet available.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    // MARK: - Clock Configuration

    private var clockPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading(
                "Clock Source",
                subtitle: "Digital synchronisation"
            )

            Picker("", selection: $device.selectedClockSource) {
                ForEach(Mbox2ClockSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("S/PDIF Lock")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 9) {
                    Circle()
                        .fill(spdifColor)
                        .frame(width: 10, height: 10)

                    Text(device.spdifState.rawValue)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                Text("Digital input synchronisation status will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Preview controls only.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    // MARK: - Diagnostics

    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                "Device Diagnostics",
                subtitle: "Hardware and driver information"
            )

            diagnosticRow("Device", value: device.identity.name)

            diagnosticRow(
                "Driver Version",
                value: device.driverState == .notInstalled
                    ? "Not installed"
                    : "Unknown"
            )

            diagnosticRow(
                "Firmware",
                value: device.firmwareVersion ?? device.firmwareState.rawValue
            )
        }
        .padding(18)
        .background(panelBackground)
    }

    // MARK: - Status Colours

    private var connectionColor: Color {
        switch device.connectionState {
        case .detected:
            return .green
        case .notDetected:
            return .secondary
        case .unavailable:
            return .orange
        }
    }

    private var usbColor: Color {
        switch device.usbState {
        case .interfaceInitialised, .communicating:
            return .green
        case .notCommunicating:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private var driverColor: Color {
        switch device.driverState {
        case .installed:
            return .green
        case .inactive, .notInstalled:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private var spdifColor: Color {
        switch device.spdifState {
        case .locked:
            return .green
        case .unlocked:
            return .orange
        case .unknown, .unavailable:
            return .secondary
        }
    }

    // MARK: - Reusable Components

    private var panelBackground: some ShapeStyle {
        Color.primary.opacity(0.035)
    }

    private func sectionHeading(
        _ title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusIndicator(
        title: String,
        state: String,
        color: Color
    ) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)

                Text(state)
                    .font(.caption.weight(.medium))
            }
        }
    }

    private func diagnosticRow(
        _ title: String,
        value: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
        .font(.subheadline)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()

            Text("Development Build · 0.1")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
