# DriverKit scaffold status

**Updated:** 16 November 2026  
**Project target:** Original full-size Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`)  
**Status:** Xcode project discovery confirmed; standalone IIG generation confirmed; native DriverKit build integration still pending.

## What exists locally

The initial implementation scaffold has been created in the development working copy:

- A DriverKit extension target named `Mbox2Driver`.
- A minimal service implementation that calls the superclass start method and logs successful service startup.
- Driver personality metadata matching the original full-size Mbox 2 USB vendor and product identifiers.
- A small macOS host-app target intended to become the host for the system extension.
- A hand-authored Xcode project file joining the initial targets.

These files are local working material at this checkpoint. They have not yet been committed as driver source to the public repository.

## Confirmed progress

The hand-authored project configuration-list references have been corrected. `xcodebuild -list -project Mbox2Driver.xcodeproj` now succeeds and recognises both `Mbox2Driver` and `Mbox2DriverHost`, with Debug and Release configurations.

A first native DriverKit build was attempted. It reached C++ compilation but stopped because `Mbox2Driver.h` had not been generated or made available to the compiler. This exposed the next integration task: connect Apple's IIG compiler to the Xcode build.

The IIG compiler has now been run successfully as a standalone diagnostic against the project's `.iig` definition. The required invocation includes `-D__IIG=1`; without that define, DriverKit's IIG headers do not parse correctly. The compiler generated both the class header and dispatch implementation. This confirms the definition can be processed, but does not yet prove that Xcode invokes IIG or compiles its generated implementation as part of a native build.

## Current blocker

Automatic IIG generation and compilation are not yet integrated into the Xcode target. The next local change is to add a build phase that generates the header and implementation into Xcode's Derived Sources directory, then make those outputs available to the driver compilation.

## What has not been demonstrated

At this checkpoint:

- A complete native DriverKit build has not succeeded.
- Xcode's automatic IIG generation and generated-source compilation have not yet been validated.
- The host app does not yet have a verified extension-embedding and activation workflow.
- The host app does not yet have a verified extension-embedding and activation workflow.
- Signing, provisioning and DriverKit entitlement approval have not been established.
- The extension has not been installed, activated or loaded.
- The Mbox 2 has not been claimed by this new implementation.
- No firmware handshake, USB audio transport, AudioDriverKit publication, capture or playback has been tested.

## Immediate next steps

1. Integrate the confirmed IIG compiler invocation into the DriverKit target's build phases.
2. Run a clean native DriverKit build and resolve any remaining compiler, framework or packaging errors.
3. Add the host-app dependency and system-extension embedding structure.
5. Establish signing, provisioning and entitlement requirements before any activation attempt.
6. Keep USB protocol and audio work behind the verified project/build foundation.

## Architectural direction

The intended separation remains:

1. **USB transport:** device matching, descriptors, interfaces, alternate settings, pipes and isochronous transfers.
2. **Mbox 2 protocol:** firmware readiness, vendor control requests, clock and device-specific behaviour.
3. **Audio publication:** AudioDriverKit device, clock and stream objects for Core Audio.
4. **Host/configuration app:** system-extension activation and later user-facing status/configuration.

Only the first, minimal service scaffold has been started. The remaining layers are future work, not implemented capabilities.

## Evidence discipline

A project file being present is not evidence of a successful build. A successful build would not prove extension activation or device ownership. USB detection would not prove firmware readiness, clock lock or audio streaming. Each milestone must be validated separately and documented with its actual test result.
