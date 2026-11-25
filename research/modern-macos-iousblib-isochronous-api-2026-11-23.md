# Modern macOS IOUSBLib isochronous API compatibility (23 November 2026)

## Scope

This note records a read-only inspection of the IOUSBLib declarations in the macOS SDK selected by Xcode on the Apple Silicon development Mac. It answers a narrow API-availability question for the future Mbox 2 user-space audio transport.

It does **not** demonstrate that an Mbox 2 isochronous transfer works, that a particular interface can be opened, or that any Mbox 2 endpoint, alternate setting, packet size, feedback format or scheduling value has been identified.

## SDK header inspected

The active SDK was resolved using:

```sh
xcrun --sdk macosx --show-sdk-path
```

The relevant header is:

`System/Library/Frameworks/IOKit.framework/Headers/usb/IOUSBLib.h`

The same header is also present through the framework's versioned `Versions/A/Headers/usb/IOUSBLib.h` path.

## Findings

### IOUSBInterfaceInterface192

The `IOUSBInterfaceStruct192` declaration includes:

- `ReadIsochPipeAsync()`
- `WriteIsochPipeAsync()`
- `LowLatencyReadIsochPipeAsync()`
- `LowLatencyWriteIsochPipeAsync()`

Therefore, low-latency isochronous read/write entry points are not exclusive to interface version 500.

### IOUSBInterfaceInterface500

The `IOUSBInterfaceStruct500` declaration includes the standard asynchronous isochronous read/write methods and the low-latency read/write methods. It also declares supporting operations including:

- `LowLatencyCreateBuffer()`
- `LowLatencyDestroyBuffer()`
- `GetBusMicroFrameNumber()`
- `GetFrameListTime()`
- `GetIOUSBLibVersion()`

The SDK declarations therefore provide both standard and low-latency asynchronous isochronous paths through interface version 500, together with buffer-management and timing helpers.

### Low-latency buffer requirements

The header documentation states that the low-latency path uses preallocated buffers and frame lists created with `LowLatencyCreateBuffer()`. Those buffers must be released with `LowLatencyDestroyBuffer()`. The interface must be open before the low-latency transfer methods are used.

The documented `updateFrequency` parameter accepts 0–8 milliseconds. A value of zero means the frame list is updated only when the transfer completes; nonzero values request updates at the selected primary-interrupt frequency. This is API documentation, not a recommended Mbox 2 setting.

The header defines these buffer-type constants:

| Constant | Value | Meaning |
|---|---:|---|
| `kUSBLowLatencyWriteBuffer` | 0 | Write buffer |
| `kUSBLowLatencyReadBuffer` | 1 | Read buffer |
| `kUSBLowLatencyFrameListBuffer` | 2 | Frame-list buffer |

## Engineering conclusion

There is no need to select interface version 500 solely to obtain low-latency isochronous methods: interface version 192 also declares low-latency read/write entry points. Version 500 offers additional declared helpers, including explicit low-latency buffer allocation/destruction and bus microframe/frame-list timing methods.

This is a declaration-level compatibility finding only. The next implementation choice must be based on the exact supported API contract, the target macOS runtime, safe ordinary interface access, and verified Mbox 2 requirements—not on the presence of a method name alone.

The SDK inspection does **not** resolve:

- Which Mbox 2 streaming interface or endpoint uses each direction or transfer class.
- Which alternate settings are required.
- The Mbox 2 packet sizes, frame-list lengths, queue depth or feedback units.
- The meaning of the legacy USB-interface vtable calls at offsets `+0x1f8` and `+0x200`.
- Whether low-latency or standard asynchronous transfers are preferable for the actual Mbox 2 implementation.

Do not copy Eleven Rack endpoint numbers, packet limits, feedback assumptions or scheduling values. Do not send transfers or change interface state as part of this SDK-only finding.

## Validation boundary

This was a header/source inspection on the development Mac. It was not a USB hardware test, runtime API invocation, compile/link test of a transport implementation, or audio-streaming test.
