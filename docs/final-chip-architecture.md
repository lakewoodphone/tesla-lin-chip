# Final Active-Capable Chip Architecture

Status: planning document. Do not treat this as a released PCB design.

## Product Modes

| Mode | TX code compiled | TX hardware allowed | Intended use |
|---|---:|---:|---|
| `field_passive` | No | No | Vehicle capture and passive diagnostics |
| `bench_active_ble` | Yes | Bench only | XIAO/TJA1021/APG isolated validation |
| `chip_lab_active` | Yes | Controlled lab only | Final-chip engineering validation |

## Hardware Blocks

```text
Vehicle 12V
  -> fuse / resettable protection
  -> reverse polarity protection
  -> transient TVS
  -> automotive buck regulator
  -> 3V3 MCU rail

Vehicle LIN
  -> ESD protection
  -> automotive LIN transceiver
  -> MCU RX
  -> gated MCU TX path

Active gate
  physical arm switch/jumper
  MCU TX enable GPIO
  default-passive pull resistor
  fault latch / watchdog reset behavior

Service/debug
  USB/UART pads
  SWD/JTAG or boot pads if supported
  LEDs: power, RX, armed, TX, fault
  test pads: 12V, 5V/3V3, LIN, TXD, RXD, EN, GND
```

## Electrical Requirements

- Reset, brownout, firmware crash, unprogrammed MCU, and bootloader mode must leave TX disabled.
- BLE cannot enable TX unless the physical arm path is present.
- The physical arm control must be visible on a test pad and reflected in firmware `config` output.
- LIN line must have ESD protection and a test point near the connector.
- Power input must tolerate reverse polarity and common automotive transients appropriate for a lab accessory.
- The device must have a fast physical removal/bypass path.

## Candidate BOM Classes

| Function | Requirement | Candidate class |
|---|---|---|
| MCU | BLE, UART LIN, NVS, watchdog | ESP32-C3 module or automotive-suitable MCU+BLE module |
| LIN transceiver | 12V LIN physical layer | Automotive LIN transceiver with sleep/enable pin |
| Regulator | 12V to logic rail | Automotive buck or protected DC/DC module |
| Protection | Vehicle rail and LIN protection | Fuse/PTC, TVS, ESD array, reverse protection MOSFET/diode |
| Active gate | Default-passive TX isolation | Analog switch, logic gate, or transceiver enable path with passive default |
| Connector | Strain-relieved harness | Keyed locking connector, labeled service disconnect |

## Firmware Requirements

- Boot in `SAFE_PASSIVE` every time.
- Load model/mode/period config only after CRC/version validation.
- Never persist active enable state.
- Require physical arm and software `safe:arm` before TX.
- Rate-limit TX and force timeout to `safe:off`.
- Log boot reason, config CRC, arm transitions, TX count, inhibit count, and last fault.
- BLE status characteristic must expose build, active state, arm state, model, TX count, and last inhibit/fault.

## Rev A Exit Gate

- Passive RX decodes APG frames at 19200 on the fixture.
- TX is electrically disabled on reset, brownout, firmware crash simulation, and unarmed state.
- With arm present and software armed, bench active proof passes.
- Removing physical arm during active session stops TX.
- BLE `on` fails before arming and succeeds after arming.
- Test jig report includes serial number, firmware hash, current draw, rail voltages, LIN idle voltage, RX proof, TX proof, and final `safe:off` proof.