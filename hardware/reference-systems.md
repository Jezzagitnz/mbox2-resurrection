# Reference systems

This document records the known systems used to understand and compare the original Mbox 2.

## Known-working legacy reference

| Item | Recorded value |
|---|---|
| Computer | 2012 Mac mini |
| Operating system | OS X Mavericks 10.9.5 |
| Build | `13F1911` |
| Interface | Original full-size Digidesign Mbox 2 |
| USB vendor ID | `0x0dba` |
| USB product ID | `0x3000` |
| USB device version | `1.38` |
| USB speed | 12 Mb/s |

The Mbox 2 is known to work on this system after installation of the relevant Pro Tools and Mbox driver software.

### Recorded driver components

- Avid CoreAudio plug-in: `com.avid.avid.AvidCoreAudioPlugIn`, version `10.3.10d613` (short version `10.3.10.613`).
- DigiDal: `com.digidesign.iokit.DigiDal`, version `10.3.10d4`.
- Mbox 2 kernel extension: `com.digidesign.mbox2.driver`, version `10.3.9f4` (short version `10.3.9.12`), x86_64 only.

This is the baseline against which modern-system observations should be compared.

## Other legacy-system observations

A Snow Leopard installation volume named **Pro Tools mBox** previously had a boot problem and displayed a “System extension cannot be used” message. A separate Yosemite environment was able to boot.

These observations do not establish whether the Mbox 2 driver itself worked in either environment. Booting an operating system and successfully initialising or streaming audio through the Mbox 2 are separate tests.

## Modern target

The primary modern target is an Apple M1 Pro MacBook Pro (model identifier `MacBookPro18,3`) running macOS `27.0.1`, build `26A434`, on `arm64`.

The Mbox 2 is detected by the USB system on this computer. Successful device-specific initialisation and audio streaming have not yet been established.

## Comparison principles

When comparing systems, record:

- Computer model and processor architecture.
- Operating-system version and build.
- Exact driver and utility versions.
- USB vendor ID, product ID, device version and speed.
- USB configurations, interfaces and endpoints.
- Device initialisation results and relevant logs.
- Whether CoreAudio sees the device.
- Whether actual input and output audio have been tested.

Keep observations from each system separate. Do not assume that a result on one operating system proves the same behaviour on another.
