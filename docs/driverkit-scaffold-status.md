# DriverKit scaffold status

**Updated:** 15 November 2026  
**Project target:** Original full-size Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`)  
**Status:** Initial local project scaffold authored; Xcode project validation not yet successful.

## What exists locally

The initial implementation scaffold has been created in the development working copy:

- A DriverKit extension target named `Mbox2Driver`.
- A minimal service implementation that calls the superclass start method and logs successful service startup.
- Driver personality metadata matching the original full-size Mbox 2 USB vendor and product identifiers.
- A small macOS host-app target intended to become the host for the system extension.
- A hand-authored Xcode project file joining the initial targets.

These files are local working material at this checkpoint. They have not yet been committed as driver source to the public repository.

## Current blocker

The first `xcodebuild -list` attempt caused Xcode to terminate with an internal project-model assertion:

```
owner should conform to protocol XCBuildConfigurationOwners
```

Inspection identified the immediate structural error: the Driver and Host `PBXNativeTarget` objects point directly to `XCBuildConfiguration` objects instead of their corresponding `XCConfigurationList` objects.

The correct configuration-list references have been identified:

- Driver target → its Driver configuration list.
- Host target → its Host configuration list.

The corrective edit has been prepared as the next local step, but it has not yet been executed or verified. No conclusion should be drawn about source compilation from this project-model failure.

## What has not been demonstrated

At this checkpoint:

- Xcode has not successfully listed the project targets.
- The DriverKit extension has not been built.
- The IIG-generated interface and native build integration have not been validated by a project build.
- The host app does not yet have a verified extension-embedding and activation workflow.
- Signing, provisioning and DriverKit entitlement approval have not been established.
- The extension has not been installed, activated or loaded.
- The Mbox 2 has not been claimed by this new implementation.
- No firmware handshake, USB audio transport, AudioDriverKit publication, capture or playback has been tested.

## Immediate next steps

1. Correct the two target configuration-list references in the Xcode project.
2. Re-run `xcodebuild -list` and confirm that both targets are recognised.
3. Attempt a native build and address errors from the actual Xcode build system, including IIG processing.
4. Add the host-app dependency and system-extension embedding structure.
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
