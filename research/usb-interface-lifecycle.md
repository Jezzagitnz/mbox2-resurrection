# Mbox 2 USB interface lifecycle research

**Date:** 5 November 2026  
**Reference binary:** Mavericks `DigidesignMbox2.kext`, x86_64  
**Status:** Static disassembly and symbol/relocation analysis; runtime behaviour not yet validated.

## Scope

This note records the USB interface wrapper and device-rematching work completed on 5 November. Addresses are specific to the inspected binary and must not be assumed stable across driver builds.

## Wrapper object and interface ownership

The class `MaudioShDrRayUsbInterface` contains these relevant methods:

| Method | Address |
|---|---:|
| `GetInterface() const` | `0x2150` |
| `SetInterface(IOUSBInterface*)` | `0x215e` |
| `SetAlternateInterface(unsigned int)` | `0x22a2` |

`SetInterface()` stores the supplied interface pointer at object offset `+0x88`. When replacing an existing pointer it calls the old object's vtable slot at byte offset `0x28`, then calls slot `0x20` on the new object before storing it. The IOUSBInterface vtable relocations identify these inherited slots as `OSObject::release()` and `OSObject::retain()`, respectively. This confirms the wrapper retains the new interface and releases the old one.

The method also resets state fields at offsets `+0x114`, `+0x118`, `+0x11c` and `+0x11e`.

## Alternate-interface operation

`SetAlternateInterface()` first releases an object held at `+0xc0), obtains the interface pointer at `+0x88`, then calls interface vtable slots at byte offsets `0x5d0`, `0x890` and `0x5d8`. The middle call receives the requested alternate-setting number; the first and final calls receive zero-valued arguments. The return value from the middle operation is preserved and returned.

The call sequence is structurally consistent with an interface access/open, alternate-setting change and close/release sequence. The exact method names for these virtual slots have **not** yet been established, so this interpretation remains provisional.

## Device initialisation and interface rematching

The device initialisation path calls:

1. `UsbSetConfiguration(1, false)`
2. `UsbRematchInterface(0)`
3. `UsbRematchInterface(6)`
4. `FirmwareHandshake(false)` on the relevant startup branches
5. The device-level `CreateAudioEngines()` entry point if the second rematch succeeds.

The method `UsbRematchInterface()` is at `0x51b2`. It obtains a provider pointer from `this+0xe0`, iterates interface-like objects using provider vtable slot `0x898`, compares a byte returned through object slot `0x8b0` with the requested interface number, and invokes object slot `0x5b0` with argument `2` when a match is found. It releases each candidate object through slot `0x28`.

Observed return paths include `0xe00002c2` when the provider is absent and `0xe00002f0` when no matching interface is found. A match returns zero.

The likely role of slot `0x8b0` is interface-number retrieval, but this has not been proven by relocation mapping. The meaning of slot `0x5b0` with argument `2` is unresolved. Neither should be assigned a method name yet.

## IOUSBInterface vtable mapping

The symbol table places `vtable for IOUSBInterface` at `0x387a0`. Using the Itanium ABI two-entry prefix, the address point used for virtual-slot offsets is `0x387b0`.

Relocation entries inspected so far confirm:

| Byte offset from address point | Resolved target |
|---|---|
| `0x20` | `OSObject::retain()` |
| `0x28` | `OSObject::release()` |

The remaining slots used by the Mbox wrapper/rematching code have not yet been resolved. Their corresponding addresses relative to the vtable address point are:

| Slot offset | Vtable address |
|---|---:|
| `0x5b0` | `0x38d60` |
| `0x5d0` | `0x38d80` |
| `0x5d8` | `0x38d88` |
| `0x890` | `0x39040` |
| `0x8b0` | `0x39060` |

The relocation dump previously examined ended at `0x38c00`, before these relevant entries. The next static-analysis step is to inspect the vtable relocation range through at least `0x39070`, then compare the resolved targets with the corresponding IOUSBInterface implementations and any relevant provider/subclass vtables.

## Evidence and limitations

**Confirmed from the inspected binary and relocation data:**
- The wrapper stores its `IOUSBInterface*` at `+0x88`.
- The wrapper uses the inherited retain/release slots at `0x20` and `0x28`.
- `SetAlternateInterface()` calls slots `0x5d0`, `0x890` and `0x5d8` in that order.
- Initialisation attempts to rematch interface numbers 0 and 6.
- The rematching loop uses provider slot `0x898`, candidate slots `0x8b0` and `0x5b0`, and releases candidates.

**Still unresolved:**
- Exact names and signatures for the virtual slots at `0x5b0`, `0x5d0`, `0x5d8`, `0x890`, `0x898` and `0x8b0`.
- Whether the provider and candidate objects use the base `IOUSBInterface` vtable or a subclass/other interface.
- The precise runtime meaning of the rematch operation and its argument `2`.
- The complete relationship between interface rematching, firmware handshake, and audio-engine creation.

These are static-analysis findings only. They do not establish that the same sequence succeeds on modern macOS or that audio streaming has started.
