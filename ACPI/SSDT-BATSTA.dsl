/*
 * SSDT-BATSTA - GPD P2 MAX, silence the BAT0._STA boot-ordering ACPI errors
 *
 * 14 of the 18 standing ACPI errors are one fault, logged twice and duplicated:
 *     ACPI Error: No handler for Region [ECF2] (...) [EmbeddedControl]  (evregion-252)
 *     ACPI Error: Region EmbeddedControl (ID=3) has no handler          (exfldio-392)
 *     ACPI Error: Method parse/execution failed [\_SB.PCI0.LPCB.EC.BAT0._STA]
 *     ACPI Error: Method execution failed       [\_SB.PCI0.LPCB.EC.BAT0._STA]
 *
 * Cause (DSDT line 39635): BAT0._STA reads the EC field ECWR *directly* -
 *
 *     Method (_STA, 0, NotSerialized) {
 *         If ((ECWR & 0x02)) { Return (0x1F) }
 *         Return (0x0F)
 *     }
 *
 * - with no ECAV guard and without going through ECRD.  Compare LID0._LID,
 * which is Return(ECRD(RefOf(LSTE))) and is therefore guarded.  ECAV is only
 * set by the EC's _REG(3,1) (DSDT line 39748), so any _STA evaluation before
 * the EmbeddedControl handler is installed hits a region with no handler.
 * SSDT-BATT overrides _BIF and _BST but not _STA, which is why this survived.
 *
 * The fix returns "battery present" until the EC is actually readable, then
 * defers to the firmware method unchanged.  0x1F, not 0x0F: bit 4 (0x10) is
 * the ACPI "battery present" bit, and this machine's battery is non-removable,
 * so claiming absent could make macOS skip the device entirely.
 *
 * Paired with a BYTE-TARGETED rename, because _STA appears 125 times in this
 * DSDT and a name rename would be catastrophic.  Exactly one _STA is followed
 * by flags=0 and ECWR:
 *     Find    5F 53 54 41 00 A0 0C 7B 45 43 57 52
 *     Replace 58 53 54 41 00 A0 0C 7B 45 43 57 52
 *
 * Not gated on _OSI("Darwin"): the ECAV guard is correct for any OS, and
 * strictly better than the unguarded firmware original.
 */
DefinitionBlock ("", "SSDT", 2, "P2MAX", "BATSTA", 0x00000000)
{
    External (_SB_.PCI0.LPCB.EC__, DeviceObj)
    External (_SB_.PCI0.LPCB.EC__.BAT0, DeviceObj)
    External (_SB_.PCI0.LPCB.EC__.BAT0.XSTA, MethodObj)
    External (_SB_.PCI0.LPCB.EC__.ECAV, IntObj)

    Scope (\_SB.PCI0.LPCB.EC.BAT0)
    {
        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            If (!\_SB.PCI0.LPCB.EC.ECAV)
            {
                /* EC not readable yet - battery is present, details unknown */
                Return (0x1F)
            }

            Return (XSTA ())
        }
    }
}
