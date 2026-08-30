# How the P2 MAX hides Advanced/Chipset — and how to turn them on

**Found and verified in the ROM.** The pages are hidden by a CMOS-gated branch compiled into
AMI's own setup browser (`AMITSE`). No reflash is needed to unlock them.

## The mechanism

`AMITSE` (GUID `B1DA0ADF-4F77-4070-A88E-BFFE1C60529A`), while building the top-level menu:

1. Reads **CMOS upper-bank index `0x44`** through I/O ports `0x72`/`0x73`.
2. If that byte is **not `0xAA`**, it skips exactly **FormId `0x2712` (Advanced)** and
   **FormId `0x2713` (Chipset)** while promoting the other four pages to tabs.
   Skipped pages keep `ParentIdx = 1`, so they stay children of container form `0x2710`
   and are never drawn.
3. Immediately after, it writes **`0xFF` back** to CMOS `0x44` — so the unlock is **one-shot**.

Verified bytes in the extracted `AMITSE` PE32 (file offset == RVA in this image):

| Offset | Bytes | Meaning |
|---|---|---|
| `0x32BE0` | `BA 72 00 00 00 B0 44 EE BA 73 00 00 00 EC 44 8A F0` | `mov edx,0x72` / `mov al,0x44` / `out dx,al` / `mov edx,0x73` / `in al,dx` / `mov r14b,al` |
| `0x32C27` | `41 80 FE AA 74 16 B8 12 27 00 00 66 39 43 0A 74 51 B8 13 27 00 00 66 39 43 0A 74 46` | `cmp r14b,0xAA` / `je normal` / `mov eax,0x2712` / `cmp [rbx+0xA],ax` / `je skip` / `mov eax,0x2713` / `cmp` / `je skip` |
| `0x32CBC` | `BA 72 00 00 00 B0 44 EE BA 73 00 00 00 B0 FF EE` | write `0xFF` to CMOS `0x44` |

All three re-verified independently against the committed `P2MAX029.bin`. A scan for
"write `0xAA` to index `0x44`" returns **zero** occurrences anywhere in the BIOS region — so
nothing in the firmware ever sets it. It is an externally-poked factory/service unlock, which is
why no key combination reveals these pages.

## Two dead ends, now closed

- **The IFR is not the mechanism.** The top-level Refs for all six pages are unconditional, and
  the six `$SPF` form records in `AMITSESetupData` are byte-for-byte parallel. Editing the IFR or
  the form data would achieve nothing.
- **TAB / F9 at POST are a different feature.** They set CMOS `0x60` / `0x61` to `0xAA`, which
  feed a `/RecoveryBCD` boot path — unrelated to the page gate. Don't confuse them.

## Procedure

Free pre-flight that confirms the whole analysis on the live machine: **read CMOS `0x44` first.**
It should read `0xFF`, because the write-back path runs on every boot. If it does, the analysis is
confirmed against the actual hardware before we change anything.

In OpenShell (Space at the OpenCore picker to reveal it):

```
mm 0x72 0x44 -w 1 -IO -n
mm 0x73 -w 1 -IO -n
```

The second command prints the current value — expect `0xFF`.

Then arm the unlock and reboot straight into setup:

```
mm 0x72 0x44 -w 1 -IO -n
mm 0x73 0xAA -w 1 -IO -n
reset
```

Press **DEL** during POST. Advanced and Chipset should now be tabs.

Check `mm -?` for your shell build's exact flag spelling if it rejects the syntax.

## Notes

- **One-shot by design.** The firmware resets the byte to `0xFF` as it uses it, so re-arm before
  every boot in which you want the pages. That is the firmware's behaviour, not a mistake on our part.
- **Risk is low and reversible.** We are writing a value the firmware itself writes to the same
  index; the byte is used only by this gate. Worst realistic case is a CMOS checksum complaint and
  a defaults reload, which is self-healing — and `Setup-factory-default.bin` holds every setting
  byte-exact if anything needs restoring.
- **No reflash, no disassembly, no SPI programmer.** This is why the ROM-patch route is not needed.
