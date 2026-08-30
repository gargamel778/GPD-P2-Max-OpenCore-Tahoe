# itlwm: clamp the negotiated VHT width to the card's own capability

**Status: built, deployed and verified on hardware 2026-08-30.**
Intel Wireless-AC 7265 (`8086:095A`), macOS Tahoe 26.6.2, itlwm master @ `53c51c2` (2.4.0).

## The bug

`ieee80211_vht_negotiate()` derives `support_160`, `support_80_80`, `supp_chwidth`,
`ext_nss_bw_supp` and ultimately `ni->ni_chw` **entirely from `ni->ni_vhtcaps`** —
the *AP's* advertised capability — and never intersects them with `ic->ic_vhtcaps`,
our own. itlwm gates its own 160MHz claim correctly (`hal_iwm/mac80211.cpp:473`,
`if (sc->sc_nvm.vht160_supported)`), so `ic_vhtcaps` is right; it is simply never
consulted when picking the width.

Associate a 2x2/80MHz part with an AP that advertises 160MHz and you program a PHY
context the firmware cannot execute:

```
ieee80211_vht_negotiate chan_width=160 support_160=1 support_80_80=1
ieee80211_sta_set_rx_nss ni_rx_nss: 4
iwm_run -> iwm_phy_ctxt_cmd
Start Error Log Dump: Status: 0x79
0x000014FC | ADVANCED_SYSASSERT
could not update PHY context (error 35) / failed to update PHY
```

The device then resets in a loop and association never completes. Every
iwm-generation part is 80MHz max (7265, 8260, 8265), so any of them hits this
against a 160MHz-capable AP.

Linux performs exactly this intersection in
`ieee80211_vht_cap_ie_to_sta_vht_cap()`, which is why `iwlwifi` negotiates
**80MHz / VHT-NSS 2 / 866 Mbit/s** against the *same BSS* that asserts here —
verified on the same machine, same AP, same card, minutes apart.

## The fix

Clamp `ni->ni_chw` to `ic_vhtcaps` after the width switch. 31 lines, no behaviour
change for cards that genuinely support 160MHz.

## Verification

| | stock 2.3.0 | patched 2.4.0 |
|---|---|---|
| `vht_negotiate chan_width` | 160 | 80 |
| `ADVANCED_SYSASSERT` | 4 of 4 attempts | **0** |
| `failed to update PHY` | 4 | **0** |
| association | never completes | `en0 inet 192.0.2.x, status: active` |

## Building

`itlwm.xcodeproj` needs **MacKernelSDK** beside it — it is not a submodule and a
plain `git clone` will not bring it:

```bash
git clone --depth 1 https://github.com/acidanthera/MacKernelSDK.git
xcodebuild -project itlwm.xcodeproj -scheme itlwm -configuration Release \
  ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath ./DerivedData build
```

Do **not** hand-set `HEADER_SEARCH_PATHS` to the SDK's `Kernel.framework/Headers`.
That gets past the first `libkern/libkern.h not found` error but then displaces
MacKernelSDK, and `outputStart` (a `__PRIVATE_SPI__` method the public SDK does not
declare) fails to override. Install MacKernelSDK and use the project's own settings.

## Deployed

`EFI/OC/Kexts/itlwm-Tahoe.kext` — patched build, md5 `789e72e134561f15c634f28421c85165`.
Stock preserved alongside as `itlwm-Tahoe.kext.STOCK`, md5 `06a1b3b339e5e5335253b5d5df96f5a0`.
