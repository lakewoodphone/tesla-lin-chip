from __future__ import annotations

import re
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent
TERMS = (b"TXD", b"RXD", b"SLP", b"WAKE", b"INH", b"Pinning", b"pinning")


def clean(data: bytes) -> bytes:
    return re.sub(rb"[^\x09\x0a\x0d\x20-\x7e]+", b" ", data)


for path in sorted(ROOT.glob("*.pdf")):
    data = path.read_bytes()
    print(f"\n==== {path.name} {len(data)}")
    hit_count = 0
    for match in re.finditer(rb"stream\r?\n(.*?)\r?\nendstream", data, re.S):
        stream = match.group(1)
        text = b""
        for raw in (stream, stream.strip(b"\r\n")):
            try:
                text = zlib.decompress(raw)
                break
            except Exception:
                pass
        if not text:
            text = stream
        payload = clean(text)
        if not any(term in payload for term in TERMS):
            continue
        for term in TERMS:
            idx = payload.find(term)
            if idx != -1:
                start = max(0, idx - 500)
                end = min(len(payload), idx + 1500)
                print("---hit---")
                print(payload[start:end].decode("latin1", "replace"))
                hit_count += 1
                break
        if hit_count >= 12:
            break