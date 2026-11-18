# DriverKit prototype preparation

**Status:** Next-step plan for the existing compile/package scaffold. The separate `driverkit-foundation` branch (PR #14) contains a minimal DriverKit target and host app; its recorded Xcode 27.2 build validates compilation and packaging only. It has not been signed with approved entitlements, activated, or shown to open/match the physical Mbox 2.  
**Target:** Original full-size Digidesign Mbox 2, USB VID `0x0dba`, PID `0x3000`.  
**Target Mac:** Apple M1 Pro, macOS 27.0.1 ("Golden Gate"), Xcode 27.2.

## Purpose

The first source scaffold now exists. The next DriverKit work must establish whether a correctly signed and entitled service can activate and obtain the expected USB provider under the Mac's normal security configuration.

This plan is only for the DriverKit candidate. The parallel IOUSBHost + Audio Server Plug-in candidate, including its interface-ownership gate, is documented in [SIP-compatible user-space USB and Core Audio path](../research/sip-compatible-user-space-path.md).

**SIP and Startup Security must remain enabled and unchanged on the primary Mac.** Do not use ad-hoc signing that requires security-check bypasses, device capture, root-only takeover, a kernel extension or any other security-reduction workaround. If the secure activation route is not available, stop and continue with the alternative architecture or hardware-independent work.

## Existing scaffold — what is and is not present

The `driverkit-foundation` branch contains:

- An Xcode project with a DriverKit extension target and a separate host app target.
- A matching personality in the dext Info.plist for VID `0x0dba` and PID `0x3000`.
- A minimal C++ `Mbox2Driver::Start` implementation and IIG declaration.
- A host SwiftUI placeholder.
- An Xcode build phase that runs IIG generation.
- A recorded successful arm64 build/package result using Xcode 27.2.

Inspection of the branch source shows the current service start calls the superclass and logs that the service started. It does not yet open the USB provider, read descriptors, claim an interface, issue a control request or perform audio I/O.

The project file currently sets `CODE_SIGNING_ALLOWED = NO` and does not specify a `CODE_SIGN_ENTITLEMENTS` file. Therefore the recorded build is not evidence of a correctly signed or activation-ready system extension.

## First runtime milestone — secure activation and provider proof

### In scope

1. Review the existing scaffold rather than creating a second DriverKit project.
2. Verify the generated project settings, IIG output and source against the installed macOS 27 SDK.
3. Establish the correct bundle identifiers and signing relationship for host app and dext.
4. Request the required DriverKit and USB transport entitlements from Apple, if the user chooses to proceed with that route.
5. Configure a provisioning profile containing the complete Apple-granted entitlement group.
6. Implement the minimum SystemExtensions activation flow in the host app.
7. Add narrowly scoped lifecycle logging and, only after activation succeeds, verify the provider passed to the driver.
8. Read only safe device identity/descriptor information for the original full-size Mbox 2.
9. Release resources and log cleanly on stop/removal.

### Explicitly out of scope

- Disabling SIP or reducing Startup Security.
- Ad-hoc DriverKit activation that depends on bypassing system security checks.
- Kernel extensions or legacy kext loading.
- Root-only device capture or forcibly terminating Apple's USB clients.
- Firmware handshake or vendor control requests.
- Interface rematching, alternate-setting changes or endpoint-pipe acquisition beyond what is strictly necessary for the first provider proof.
- Isochronous transfers, audio buffers or real-time code.
- AudioDriverKit device/stream publication.
- Sample-rate, clock, S/PDIF or AC-3 controls.

## Entitlement and signing gate

Apple's current DriverKit documentation says a DriverKit extension needs the `com.apple.developer.driverkit` entitlement and, for USB transport, the `com.apple.developer.driverkit.transport.usb` entitlement. The host app needs the System Extension capability/entitlement to activate the extension. Apple says developers should request the complete entitlement group for the product and configure a matching App ID and provisioning profile.

The USB transport entitlement is an array describing supported USB devices. Its exact dictionary schema and required values must be taken from the entitlement reference and current SDK, not guessed.

**Important separation of work:**

- Source development, portable protocol tests, architecture and static validation can continue while entitlement eligibility is investigated.
- A successful local compile does not prove that the extension can be activated.
- A valid code signature and matching provisioning profile do not substitute for Apple's grant of the restricted entitlements.
- Apple's ad-hoc development workaround disables security checks, including SIP-related checks. This project will not use it.
- Do not assume a paid Apple Developer Program membership alone guarantees approval, device matching, entitlement issuance or working audio.
- Before spending money, confirm the current membership requirement for the entitlement request and whether Apple will review this specific hardware-support use case for the account/team.

### Decision gate

Do not proceed to a physical-device activation test until all of the following are known:

1. Required DriverKit and USB transport entitlements have been granted to the intended team.
2. The host app and dext have consistent bundle identifiers, Team ID and signing configuration.
3. A provisioning profile includes the complete approved entitlement group.
4. The planned activation and provider test can be performed with SIP and Startup Security unchanged.

If these conditions cannot be met, do not weaken security. Continue with source development, compilation where possible, static analysis, protocol tests and the IOUSBHost alternative. Record the limitation honestly; do not describe the result as a loaded or working driver.

## Implementation sequence

### A. Environment and scaffold verification

- Confirm Xcode version, selected developer directory and macOS SDK.
- Confirm the DriverKit, USBDriverKit and AudioDriverKit headers are present in that SDK.
- Inspect the existing DriverKit target and compare it with the installed Xcode template.
- Record generated target settings, bundle identifiers and template source before editing.

### B. Signing and activation preparation

- Confirm the entitlement request process and the required entitlement dictionary schema.
- Keep host-app and dext entitlements separate.
- Configure signing only after the approved entitlement group is available.
- Add the SystemExtensions activation delegate and record actual error domains/codes.
- Do not add a fallback that disables system security.

### C. Minimal provider proof

- Use the exact USB match schema supported by the SDK and entitlement reference.
- Log activation, service start, provider availability, identity readback and stop as separate events.
- Do not claim interfaces or issue control transfers in this first source pass.
- Check whether Apple USB audio components still own relevant interfaces; do not forcibly terminate them.

### D. Later device protocol work

Only after a secure provider connection is proved should work proceed to controlled interface access and descriptor capture. Firmware initialisation must remain separate because the Linux 18-byte boot-status exchange and Mavericks one-byte handshake have not yet been reconciled. AudioDriverKit publication and isochronous audio transport come later still.

## Acceptance criteria

The DriverKit provider milestone is complete only when evidence demonstrates all of the following:

- The dext builds successfully for arm64 with the intended SDK.
- The packaged dext is embedded in the correct app-bundle location.
- The signed entitlement set matches the Apple-granted profile.
- The host app receives a successful SystemExtensions activation result with SIP unchanged.
- The service matches the connected original full-size Mbox 2.
- The driver can read and log the expected VID/PID and cleanly stop on removal.

A successful build alone is not completion. An activated extension without a device match is not completion. A device match is not firmware initialisation or audio operation.

## Risks to keep visible

| Risk | Current status | Response |
|---|---|---|
| Apple grants DriverKit + USB transport entitlements | Not established | Confirm process and membership requirements before expenditure |
| Existing scaffold is activation-ready | No — code signing is disabled and no entitlement file is configured | Configure only after the Apple-granted entitlement group is available |
| macOS allows this service to match the Mbox 2 | Not established | Test only after secure signing/entitlement gate |
| Existing Apple USB audio service conflicts with matching | Plausible risk | Inspect actual provider ownership; no forced takeover |
| Xcode 27.2 API/template details | Local compile/package reported; runtime APIs still unverified | Use installed headers and template as source of truth |
| SIP/security reduction would be required | Unresolved for DriverKit ad-hoc development; prohibited for this project | Stop and use another route |
| Device match leads to usable audio | Not established | Separate later milestones for firmware, transport and AudioDriverKit |

## Evidence references

- Apple, [Requesting Entitlements for DriverKit Development](https://developer.apple.com/documentation/driverkit/requesting-entitlements-for-driverkit-development).
- Apple, [USBDriverKit](https://developer.apple.com/documentation/USBDriverKit).
- Apple, [Creating a Driver Using the DriverKit SDK](https://developer.apple.com/documentation/driverkit/creating-a-driver-using-the-driverkit-sdk).
- Apple, [Debugging and testing system extensions](https://developer.apple.com/documentation/DriverKit/debugging-and-testing-system-extensions).
- Project research: [Modern DriverKit architecture](../research/driverkit-architecture.md).
- Project research: [SIP-compatible user-space path](../research/sip-compatible-user-space-path.md).
- Project implementation: [DriverKit foundation PR #14](https://github.com/Jezzagitnz/mbox2-resurrection/pull/14).
