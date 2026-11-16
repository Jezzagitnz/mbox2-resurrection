# Initial USB Open Experiment

These files preserve an early experimental implementation of the
Mbox 2 DriverKit service.

The experiment attempted to:
- Open the USB device provider.
- Read and log the USB device descriptor.
- Close the device during the Stop lifecycle method.

This code is archival only. It is not the active driver implementation.

No successful device activation, USB ownership, descriptor read,
firmware communication, or audio operation is established by
preserving these files.

The active implementation is maintained under Driver/Sources/.
