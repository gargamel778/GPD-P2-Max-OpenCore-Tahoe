/*
 * SSDT-LIDFIX - GPD P2 MAX, macOS lid support  (v5, EC-query approach)
 *
 * HISTORY - READ THIS BEFORE "IMPROVING" IT
 * -----------------------------------------
 * The lid is an EC query.  _Q0C in the firmware DSDT is:
 *
 *     Method (_Q0C, 0, NotSerialized) {
 *         LIDS = ECRD (RefOf (LSTE))
 *         ^^^GFX0.GLID (LIDS)        <-- Intel graphics OpRegion call
 *         Notify (LID0, 0x80)        <-- never reached if GLID throws
 *     }
 *
 * An earlier revision concluded macOS never dispatches _Qxx at all, and worked
 * around it by renaming the EC's _GPE and handing macOS a decoy GPE so a
 * hand-written \_GPE._E50 would receive GPE 0x50 instead.  That DID give an
 * instant lid - and it BROKE THE POWER BUTTON, because _Q54 (Notify PWRB 0x80)
 * and the Fn/hotkey handlers (_Q80.._Q99 -> HIDD) ride the very same dispatch
 * path.  Verified on hardware: with the decoy in place a short power-button
 * press does nothing, where it previously raised the shutdown dialog.
 *
 * So macOS DOES dispatch EC queries.  Only _Q0C was failing, and it explains
 * the ~12 AML method executions measured at each lid close that the decoy
 * theory could not account for: the query handlers were running all along.
 *
 * THIS VERSION
 * ------------
 * Leaves the EC's _GPE alone, so AppleACPIEC keeps GPE 0x50 and every other
 * _Qxx (power button, Fn keys, thermal, battery) keeps working.  It replaces
 * only _Q0C/_Q0D with a bare Notify - LIDS and GFX0.GLID are dropped as
 * Windows graphics-driver bookkeeping macOS does not need.  _LID is
 * Return(ECRD(RefOf(LSTE))), i.e. it reads the EC live, so the Notify alone
 * is sufficient and no cached lid state has to be maintained.
 *
 * ADP1._PSR stays hooked as a backstop on macOS's ~60s power poll (0-60s
 * latency).
 *
 * ⚠ THE EC-QUERY PATH NOTIFIES UNCONDITIONALLY - DO NOT "OPTIMISE" IT WITH THE
 * LIDC CACHE.  An earlier revision had _Q0C call CHKL(), which only notifies
 * when LSTE differs from the cached value.  If the query fires before the EC's
 * lid bit has settled, that reads the stale value, sees no change, and DISCARDS
 * the event - detection then falls through to the ~60s poll.  Measured: the
 * same build gave ~5s once and exactly 30s the next time, intermittently.
 * The firmware's own _Q0C notifies unconditionally, and _LID is
 * Return(ECRD(RefOf(LSTE))) - macOS re-reads the EC live when it receives the
 * Notify - so an occasional redundant notify is free and a dropped one is not.
 *
 * LIDC is deliberately NOT updated here either: leaving it alone lets the poll
 * path re-evaluate independently and self-correct if the query did race.
 */
DefinitionBlock ("", "SSDT", 2, "P2MAX", "LIDFIX", 0x00000000)
{
    External (_SB_.PCI0.LPCB.EC__, DeviceObj)
    External (_SB_.PCI0.LPCB.EC__.ADP1, DeviceObj)
    External (_SB_.PCI0.LPCB.EC__.ADP1.XPSR, MethodObj)
    External (_SB_.PCI0.LPCB.EC__.LID0, DeviceObj)
    External (_SB_.PCI0.LPCB.EC__.LSTE, FieldUnitObj)
    External (_SB_.PCI0.LPCB.EC__.ECRD, MethodObj)
    External (_SB_.PCI0.LPCB.EC__.ECAV, IntObj)

    Name (LIDC, 0xFF)

    Method (CHKL, 0, Serialized)
    {
        If (!\_SB.PCI0.LPCB.EC.ECAV)
        {
            Return (Zero)
        }

        Local0 = \_SB.PCI0.LPCB.EC.ECRD (RefOf (\_SB.PCI0.LPCB.EC.LSTE))
        If ((Local0 == LIDC))
        {
            Return (Zero)
        }

        LIDC = Local0
        Notify (\_SB.PCI0.LPCB.EC.LID0, 0x80) // Status Change
        Return (One)
    }

    Scope (\_SB.PCI0.LPCB.EC)
    {
        /* Lid open/close EC queries - paired with _Q0C->XQ0C, _Q0D->XQ0D.
           Unconditional, exactly like the firmware handler. */
        Method (_Q0C, 0, NotSerialized)  // _Qxx: EC Query
        {
            Notify (\_SB.PCI0.LPCB.EC.LID0, 0x80) // Status Change
        }

        Method (_Q0D, 0, NotSerialized)  // _Qxx: EC Query
        {
            Notify (\_SB.PCI0.LPCB.EC.LID0, 0x80) // Status Change
        }
    }

    Scope (\_SB.PCI0.LPCB.EC.ADP1)
    {
        Method (_PSR, 0, NotSerialized)  // _PSR: Power Source
        {
            If (_OSI ("Darwin"))
            {
                \CHKL ()
            }

            Return (XPSR ())
        }
    }
}
