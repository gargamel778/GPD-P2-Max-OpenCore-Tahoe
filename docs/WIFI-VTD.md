# Wi-Fi on Tahoe: AppleVTD was blocking the card, and the AirportItlwm migration was half-done

## Symptom

No Wi-Fi at all on Tahoe 26.6.2 (Darwin 25.6.0). `networksetup -listallhardwareports`
showed only the USB dongle and a stale `Ethernet`; there was no Wi-Fi interface.
Enabling `itlwm-Tahoe.kext` made the kext **load** but never **bind** — zero
`ItlIwm` instances, no `en0`, and not one itlwm log line. Switching to
`AirportItlwm-Sequoia` produced exactly the same result.

**When two independent drivers both silently decline the same device, stop
blaming the driver.**

## Cause 1 — AppleVTD never mapped the card

```
nvme (0x1cc1,0x8201): iommu-selection = <11000000>  iommu-parent = AppleVTDDeviceMapper
wifi (0x8086,0x095A): iommu-selection = <00000000>  (no iommu-parent)
Kernel > Quirks > DisableIoMapper = False
```

The Wi-Fi card is the one PCI device AppleVTD does not map, so it can never set up
DMA — and a driver that cannot get DMA attaches nothing and logs nothing. VT-d had
been turned **on** earlier the same session, which is what broke it.

**Fix: `Kernel > Quirks > DisableIoMapper = True`.** Wi-Fi appears immediately.

`PXSX@0`'s retain count going 9 → 12 is the quick tell that a driver finally
attached.

## Cause 2 — the AirportItlwm migration was left half-applied

The plan of record was to move `itlwm` → `AirportItlwm`, which needs **four**
changes. Only two had been made:

| item | required | was |
|---|---|---|
| `AirportItlwm-Sequoia.kext` | `MaxKernel = ""` | `24.9.9` ❌ |
| `IOSkywalkFamily.kext` | `MaxKernel = ""` | `24.9.9` ❌ |
| `IO80211FamilyLegacy.kext` | `MaxKernel = ""` | `24.9.9` ❌ |
| `Kernel > Block` `com.apple.iokit.IOSkywalkFamily` | `MaxKernel = ""` | `""` ✓ |
| `itlwm.kext` / `itlwm-Tahoe.kext` | disabled | disabled ✓ |

So Apple's `IOSkywalkFamily` was **blocked on every kernel ≥ 24.0.0** while its
replacement was gated off above 24.9.9 — blocked with nothing replacing it — and
`AirportItlwm` never loaded either. Both Wi-Fi paths were off simultaneously.

⚠ **The block and the kext that replaces it must be gated identically.** A block
with `MaxKernel = ""` plus a replacement capped at `24.9.9` is always a bug.

## Result — two separate faults, both fixed.

### Part 1: AirportItlwm binds on Tahoe but CANNOT SCAN

`AirportItlwm-Sequoia` **does** bind on Tahoe when un-gated — the earlier note
that it "may simply not bind" is wrong:

```
Card Type: Wi-Fi (0x8086, 0x9010)
Firmware: itlwm 2.3.0  fw 17.3216344376.0
Supported PHY Modes: 802.11 a/b/g/n/ac
Channels: full 2.4GHz + 5GHz (36 … 165)
Wake On Wireless / AirDrop / Auto Unlock: Supported
```

That is a straight upgrade on the old path: `itlwm` is **802.11n / 20 MHz only**
(~40 Mbps PHY) and needs HeliPort running; this is native 802.11ac on Apple's own
stack, with a real menu-bar item, AirDrop and Auto Unlock, and **no HeliPort**.
It also sidesteps the `panic: itlwm: nic locks counter 0` that got itlwm disabled
on 2026-08-28.

**But it cannot scan.** Every scan request is rejected by the driver in ~130 us:

```
E airportd (IO80211) Apple80211Scan:1489 ifname['en0'], total time [0.000129], err[22]
```

`err[22]` = `EINVAL`. `Scan Cache Count` stays 0, `SSID: None`, and the menu shows
no networks. The Sequoia build's IO80211 ioctl ABI does not match Tahoe's
CoreWLAN. Capabilities report correctly (802.11ac, all channels, AirDrop) which
makes it *look* healthy — **binding is not function**. Re-gated to `24.9.9`.

### Part 2: itlwm crashes the card firmware — an itlwm bug, FIXED

With VT-d off, `itlwm-Tahoe` binds, scans and associates fine. It then died in
`iwm_run`:

```
choose_bss 5ghz ssid=<redacted> mac=xx:xx:xx:xx:xx:xx rssi=57
SCAN -> AUTH -> ASSOC ; ieee80211_recv_assoc_resp reassoc=0   <- the AP accepted us
ieee80211_vht_negotiate chan_width=160 support_160=1 support_80_80=1
ieee80211_sta_set_rx_nss ni_rx_nss: 4
iwm_run -> iwm_phy_ctxt_cmd
0x000014FC | ADVANCED_SYSASSERT ; could not update PHY context (error 35)
```

4 association attempts, 4 identical asserts.

**This is an itlwm defect, not the AP.** `ieee80211_vht_negotiate()` derives the
width entirely from `ni->ni_vhtcaps` (the AP's advertised *capability*) and never
intersects it with `ic->ic_vhtcaps` (ours). The 7265 is 2x2/80MHz, so a
160MHz-capable AP drags it to a PHY context the firmware cannot execute.

**Proof it was never the AP:** Linux on this same machine, same card, same BSSID,
minutes later:

```
Connected to xx:xx:xx:xx:xx:xx   SSID: <redacted>   freq: 5560.0    (ch 112 - the same BSS)
rx 325.0 MBit/s VHT-MCS 7 80MHz VHT-NSS 1
tx 866.7 MBit/s VHT-MCS 9 80MHz VHT-NSS 2      signal -45 dBm, zero iwlwifi errors
```

`iwlwifi` clamps to `min(AP, own)` in `ieee80211_vht_cap_ie_to_sta_vht_cap()` and
lands on 80MHz. itlwm does not clamp at all.

**Why it "used to work":** it was associating on the **2.4 GHz** BSS, where VHT
never enters the picture (the old notes record HT-only, 20MHz, ~40 Mbps). Nothing
about the network changed — the moment the card started preferring the 5 GHz BSS
it hit a bug latent since itlwm v2.0.0, which is where "802.11AC / VHT160" was
introduced.

**Fixed** by patching itlwm to clamp the negotiated width to `ic_vhtcaps`. Built,
deployed, verified: `chan_width=80`, 0 asserts, `en0 inet 192.0.2.x active`.
See `opencore/itlwm-patch/` for the patch, the build recipe (it needs MacKernelSDK)
and the before/after table.

## Diagnosis rule this cost us

**Binding is not function, and "the interface exists" is not "Wi-Fi works."**
Three separate layers each looked fine while Wi-Fi was dead: the kext loaded but
did not bind (VT-d); it bound but could not scan (AirportItlwm ABI); it scanned
and associated but the firmware asserted (VHT width). Verify with an actual scan
result and an actual association before calling it working — "Supported PHY Modes:
802.11 a/b/g/n/ac" was reported by a driver that could not scan at all.

**And when the Mac side runs out of answers, boot the other OS before blaming
anything external.** Two wrong calls were made here — "the card is unsupported"
(from a case-sensitive `strings|grep 3165` that missed `iwlwifi-7265D`) and "your
AP moved to 160MHz" — and a single `iw dev wlp2s0 link` on Ubuntu refuted both in
one command, and pointed straight at the real defect.

## Trade-off to be aware of

`DisableIoMapper = True` turns AppleVTD off. On this machine that is the cost of
having Wi-Fi at all. If VT-d is ever wanted back, the card needs a DMAR fix
rather than a quirk flip — do not simply re-enable it and expect Wi-Fi to survive.

## Card identity — get this right

`0x8086:0x095A` is an **Intel Wireless-AC 7265**, not a 3165 (3165 is `0x3165`).
A case-sensitive `strings | grep 3165` on the kext returning 0 hits proves
nothing; the 7265 loads `iwlwifi-7265D-*.ucode`, which a lowercase-only regex
misses.

## Aftercare

The interface comes up as `en0` with **no network service**, reported as
`Status: Network Service Inactive`. Create one and fix the order:

```bash
sudo networksetup -createnetworkservice Wi-Fi en0
sudo networksetup -ordernetworkservices "AX88x72A" "Wi-Fi" "Ethernet" "Ethernet 2"
```

Order matters: this box has previously routed **all** WAN traffic over Wi-Fi while
the wired dongle sat idle (LAN fast, WAN ~300x slow, plus a PMTU black hole).
Keep the wired adapter first.

A stale `Ethernet` service still points at `en0` from the itlwm era, when itlwm
presented as an Ethernet device. Harmless, but do not confuse it with `Ethernet 2`
(`en1`), which is `NullEthernet` and exists for iServices.
