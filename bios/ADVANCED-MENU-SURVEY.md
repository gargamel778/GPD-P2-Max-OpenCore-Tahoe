# What the unlocked Advanced menu exposes (BIOS 0.29)

Surveyed 2026-08-29, immediately after the permanent unlock.

## The two actionable findings

### 1. CFG Lock is settable — we can drop `AppleXcpmCfgLock`

`Advanced → CPU Configuration → CPU Lock Configuration`:

```
CFG Lock            [Enabled]      <-- set to Disabled
Overclocking Lock   [Disabled]
```

This is the setting `ControlMsrE2.efi` reported as "No corresponding BIOS Options found" and that
we long recorded as unfixable. It is simply a normal option on a hidden page.

Order matters: set it Disabled, boot macOS and confirm it still boots (the quirk is harmless while
redundant), *then* remove `AppleXcpmCfgLock` from `Booter > Quirks` and confirm again.

### 2. The real PL1 lever is under Config TDP, not "Platform PL1"

`Advanced → CPU Configuration → Power & Performance → CPU - Power Management Control →
Config TDP Configurations`:

```
Configurable TDP Boot Mode      [Up]        <-- so the "Up" level is what applies
Configurable TDP Lock           [Disabled]  <-- not locked, we can change it
ConfigTDP Levels                3
  Power Limit 1                 6.0W (MSR:8.0)
  Power Limit 2                 9.0W (MSR:15.0)

Custom Settings Nominal   Ratio:11 TAR:10 PL1:5.0W    PL1 6000   PL2 15000
Custom Settings Down      Ratio:6  TAR:5  PL1:3.500W  PL1 6000   PL2  9000
Custom Settings Up        Ratio:16 TAR:15 PL1:7.0W    PL1 8000   PL2 15000   <-- ACTIVE
```

Boot mode is **Up**, so `Custom Settings Up → Power Limit 1 = 8000` is the field that produces the
`Power Limit 1: 8.0` shown under Current Turbo Settings. **That is the byte to raise**, not the
"Platform PL1 Power" field on the parent page.

This also confirms the long-standing note that the firmware default is really **8 W**, and that the
7 W we kept seeing on Ubuntu is `thermald` rewriting it after boot.

## Why "Platform PL1" is probably the wrong knob

`CPU - Power Management Control` shows `Platform PL1 Enable [Enabled] / Power 8000` and
`Platform PL2 Enable [Enabled] / Power 8000`. These are **PSYS** (whole-platform) limits — and in
`CPU VR Settings`, `PSYS Slope`, `PSYS Offset` and `PSYS PMax Power` are **all 0** with
`VR Power Delivery Design [AUTO]`. With no PSYS calibration the platform limit is very likely inert
on this board. Treat it as a red herring unless measurement says otherwise.

## Headroom check — the VRs are not the constraint

`CPU VR Settings → Core/IA VR Domain`:

```
VR Current Limit   112     (quarter-amp units => 28 A)
TDC Current Limit  144
AC/DC Loadline     400 / 400
VR Voltage Limit   1520
```

28 A at ~1 V is far above anything a 12 W package limit would draw. GT-Sliced is 96 (24 A), SA is
16 (4 A). Nothing here needs touching to run a higher PL1.

## Other state worth recording

| Setting | Value | Note |
|---|---|---|
| Package Power Limit MSR Lock | **Disabled** | why the OS-side PL1 switcher can write MSRs at all |
| Package TDP Limit | 5.0 | SKU nominal |
| Power Limit 1 / 2 (current) | 8.0 / 15.0 | matches the ConfigTDP "Up" level |
| 1-core / 2-core Turbo Ratio | 34 / 27 | rated turbo; ratio overrides are 0 |
| Boot performance mode | Turbo Performance | already maximal |
| SpeedStep / Speed Shift / Turbo / RTH | all Enabled | nothing to gain |
| Package C State Limit | Auto | = deepest (C10) on this part |
| EC Turbo Control Mode | Disabled | the EC is not overriding turbo |
| Energy Performance Gain | Disabled | |
| Acoustic Noise Mitigation | Disabled | slew rates all Fast/2 |
| Custom P-state Table | 0 P-states | unused |
| Power Limit 3 Override | Disabled | |
| Power Limit 4 Override | Disabled | |

## Recommended next step: change one thing, then MEASURE

Set `Custom Settings Up → Power Limit 1` from `8000` to `12000`, leave PL2 at 15000, save, and then
read back the *effective* limit from an OS rather than trusting the menu:

- Linux: `/sys/class/powercap/intel-rapl-mmio:0/constraint_0_power_limit_uw` — note the enforcing
  domain is **`intel-rapl-mmio:0`**, not `intel-rapl:0`, and `thermald` will rewrite it ~0.5 s after
  start, so check with thermald stopped or immediately after the drop-in re-asserts.
- The measured payoff previously recorded for 12 W was ~2700 MHz sustained at ~78 °C with roughly
  20 °C of thermal margin still unused, versus ~2186 MHz at 7 W.

**Caveat:** a firmware PL1 applies on battery too, where the existing Ubuntu switcher deliberately
drops to 7 W. Raising the firmware value helps Windows and macOS, but consider whether you want
12 W sustained on battery before committing.

## Wake-relevant settings — LIVE values (confirmed on the machine 2026-08-29)

Previously these were only *predicted* from the factory `Setup` blob recovered from the ROM. Now
read directly off the running machine. **Every prediction was correct.**

`Advanced → Intel RC ACPI Settings`:

| Setting | Live value | Bearing on the wake failure |
|---|---|---|
| **Low Power S0 Idle Capability** | **Disabled** | The classic "firmware advertises S0ix instead of S3" wake killer is **not** in play. Ruled out. |
| Wake system from S5 | Disabled | unrelated |
| Native PCIE Enable / Native ASPM | Enabled / Auto | stock |
| Lpit Windows RS2 Workaround | Enabled | S0ix-adjacent, see note below |
| Lpit Recidency Counter | SLP S0 | S0ix-adjacent, see note below |
| PCI Delay Optimization | Disabled | unrelated |
| Type C Support | Enabled | unrelated |

`Advanced → ACPI Settings`:

| Setting | Live value | Bearing |
|---|---|---|
| **ACPI Sleep State** | **S3 (Suspend to RAM)** | S3 is properly advertised. Ruled out. |
| **Enable ACPI Auto Configuration** | **Disabled** | so the S3 Video Repost gate is OPEN — that setting is live, not ignored |
| **S3 Video Repost** | **Disabled** | the one remaining untested candidate |
| Enable Hibernation | Enabled | supports the `hibernatemode 25` workaround |
| Lock Legacy Resources | Disabled | unrelated |

`Chipset → PCH-IO Configuration`:

| Setting | Live value | Bearing |
|---|---|---|
| **DeepSx Power Policies** | **Disabled** | DeepSx is not cutting rails in S3. Ruled out. |
| LAN Wake From DeepSx | Enabled | no LAN on this machine (`No GbE Region`) |
| Wake on WLAN and BT Enable | Disabled | affects *sources* of wake, not the ability to resume |
| State After G3 | S5 State | unrelated to S3 |
| DCI enable (HDCIEN) | Disabled | debug interface off — rules out that family |
| **Flash Protection Range Registers (FPRR)** | **Disabled** | ★ this is why Intel FPT was able to write the BIOS region. **Do not enable it** if you want to reflash again. |
| Unlock PCH P2SB | Disabled | |
| PCH Cross Throttling | Enabled | |

### The one thing left to try: S3 Video Repost

It is `Disabled`, its gate (`Enable ACPI Auto Configuration`) is `Disabled` so it *would* be honoured,
and it is now a single menu toggle.

**Expectations should be low, for two independent reasons:**

1. **CSM Support is Disabled** (`0x10A3 = 0x00`). A video re-POST re-runs the legacy video option
   ROM; with no CSM there is likely no legacy VBIOS path for it to execute. It may be structurally
   inert, in which case a null result is *uninformative*, not exculpatory.
2. **Wrong failure class.** A display re-post fixes "the system is alive but the panel is dark".
   Ours is a *total* non-resume — the machine never returns and needs a hard power-off. A re-post
   cannot fix that.

Try it because it is now free, not because it is likely.

### New observation: the LPIT settings are S0ix-flavoured while S0ix is off

`Lpit Recidency Counter = SLP S0` and `Lpit Windows RS2 Workaround = Enabled`, yet
`Low Power S0 Idle Capability = Disabled`. That is a mild internal inconsistency — the firmware
carries S0ix-oriented LPIT reporting while telling the OS to use S3.

**Rated very low as a cause:** macOS does not consume LPIT at all (it is a Windows/Linux S0ix
mechanism), and Ubuntu resumes cleanly on this exact firmware. Recorded for completeness only.

### Second wave, if S3 Video Repost does nothing

`Package C State Limit` is `[Auto]` = deepest available = **C10** on this part. Capping it
(`Setup:0x58F` → C8 or C6) is a known resume lever. Weakened considerably by the fact that Ubuntu
does clean deep S3 on identical firmware, so the CPU idle path is demonstrably fine.
