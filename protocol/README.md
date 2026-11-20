# Transport-independent Mbox 2 protocol core

This small C++17 library records protocol facts that can be tested without a connected Mbox 2 or a particular USB API.

It deliberately contains no USB transport, device discovery, interface claiming, device capture, audio I/O, or system configuration. The same protocol code can later be called from either a USBDriverKit service or an ordinary IOUSBHost helper.

## Currently represented

- The one-byte Mavericks firmware-handshake request shape and retry condition.
- The distinct 18-byte Linux boot-status request and response-byte interpretation.
- The explicit 44.1 kHz and 48 kHz entries in the inspected Mavericks driver's valid-rate table.

The Mavericks and Linux request variants remain separate. They share request type/code but differ in value, index, response length and polling behaviour. Their relationship has not been established, so this library does not combine them or invent an order between them.

The Boolean passed to the Mavericks request builder is intentionally named only `flag`; its higher-level meaning is not assigned here. Likewise, the rate table does not claim that every rate is available in every bit-depth, clock or stream mode.

## Build and test

From the repository root:

```sh
cmake -S protocol -B build/protocol
cmake --build build/protocol
ctest --test-dir build/protocol --output-on-failure
```

The tests are hardware-independent and use only the C++ standard library.
