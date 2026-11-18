# DriverKit prototype preparation

**Status:** Preparation only — no DriverKit source, build, activation or hardware claim has been completed.
**Target:** Original full-size Digidesign Mbox 2, USB VID `0x0dba`, PID `0x3000`.
**Target Mac:** Apple M1 Pro, macOS 27.0.1 ("Golden Gate"), Xcode 27.2 (recorded project environment).

## Purpose

Prepare a deliberately small first milestone that can be implemented and built before attempting firmware initialisation or audio streaming. The prototype must answer one question at a time: can a correctly entitled DriverKit USB service match the Mbox 2 and establish a supported connection?

This document does not promise that the system will allow the service to claim the device. macOS currently shows Apple USB audio components associated with the Mbox 2 interfaces, so interface ownership and matching behaviour remain explicit risks.

## First milestone: USB match and connection proof

### In scope

1. Add a DriverKit Driver target using the template supplied by the installed Xcode version.
2. Keep the existing `mBox 2 Control` macOS application as the host app; do not create a separate product or bundle namespace without a reason.
3. Use USBDriverKit's documented service/provider model and the SDK headers actually installed on the target Mac.
4. Match only the original full-size Mbox 2: VID `0x0dba`, PID `0x3000`. Do not match Mini, Pro, Micro or Academic variants.
5. On service start, log a clear lifecycle sequence and read only safe device identity/descriptor information initially.
6. On stop/removal, release acquired resources and log the reason.
7. Surface distinct states in the host utility only after a reliable host/driver communication path exists: extension requested, extension activated, service matched, device connection established, and failure reason.

### Explicitly out of scope

- Firmware handshake or any vendor control request.
- Interface rematching, alternate-setting changes or endpoint pipe acquisition beyond what is strictly necessary to prove the initial connection.
- Isochronous transfers, audio buffers or real-time code.
- AudioDriverKit device/stream publication.
- Sample-rate, clock, S/PDIF or AC-3 controls.
- SIP changes, reduced security, kernel extensions, or destructive system configuration changes.

## Proposed source layout

The exact filenames and target membership should follow the Xcode DriverKit template generated on the target machine. Do not hand-author a speculative project file or assume that SDK APIs match another Xcode release.

Suggested logical separation:

- `Driver/` — DriverKit service class, IIG interface declaration, driver entitlements and matching configuration.
- `App/` — existing SwiftUI host app and later SystemExtensions activation/approval flow.
- `Shared/` — small, versioned status/error definitions only if a supported IPC mechanism requires them.
- `docs/` — this plan, entitlement gate and test record.

Use Xcode's generated DriverKit C++ and IIG files as the authoritative starting point. Verify every override, type and API against the installed macOS 27 SDK before implementation.

## Entitlement and signing gate

Apple's current DriverKit documentation says a DriverKit extension needs the `com.apple.developer.driverkit` entitlement and, for USB transport, the `com.apple.developer.driverkit.transport.usb` entitlement. The host app needs the System Extension capability/entitlement to activate the extension. Apple says developers should request the complete entitlement group for the product and configure a matching App ID and provisioning profile.

The USB transport entitlement is an array describing the supported USB devices. Its exact dictionary schema and required values must be taken from the entitlement reference and current SDK, not guessed in this project note.

**Important separation of work:**

- We can prepare architecture, source structure, matching logic, logging, documentation and compile-time checks while entitlement approval is pending.
- A successful local compile does not prove the extension can be activated.
- A valid code signature and matching provisioning profile do not substitute for Apple's grant of the required restricted entitlements.
- Apple explicitly describes disabling some security checks, including SIP-related checks, as a development/testing workaround. This project will not adopt that route by default.
- Do not assume a paid Apple Developer Program membership alone guarantees approval, device matching, entitlement issuance or working audio.
- Before spending money, confirm the current membership requirement for the entitlement request and whether Apple will review this specific hardware-support use case for the account/team. Public documentation establishes the entitlement request process, but does not guarantee approval or establish every account-specific fee condition.

### Decision gate

Do not proceed to a physical-device activation test until all of the following are known:

1. Required DriverKit and USB transport entitlements have been granted to the intended team.
2. The host app and dext have consistent bundle identifiers, Team ID and signing configuration.
3. A provisioning profile includes the complete approved entitlement group.
4. The test plan can be performed without changing SIP or Startup Security settings, or the user has separately made an informed decision about any proposed security change.

If these conditions cannot be met, continue with source development, compilation where possible, static analysis and host-app work. Record the limitation honestly; do not describe the result as a loaded or working driver.

## Implementation sequence once back at the Mac

### A. Environment verification

- Confirm Xcode version, selected developer directory and macOS SDK.
- Confirm the DriverKit, USBDriverKit and (later) AudioDriverKit headers are present in that SDK.
- Create the DriverKit target through Xcode's template.
- Record the generated target settings, bundle identifiers and template source before editing.

### B. Minimal service

- Implement only the template-required service class and IIG declarations.
- Add a narrowly scoped USB match dictionary for VID `0x0dba` and PID `0x3000`, using the exact schema supported by the SDK and entitlement reference.
- Log service start, provider availability, identity readback and stop.
- Avoid claiming interfaces or issuing control transfers in this first source pass.

### C. Build and static validation

- Build the host app and dext for arm64 using the installed SDK.
- Inspect the dext's built entitlements and signature.
- Confirm the extension is embedded at `Contents/Library/SystemExtensions`.
- Check bundle identifiers, Team ID, deployment target and generated Info.plist values.
- Treat all build/signing checks as packaging validation only; they do not prove activation.

### D. Activation and device test (only after entitlement/security gate)

- Request activation using Apple's SystemExtensions framework from the host app.
- Record the system's actual activation result and error domain/code.
- If approved and activated, connect the Mbox 2 and record whether the service matches.
- Check whether Apple USB audio components still own relevant interfaces and whether the new service is actually the provider.
- Stop immediately on unexpected device/system behaviour; do not add interface takeover workarounds in this milestone.

## Acceptance criteria

The first milestone is complete only when evidence demonstrates all of the following:

- The dext builds successfully for arm64 with the intended SDK.
- The packaged dext is embedded in the correct app-bundle location.
- The signed entitlement set matches the Apple-granted profile.
- The host app receives a successful SystemExtensions activation result.
- The service matches the connected original full-size Mbox 2.
- The driver can read and log the expected VID/PID and cleanly stop on removal.

A successful build alone is not completion. An activated extension without a device match is not completion. A device match is not firmware initialisation or audio operation.

## Risks to keep visible

| Risk | Current status | Response |
|---|---|---|
| Apple grants DriverKit + USB transport entitlements | Not established | Confirm process and membership requirements before expenditure |
| macOS allows this service to match/own the required device interfaces | Not established | Test only after signing/entitlement gate; inspect actual provider ownership |
| Existing Apple USB audio service conflicts with matching | Plausible risk | Keep first test narrow; no speculative interface takeover |
| Xcode 27.2 template/API details differ from earlier SDK research | Must verify | Generate target locally and use installed headers as source of truth |
| SIP/security reduction would be required for local activation | Unresolved for this exact setup | Do not change SIP; stop and reassess if the system requires it |
| Device match leads to usable audio | Not established | Separate later milestones for firmware, transport and AudioDriverKit |

## Evidence references

- Apple, [Requesting Entitlements for DriverKit Development](https://developer.apple.com/documentation/driverkit/requesting-entitlements-for-driverkit-development).
- Apple, [USBDriverKit](https://developer.apple.com/documentation/USBDriverKit).
- Apple, [Creating a Driver Using the DriverKit SDK](https://developer.apple.com/documentation/driverkit/creating-a-driver-using-the-driverkit-sdk).
- Apple, [Debugging and testing system extensions](https://developer.apple.com/documentation/DriverKit/debugging-and-testing-system-extensions).
- Project research: [Modern DriverKit architecture](driverkit-architecture.md).
- Project research: [Apple Silicon research](apple-silicon.md).

## Next milestone after a proven match

Only after the first milestone is accepted should work proceed to controlled interface access and descriptor capture. Firmware initialisation must remain a separate milestone because the Linux 18-byte boot-status exchange and Mavericks one-byte handshake have not yet been reconciled. AudioDriverKit publication and isochronous audio transport come later still.
