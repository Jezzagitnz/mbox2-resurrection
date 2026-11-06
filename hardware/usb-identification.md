# USB identification

## Recorded device identity

The original full-size Digidesign Mbox 2 has been identified by these USB values:

| Field | Hexadecimal | Decimal |
|---|---:|---:|
| Vendor ID | `0x0dba` | 3514 |
| Product ID | `0x3000` | 12288 |

The recorded device version on the known-working Mavericks system is `1.38`.

The device is reported at **12 Mb/s**, which is USB Full Speed.

## Meaning of USB detection

When macOS lists the device as Digidesign Mbox 2 with the expected vendor and product IDs, this confirms that the USB system has detected and identified it.

It does not establish that the device-specific firmware handshake has completed, that the audio interfaces are usable, or that audio is being transferred.

Keep these milestones distinct:

1. **Enumeration** — the USB host detects the device and reads its identity.
2. **Interface access** — the required USB interfaces can be claimed and used.
3. **Device initialisation** — the Mbox-specific setup and handshake complete.
4. **Audio engine setup** — the driver configures the audio paths and formats.
5. **Streaming** — real audio data is successfully captured or played.

## Further USB evidence to collect

For both the Mavericks reference and the modern target, record:

- Full device descriptors.
- Configuration descriptors.
- Interface numbers and alternate settings.
- Endpoint addresses and transfer types.
- Endpoint packet sizes and intervals.
- Any class-specific audio descriptors.
- Any vendor-specific control requests used during initialisation.
- Which operating-system component claims each interface.

Where possible, preserve the raw descriptor output as well as a human-readable summary.

## Interpretation cautions

- Do not infer support for 24-bit audio or a particular sample rate from the USB identity alone.
- Do not assume that USB Full Speed prevents a particular audio mode without analysing the actual transport and bandwidth requirements.
- Do not treat a generic Apple USB audio component appearing in logs as proof that the device-specific driver is functioning.
- Do not assume that other Mbox-family products share these identifiers or descriptors.
