# Apple Silicon research

## Target system

The primary modern test target recorded for this project is:

| Item | Recorded value |
|---|---|
| Mac model identifier | `MacBookPro18,3` |
| Processor | Apple M1 Pro |
| macOS version | `27.0.1` |
| macOS build | `26A434` |
| Architecture | `arm64` |
| CPU cores | 8 total (6 performance, 2 efficiency) |
| Memory | 16 GB |

The user has designated the current target macOS release as **Golden Gate** for this project.

## USB detection

With the Mbox 2 connected, macOS identifies the USB device as **Digidesign Mbox 2**.

Recorded USB identifiers and properties:

| Property | Value |
|---|---|
| Vendor ID | `0x0dba` (decimal 3514) |
| Product ID | `0x3000` (decimal 12288) |
| USB speed | 12 Mb/s (Full Speed) |
| User authorisation | Authorised |

System logs showed Apple USB audio components, including `AppleUSBAudio` and `usbaudiod`, associated with ownership of USB interfaces.

## What is confirmed

- The USB system can detect and identify the connected Mbox 2.
- The reported vendor and product identifiers match the recorded Mbox 2 identifiers.
- The device is operating at USB Full Speed (12 Mb/s).

## What this does not prove

USB detection is only the first step. It does not prove that:

- The original firmware initialisation handshake has completed.
- The device is in the correct operating state.
- All required USB interfaces and endpoints are available to a replacement driver.
- CoreAudio can open the device successfully.
- Audio input or output streams correctly.
- Sample-rate changes or S/PDIF clock synchronisation work.

The presence of Apple USB audio components in logs should not be treated as proof that the Mbox 2 is fully supported by the modern operating system.

## Next investigation

Compare the USB descriptors and interface layout on the Mavericks reference system and the Apple Silicon target. Then determine which component claims each interface and whether the original device-specific initialisation sequence has taken place.
