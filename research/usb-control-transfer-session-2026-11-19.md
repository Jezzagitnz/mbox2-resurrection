# Mbox 2 USB control-transfer session — 19 November 2026

**Test system:** Apple M1 Pro MacBook Pro, macOS 27.0.1 (build 26A434), Xcode 27.2 / macOS SDK 27.2  
**Device:** Original full-size Digidesign Mbox 2  
**USB identity:** VID 0x0dba, PID 0x3000  
**Interface used:** USB interface 6 (vendor-specific, interface number 6)  
**Test type:** Ordinary interface access followed by one standard, read-only device-descriptor control request  
**Outcome:** Successful; 18 bytes returned and device identity verified

## Purpose

The preceding ordinary-open test established that interface 6 could be opened and immediately released without forcing ownership away from another process. This session extended that result by testing whether the opened interface object could perform a single, harmless standard USB control request.

The only request authorised and sent in this test was a standard USB GET_DESCRIPTOR request for the device descriptor. It was not a firmware or vendor-specific request.

## Interface discovery and access

The test enumerated registered IOUSBHostInterface services using IOServiceMatching("IOUSBHostInterface") and IOServiceGetMatchingServices(kIOMainPortDefault, ...). It read the registry properties idVendor, idProduct, and bInterfaceNumber and selected the service matching:

| Property | Value |
|---|---:|
| Vendor ID | 0x0dba (3514) |
| Product ID | 0x3000 (12288) |
| Interface number | 6 |

The interface object was initialised using IOUSBHostInterface with IOUSBHostObjectInitOptionsNone, no dispatch queue, and no interest handler.

Observed result:

    FOUND: Original Digidesign Mbox 2, interface 6.
    Opening with ordinary access only...
    SUCCESS: Interface opened.

This is ordinary access. No seize/capture API or forced ownership mechanism was used.

## Exact USB request

The request used the inherited IOUSBHostObject.sendDeviceRequest API on the interface object. The method sends a synchronous request through the default control endpoint.

| Request field | Value | Meaning |
|---|---:|---|
| bmRequestType | 0x80 | Device-to-host, standard request, device recipient |
| bRequest | 0x06 | GET_DESCRIPTOR |
| wValue | 0x0100 | Device descriptor type (1), descriptor index 0 |
| wIndex | 0x0000 | No language/interface index |
| wLength | 0x0012 | 18 bytes |

The 16-bit fields were converted to USB little-endian representation with HostToUSB16. The receive buffer was 18 bytes. The completion timeout was 2.0 seconds.

No other USB request was sent.

## Exact result

Terminal output:

    ===== MBOX 2 — READ-ONLY DEVICE DESCRIPTOR TEST =====
    FOUND: Original Digidesign Mbox 2, interface 6.
    Opening with ordinary access only...
    SUCCESS: Interface opened.
    Preparing one standard GET_DESCRIPTOR request...
    Sending request (18-byte maximum, 2-second timeout)...
    REQUEST SUCCEEDED.
    Bytes transferred: 18
    Descriptor bytes: 12 01 00 01 00 00 00 08 BA 0D 00 30 38 01 01 02 00 01
    Descriptor length: 18
    Descriptor type:   1
    USB version:       1.00
    Vendor ID:         0x0DBA
    Product ID:        0x3000
    Device revision:   0x0138
    Configurations:    1
    CONFIRMED: Valid Mbox 2 device descriptor received.
    Releasing interface...
    Interface released.
    ===== TEST COMPLETE =====

### Parsed 18-byte descriptor

| Byte offset | Field | Returned value |
|---:|---|---:|
| 0 | Descriptor length | 0x12 (18) |
| 1 | Descriptor type | 0x01 (Device) |
| 2–3 | USB specification version | 0x0100 (1.00) |
| 4 | Device class | 0x00 |
| 5 | Device subclass | 0x00 |
| 6 | Device protocol | 0x00 |
| 7 | Maximum control endpoint packet size | 0x08 (8 bytes) |
| 8–9 | Vendor ID | 0x0dba |
| 10–11 | Product ID | 0x3000 |
| 12–13 | Device release | 0x0138 |
| 14 | Manufacturer string index | 0x01 |
| 15 | Product string index | 0x02 |
| 16 | Serial-number string index | 0x00 (no serial string) |
| 17 | Number of configurations | 0x01 |

The descriptor values match the expected original full-size Mbox 2 identity. The device revision matches the previously observed bcdDevice 312 value.

## Resource cleanup

After the request, the test explicitly called destroy on the interface object, released the Objective-C object, and released the matching I/O Registry service. The program reported:

    Releasing interface...
    Interface released.
    ===== TEST COMPLETE =====

## Safety and scope boundaries

The following operations were **not** performed:

- No USBDeviceOpenSeize() or USBInterfaceOpenSeize().
- No forced capture, exclusive ownership request, or termination of Apple's USB audio clients.
- No change to SIP, Startup Security, or other macOS security settings.
- No USB configuration selection or change.
- No interface alternate-setting change.
- No pipe creation or endpoint read/write/streaming transfer.
- No firmware handshake (including the previously reverse-engineered vendor request 0x85).
- No sample-rate or clock-source request.
- No audio-engine initialisation or Core Audio stream publication.

The request was standard, read-only identification traffic. It did not alter device configuration or request firmware initialisation.

## What this proves — and what it does not

**Confirmed:**

1. The Mbox 2's interface 6 can be found through the modern IOUSBHostInterface service registry.
2. An ordinary IOUSBHostInterface object for interface 6 can be created successfully.
3. The object can send a standard control request and receive the complete 18-byte device descriptor.
4. The returned descriptor identifies the expected Mbox 2 hardware.

**Not established:**

- That the Mbox 2 firmware has been initialised or is in its operational state.
- That vendor-specific control requests will succeed or are safe to send.
- That the USB LED or any other indicator can be controlled.
- That audio endpoints can be opened or streamed.
- That macOS can publish working input/output streams.
- That any sample format, sample rate, or S/PDIF clock mode works.

### LED interpretation

A device-descriptor request asks the device to return static USB identity information. It does not request firmware initialisation, audio-engine startup, or a change to any indicator state. Therefore **no LED change should be expected from this test**.

The earlier observed physical state was USB indicator off and mono indicator on. The descriptor-test output did not include a fresh physical LED observation, so this record does not claim that the LEDs were rechecked after the request.

## Next investigation

The next step is to review the legacy startup sequence and the exact semantics of the firmware handshake before proposing any further hardware request. The successful descriptor read is a foundation for that investigation, not authorisation to send the handshake automatically.

Any subsequent USB request must be separately described, bounded, and approved before it is sent.


## Follow-up: read-only configuration-descriptor header — 19 November 2026

After the successful device-descriptor read, a separately authorised standard GET_DESCRIPTOR request read only the 9-byte configuration descriptor header through the same ordinary interface-6 access path.

### Exact request

| Request field | Value | Meaning |
|---|---:|---|
| bmRequestType | 0x80 | Device-to-host, standard request, device recipient |
| bRequest | 0x06 | GET_DESCRIPTOR |
| wValue | 0x0200 | Configuration descriptor type (2), index 0 |
| wIndex | 0x0000 | No language/interface index |
| wLength | 0x0009 | 9-byte header only |

The request used the existing IOUSBHostInterface object created with IOUSBHostObjectInitOptionsNone. The response buffer was 9 bytes and the completion timeout was 2.0 seconds.

### Exact result

Terminal output:

    SUCCESS: Interface 6 opened with ordinary access.
    Preparing one standard configuration GET_DESCRIPTOR request.
    REQUEST SUCCEEDED.
    Bytes transferred: 9
    Descriptor bytes: 09 02 86 02 07 01 00 80 FA
    Descriptor length:       9
    Descriptor type:         2 (Configuration)
    Total configuration size: 646 bytes
    Number of interfaces:    7
    Configuration value:     1
    Attributes:               0x80
    Maximum power:            500 mA
    MATCH: Linux boot-quirk descriptor-length check.
    Releasing interface...
    Interface released.

### Interpretation

**Confirmed on this hardware:** the configuration descriptor reports a total configuration length of **646 bytes** and seven interfaces. The 646-byte total exactly matches the explicit configuration-length prerequisite in the Linux Mbox 2 boot quirk.

This is a useful hardware-specific cross-check: the Linux boot path's descriptor-length guard matches the connected original full-size Mbox 2.

**It does not establish** that the Linux boot-status request should be sent on macOS, that its firmware-initialisation sequence is interchangeable with the Mavericks driver's one-byte request, or that either request is safe to send without further analysis. Matching the descriptor length validates the Linux quirk's hardware prerequisite only; it does not validate the later protocol steps.

### Scope and safety

- Exactly one 9-byte standard configuration GET_DESCRIPTOR request was sent.
- At the time of this header-only follow-up, only the 9-byte header had been retrieved. A later, separately authorised read in this session retrieved the complete 646-byte configuration; see the full-descriptor follow-up below.
- No configuration was selected or changed.
- No interface alternate setting was changed.
- No firmware/vendor-specific request, endpoint transfer, sample-rate request, or audio operation was attempted.
- Interface 6 was destroyed and released after the request.
- No seize/capture API or forced ownership operation was used.

The read-only header request does not initialise the device and provides no reason to expect an LED change. No new physical LED observation was recorded during this test.

### Updated next step

Continue static comparison of the Mavericks and Linux startup paths, including their different request fields, response interpretations, polling behaviour, and post-ready actions. The 646-byte match is evidence for the Linux quirk's device match, **not** authorisation to send its firmware-status request. Any further USB request remains subject to a separate explanation and explicit approval.


## Follow-up: complete configuration descriptor read and offline parse — 19 November 2026

A further separately authorised, standard, read-only GET_DESCRIPTOR request retrieved the complete configuration descriptor through the same ordinary IOUSBHost interface-6 access path.

### Exact request

| Request field | Value | Meaning |
|---|---:|---|
| `bmRequestType` | `0x80` | Device-to-host, standard request, device recipient |
| `bRequest` | `0x06` | GET_DESCRIPTOR |
| `wValue` | `0x0200` | Configuration descriptor type (2), index 0 |
| `wIndex` | `0x0000` | No language/interface index |
| `wLength` | `0x0286` (646) | Complete configuration descriptor |

The request returned exactly 646 bytes. The raw descriptor was saved locally as `/tmp/mbox2_configuration_descriptor.bin` and parsed offline. No descriptor data was written to the device.

### Parsed interface and endpoint map

Endpoint packet sizes below are the descriptor's maximum packet sizes. Endpoint transfer type and direction are decoded from the endpoint address and attributes.

| Interface | Alternate setting | Class / subclass / protocol | Endpoints |
|---:|---:|---|---|
| 0 | 0 | `0xFE / 0x01 / 0x00` | None |
| 1 | 0 | Audio Control `0x01 / 0x01 / 0x00` | None |
| 2 | 0 | Audio Streaming `0x01 / 0x02 / 0x00` | None |
| 2 | 2, 3 | Audio Streaming | `0x03` OUT isochronous, 296 bytes; `0x83` IN isochronous, 3 bytes |
| 3 | 0 | Audio Streaming `0x01 / 0x02 / 0x00` | None |
| 3 | 2, 3 | Audio Streaming | `0x04` OUT isochronous, 296 bytes; `0x84` IN isochronous, 3 bytes |
| 3 | 6 | Audio Streaming | `0x04` OUT isochronous, 192 bytes; no IN endpoint |
| 4 | 0 | Audio Streaming `0x01 / 0x02 / 0x00` | None |
| 4 | 2 | Audio Streaming | `0x85` IN isochronous, 296 bytes |
| 4 | 3 | Audio Streaming | `0x85` IN isochronous, 296 bytes |
| 5 | 0 | Audio Streaming `0x01 / 0x02 / 0x00` | None |
| 5 | 2 | Audio Streaming | `0x86` IN isochronous, 296 bytes |
| 5 | 3 | Audio Streaming | `0x86` IN isochronous, 296 bytes |
| 6 | 0 | Vendor-specific `0xFF / 0x00 / 0x00` | `0x81` IN interrupt, 16 bytes, interval 1; `0x82` IN bulk, 16 bytes; `0x02` OUT bulk, 16 bytes |

The configuration contains seven interfaces and 646 bytes total, consistent with the separately read 9-byte configuration header.

### Audio descriptor observations

The AudioStreaming descriptors for the PCM paths describe Type I, two-channel audio with three-byte subframes and 24-bit samples, with a continuous 8 kHz–48 kHz rate range. These are descriptor-advertised capabilities; they do not prove that every format/rate combination works with the legacy driver or a new macOS implementation.

The endpoint map distinguishes several paths that must not be conflated:

- Interfaces 2 and 3 have isochronous OUT audio endpoints and small IN isochronous endpoints on alternate settings 2 and 3.
- Interfaces 4 and 5 have isochronous IN endpoints on alternate settings 2 and 3.
- Interface 3 alternate setting 6 has an OUT endpoint with a 192-byte maximum packet and no corresponding IN endpoint. Existing legacy research associates this path with AC-3 output, but the descriptor alone does not establish its complete operating semantics.

### Interface 0 descriptor caution

Interface 0 reports class `0xFE`, subclass `0x01`, protocol `0x00`, and contains a seven-byte class-specific descriptor:

```
07 21 05 FF FF 08 00
```

This is recorded as a DFU-related class/subclass identifier only. The available descriptor is not sufficient to label the interface as a standard, operational DFU implementation. No DFU request was sent.

### Interface 6 endpoint interpretation

The Linux Mbox 2 quirk maps interface 6 endpoints `0x02` OUT and `0x81` IN to MIDI. Endpoint `0x82` IN is present in the hardware descriptor but is not assigned a role by the inspected Linux quirk. Its purpose remains unknown; it must not be labelled as MIDI, status, or clock feedback without further evidence.

### What this adds — and what it does not

**Confirmed on hardware:**
1. The complete 646-byte configuration descriptor can be read through ordinary interface-6 IOUSBHost access.
2. The configuration contains seven interfaces and the endpoint/alternate-setting map recorded above.
3. The descriptor data can be parsed offline without further USB traffic.

**Still not established:**
- Which alternate settings the original driver selects in each operating mode.
- The precise meaning of the small isochronous IN endpoints on interfaces 2 and 3.
- The purpose of interface 6 endpoint `0x82`.
- Whether interface 3 alternate setting 6 is the only AC-3 path for every hardware/firmware revision.
- Whether the advertised PCM rates and formats are all operational.
- Firmware initialisation, LED response, clock lock, or working audio streaming.

### Scope and safety

- One standard, read-only configuration GET_DESCRIPTOR request was sent for 646 bytes.
- The descriptor was parsed offline after the transfer.
- No configuration or alternate setting was changed.
- No endpoint pipe was created and no endpoint data was read or written.
- No firmware/vendor-specific request, sample-rate request, USB reset, or audio operation was attempted.
- Interface 6 was destroyed and released normally.
- No seize/capture API, forced ownership operation, or security-setting change was used.

The complete descriptor read is a significant discovery milestone, but it remains descriptor inspection only. Any further device operation requires its own technical justification and explicit approval.
