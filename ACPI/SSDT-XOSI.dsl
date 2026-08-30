/*
 * SSDT-XOSI — report the Windows _OSI strings this DSDT's OSYS ladder tests for.
 *
 * Purpose here is NOT to change AML on the sleep-entry path: the _PTS call closure
 * (14 methods) was verified OSYS-blind on the runtime DSDT. The purpose is that OSYS
 * is a field in the GNVS ACPI-NVS region (runtime 0x8CA53000, len 0x0793), which SMM
 * firmware also maps. macOS currently leaves OSYS = 0x07D0 (Windows 2000); Linux, which
 * resumes fine, leaves 0x07DF. This makes macOS write 0x07DF too, so that any SMM S3-entry
 * code branching on GNVS.OSYS takes the same path it takes under Linux.
 *
 * Pair with an ACPI rename patch: _OSI -> XOSI, TableSignature DSDT.
 * Strings match the ladder in \_SB.PCI0._INI (runtime DSDT lines 19305-19345).
 */
DefinitionBlock ("", "SSDT", 2, "ACDT", "XOSI", 0x00001000)
{
    Method (XOSI, 1, NotSerialized)
    {
        Local0 = Package ()
            {
                "Windows 2001",       /* OSYS 0x07D1  Windows XP     */
                "Windows 2001 SP1",   /* OSYS 0x07D1                 */
                "Windows 2001 SP2",   /* OSYS 0x07D2                 */
                "Windows 2001.1",     /* OSYS 0x07D3  Server 2003    */
                "Windows 2006",       /* OSYS 0x07D6  Vista          */
                "Windows 2009",       /* OSYS 0x07D9  Windows 7      */
                "Windows 2012",       /* OSYS 0x07DC  Windows 8      */
                "Windows 2013",       /* OSYS 0x07DD  Windows 8.1    */
                "Windows 2015"        /* OSYS 0x07DF  Windows 10     */
            }
        Return ((Ones != Match (Local0, MEQ, Arg0, MTR, Zero, Zero)))
    }
}
