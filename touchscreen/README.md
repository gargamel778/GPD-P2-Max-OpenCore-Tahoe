# Touchscreen (Goodix GT928) on macOS Tahoe — root cause and fix

Status: **working stack, verified up to and including live touch interrupts.**
Cursor-level confirmation needs a finger on the glass (see *Verifying* below).

The panel is a Goodix **GT928** on `I2C2`, ACPI `\_SB.PCI0.I2C2.TCSE`, `_HID GDIX1002`,
I2C address `0x14`, GPIO interrupt pin 128, 400 kHz.

## Two independent faults, both required fixing

Everything before this had been blamed on one thing. It was two, in series — fixing
either one alone leaves the touchscreen just as dead.

### Fault 1 — the kext never loaded (`0xdc00800e`)

`VoodooI2CGoodix` **0.3.1** (2020) — the build this config shipped — declares

    OSBundleLibraries: com.apple.iokit.IOGraphicsFamily = 1.0.0b1

`IOGraphicsFamily` lives in `SystemKernelExtensions.kc`. OpenCore injects into
`BootKernelExtensions.kc`, and a boot-collection kext cannot link against the system
collection — the same wall AppleHDA hits. Result, 68x per boot:

    Kext net.lazd.VoodooI2CGoodix - library kext com.apple.iokit.IOGraphicsFamily not found.
    Failed to load kext net.lazd.VoodooI2CGoodix (error 0xdc00800e)

Upstream fixed this on `master` in **`df42eb3`** ("Fix Big Sur issues", 2024-08-21) by
replacing `OSDynamicCast(IOFramebuffer, ...)` with `metaCast("IOFramebuffer")` and
dropping the `IOGraphicsFamily` dependency.

**Every published release is affected, not just 0.3.1.** `df42eb3` is dated 2024-08-21; the
newest tag, **v0.4.0, is from 2023-03-22** and therefore predates the fix. Verified by
downloading the release asset:

    $ gh release download v0.4.0 -R lazd/VoodooI2CGoodix
    $ PlistBuddy -c "Print :OSBundleLibraries" ex/VoodooI2CGoodix.kext/Contents/Info.plist
        com.apple.iokit.IOGraphicsFamily = 1.0.0b1      <-- still there

So there is no release you can download that loads under OpenCore. Build from `master`.

⚠ **`CFBundleVersion` cannot distinguish them** — the version was never bumped after the
v0.4.0 tag, so a source build from `master` *also* reports `0.4.0`. Identify a build by its
`OSBundleLibraries`, never by its version string.

### Fault 2 — VoodooI2C 2.8 could not talk to the chip

With the kext finally loading, it bound, probed and started correctly, then died in
`init_device()`. Instrumenting the driver produced:

    goodix_read_reg(GOODIX_REG_ID) -> 0xE00002BC  (kIOReturnError)
    bytes read: <000000000000>

12 retries across 600 ms all failed identically, so not a power/settling race — and
`_PS0` returned `0`. The fix was **upgrading VoodooI2C 2.8 -> 2.9.1** (built from
source; 2.9.1 has no binary release either). Immediately:

    goodix_read_reg -> 0 on attempt 1
    bytes: <39 32 38 00 60 10>  = "928" + version 0x1060
    ts_id = 928, ts_version = 4192

This machine has **exactly one I2C device**, so VoodooI2C's transfer path had never
actually been exercised here before — the touchscreen was its only consumer.

## What is deployed

| kext | was | now | source |
|---|---|---|---|
| `VoodooI2CGoodix.kext` | 0.3.1 (release) | **`master` @ `df42eb3`** (also reports 0.4.0) | `lazd/VoodooI2CGoodix` + patch below |
| `VoodooI2C.kext` (+ PlugIns) | 2.8 | **2.9.1** | `VoodooI2C/VoodooI2C` @ `5c0c99c`, stock |

Old copies are archived in this repo at `opencore/kexts-retired/` rather than left on the ESP —
`esp-kext-backups.tgz` (the 0.3.1 build that cannot load, and VoodooI2C 2.8) and
`Kexts-I2C-backup.tgz` (the complete pre-fix I²C stack: VoodooI2C 2.8 + VoodooGPIO 1.1 +
VoodooI2CServices 1 + VoodooInput 1.1.4). Those are the experimental controls behind the
"2.8 cannot drive this bus" finding, so they are kept deliberately. No `config.plist` change was needed — the Goodix entry was
already present and enabled, and the VoodooI2C PlugIns paths are unchanged.

## Local patch — `VoodooI2CGoodix-p2max.patch`

Applies on top of `df42eb3`. Four changes:

1. **Null-deref fix, `reportTouches()`** — `OSDynamicCast(OSNumber, ...getProperty(kIOFBTransformKey))`
   was dereferenced unchecked. A framebuffer without `IOFBTransform` panics the kernel
   *on every touch*. Guarded.
2. **Null-deref fix, `getFramebuffer()`** — `display->getParentEntry(...)->getParentEntry(...)`
   chained without checking the first result. Guarded.
3. **Retry the initial version read** (12 x 50 ms). Not needed once VoodooI2C 2.9.1 is in
   place, but cheap insurance — it exits on first success.
4. **`GoodixInterrupts` counter** on the nub, for verification (below).

Also split `IOPropertyMatch` from an array-of-dicts into one personality per device ID,
matching the ELAN/FTE/AtmelMXT convention. **This was not a fix** — a canary personality
proved the array form matches correctly; it is only house style.

Items 1 and 2 are upstreamable as-is.

## Verifying

    ioreg -c VoodooI2CDeviceNub -r -d1 -w0 | grep GoodixInterrupts

Sits at `4` (initialisation) when idle, with no spurious noise. **Touch the screen and
it climbs.** Full stack when healthy:

    TCSE (VoodooI2CDeviceNub)
     +- VoodooI2CGoodixTouchDriver
         +- VoodooI2CGoodixEventDriver        (IOHIDEventService)
             +- VoodooI2CMultitouchInterface
             +- IOHIDEventServiceUserClient   (WindowServer attached)

## Diagnostic notes worth keeping

- **Third-party `IOLog` does not reach `log show` on this system.** WhateverGreen,
  AppleALC, VoodooGPIO and NVMeFix all produce zero lines. `dmesg` works but its buffer
  is 128 KB and the Intel graphics driver floods it within ~7 minutes; the `msgbuf=`
  boot-arg is ignored on Tahoe. Any "no log output, therefore it didn't run" conclusion
  here is worthless — write state into the IORegistry instead (`provider->setProperty`)
  and read it with `ioreg`. That is what actually cracked this.
- **Canary personalities** are a clean way to test IOKit matching: point a personality at
  a deliberately nonexistent `IOClass` and watch for `Couldn't alloc class "X"` in
  `log show`. That message *is* emitted (it comes from xnu, not the kext), so it cleanly
  separates "personality never matched" from "matched but the driver bailed".
- A failing `IOPropertyMatch` logs **nothing**; a matched-but-unallocatable class logs
  `Couldn't alloc class`; a failing `init()` is **silent**. Know which silence you have.

## Prebuilt kexts

[`prebuilt/`](prebuilt/) has both kexts built from the sources and commits named above,
stripped of the debug map, with licences and checksums. They are the exact binaries running
on the machine. Neither project publishes a release that works here, so building — or taking
these — is the only route.

## Gesture speed — `physical_max_*` was in the wrong units

Once touch worked, scroll and pinch were ~7.5x too weak while tracking and rotate were
perfect. Cause, at `VoodooI2CGoodixEventDriver.cpp:479-480`:

    multitouch_interface->physical_max_x = logicalMaxX;   // 2560  <-- coordinate count
    multitouch_interface->physical_max_y = logicalMaxY;   // 1600  <-- coordinate count

`physical_max_*` is contractually **0.01 mm**, not coordinates. VoodooInput packs it
verbatim into the MT2 "Sensor Surface Description" feature report (0xD9/0xDB), so macOS
believed it was driving a **25.6 x 16.0 mm** trackpad. The panel is **192 x 120 mm**
(EDID DTD; 8.9" 16:10 geometry agrees to 0.2%). Declared surface was exactly **7.500x**
too small on both axes.

That the error is *isotropic* explains the symptom set exactly:
- **Tracking fine** — absolute position never uses `physical_max_*`; it normalises by
  `logical_max_*` (`VoodooInputSimulatorDevice.cpp:100-101`), and single-finger events
  bypass VoodooInput entirely (`VoodooI2CGoodixEventDriver.cpp:48-49`).
- **Rotate fine** — angles are scale-invariant.
- **Scroll/pinch weak** — those are distances, in mm.

`physical_max_*` has exactly three consumers tree-wide, all of them the 0xD9/0xDB reports.
Fixing it cannot touch the coordinate path.

Not unique to Goodix. Verified across the whole satellite family:

| satellite | assigns to `physical_max_x` | correct? |
|---|---|---|
| `VoodooI2CSynaptics` | `x_size_mm * 100` | yes |
| `VoodooI2CELAN` | `max_report_x * 100 / hw_res_x` | yes |
| `VoodooI2CHID` | `parseElementPhysicalMax(...)` | yes |
| `VoodooI2CAtmelMXT` | `max_report_x` | **no** |
| `VoodooI2CFTE` | `max_report_x` — with `// max_report_x * 10 / hw_res_x` commented out beside it | **no** |
| `VoodooI2CGoodix` | `logicalMaxX` (fixed here) | **was no** |

### Tuning without a rebuild

Three keys in each personality of the deployed `VoodooI2CGoodix.kext/Contents/Info.plist`:

    PhysicalSurfaceWidth   19200    (0.01mm - true panel width)
    PhysicalSurfaceHeight  12000    (0.01mm - true panel height)
    GestureGainPercent     100      (100 = physically honest; higher = faster)

Gain is clamped to 10-300; the product is clamped to 65535 (the 16-bit report field —
overflowing it wraps to a nonsensically tiny surface). Edit, reboot, done. Confirm with:

    ioreg -c VoodooI2CGoodixTouchDriver -r -d1 -w0 | grep Goodix
    ioreg -c AppleMultitouchDevice -w0 -r -l -d1 | grep "Sensor Surface"

Expect to want gain **below** 100 rather than above: macOS scroll acceleration is
velocity-dependent, and the deflated surface was also deflating apparent velocity, so the
real-world speedup at speed is larger than 7.5x.

Rollback: `VoodooI2CGoodix.kext.pre-gesture` on the ESP, or set the two surface keys back
to 2560/1600 to reproduce the old feel exactly.
