---
name: LIN Profile Update
about: Review evidence before changing firmware model profiles
title: "Profile update: <model> <ID/payload>"
labels: ["profile", "evidence-required"]
---

## Proposed Change

- Model:
- Raw LIN ID:
- Payload bytes/meaning:
- Firmware file/constant to change:

## Evidence Gate

- [ ] At least two passive captures agree
- [ ] Analyzer action-window ranking supports the same ID
- [ ] Payload byte deltas are mapped for idle/up/down/click
- [ ] Checksum/parity validity confirmed
- [ ] No active command was run on vehicle bus

## Artifacts

- Capture 1 manifest:
- Capture 1 analyzer JSON:
- Capture 2 manifest:
- Capture 2 analyzer JSON:
- Notes/photos:

## Risk Review

- What is still uncertain?
- What bench replay/test should run before changing active profiles?