# Lid on macOS: the EC signals SCI on GPE 0x50, and macOS drops it

## Symptom

Closing the lid did nothing in macOS. `AppleClamshellState` stayed `No` across a
real lid close (65/65 samples), and the kernel log for that window was completely
silent — no ACPI errors, no EC activity. The same lid on the same hardware sleeps
and wakes Ubuntu correctly:

```
lid=open x42 -> lid=closed x2 -> lid=open x46
Lid closed. -> PM: suspend entry (deep) -> Lid opened. -> PM: suspend exit
```

## Why

The lid is an EC query, not a GPIO button. `INT33D6` is absent; the handler is:

```asl
Method (_Q0C, 0, NotSerialized)          // DSDT line 39798
{
    LIDS = ECRD (RefOf (LSTE))
    ^^^GFX0.GLID (LIDS)
    Notify (LID0, 0x80)
}
```

The EC device names its SCI GPE indirectly (DSDT line 39576):

```asl
Method (_GPE, 0, NotSerialized) { Local0 = GGPE (0x02040010); Return (Local0) }
```

`GGPE` (line 11488) resolves that at runtime:

```
GGRP(0x02040010) = (0x02040010 & 0x00FF0000) >> 16 = 0x04
GNMB(0x02040010) = (0x02040010 & 0x0000FFFF)       = 0x10
Local2 = (GPEM >> (0x04 * 2)) & 3 = (GPEM >> 8) & 3

Local2 == 0 -> return 0x6F          <-- fallback only
Local2 == 1 -> 0x00 + 0x10 = 0x10
Local2 == 2 -> 0x20 + 0x10 = 0x30
Local2 == 3 -> 0x40 + 0x10 = 0x50
```

**Do not stop at the `0x6F` literal.** It is the `GPEM == 0` fallback and it is not
what this machine uses. The live value is **GPE 0x50**, and that is confirmed
independently from macOS itself:

```
ioreg -l | grep "ACPI Statistics"
  {"GpeLastDispatched"=80, "MethodCount"=..., "SciCount"=8811, "GpeCount"=8811, "FixedEventCount"=0}
```

80 decimal = 0x50. `GpeCount == SciCount` on every sample.

The firmware ships **no `_L50` and no `_E50`** — deliberately, because the OS's EC
driver is supposed to claim that GPE and run the `_Qxx` queries. macOS dispatches
GPE 0x50 but never executes `_Q0C`, so the lid event is simply lost.

## The measurable fingerprint

At idle, GPEs arrive in **bursts of ~64 dispatches** with ~11 AML method executions
per burst, separated by long quiet periods:

```
45s idle:  t=37.6s  MethodCount +11   GpeCount +64
```

A burst of ~64 identical dispatches of one level-triggered GPE is the signature of
an SCI that nobody ever clears: macOS never performs the EC query handshake, the EC
keeps SCI asserted, and the GPE re-fires until dispatch is suppressed.

Only 7 GPE methods exist in the DSDT — `_L6D _E09 _L69 _L61 _L62 _L66 _L6F` — and
none of them is the EC. `_L6F` is the PCIe RTD3 root-port handler (`AL6F`/`P0L6`/
`P1L6`/`P2L6`); it has nothing to do with the EC and wrapping it would not help.

## Two fixes, and why there are two

### Shipped first: poll `ADP1._PSR` (`SSDT-LIDPOLL`, superseded)

`_PSR` -> `XPSR` rename plus a wrapper that reads `LSTE` and notifies `LID0` on
change before calling `XPSR()`. This **works but is not a timed poll** — macOS
evaluates `_PSR` opportunistically. Measured: once detected the lid in ~30 s;
another time did not fire at all in 130 s. Good as a backstop, not as the mechanism.

### The real fix: supply the missing `\_GPE._L50` (`SSDT-LIDFIX`)

Nothing to rename — `_L50` is absent from the DSDT, so this is an **addition**, not
an override, and needs **no ACPI>Patch entry**. It mirrors `_Q0C` minus `GLID`
(a Windows graphics hook). `_LID` is `Return (ECRD (RefOf (LSTE)))`, i.e. it reads
the EC live, so no cached lid state has to be maintained for macOS to read back the
right value.

Gate the body on `_OSI("Darwin")`: this machine multiboots, and Linux's `acpi_ec`
installs a raw handler for this GPE that must not be shadowed.

## Traps hit on the way here

- **`0x6F` is the wrong answer.** It is `GGPE`'s fallback branch. Compute `GNMB`
  and `GGRP` and use `GpeLastDispatched` to pin the runtime value.
- **A PCI function number is not a root-port number**, and `_L6F` is not the EC.
- **`ioreg`'s `ACPI Statistics` is the cheapest ACPI instrument on macOS.**
  `GpeCount`, `SciCount`, `MethodCount` and `GpeLastDispatched` reveal GPE identity
  and AML execution rate with no kext and no debug build. Sample it over time —
  the deltas are what matter, the absolute totals say little.
- **Only ~half of an observed lid-to-sleep delay was ACPI.** Measured split:
  ~30 s of detection latency (ACPI) plus 31 s of macOS refusing to sleep while
  `cloudd` spammed `SystemIsActive`, `routined` held a Continuity assertion, and
  the AX88x72A USB-Ethernet dongle held a kernel USB assertion. Read
  `pmset -g assertions` before blaming firmware.
- **BSD awk has no `strftime`** and `log show --last <n>m` silently misses the event
  if the window is too short. Both produced wrong conclusions before being caught.

## SOLVED — 2026-08-30. But the FIRST answer was wrong; read both parts.

### What was actually wrong

`_Q0C`, the lid EC query, is:

```asl
Method (_Q0C, 0, NotSerialized) {
    LIDS = ECRD (RefOf (LSTE))
    ^^^GFX0.GLID (LIDS)        <-- Intel graphics OpRegion call
    Notify (LID0, 0x80)        <-- never reached
}
```

`LIDS` and `GFX0.GLID` both live in the Intel graphics SSDT (`SaSsdt`). The
handler aborts before the Notify, so the lid event is lost. **Fix: override
`_Q0C`/`_Q0D` with a bare `Notify(LID0, 0x80)`** — `_LID` is
`Return(ECRD(RefOf(LSTE)))`, i.e. it reads the EC live, so the Notify alone is
enough and `LIDS`/`GLID` are Windows graphics bookkeeping macOS does not need.

`_Q0C` and `_Q0D` are each unique in the DSDT, so plain 4-byte renames work.

Result: lid detected in **~5s** (macOS's EC-query servicing cadence), then
macOS's own ~30s clamshell->sleep assertion delay before the fan stops. Wake on
open is instant. Power button, Fn keys, thermal and battery notifies all keep
working. 0 ACPI errors, no GPE storm.

### ⚠ The wrong answer, and why it looked right for hours

The first diagnosis was **"macOS never dispatches `_Qxx` at all"**, supported by:
`_Q0C` never firing, `AppleClamshellState` never changing, zero ACPI errors in
the window, and ACPICA's `AcpiEvGpeDispatch` ("If a handler exists, we invoke it
and do not attempt to run the method") proving a raw driver handler on GPE 0x50
would make any `_L50`/`_E50` method inert.

That led to a **decoy**: rename the EC's `_GPE` and return an unused GPE (0x3F)
under `_OSI("Darwin")`, freeing GPE 0x50 for a hand-written `\_GPE._E50`.
It worked — the lid became genuinely instant.

**It also silently broke the power button.** `_Q54` (`Notify(PWRB, 0x80)`) and
the Fn/hotkey handlers (`_Q80..._Q99` -> `HIDD`) ride the same dispatch path.
Taking GPE 0x50 from `AppleACPIEC` killed all of them. Caught only because the
owner noticed a short power-button press no longer raised the shutdown dialog.

So macOS **does** dispatch EC queries. The evidence that "proved" otherwise was
all consistent with a *single failing handler*. The tell was there and was
misread: **~12 AML method executions were measured at every lid close** and the
decoy theory could not explain them. Those were the query handlers running.

**Do not re-derive the decoy.** It trades the power button, Fn keys and thermal
notifies for ~5s of lid latency. The artefacts are kept on the ESP as
`SSDT-LIDFIX.aml.DECOY` and `config.plist.PRE-ECQ` purely as a record.

### Lesson

A negative ("macOS never runs `_Qxx`") drawn from one broken instance is not a
negative — it is one broken instance. Before concluding a whole subsystem is
dead, test a *second* consumer of it. One short power-button press would have
falsified the theory in five seconds, before any of the GPE work was done.

### The caching trap — a bug that shipped and had to be caught on hardware

The first EC-query build had `_Q0C` call a shared `CHKL()` helper that only
notified when `LSTE` **differed from a cached value**:

```asl
Local0 = ECRD (RefOf (LSTE))
If ((Local0 == LIDC)) { Return (Zero) }   /* silently drops the event */
```

If the query fires before the EC's lid bit has settled, that reads the stale
value, sees no change, and **discards the event entirely** — detection then falls
through to the `ADP1._PSR` poll. The same build measured **~5s once and exactly
30s the next time**, intermittently, which is the signature of the poll carrying
it rather than the query.

The firmware's own `_Q0C` notifies **unconditionally**, and `_LID` is
`Return(ECRD(RefOf(LSTE)))` — macOS re-reads the EC live when it receives the
Notify. So a redundant notify costs nothing and a dropped one costs everything.

⚠ **Do not "optimise" the EC-query path with the LIDC cache.** `LIDC` is
deliberately not even updated there, so the poll path can re-evaluate
independently and self-correct if the query did race. The cache exists only for
`ADP1._PSR`, where deduplication actually matters.

### Dead ends, so nobody repeats them

* **Wrapping the seven firmware GPE handlers** (`_L61 _L62 _L66 _L69 _L6D _L6F
  _E09`) does nothing: `GpeLastDispatched` is **0x50 on every sample** — 0x50 is
  the only GPE this machine ever fires, so those handlers never run.
* **`_L6F` is not the EC.** It is the PCIe RTD3 root-port handler
  (`AL6F`/`P0L6`/`P1L6`/`P2L6`).
* **Polling `ADP1._PSR` works but is not a timer.** Kept as the backstop. macOS
  evaluates it on a ~60s power poll: measured 30s, 45s and 61.0s latencies, and
  once not at all in 130s.
* **Do not drain the EC queue from AML** with a `SystemIO` region over ports
  0x62/0x66 doing `QR_EC`. It races macOS's own EC driver on the same ports.

### Verifying on the machine

```bash
python3 /tmp/probe3.py 45   # GpeCount/MethodCount deltas per second
```
Methods-per-GPE is the tell: **0.17** means `_E50` is not being dispatched,
**~4** means it is. `/tmp` is wiped on reboot — re-upload the probe each time.
