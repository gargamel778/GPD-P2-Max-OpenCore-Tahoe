# Getting the boot ACPI error count from 18 to 0

Two unrelated faults, both silent, both fixed 2026-08-30. The 18 lines were only
**9 distinct errors** — this log double-prints every ACPI error, so always divide
by two before estimating how much is wrong.

## Fault 1 (4 lines): SSDT-PM never loaded

```
ACPI Error: [_DSM] Namespace lookup failure, AE_ALREADY_EXISTS
ACPI Error: 1 table load failures, 25 successful   (20160930/tbxfload-342)
            (SSDT:   CpuPm) while loading table
```

`SSDT-PM.aml` (OEM Table ID `CpuPm`) and `SSDT-PLUG.aml` **both** define `_DSM`
on `\_PR.PR00`. SSDT-PLUG loads first, so SSDT-PM is rejected **in its entirety**,
every boot. It was added during the sleep investigation and therefore **played no
part in the sleep fix** — it has never been in effect.

Nothing was lost by disabling it. Its 1908 bytes are:

| object | what it is | used here? |
|---|---|---|
| `APSN` / `APSS` (29 P-state packages) / `ACST` / `APLF` | legacy CPU PM tables | **No** |
| `_DSM` → `"plugin-type", One` | duplicate of SSDT-PLUG's | Redundant |

Those legacy objects are consumed by `AppleIntelCPUPowerManagement`, and this
machine runs XCPM:

```
machdep.xcpm.mode: 1
X86PlatformPlugin loaded:            1
AppleIntelCPUPowerManagement loaded: 0     <- the only consumer
```

SSDT-PLUG's `_DSM` is also the better implementation — it goes through `DTGP`,
where SSDT-PM's writes to the `Debug` object.

**Fix:** disable `SSDT-PM.aml`.

## Fault 2 (14 lines): BAT0._STA reads the EC unguarded

```
ACPI Error: No handler for Region [ECF2] (...) [EmbeddedControl]  (evregion-252)
ACPI Error: Region EmbeddedControl (ID=3) has no handler          (exfldio-392)
ACPI Error: Method parse/execution failed [\_SB.PCI0.LPCB.EC.BAT0._STA]
ACPI Error: Method execution failed       [\_SB.PCI0.LPCB.EC.BAT0._STA]
```

DSDT line 39635:

```asl
Method (_STA, 0, NotSerialized) {
    If ((ECWR & 0x02)) { Return (0x1F) }   // direct EC field read
    Return (0x0F)
}
```

`ECWR` is read **raw** — no `ECAV` guard, not via `ECRD`. Compare `LID0._LID`,
which is `Return (ECRD (RefOf (LSTE)))` and is guarded. `ECAV` is only set by the
EC's `_REG(3,1)` (DSDT line 39748), so any `_STA` evaluation before the
EmbeddedControl handler is installed hits a region with no handler.
`SSDT-BATT` overrides `_BIF` and `_BST` but **not** `_STA` — which is why this one
survived every previous cleanup.

**Fix:** `SSDT-BATSTA.aml` returns "battery present" until the EC is readable,
then defers to the firmware method unchanged.

⚠ **`_STA` appears 125 times in this DSDT** — a name rename would be
catastrophic. Use a byte-targeted patch. Exactly one `_STA` is followed by
`flags=0` and `ECWR`:

```
Find    5F 53 54 41 00 A0 0C 7B 45 43 57 52     TableSignature DSDT, Count 1
Replace 58 53 54 41 00 A0 0C 7B 45 43 57 52

14 16 | 5F 53 54 41 | 00 | A0 0C | 7B | 45 43 57 52 | 0A 02 | 00 | A4 0A 1F | A4 0A 0F
Method  _STA          flg   If     And   ECWR          0x02    dst  Ret 0x1F   Ret 0x0F
```

Return **0x1F**, not 0x0F: bit 4 (0x10) is the ACPI "battery present" bit, and
this battery is non-removable — claiming absent risks macOS skipping the device.
Not gated on `_OSI("Darwin")`: the `ECAV` guard is correct for any OS and is
strictly better than the unguarded firmware original.

## Result

```
ACPI errors: 0        ACPI exceptions: 0
battery: 100%; charged; present: true      (still detected through the override)
no table load failures
```

## Also settled the same day: CFG Lock

`AppleXcpmCfgLock` was dropped to `False`. There is **no way to read MSR 0xE2
from macOS here** — no OpenCore log file on the ESP, and the firmware `Setup`
variable is not exposed via `nvram` — and with the quirk on, locked and unlocked
boot identically, so there is no runtime signal either. The only test is to drop
it and boot: if CFG Lock were still locked, XCPM writing MSR 0xE2 faults `#GP` →
early kernel panic, unrecoverable remotely. It booted clean, so the
`setup_var.efi` CFG-Lock change did stick.

Recovery for that class of change, if ever needed: **OpenShell → `fs0:` →
`cd EFI\OC` → copy the backup over `config.plist`.** Never from Linux.
