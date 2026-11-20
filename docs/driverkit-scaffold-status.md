# DriverKit scaffold status

**Updated:** 17 November 2026  
**Project target:** Original full-size Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`)  
**Status:** Minimal DriverKit scaffold source is published. An earlier version built and packaged successfully; the current interface-scoped revision requires a fresh build. Audio-device implementation and USB-audio feasibility remain unverified.

## Published scaffold

The minimal source scaffold is now published in the repository under `Driver/`, `Host/` and `Mbox2Driver.xcodeproj/`. The active personality is scoped to `IOUSBHostInterface` number 6, configuration 1, vendor `0x0dba`, product `0x3000`, class `0xff`, subclass 0 and protocol 0. This avoids matching the entire USB device and avoids targeting the audio interfaces currently used by Apple's audio service.

This is a matching configuration proposal, not proof that macOS will match or activate it safely. The service `Start` method currently only calls its superclass and logs startup; it does not open the interface or submit transfers.

## Earlier local build evidence

The local development working copy contains:

- A DriverKit extension target named `Mbox2Driver`.
- A minimal `IOService` implementation that calls the superclass start method and logs successful service startup.
- Driver personality metadata matching the original full-size Mbox 2 USB vendor and product identifiers.
- A macOS host-app target.
- An Xcode build phase that invokes Apple's IIG compiler and generates the driver interface header and dispatch implementation into the derived build directory.
- A host-app copy-files phase that embeds the extension in `Contents/Library/SystemExtensions`.

The initial successful build/package result was recorded before the interface-scoped matching refinement. The revised public project must be rebuilt before that result can be attributed to the current source.

## Confirmed progress

### Native build and packaging

- `xcodebuild -list` recognises both `Mbox2Driver` and `Mbox2DriverHost`.
- Standalone IIG generation was confirmed with `-D__IIG=1`.
- IIG generation is now integrated into the Xcode build.
- The DriverKit extension builds successfully for the DriverKit 27.2 SDK.
- The macOS host application builds successfully.
- The extension is embedded in the host app at `Contents/Library/SystemExtensions/Mbox2Driver.dext`.
- The packaged extension has a valid root `Info.plist`, a declared `CFBundleExecutable`, and an arm64 Mach-O executable.
- The earlier build's personality matched the whole device through `IOUSBHostDevice`. The current source instead proposes a narrower `IOUSBHostInterface` match for interface 6; that revised personality has not yet been built or runtime-tested.

### SDK API investigation

The active DriverKit 27.2 SDK contains both:

- `USBDriverKit.framework`, including `IOUSBHostDevice`, `IOUSBHostInterface` and `IOUSBHostPipe` APIs.
- `AudioDriverKit.framework`, including `IOUserAudioDriver`, `IOUserAudioDevice` and `IOUserAudioStream` declarations.

The AudioDriverKit framework is located under:

`System/DriverKit/System/Library/Frameworks/AudioDriverKit.framework`

It is not located at the initially checked SDK-root `System/Library/Frameworks` path. The macOS SDK is not the correct place to look for this DriverKit framework.

Header inspection confirmed declarations for audio-driver lifecycle methods such as `StartDevice` and `StopDevice`, audio-device I/O methods such as `StartIO` and `StopIO`, stream configuration methods, and USB device/interface operations.

## Current architectural question

The next design task is to establish the supported relationship between AudioDriverKit and USB hardware access for a USB audio interface.

Apple's general DriverKit documentation contains a restriction concerning USB devices that manipulate audio, while the AudioDriverKit documentation and sample describe hardware audio drivers communicating over USB or PCI. These statements need to be reconciled against the current SDK, the specific USB transport APIs, and required entitlements before choosing the implementation architecture.

The intended design under investigation is an AudioDriverKit audio driver/device layer together with a permitted hardware-communication path for the Mbox 2. This is a direction to validate, not an established supported architecture.

## What has not been demonstrated

At this checkpoint:

- The extension has not been signed with the required development identity and entitlements.
- Provisioning and DriverKit entitlement approval have not been established.
- The extension has not been installed, activated or loaded.
- The Mbox 2 has not been claimed by this new implementation.
- No firmware handshake has been implemented or tested by the new driver.
- No USB audio transfers or isochronous streaming have been implemented.
- No AudioDriverKit device, clock or stream has been implemented or published to Core Audio.
- Capture, playback, sample-rate switching and external clock operation have not been tested.

A successful build and embedding check do not establish runtime activation, USB ownership or working audio.

## Immediate next steps

1. Reconcile Apple's USB-audio restrictions with the AudioDriverKit hardware-communication model and identify the supported transport/entitlement combination.
2. Study the installed AudioDriverKit and USBDriverKit declarations and Apple's sample implementation in detail.
3. Design the smallest AudioDriverKit driver/device structure that can be built without claiming unverified USB functionality.
4. Determine signing, provisioning and entitlement requirements before attempting activation.
5. Only then implement and test Mbox 2 USB matching, firmware initialisation and transport when the hardware is available.

## Architectural direction under investigation

The intended functional separation remains:

1. **Hardware communication:** permitted device matching, descriptors, interfaces, alternate settings, pipes and transfers.
2. **Mbox 2 protocol:** firmware readiness, vendor control requests, clock and device-specific behaviour.
3. **Audio publication:** AudioDriverKit driver, device, clock and stream objects for Core Audio.
4. **Host/configuration app:** system-extension activation and later user-facing status/configuration.

Only the minimal service scaffold and host-app packaging have been built. The remaining layers are future work, not implemented capabilities.

## Evidence discipline

A project file being present is not evidence of a successful build. A successful build does not prove extension activation or device ownership. USB detection does not prove firmware readiness, clock lock or audio streaming. Each milestone must be validated separately and documented with its actual test result.
