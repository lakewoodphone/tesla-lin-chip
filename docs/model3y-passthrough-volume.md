# Model 3/Y Passthrough Volume Program

This document describes the active passthrough direction implemented in `car_passthrough` firmware. It is separate from the proven passive receiver and bench active transmitter.

## Non-Negotiable Requirement

If the wheel buttons must keep working while this device is connected, the board must be inline passthrough hardware with two LIN transceivers.

A single-transceiver board can listen to one LIN bus, and it can inject on an isolated bench. It cannot separate the car-side LIN master from the steering-wheel-side responder. In a real inline install, the board has to preserve the native steering-wheel response and sometimes substitute a controlled response. That requires two electrical LIN domains:

```text
car side <-> LIN transceiver A <-> MCU proxy/cache <-> LIN transceiver B <-> wheel side
```

This is why one-LIN boards, including ESP32S3 CAN/LIN boards with a single TJA1021, are reference hardware only. They are not the final active-use topology.

## Why Passthrough Is Different

The current single-transceiver bench rig can transmit complete LIN master frames with `tx:`. That is useful on an isolated bench, but it is not a proper vehicle install because the car already has a LIN master. A production-style install must not fight the car's schedule master.

A true steering-wheel passthrough needs two LIN transceiver channels:

```text
car harness LIN side  <-> transceiver A <-> XIAO car UART
steering wheel LIN side <-> transceiver B <-> XIAO wheel UART
```

The firmware then behaves as a proxy:

1. It polls the wheel-side module and caches real responses.
2. It listens for car-side master headers.
3. When the car asks for ID `0x2A`, it responds immediately from cache.
4. If a volume injection is pending, it substitutes byte[0] on `0x2A` for a few frames.
5. For other known IDs, it forwards the cached wheel-side response.

This is not a literal bit-level bridge. LIN timing does not leave enough room to wait for the wheel-side slave after the car-side PID arrives, so the firmware uses cached wheel responses and immediate slave emulation on the car side.

Practical implication: native wheel buttons work only if the cache/proxy is healthy. If the board is unpowered, faulted, or removed, the harness must provide a simple physical bypass path.

## Build

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
python -m platformio run -e car_passthrough
```

Full build script now includes it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-all-envs.ps1
```

## Default Pins

| Side | RX | TX | Purpose |
|---|---:|---:|---|
| Car harness side | GPIO5 / D3 | GPIO4 / D2 | Respond to the vehicle LIN master |
| Steering wheel side | GPIO20 / D7 | GPIO21 / D6 | Poll the steering wheel module |

These defaults assume a second LIN transceiver and should be confirmed against the actual XIAO pinout and wiring before flashing for hardware tests.

## Commands

```text
version              Print firmware/build/reset info
config               Print runtime counters and pending injection state
stats                Same as config
safe:arm             Enable car-side responses
safe:off             Disable responses and clear pending injection
bridge:on            Enable bridge logic
bridge:off           Disable bridge logic without resetting counters
cache                Dump cached wheel-side frames
vol:up[:count]       Queue left-wheel volume-up frames, default count 6
vol:down[:count]     Queue left-wheel volume-down frames, default count 6
vol:click[:count]    Queue left-wheel click frames
vol:idle[:count]     Queue idle frames
inject:clear         Clear pending injection
```

Example bench command flow:

```text
safe:arm
cache
vol:up:8
config
safe:off
```

## Confirmed Volume Payload

The passthrough volume injection uses the confirmed Model 3/Y left wheel frame:

```text
ID 0x2A, PID 0x6A, 7 data bytes, enhanced checksum
```

Payload format:

```text
[control, 0x80, 0x3F, 0x96, 0x00, counter_a, counter_b]
```

Control byte:

```text
0x0C idle
0x0D volume up
0x0B volume down
0x2C click
```

Counter table is shared with `tools/inject-vol-scroll.py` and the active bench firmware.

## Safety Boundaries

- Do not connect `car_passthrough` to the vehicle until the second transceiver wiring is verified with no shorts.
- Do not use the one-transceiver bench wiring as a passthrough install.
- Do not leave the bridge armed unattended. `safe:arm` starts a 300-second active-session limit.
- If car-side misses increase, disarm immediately and inspect cache/wiring.
- If steering controls are still dead from the short event, restore the car first before any further vehicle-side tests.

## Validation Plan

1. Build `car_passthrough`.
2. Bench-wire two TJA1021 channels with shared ground and 12V bus power.
3. Use APG or the known XIAO active sender as a simulated car-side master.
4. Use the real steering wheel module or a second simulator on the wheel side.
5. Confirm `cache` fills for `0x28..0x2D` without checksum errors.
6. Confirm car-side master receives valid `0x2A` idle frames.
7. Queue `vol:up:8` and confirm the next `0x2A` responses contain `0x0D` with valid enhanced checksums.
8. Queue `vol:down:8` and confirm `0x0B` responses.
9. Run `safe:off` and confirm no further car-side responses are emitted.

Only after this bench proof should the design be considered for vehicle testing.
