"""
inject-vol-scroll.py  --  Send left/right wheel scroll frames to Tesla Model 3/Y via XIAO.

Archived 2026-05-28 after the guided Model 3 capture proved the active script
needed proper 7-byte Model 3/Y frames, counter handling, CRLF serial commands,
and explicit 0x-prefixed bytes to avoid the firmware parser treating 0D as an
empty decimal prefix.

Original quick script preserved for traceability only. Do not use for active work.
"""

import serial
import time
import sys

PORT = "COM7"
DIRECTION = "up"
COUNT = 8
WHEEL = "left"

if len(sys.argv) > 1: PORT = sys.argv[1]
if len(sys.argv) > 2: DIRECTION = sys.argv[2].lower()
if len(sys.argv) > 3: COUNT = int(sys.argv[3])
if len(sys.argv) > 4: WHEEL = sys.argv[4].lower()

LIN_ID = "2A" if WHEEL == "left" else "2B"
B0 = "0D" if DIRECTION == "up" else "0B"

FRAME_CMD = f"tx:{LIN_ID},{B0},80,3F,94,00,00,0B\n".encode()

print(f"Port:      {PORT}")
print(f"Wheel:     {WHEEL}  (ID 0x{LIN_ID})")
print(f"Direction: {DIRECTION}  (byte[0]=0x{B0})")
print(f"Frames:    {COUNT}")
print()

try:
    ser = serial.Serial(PORT, 115200, timeout=2)
except Exception as e:
    print(f"ERROR opening {PORT}: {e}")
    sys.exit(1)

time.sleep(0.6)

def send_and_print(cmd: bytes, label: str):
    ser.write(cmd)
    time.sleep(0.15)
    raw = ser.read(512)
    if raw:
        print(f"[{label}] {raw.decode(errors='replace').strip()}")

send_and_print(b"safe:arm\n", "arm")
time.sleep(0.1)

for i in range(COUNT):
    send_and_print(FRAME_CMD, f"tx {i+1}/{COUNT}")
    time.sleep(0.08)

send_and_print(b"safe:off\n", "disarm")

ser.close()
print("\nDone.")
