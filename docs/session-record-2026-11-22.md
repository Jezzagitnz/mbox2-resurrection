# Session record — 22 November 2026

## Summary

This session consolidated the selected architecture, reviewed the current firmware-startup evidence, checked the public Eleven Rack Linux driver repository for relevant discussion, and redefined the next implementation milestones.

## Architecture decision

The project continues exclusively with the **Eleven Rack-style user-space architecture**, adapted to macOS:

1. Ordinary user-space USB communication with the Mbox 2.
2. A transport-independent protocol core.
3. A Core Audio integration layer.
4. Shared-memory audio transport where appropriate between the USB process and Core Audio component.
5. A small native macOS configuration utility.

DriverKit is parked. It is not to be developed, investigated further, or treated as a fallback unless the project owner explicitly reopens the decision. Do not pursue SIP reduction, paid Apple Developer membership as a prerequisite for local development, kernel extensions, forced USB capture, or device seizure.

The Eleven Rack Linux project is an architectural reference, not code to port wholesale. Its public README describes a Linux ALSA `snd-usb-audio` compatibility patch that reuses ALSA's audio, MIDI and mixer implementation. It also documents implicit-feedback stream synchronisation. Those are Linux-specific mechanisms; our macOS implementation must use the appropriate macOS USB and Core Audio facilities.

## Review of the Eleven Rack GitHub project

Repository reviewed: https://github.com/kdbo/Elevenrack-driver-linux

- README reviewed.
- Pull request #1, “Fix/implicit feedback packet capacity”: closed; no issue-thread comments and no submitted PR reviews reported by GitHub.
- Pull request #2, “Feat/tauri editor”: closed; no issue-thread comments and no submitted PR reviews reported by GitHub.
- No additional replies were surfaced in those PR conversations. The repository README remains useful as architectural reference, but no new reply changed our design.

## Mbox 2 startup findings consolidated today

These findings are drawn from the existing reverse-engineering notes and the short evidence extract reviewed in this session. They are static-analysis findings, not new hardware tests.

### Mavericks one-byte firmware handshake

The legacy Mavericks `FirmwareHandshake(bool)` routine at `0x4fc6` constructs:

| Field | Value |
|---|---:|
| `bmRequestType` | `0xC0` |
| `bRequest` | `0x85` |
| `wValue` | Boolean argument + 1 |
| `wIndex` | `0x0001` |
| `wLength` | `1` |

For the observed `FirmwareHandshake(false)` call, `wValue=1`. If the transfer succeeds and the response byte is `0x01`, the routine waits 300 ms and retries, for up to 30 retries after the initial attempt. A transfer error or a response other than `0x01` exits the loop. The semantic meaning of every response value is not yet established.

### Startup ordering

The inspected `initHardware()` path identifies the device, obtains a USB-related object and reads its `bcdDevice` property. The calls previously identified at device vtable offset `+0xa38` resolve to `UsbRematchInterface(unsigned char)`; the relevant path attempts interface numbers 0 and 6, then performs `FirmwareHandshake(false)`. The successful path then calls the concrete `RayDevice::CreateAudioEngines()` override at `0xc9ca`.

The exact runtime outcome of the rematching calls is not proven by static disassembly. An earlier virtual operation at `+0xa30` also remains unidentified.

### Linux boot-status request is distinct

The Linux Mbox 2 boot quirk uses the same request type and code but a different shape:

| Field | Linux boot quirk |
|---|---:|
| `bmRequestType` | `0xC0` |
| `bRequest` | `0x85` |
| `wValue` | `0x0001` |
| `wIndex` | `0x0000` |
| `wLength` | `0x0012` (18 bytes) |
| Poll interval | 500 ms |
| Maximum attempts | 10 |
| First response byte | `0x02` ready; `0x01` loading |

Do not conflate this Linux 18-byte exchange with the Mavericks one-byte handshake or assume their order. The matching 646-byte configuration descriptor length is a hardware-recognition cross-check, not permission to send the Linux request on macOS.

### Still unresolved

- The separate `DigiHandshake::Do` routine has five stage values (0–4), with helper routines identified in the disassembly notes. Their USB operations and relationship to device startup remain unmapped.
- The earlier `initHardware()` virtual operation at `+0xa30` remains unidentified.
- The semantic meaning of the Mavericks response byte and the relationship between the two `0x85` request variants remain open.

The user could not run the final short `DigiHandshake` grep command in this session. No claim is made that those helper bodies were reviewed today.

## Work not performed

No vendor-specific or state-changing USB request was sent. No firmware handshake, Linux boot-status request, USB reset, configuration change, alternate-setting change, endpoint transfer, audio transfer, or LED initialisation test was performed. No Core Audio device publication or audio streaming was attempted.

The existing proven milestones remain unchanged: ordinary USB discovery, interface-6 attachment, standard read-only descriptor requests, full configuration descriptor parsing, and a standalone Host app build. Do not repeat those investigations as if they were outstanding.

## Redefined milestone order

### Milestone 1 — First bidirectional USB communication and Mbox 2 LED initialisation

- Finish only the necessary static reconciliation of the legacy and Linux startup evidence, including the unresolved `DigiHandshake::Do` stages.
- Define the exact first USB exchange, expected response, timeout/retry behaviour, and safe stopping conditions.
- Explain the proposed request and obtain the user's explicit approval before any vendor-specific or state-changing hardware request.
- Use ordinary user-space USB access only.
- Success: the device reaches its expected initialised state and the expected Mbox 2 LEDs illuminate.

### Milestone 2 — Core Audio input and output

After Milestone 1 succeeds:

- Integrate the proven USB transport into the selected user-space architecture.
- Implement the Core Audio device-publication and audio transport path.
- Establish playback and capture independently, then verify simultaneous operation.
- Use shared-memory transport where appropriate and validate timing, buffering and failure handling.
- Success: real audio can be played to and captured from the Mbox 2 through macOS Core Audio.

### Milestone 3 — Universal Audio LUNA

After Core Audio playback and capture work:

- Select the Mbox 2 in LUNA.
- Verify real playback and recording.
- Then investigate supported sample formats, 44.1/48 kHz operation and clocking.

### Milestone 4 — Configuration utility and additional capabilities

Build out essential status and configuration controls after the underlying device and audio path are reliable.

## Next session starting point

Resume from the existing startup research, not from USB discovery. The next narrow research target is the five-stage `DigiHandshake::Do` implementation and its helper routines. Keep the next command short and bounded. No hardware request is authorised by this session record; any such request still requires an exact explanation and explicit approval.
