# Reverse-engineering session — 25 November 2026

**Project:** Original full-size Digidesign Mbox 2 (USB VID 0x0dba, PID 0x3000)  
**Reference system:** 2012 Mac mini, OS X Mavericks 10.9.5  
**Development system:** Apple Silicon M1 Pro MacBook Pro  
**Original driver:** /System/Library/Extensions/DigidesignMbox2.kext/Contents/MacOS/DigidesignMbox2

## Session outcome

The complete MaudioShDrRayUsbDevice::initHardware() routine was recovered from the original Mavericks driver and its three relevant virtual calls were resolved against the concrete RayDevice vtable.

The key result is that the startup path calls:

1. UsbSetConfiguration(1, false)
2. UsbRematchInterface(0)
3. UsbRematchInterface(6) on the zero-return path
4. FirmwareHandshake(false)
5. RayDevice::CreateAudioEngines() on the permitted success path

This resolves the previously unknown +0xa30 call and gives us a much more precise static picture of the original startup order.

## Exact original binary

The binary was checked on the Mavericks reference system:

- Size: 434,424 bytes
- Date: 4 October 2014
- SHA-256: 7dd2fb0d19b80aa3615aa72866c00a98345fbc6e3e375e70d9cbca6411539f9d

The symbol table reconfirmed:

| Method | Address |
|---|---:|
| MaudioShDrRayUsbDevice::initHardware(IOService*) | 0x4da4 |
| MaudioShDrRayUsbDevice::FirmwareHandshake(bool) | 0x4fc6 |
| MaudioShDrRayUsbDevice::UsbSetConfiguration(unsigned char, bool) | 0x5118 |
| MaudioShDrRayUsbDevice::UsbRematchInterface(unsigned char) | 0x51b2 |
| Base MaudioShDrRayUsbDevice::CreateAudioEngines() stub | 0x547a |
| Concrete RayDevice::CreateAudioEngines() | 0xc9ca |

## Complete initHardware control flow

The disassembly from 0x4da4 to 0x4fc5 shows:

1. Check the device start state and USB provider pointer.
2. Identify the model variant (Academic, Mini, Micro or standard Mbox 2) and publish model/manufacturer properties.
3. Call the device virtual method at byte offset +0xa30, passing 1 and 0.
4. If that returns zero, obtain the USB-related object, invoke its method at +0x20, read its bcdDevice property, and store the converted revision value.
5. Call the device virtual method at +0xa38 with interface number 0.
6. If that returns zero, call the same method with interface number 6.
7. Call FirmwareHandshake(false).
8. If the second rematch status permits continuation, call the device virtual method at +0xa20 to create audio engines.
9. Return status is determined by the operation result held in the routine's status register; a non-zero configuration or rematch result prevents the normal continuation.

The early error branches still call FirmwareHandshake(false) before returning failure. This is a description of the observed static control flow; it does not establish which branches succeed at runtime on all hardware/firmware revisions.

## Vtable address-point correction

This session initially misread the raw vtable by treating the vtable symbol as the start of the function-pointer array. Under the Itanium C++ ABI, the address point is 16 bytes after the vtable symbol. Applying that offset is essential.

### Concrete RayDevice vtable

- Vtable symbol: 0x272e0
- Address point: 0x272f0
- Raw table entries read around 0x27d00:

| Virtual slot | Entry address | Function pointer | Resolved method |
|---|---:|---:|---|
| +0xa20 | 0x27d10 | 0xc9ca | RayDevice::CreateAudioEngines() |
| +0xa28 | 0x27d18 | 0x506e | performStop() |
| +0xa30 | 0x27d20 | 0x5118 | UsbSetConfiguration(unsigned char, bool) |
| +0xa38 | 0x27d28 | 0x51b2 | UsbRematchInterface(unsigned char) |

### Base-class comparison

- Vtable symbol: 0x20ee0
- Address point: 0x20ef0
- Base-class +0xa20 points to 0x547a, a stub that returns 0xe00002bc.
- The concrete RayDevice vtable overrides +0xa20 with 0xc9ca, the real audio-engine creation method.
- Base-class +0xa30 and +0xa38 also point to 0x5118 and 0x51b2.

### Explicit correction

The earlier provisional interpretation that +0xa30 was CreateAudioEngines() was wrong. It resulted from omitting the 16-byte Itanium ABI address-point prefix. The correct mapping is:

- +0xa30 = UsbSetConfiguration(1, false)
- +0xa38 = UsbRematchInterface(0), then conditionally UsbRematchInterface(6)
- +0xa20 = RayDevice::CreateAudioEngines()

The call arguments themselves independently support the corrected mapping: +0xa30 receives the two arguments expected by UsbSetConfiguration, and +0xa38 receives a single interface number.

## Relationship to the firmware-handshake research

The Mavericks one-byte request remains:

- bmRequestType=0xC0
- bRequest=0x85
- wValue=bool+1
- wIndex=0x0001
- wLength=1
- Response byte 0x01 causes another poll after approximately 300 ms, for up to 30 retries after the initial request.

The separate Linux boot-status request remains an 18-byte read using the same request type/code but wIndex=0, wLength=0x12, a 500 ms poll interval and up to 10 attempts. Linux then rereads the device descriptor, resets USB configuration and applies additional 48 kHz/24-bit requests.

The new vtable finding establishes the Mavericks call order around its own handshake. It does not prove that the Linux 18-byte request is an additional consecutive stage in the Mavericks sequence. Treat the two as independently observed OS-specific paths until further evidence resolves their relationship.

## Separate LatencyProfiler investigation

The property handler at 0x9f00 checks the name LatencyProfiler, parses a numeric suffix when present, and calls DigiHandshake::Do(int) at 0x9f66. The inspected routine performs stateful integer arithmetic and returns a 32-bit number. It does not itself issue a USB request. The caller and exact purpose of this property path remain untraced; it is not evidence of a USB firmware handshake and is set aside for now.

## What was not done

- No vendor-specific USB request was sent.
- No configuration change, interface rematch, USB reset, re-enumeration or endpoint transfer was performed on hardware.
- No hardware state was changed.
- No Apple USB service was stopped.
- No SIP or Startup Security setting was changed.
- The original driver was inspected read-only.

## Next step when work resumes

Inspect UsbSetConfiguration() at 0x5118 in a narrow disassembly window, then resolve the provider virtual methods it invokes (+0x5d0, +0x8c0, +0x5e0, and conditionally +0x5d8). Establish what configuration 1 and Boolean false mean in the original driver's provider path.

Do not send any hardware request based on this static analysis alone. Before proposing a vendor-specific or state-changing transfer, spell out the exact fields, payload, expected response, retry/timeout behaviour, risks and stop conditions, and obtain explicit user approval.

After configuration semantics are established, continue tracing the interface-rematch provider methods and the concrete RayDevice::CreateAudioEngines() implementation. Keep the already-confirmed user-space/IOUSBLib architecture and the established project milestone order unchanged.
