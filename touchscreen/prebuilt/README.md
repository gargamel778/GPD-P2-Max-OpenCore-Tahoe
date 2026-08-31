# Prebuilt touchscreen kexts

These are the exact binaries running on the machine this repo documents. They exist because
**no published release of either project works here** — see [../README.md](../README.md).

⚠ **x86_64 only.** Built for macOS Tahoe 26.6.2 (Darwin 25.6.0). Unsigned; they rely on
OpenCore injection, so `Kext Signing` must be off in `csr-active-config` as this config
already sets.

| file | contents | source |
|---|---|---|
| `VoodooI2CGoodix-df42eb3-p2max.kext.zip` | `VoodooI2CGoodix.kext` | [lazd/VoodooI2CGoodix](https://github.com/lazd/VoodooI2CGoodix) @ `df42eb3` (2024-08-21) **+ the patch in this directory's parent** |
| `VoodooI2C-2.9.1.kext.zip` | `VoodooI2C.kext` incl. PlugIns `VoodooGPIO`, `VoodooI2CServices`, `VoodooInput` | [VoodooI2C/VoodooI2C](https://github.com/VoodooI2C/VoodooI2C) @ `5c0c99c` (2025-11-26), **unmodified** |

Bundled plugin sources, all unmodified:
[VoodooGPIO](https://github.com/VoodooI2C/VoodooGPIO) @ `733dc80`,
[VoodooInput](https://github.com/acidanthera/VoodooInput) @ `d897813`,
`VoodooI2CServices` (in the VoodooI2C tree).

## Licensing

GPL. Source for everything here is public at the commits named above, and the **only**
modification made by this repo is [`../VoodooI2CGoodix-p2max.patch`](../VoodooI2CGoodix-p2max.patch),
which applies cleanly to `df42eb3`. Full license texts are in this directory:

| project | licence |
|---|---|
| VoodooI2C | GPL v3 — `LICENSE-VoodooI2C-GPLv3.txt` |
| VoodooI2CGoodix | GPL v3 — `LICENSE-VoodooI2CGoodix-GPLv3.txt` |
| VoodooGPIO | GPL v3 — `LICENSE-VoodooGPIO-GPLv3.md` |
| VoodooInput | GPL **v2** — `LICENSE-VoodooInput-GPLv2.txt` |

## Checksums

    sha256  VoodooI2CGoodix-df42eb3-p2max.kext.zip
            12b8e8367bb60d01118e2409609cd8a3c08e6a6e89e27c280322fe57992da43d
    sha256  VoodooI2C-2.9.1.kext.zip
            0ecfeb63fd8a1d997f9565f91a1324bf04267d0f278d74ca73acbdd017fa7020

    sha256  VoodooI2CGoodix.kext/Contents/MacOS/VoodooI2CGoodix
            f23b71f1eaa8ffc2a1b9c9ab8d90b4b54dd7d5710b6ea4308f3df1944d752a28
    sha256  VoodooI2C.kext/Contents/MacOS/VoodooI2C
            dd07cf6e16a450e7301402e28ea3d8a407c84a8701c642b43dbb34415a8ebb24

## How they were built

    xcodebuild -project VoodooI2CGoodix.xcodeproj -scheme VoodooI2CGoodix \
      -configuration Release ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO \
      HEADER_SEARCH_PATHS='$(PROJECT_DIR)/../../MacKernelSDK/Headers $(inherited)' \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

The Goodix satellite must sit in `VoodooI2C Satellites/` inside a VoodooI2C checkout —
its includes are relative (`../../../Multitouch Support/...`) and resolve nowhere else.
Run `git submodule update --init --recursive` first (VoodooGPIO is a submodule), and
fetch VoodooInput into `Dependencies/` per VoodooI2C's *Build Environment* doc.

Both binaries were then **stripped** (`strip -S -x`) to remove the debug map. Xcode records
absolute build paths in `N_OSO` symbol-table entries, which `strings` does not show but
`nm -pa` does — if you publish your own build, check it:

    nm -pa YourKext.kext/Contents/MacOS/YourKext | grep ' OSO '

Stripping left `__TEXT,__text` byte-identical to the tested build and preserved the
exported `gMetaClass` symbols the kernel linker needs.

## Installing

Copy both into `EFI/OC/Kexts/` and add them to `Kernel > Add` — or just use the
`config.plist` in this repo, which already has the entries. VoodooI2C's plugins are
separate `Kernel > Add` entries pointing inside the bundle:

    VoodooI2C.kext/Contents/PlugIns/VoodooGPIO.kext
    VoodooI2C.kext/Contents/PlugIns/VoodooI2CServices.kext
    VoodooI2C.kext/Contents/PlugIns/VoodooInput.kext
    VoodooI2C.kext
    VoodooI2CGoodix.kext

## Tuning gesture speed — no rebuild

`VoodooI2CGoodix.kext/Contents/Info.plist`, in **both** personalities:

    PhysicalSurfaceWidth   19200    physical width, 0.01 mm units
    PhysicalSurfaceHeight  12000    physical height, 0.01 mm units
    GestureGainPercent     100      100 = physically honest; higher = faster

⚠ **The surface values are specific to the GPD P2 MAX's 8.9" 192 x 120 mm panel.** On other
hardware, measure your own panel and convert to 0.01 mm, or scroll and pinch will be wrong
by exactly the ratio you got wrong. Gain is clamped 10-300 and the product to 65535.

Verify after rebooting:

    ioreg -c VoodooI2CGoodixTouchDriver -r -d1 -w0 | grep Goodix
    ioreg -c AppleMultitouchDevice -w0 -r -l -d1 | grep "Sensor Surface"
