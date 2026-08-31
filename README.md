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

## What's included

**OpenCore 1.0.7** (DEBUG build — console logging only, no ESP writes)

| Kext | Version | | Kext | Version |
|---|---|---|---|---|
| Lilu | 1.7.2 | | ECEnabler | 1.0.6 |
| VirtualSMC (+SMCProcessor, SMCSuperIO, SMCBatteryManager) | 1.3.7 | | RestrictEvents | 1.1.6 |
| WhateverGreen | 1.7.0 | | FeatureUnlock | 1.1.8 |
| AppleALC | 1.9.7 | | BrightnessKeys | 1.0.3 |
| NVMeFix | 1.1.3 | | AMFIPass | 1.4.1 |
| RTCMemoryFixup | 1.0.7 | | NullEthernet (+`SSDT-RMNE`) | 1.0.6 |
| HibernationFixup | 1.5.4 | | **VoodooI2C** (+HID, Input, GPIO) | **2.9.1** ⚠ |
| SystemProfilerMemoryFixup | 1.0.0 | | **itlwm-Tahoe (patched)** | **2.4.0** |
| IntelBluetoothFirmware / Injector | **2.5.1** | | BlueToolFixup | 2.7.2 |
| **VoodooI2CGoodix** (touchscreen) | `master` @ `df42eb3` ⚠ | | | |

⚠ **VoodooI2C and VoodooI2CGoodix must both be built from source** — see
[`touchscreen/`](touchscreen/). Neither project has a release that works here, and using the
released binaries gets you a dead touchscreen no matter what else is correct:

- **Every** published `VoodooI2CGoodix` release — 0.3.1 (2020) *and* 0.4.0 (2023) — declares
  `com.apple.iokit.IOGraphicsFamily` and **cannot load under OpenCore at all**. The fix is
  commit [`df42eb3`](https://github.com/lazd/VoodooI2CGoodix/commit/df42eb3) (2024-08-21),
  which landed **after** the 0.4.0 tag and has never been released.
  ⚠ **The version number will not tell you which build you have** — a source build from
  `master` also reports `CFBundleVersion 0.4.0`. Check the kext instead:
  `/usr/libexec/PlistBuddy -c "Print :OSBundleLibraries" VoodooI2CGoodix.kext/Contents/Info.plist`
  — if `IOGraphicsFamily` appears, that build cannot load.
- **VoodooI2C 2.8 cannot drive this machine's I²C bus.** 2.9.1 can, and has no release either.

⚠ **IntelBluetoothFirmware must be 2.5.1+** — upstream 2.4.0 hard-codes `KernelVersion::Sequoia`
as its maximum, loads on Tahoe and deliberately does nothing. Use the
[lshbluesky fork](https://github.com/lshbluesky/IntelBluetoothFirmware) until upstream ships one.

`AirportItlwm` 2.3.0 (BigSur→Sequoia) and `IOSkywalkFamily`/`IO80211FamilyLegacy` are present but
kernel-gated to ≤24.9.9. **They do not work on Tahoe** — AirportItlwm binds but every scan returns
`Apple80211Scan err[22] EINVAL`. Tahoe uses `itlwm` + [HeliPort](https://github.com/OpenIntelWireless/HeliPort).

**UEFI drivers:** OpenRuntime, OpenHfsPlus, ResetNvramEntry, OpenCanopy, AudioDxe

**ACPI:** `SSDT-LIDFIX`, `SSDT-BATSTA`, `SSDT-UPCFIX`, `SSDT-XOSI`, `SSDT-BATT`, `SSDT-PLUG`,
`SSDT-PNLF`, `SSDT-RMNE`, `SSDT-UIAC`, `SSDT-USBX`, `SSDT-XPRW`, `SSDT-XPTS`, `SSDT-XWAK`

## What works

- **Sleep / wake** — including idle sleep on battery and RTC wake
- **Lid** close/open, **power button** (short press sleeps, ~2 s hold gives the shutdown dialog), **Fn keys**
- **Wi-Fi** 802.11ac — 312 ↑ / 378 ↓ Mbit/s measured (needs HeliPort running; add it to Login Items)
- **Bluetooth**, **audio** (see below), **battery**, **backlight**, **trackpad**
- **Touchscreen** — Goodix GT928, full multitouch: drag, two-finger scroll, pinch-to-zoom,
  rotate, accurate tracking across the panel (see [`touchscreen/`](touchscreen/))
- **Graphical boot picker** + startup chime
- **0 ACPI errors at boot**
- Battery: ~6.0 W idle with `lowpowermode`, ~3.3–3.7 h real use

## What doesn't work

- **Fingerprint sensor** — no macOS driver
- **USB-keyboard wake from sleep** — by design. `SSDT-XPRW` forces `_PRW` wake-state to `0` for
  **GPE 0x6D** (which carries `XHC.GPEH`) under Darwin, the standard fix for instant-wake.
  ✅ **Lid open and the power button both wake the machine reliably** — only the keyboard doesn't.
  Re-enabling USB wake risks reintroducing instant wake-from-sleep
- **Battery charge limiting / Optimized Battery Charging** — impossible on this hardware. The EC
  exposes no threshold to *any* OS: Linux has no `charge_control_end_threshold` either, there are no
  `CH0B`/`CH0C`/`BCLM` SMC keys, and the BIOS has no such option
- **HDMI out** — untested here; reported broken in the reference repo

## Audio on Tahoe — requires a root patch

**Apple removed `AppleHDA` in Tahoe beta 2.** AppleALC patches AppleHDA, so with nothing to patch
there is no built-in audio at all. Restoring it needs Sequoia's `AppleHDA.kext` linked into the
system kernel collection. Three walls make the obvious approaches fail:

1. **Every installed macOS since Big Sur ships stripped kext bundles.** `/S/L/E/AppleHDA.kext` on a
   running Sequoia Mac is ~408 KB with **no `Contents/MacOS`** — the code lives in the kernel
   collections. Same for BaseSystem. Only a **KDK** ships unstripped kexts, so "install Sequoia to a
   scratch volume and copy it" fails identically.
2. **OpenCore cannot inject it.** AppleHDA's dependencies (`IOAudioFamily`, `IOGraphicsFamily`,
   `IONDRVSupport`, `OSvKernDSPLib`, `vecLib`, `AppleSMBusController`) live in
   `SystemKernelExtensions.kc` while OpenCore injects into `BootKernelExtensions.kc`, and it cannot
   link across collections. `Kernel > Force` is not a fallback — the `/S/L/E` copies of those
   dependencies are themselves stripped. Symptom: `Invalid Parameter` on `DspFuncLib`,
   `AppleHDAController`, `AppleHDA`, `AppleMikeyDriver`.
3. **`kmutil` refuses to rebuild without a KDK matching the running build.**

### What works

Take `AppleHDA.kext` from the **Sequoia 15.7.9 KDK** (x86_64, v600.2 — it includes `layout100`), then:

```bash
# Prerequisites: csr-active-config = 0x0803 in config.plist, and from Recovery:
#   csrutil authenticated-root disable

# the booted root is a sealed snapshot, so `mount -uw /` does NOT work - mount the live volume:
sudo mount -o nobrowse -t apfs /dev/disk1s4 /System/Volumes/Update/mnt1

sudo cp -R AppleHDA.kext /System/Volumes/Update/mnt1/System/Library/Extensions/
sudo chown -R root:wheel /System/Volumes/Update/mnt1/System/Library/Extensions/AppleHDA.kext
sudo chmod -R 755      /System/Volumes/Update/mnt1/System/Library/Extensions/AppleHDA.kext

# kmutil wants a KDK matching the RUNNING build. Apple published 25G82 but never 25G83:
sudo cp -R KDK_26.6.2_25G82.kdk KDK_26.6.2_25G83.kdk
sudo plutil -replace ProductBuildVersion -string 25G83 \
     KDK_26.6.2_25G83.kdk/System/Library/CoreServices/SystemVersion.plist

sudo kmutil install --volume-root /System/Volumes/Update/mnt1 --update-all
sudo bless --folder /System/Volumes/Update/mnt1/System/Library/CoreServices \
     --bootefi --create-snapshot
```

`kmutil` failing for the *debug / research / development / kasan* collections is expected on a
release system — only the **release** collections matter.

### The cost — decide before you start

- **Every macOS update reverts it.** Keep a copy of the kext; you will redo this.
- The system volume ends up **unsealed** (`authenticated-root disabled`) — a real reduction in
  integrity, not a formality.
- To undo: remove the kext, `kmutil install` + `bless` again, then `csrutil authenticated-root enable`
  from Recovery and set `csr-active-config` back to `0x67`.

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
| `touchscreen/` | Goodix GT928 fix — root cause, patch, gesture tunables, and **prebuilt kexts** |
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

**Touchscreen** — two independent faults, in series, each fatal on its own; neither project
ships a release containing its own fix.

1. **The kext never loaded.** `VoodooI2CGoodix` 0.3.1 declares an `OSBundleLibraries`
   dependency on `com.apple.iokit.IOGraphicsFamily`, which lives in
   `SystemKernelExtensions.kc`. An OpenCore-injected kext lands in
   `BootKernelExtensions.kc` and cannot link across — the same wall AppleHDA hits — so it
   fails with `0xdc00800e` on every boot. Upstream fixed this in
   [`df42eb3`](https://github.com/lazd/VoodooI2CGoodix/commit/df42eb3) (2024-08-21), which
   landed *after* the newest tag (v0.4.0, 2023-03-22) — **so no released build contains it**,
   and the 0.4.0 release is just as dead as 0.3.1. Build from `master`.
2. **VoodooI2C 2.8 could not talk to the chip.** With the kext finally loading, the driver
   bound, probed and started correctly, then failed in `init_device()`: `goodix_read_reg`
   returned `kIOReturnError` with an all-zero buffer, on every one of 12 retries across
   600 ms, while `_PS0` returned success. **Upgrading VoodooI2C to 2.9.1 fixed it
   outright** — the chip answered on the first attempt with id `928`, version `0x1060`.

A third fault made every gesture ~7.5× too weak while leaving tracking and rotate perfect:
the driver assigned the *coordinate range* to `physical_max_*`, whose contract is
**0.01 mm**. macOS therefore believed the panel was 25.6 × 16.0 mm rather than 192 × 120 mm.
Scroll and pinch speed is now tunable from the kext's `Info.plist` without a rebuild.
Full writeup, arithmetic and patch in [`touchscreen/`](touchscreen/).

⚠ Also fixed there: **two null-dereferences that panic the kernel on touch**. And if you
maintain a VoodooI2C satellite, the `physical_max_*` unit confusion is not unique to Goodix —
`VoodooI2CAtmelMXT` assigns `max_report_x` to it, and `VoodooI2CFTE` does the same with the
correct conversion sitting *commented out* on the very same line. `VoodooI2CELAN`
(`max_report_x * 100 / hw_res_x`), `VoodooI2CSynaptics` (`x_size_mm * 100`) and
`VoodooI2CHID` (parses the HID physical-max descriptor) all get it right.

## BIOS: unlocking the hidden Advanced / Chipset menus

> ⚠ **All offsets below are for BIOS version 0.29** (`P2MAX029`), which is what this machine runs
> and what was patched. **Do not apply them blind to another BIOS version** — `AMITSE` is rebuilt
> between releases and `0x32C2B` will point somewhere else. Re-derive them for your version:
> extract `AMITSE`, find the `cmp r14b, 0xAA` that precedes the `0x2712`/`0x2713` FormId compares.

GPD hides **Advanced** and **Chipset** behind a CMOS gate compiled into AMI's own
setup browser (`AMITSE`), not behind the IFR. Full analysis in `bios/`.

### The safe way — one-shot, no reflash

On BIOS 0.29, `AMITSE` reads CMOS upper-bank index `0x44` via ports `0x72`/`0x73`; if it isn't
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

In `AMITSE` (GUID `B1DA0ADF-4F77-4070-A88E-BFFE1C60529A`) **of BIOS 0.29**, PE32 offset `0x32C2B`:
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
**touchscreen with full multitouch**, **0 ACPI errors at boot**.

Not working / not possible: fingerprint sensor (no macOS driver), charge limiting (the EC
exposes no threshold to *any* OS — Linux has no `charge_control_end_threshold` either),
USB-keyboard wake (disabled by design in `SSDT-XPRW` to prevent instant-wake).

## Credits

- [rowell1](https://github.com/rowell1/GPD-P2-Max-2019-Hackintosh) — original bring-up
- [Acidanthera](https://github.com/acidanthera) — OpenCore, Lilu, VirtualSMC, WhateverGreen, AppleALC
- [OpenIntelWireless](https://github.com/OpenIntelWireless) — itlwm / AirportItlwm
