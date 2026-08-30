DefinitionBlock ("", "SSDT", 2, "P2MAX", "UPCFIX", 0x00000001)
{
    // Replaces the _UPC methods of SSDT xh_rvp03, renamed to XUPC by an
    // OpenCore ACPI patch scoped to that table. All values reproduced
    // verbatim EXCEPT HS03/HS05, which the firmware declared as type 0xFF
    // (internal) despite being the two physical external ports.
    External (\_SB.PCI0.XHC.RHUB.HS01, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS02.CAM1, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS03, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS04, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS05, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS06, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS07, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS08, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS09, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.HS10, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.USR1, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.USR2, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.SS01, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.SS02, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.SS03, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.SS04, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.SS05, DeviceObj)
    External (\_SB.PCI0.XHC.RHUB.SS06, DeviceObj)

    Scope (\_SB.PCI0.XHC.RHUB.HS01)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0x09, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS02.CAM1)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS03)    // CHANGED from 0xFF - physical external port
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0x03, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS04)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS05)    // CHANGED from 0xFF - physical external port
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0x03, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS06)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS07)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS08)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS09)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.HS10)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.USR1)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.USR2)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.SS01)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.SS02)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.SS03)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0x09, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.SS04)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { One, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.SS05)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }

    Scope (\_SB.PCI0.XHC.RHUB.SS06)
    {
        Method (_UPC, 0, NotSerialized)
        {
            Return (Package (0x04) { Zero, 0xFF, Zero, Zero })
        }
    }
}
