# Modern macOS Mbox 2 interface 6 endpoint discovery

**Observation date:** 19 November 2026  
**Test environment:** Apple M1 Pro MacBook Pro, macOS 27.0.1, arm64  
**Device:** Original full-size Digidesign Mbox 2 (VID `0x0dba`, PID `0x3000`)  
**Evidence type:** Read-only IORegistry inspection and IOUSBLib endpoint-descriptor query

## Summary

A small diagnostic program successfully created an IOUSBLib plug-in for the Mbox 2's instantiated USB interface 6 and queried `IOUSBInterfaceInterface190`. It then retrieved endpoint properties for three endpoint/direction combinations without opening the USB interface or transferring USB data.

This is a useful compatibility result: the legacy IOUSBLib interface can expose endpoint descriptors for the Mbox 2's vendor-specific interface on the modern Apple Silicon target. It does **not** establish that the interface can be opened, claimed, or used for device communication.

## Interface 6 as observed in IORegistry

The matching `IOUSBHostInterface` service was identified by the device's VID/PID and `bInterfaceNumber = 6`.

| Property | Observed value |
|---|---|
| Interface number | 6 |
| Interface class | `0xff` (vendor-specific) |
| Subclass / protocol | `0x00 / 0x00` |
| Current alternate setting | 0 |
| Endpoint count | 3 |
| IORegistry exclusive-owner property | No owner listed in the queried service |

The absence of a listed owner in this IORegistry snapshot is not proof that an interface can be opened or claimed by another process. The standard audio interfaces 1–5 had existing `usbaudiod` client associations in the wider device inspection.

## Diagnostic method

The diagnostic:

1. Matched `IOUSBHostInterface` services for VID `0x0dba`, PID `0x3000`, and interface number 6.
2. Created an interface plug-in using `kIOUSBInterfaceUserClientTypeID`.
3. Queried `kIOUSBInterfaceInterfaceID190`.
4. Called `GetEndpointProperties(alternateSetting: 0, ...)` for endpoint numbers 1–15 in both directions.
5. Released the queried interfaces and plug-in objects.

The SDK header documents `GetEndpointProperties` as returning transfer type, maximum packet size and polling interval for a specified alternate setting, endpoint number and direction. Unlike `GetPipeProperties`, this descriptor query does not require the interface to be open. The diagnostic used direction value 1 for IN and 0 for OUT, following USB direction convention; the inspected SDK declaration did not provide named direction constants.

## Results

| Endpoint number | Direction | Transfer type | Maximum packet size | Interval |
|---:|---|---|---:|---:|
| 1 | IN | Interrupt | 16 bytes | 1 |
| 2 | OUT | Bulk | 16 bytes | Not applicable / reported 0 |
| 2 | IN | Bulk | 16 bytes | Not applicable / reported 0 |

Three endpoint queries succeeded. All other tested endpoint/direction combinations did not return endpoint properties.

The endpoint numbers and directions above are the parameters used for the descriptor query. They are not a claim that the endpoint's protocol purpose has been identified.

## Interpretation and evidence limits

**Confirmed:**
- The modern macOS IOUSBLib plug-in could be created for interface 6.
- QueryInterface for `IOUSBInterfaceInterface190` succeeded.
- `GetEndpointProperties` returned three endpoint descriptors for alternate setting 0.
- The returned descriptors describe one interrupt-IN endpoint and a bulk endpoint in each direction.
- The diagnostic did not call `USBInterfaceOpen`, change an alternate setting, issue a control request, or submit an endpoint transfer.

**Strong indication, not yet proven:**
- The vendor-specific interface 6 and its bidirectional bulk endpoint may provide a path for proprietary device commands and responses.
- The interrupt-IN endpoint may provide status or notification information.

Endpoint transfer types alone do not identify their protocol purpose. No packet format, command, firmware handshake, status message, or device response has been established by this test.

**Not established:**
- Whether ordinary interface open or claim succeeds.
- Whether interface 6 can be used while Apple's audio service owns interfaces 1–5.
- Whether a control transfer or bulk/interrupt transfer succeeds.
- Whether this interface is sufficient for firmware initialisation or device configuration.
- Whether the endpoint layout changes at other alternate settings.
- Whether the interface is used by the original driver in the same way inferred from these endpoint descriptors.

## Relationship to the audio channels

The Mbox 2 is a four-input / two-output audio interface: analog inputs 1–2, S/PDIF digital inputs 3–4, and stereo outputs. Interface 6's vendor-specific endpoints are USB transport endpoints, not a direct representation of those six logical audio channels. Audio streaming remains a separate investigation involving the audio streaming interfaces and their alternate settings.

## Next safe investigation

1. Compare interface 6 with the original Mavericks driver's interface matching and control paths.
2. Determine the exact ordinary-open requirements and ownership behaviour from the SDK and observed service state.
3. If a future test attempts an ordinary open, keep it separate and low-risk. Do not use seize/capture operations, detach Apple's audio clients, or change system security settings.
4. Do not send firmware-handshake or proprietary commands until the request sequence and safe access path are understood.

The project-wide security boundary remains unchanged: SIP and normal Startup Security stay enabled; no forced USB capture, device-seize fallback, kernel extension, root-only access, or disruption of Apple's existing USB audio clients is permitted.
