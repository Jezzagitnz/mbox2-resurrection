# Firmware handshake investigation

## Purpose

The original Mavericks Mbox 2 driver contains a multi-stage device handshake. Understanding this sequence is likely to be essential before a modern implementation can initialise the hardware reliably.

This document records the current disassembly findings and separates them from questions that still need evidence.

## Identified code

The following locations were identified in the inspected x86_64 Mavericks driver:

| Item | Address |
|---|---:|
| `FirmwareHandshake` | `0x4fc6` |
| `HandleDigiHandshakeProperty` | `0x9f00` |
| `DigiHandshake::Do` | `0x9f66` |
| Stage 1 helper | `0xa174` |
| Stage 4 helper | `0xa1a8` |
| Stage 2 helper | `0xa1da` |
| Stage 3 helper | `0xa1e6` |

The main routine compares its stage value against 4, consistent with five possible stage values: 0, 1, 2, 3 and 4.

The handshake-related property handler checks a property named `LatencyProfiler`.

## Current interpretation

The code structure indicates a staged handshake or initialisation process. The helper locations suggest that individual stages have separate handling routines.

This is a structural interpretation of the disassembly. The actual purpose and USB operation of each stage have not yet been fully established.

## Important unanswered questions

- What operation, if any, is performed for stage 0?
- What USB control request or other operation is issued by each stage?
- What are the exact request type, request, value, index and data fields?
- What response is expected, and how is it checked?
- Does a stage change firmware state, configure hardware, or confirm readiness?
- Are the same stages used for every Mbox 2 hardware and firmware revision?
- At what point can the audio engine safely start?
- What does the legacy utility's green “locked” indicator actually represent?

The green indicator must not currently be described as proof of S/PDIF clock lock. It may indicate device communication or successful initialisation instead; this remains an open question.

## Evidence recording template

Use a table like this when the USB operations are mapped:

| Stage | Trigger / input | USB operation | Data sent | Response | Resulting state | Evidence |
|---|---|---|---|---|---|---|
| 0 | To be determined | To be determined | To be determined | To be determined | Unknown | Pending |
| 1 | To be determined | To be determined | To be determined | To be determined | Unknown | Pending |
| 2 | To be determined | To be determined | To be determined | To be determined | Unknown | Pending |
| 3 | To be determined | To be determined | To be determined | To be determined | Unknown | Pending |
| 4 | To be determined | To be determined | To be determined | To be determined | Unknown | Pending |

Do not fill unknown fields by inference. Record the source binary, relevant function and surrounding instructions for each conclusion.

## Next steps

1. Examine each stage helper and its callers.
2. Trace the USB request functions and arguments used by each stage.
3. Identify response checks, retries, timeouts and error paths.
4. Compare the code path with observed behaviour on the working reference system.
5. Record which parts are directly established and which remain interpretations.
