# NOTICE — third-party components in `prebuilt-efi/`

Every binary shipped here, its licence, and where it came from.
Nothing Apple-copyrighted is included; see **Not included** below.

| kext | version | licence | upstream |
|---|---|---|---|
| `AirportItlwm-Tahoe.kext` | 2.4.0 | GPL-2.0 | https://github.com/OpenIntelWireless/itlwm |
| `AppleALC.kext` | 1.9.7 | BSD-3-Clause | https://github.com/acidanthera/AppleALC |
| `BlueToolFixup.kext` | 2.7.2 | GPL-2.0 | https://github.com/acidanthera/BrcmPatchRAM |
| `BrightnessKeys.kext` | 1.0.3 | BSD-3-Clause | https://github.com/acidanthera/BrightnessKeys |
| `FeatureUnlock.kext` | 1.1.8 | BSD-3-Clause | https://github.com/acidanthera/FeatureUnlock |
| `HibernationFixup.kext` | 1.5.4 | BSD-3-Clause | https://github.com/acidanthera/HibernationFixup |
| `IntelBluetoothFirmware.kext` | 2.5.1 | GPL-3.0 | https://github.com/OpenIntelWireless/IntelBluetoothFirmware |
| `IntelBluetoothInjector.kext` | 2.5.1 | GPL-3.0 | https://github.com/OpenIntelWireless/IntelBluetoothFirmware |
| `Lilu.kext` | 1.7.2 | BSD-3-Clause | https://github.com/acidanthera/Lilu |
| `NVMeFix.kext` | 1.1.3 | BSD-3-Clause (LICENSE.txt: "Copyright (c) 2019, acidanthera") | https://github.com/acidanthera/NVMeFix |
| `RTCMemoryFixup.kext` | 1.0.7 | BSD-3-Clause | https://github.com/acidanthera/RTCMemoryFixup |
| `RestrictEvents.kext` | 1.1.6 | BSD-3-Clause | https://github.com/acidanthera/RestrictEvents |
| `SMCBatteryManager.kext` | 1.3.7 | BSD-3-Clause | https://github.com/acidanthera/VirtualSMC |
| `SMCProcessor.kext` | 1.3.7 | BSD-3-Clause | https://github.com/acidanthera/VirtualSMC |
| `SMCSuperIO.kext` | 1.3.7 | BSD-3-Clause | https://github.com/acidanthera/VirtualSMC |
| `SystemProfilerMemoryFixup.kext` | 1.0.0 | MIT | https://github.com/Goldfish64/SystemProfilerMemoryFixup |
| `VirtualSMC.kext` | 1.3.7 | BSD-3-Clause | https://github.com/acidanthera/VirtualSMC |
| `VoodooI2C.kext` | 2.9.1 | GPL-3.0 | https://github.com/VoodooI2C/VoodooI2C |
| `VoodooI2CGoodix.kext` | 0.4.0 | GPL-3.0 | https://github.com/lazd/VoodooI2CGoodix |
| `VoodooI2CHID.kext` | 1 | GPL-3.0 | https://github.com/VoodooI2C/VoodooI2C |
| `WhateverGreen.kext` | 1.7.0 | BSD-3-Clause | https://github.com/acidanthera/WhateverGreen |

**Total: 21 kexts.**

## Source, as required by the GPL

`AirportItlwm-Tahoe.kext` is the **only modified** binary here. It is built from
[OpenIntelWireless/itlwm](https://github.com/OpenIntelWireless/itlwm) plus the patches published in
[`../itlwm-patch/`](../itlwm-patch/) — principally the VHT-width clamp submitted upstream as
[itlwm#1067](https://github.com/OpenIntelWireless/itlwm/pull/1067). Nothing else is applied.

Every other kext is an **unmodified upstream release** at the version in the table. For any GPL
component here, the corresponding source is the upstream repository at that release tag; if you would
prefer it supplied directly, open an issue and it will be provided.

Full licence texts for the GPL components are in
[`../touchscreen/prebuilt/`](../touchscreen/prebuilt/) (VoodooI2C, VoodooI2CGoodix, VoodooGPIO,
VoodooInput). The BSD-3-Clause and MIT components carry their licence in each upstream repository.

## Not included — and why

**Apple-copyrighted binaries. These are macOS components; redistributing them is not permitted, so
they are deliberately absent and this EFI will not boot as shipped without them.**

| kext | why |
|---|---|
| `IOSkywalkFamily.kext` | `com.apple.iokit.IOSkywalkFamily` — "Copyright © 2022 Apple Inc." |
| `IO80211FamilyLegacy.kext` | `com.apple.iokit.IO80211FamilyLegacy` — extracted from macOS 12/13 |
| `AppleHDA.kext` | `com.apple.driver.AppleHDA` — "Copyright © 2000-2019 Apple Inc." Stock and Apple-signed; it is **not** modified (see below). |

⚠ **`AppleHDA` does not come from your running macOS.** Tahoe removed it, and every installed macOS
since Big Sur ships stripped kext bundles with no `Contents/MacOS`. It has to be extracted from a
**Sequoia 15.7.x Kernel Debug Kit**, and a *second* KDK matching your running build is required before
`kmutil` will relink the collections. Both are downloaded from Apple under your own developer account
Community mirrors that avoid the Apple
login exist, but are not linked here.
The bundle is bit-identical stock Apple — "root patch" refers to patching the root **volume**, not the
kext — which is precisely why it cannot be redistributed here.

The `IO80211` **userland root patch** the Wi-Fi setup depends on is likewise Apple's
`IO80211.framework` from 13.7.2 and is not distributed here.

**No licence granted.** These carry no licence file at all, so no redistribution right exists —
get them from upstream:

| kext | upstream |
|---|---|
| `ECEnabler.kext` | https://github.com/1Revenger1/ECEnabler |
| `NullEthernet.kext` | RehabMan — https://github.com/RehabMan/OS-X-Null-Ethernet |

**Provenance unverified.**

| kext | note |
|---|---|
| `AMFIPass.kext` | Ships with OpenCore Legacy Patcher; I could not establish an authoritative upstream or licence, so it is not redistributed here. |

**Omitted for size.** `AirportItlwm` 2.3.0 for BigSur/Monterey/Ventura/Sonoma/Sequoia (~92 MB) — this
build targets Tahoe. Get them from
[itlwm releases](https://github.com/OpenIntelWireless/itlwm/releases) if you boot other versions.
