# Mbox 2 hardware detection session — 18 November 2026

**Test system:** Apple M1 Pro MacBook Pro, running the project's modern macOS target
**Device:** Original full-size Digidesign Mbox 2
**Application:** mBox 2 Control
**Session type:** Initial application-level hardware detection check

## Observations

- The mBox 2 Control application reported the connected Mbox 2 as **Detected**.
- The physical Mbox 2 indicator lights did not change during this detection check.
- The observed indicator state remained: USB indicator off; mono indicator on.
- A USB-B to USB-C cable has now been located for a later connection test. That cable has **not yet been tested** as part of this session.

## Interpretation

The application-level detection result is a useful confirmation that the current detection path recognises the device. It must not be conflated with successful device initialisation or working audio.

The unchanged indicator state means the physical feedback has not yet shown a corresponding change during this test. This observation alone does not identify which initialisation stage has or has not completed.

The USB-B to USB-C cable test remains an open test item. No conclusion can yet be drawn about whether changing the cable or host connector will affect detection, device initialisation, indicator behaviour, or audio operation.

## Next test

When convenient, repeat the connection check using the located USB-B to USB-C cable. Record:

1. Whether the application still reports the Mbox 2 as detected.
2. Whether the USB and mono indicators change.
3. Whether macOS USB device identity and connection details remain consistent.
4. Whether any additional initialisation or audio-format status becomes available.

Keep the result of the cable test separate from this session so that the connection method and outcome are unambiguous.

## Status

| Milestone | Result |
|---|---|
| Application reports Mbox 2 detected | Confirmed |
| Physical indicator state changes during detection | No change observed |
| USB-B to USB-C cable located | Confirmed |
| USB-B to USB-C cable tested | Pending |
| Firmware/device initialisation confirmed | Not established |
| Audio input/output confirmed | Not established |
