# GPD P2 MAX — OpenCore for macOS Tahoe

Working OpenCore config for the **GPD P2 MAX (2019, Core m3-8100Y, Amber Lake-Y)**
on **macOS Tahoe 26.6.2** (Darwin 25.6.0), OpenCore 1.0.7.

Built on top of [rowell1/GPD-P2-Max-2019-Hackintosh](https://github.com/rowell1/GPD-P2-Max-2019-Hackintosh),
which did the original hardware bring-up for this machine — framebuffer patches,
`layout-id`, USB map, SMBIOS choice and the kext set all come from that work and
the credit for them belongs there. This repo is the delta: what had to change for
Tahoe, plus three defects found along the way.

> ⚠ **Generate your own SMBIOS before using this.** `PlatformInfo > Generic` here
> has `MLB`, `SystemSerialNumber`, `SystemUUID` and `ROM` blanked on purpose. Use
> [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS). Copying someone else's serials
> means impersonating their Mac to Apple's activation servers, which is a good way
> to get **their** iMessage/iCloud flagged as well as your own.

## What's fixed here

### Three defects inherited from the reference config

**1. `SSDT-PTSWAK.aml` breaks sleep entirely — remove it.**
It declares `External (ZPTS, MethodObj)` / `External (ZWAK, MethodObj)` and calls
them from `_PTS`/`_WAK`, but **nothing anywhere defines `ZPTS` or `ZWAK`**. `_PTS`
aborts on the undefined call, so `TPTS`/`SPTS`/`NPTS`/`RPTS` never run — the EC is
never told about S3 and the PM registers are never saved. Every S3 resume then dies
with `Sleep Wake failure … 0x1F EFI/Bootrom Failure`. Bisected to this table alone:
disabling it gave 5/5 clean wakes where the same machine had 0/5 before.

**2. `SSDT-PM.aml` never loads.** It and `SSDT-PLUG.aml` both define `_DSM` on
`\_PR.PR00`. PLUG loads first, so SSDT-PM is rejected on every boot
(`[_DSM] AE_ALREADY_EXISTS` + `1 table load failures`). Nothing is lost by removing
it — its `APSN`/`APSS`/`ACST` are legacy `AppleIntelCPUPowerManagement` objects and
this machine runs XCPM — but as shipped it is silently dead weight.

**3. `Kernel > Block` on `IOSkywalkFamily` is unbounded** (`MinKernel 24.0.0`, no
`MaxKernel`) while the replacement kext is capped at `24.9.9`. On macOS 25+ that
blocks Apple's Skywalk with nothing replacing it. **A block and the kext that
replaces it must be gated identically.**

### Added here

| file | what it does |
|---|---|
| `ACPI/SSDT-LIDFIX.dsl` | makes the lid work — see `docs/LID-GPE50.md` |
| `ACPI/SSDT-BATSTA.dsl` | `ECAV`-guards `BAT0._STA`; takes boot ACPI errors from 18 to **0** |
| `itlwm-patch/` | itlwm VHT-width clamp + **prebuilt kext** — upstream [OpenIntelWireless/itlwm#1067](https://github.com/OpenIntelWireless/itlwm/pull/1067) |
| `picker/` | OpenCanopy assets and a macOS volume icon |

**Lid** — the lid is an EC query. `_Q0C` reads `LSTE`, then calls `^^^GFX0.GLID(LIDS)`
and aborts there, never reaching `Notify(LID0, 0x80)`. Overriding `_Q0C`/`_Q0D` with a
bare unconditional Notify fixes it. macOS *does* dispatch EC `_Qxx` — do **not**
"fix" this by taking GPE 0x50 away from `AppleACPIEC`; that breaks the power button
and the Fn keys, which ride the same dispatch path. The full reasoning, including
that wrong turn, is in `docs/LID-GPE50.md`.

**Wi-Fi** — two separate faults. `DisableIoMapper=False` (AppleVTD) means the Intel
7265 is never IOMMU-mapped, so **every** driver loads and binds nothing, silently.
And itlwm's `ieee80211_vht_negotiate()` takes the channel width from the AP's
advertised capability without intersecting it with the card's own, so a 160 MHz AP
makes a 2×2/80 MHz part program a PHY context the firmware can't execute
(`ADVANCED_SYSASSERT`). See `docs/WIFI-VTD.md`.

## BIOS: unlocking the hidden Advanced / Chipset menus

GPD hides **Advanced** and **Chipset** behind a CMOS gate compiled into AMI's own
setup browser (`AMITSE`), not behind the IFR. Full analysis in `bios/`.

### The safe way — one-shot, no reflash

`AMITSE` reads CMOS upper-bank index `0x44` via ports `0x72`/`0x73`; if it isn't
`0xAA` it skips FormIds `0x2712` (Advanced) and `0x2713` (Chipset), then writes
`0xFF` back — so the unlock is **one-shot**. From OpenShell:

```
mm 0x72 0x44 -w 1 -IO -n     # confirm it reads 0xFF first
mm 0x73 -w 1 -IO -n

mm 0x72 0x44 -w 1 -IO -n     # arm
mm 0x73 0xAA -w 1 -IO -n
reset
```

Both pages appear on that boot only. **This is reversible and touches no firmware** —
start here.

### The permanent way — patched BIOS ⚠ CAN BRICK YOUR MACHINE

In `AMITSE` (GUID `B1DA0ADF-4F77-4070-A88E-BFFE1C60529A`), PE32 offset `0x32C2B`:
`0x74` (je) → `0xEB` (jmp), making the CMOS gate unconditional.

> ⚠⚠ **Patch YOUR OWN DUMP — not the vendor image.** `P2MAX029.bin` (the image
> inside GPD's updater) is **generic**, not a dump of your machine. Flashing it
> wholesale overwrites per-unit content.

```bash
# 1. Get the stock vendor image OFF the machine first - recovery material,
#    useless sitting on a device that won't boot.

# 2. Dump THIS machine's BIOS region - read-only, no risk:
FPTW64.exe -d mybios.bin -BIOS

# 3. Apply the AMITSE patch to *that dump* (UEFIPatch), producing mybios-unlocked.bin

# 4. Flash it back:
FPTW64.exe -f mybios-unlocked.bin -BIOS

# 5. VERIFY by reading back - do not trust the success message:
FPTW64.exe -d after.bin -BIOS
#    md5(after.bin) must equal md5(mybios-unlocked.bin), and AMITSE 0x32C2B must read 0xEB
```

**Keep `mybios.bin`. It is your restore path:** `FPTW64.exe -f mybios.bin -BIOS`.

> ⚠⚠ **Do not talk yourself into this being low-risk.** `AMITSE` is LZMA-compressed,
> so the change requires decompress → patch → recompress → rebuild. **At image level
> 2,582,061 bytes differ across 10,038 runs.** "Only one byte changes" is true only of
> the *extracted module*. The whole BIOS region is rewritten. Verify structurally:
> extract both images, confirm exactly one module differs and only by the intended
> byte, and that the Descriptor and ME regions are byte-identical.

⚠ **Flashing trap that will waste your time:** `FPTW64.exe -f <img> -ME` — `-ME` is a
**region selector**, not a modifier; it writes only the ME region. GPD's `V029.exe` is
AFUWINx64 with a complete 8 MiB image appended as a PE overlay, self-invoked with no
filename, so it flashes **its own embedded image** and ignores yours. Renaming a
patched file into that flow silently reflashes stock and leaves you concluding the
analysis was wrong.

For reference, the successful flash here: Intel FPT 11.6.1.1142, flash device
**GD25B64B** (`ID:0xC84017`, 8192 KB), descriptor Valid. FPT wrote **differentially** —
2536 KB, matching the changed range — and the read-back was byte-identical to the
intended image.

No firmware images are included in this repo: a dump contains your unit's serial, UUID
and MAC, and redistributing the vendor image is a separate matter. Produce your own
per the steps above.

## Status

Working: sleep/wake (incl. on battery), lid, power button, Fn keys, Wi-Fi 802.11ac
(312↑/378↓ Mbit/s measured), audio, battery, graphical picker + boot chime,
**0 ACPI errors at boot**.

Not working / not possible: charge limiting (the EC exposes no threshold to *any* OS —
Linux has no `charge_control_end_threshold` either), USB-keyboard wake (disabled by
design in `SSDT-XPRW` to prevent instant-wake).

## Credits

- [rowell1](https://github.com/rowell1/GPD-P2-Max-2019-Hackintosh) — original bring-up
- [Acidanthera](https://github.com/acidanthera) — OpenCore, Lilu, VirtualSMC, WhateverGreen, AppleALC
- [OpenIntelWireless](https://github.com/OpenIntelWireless) — itlwm / AirportItlwm
