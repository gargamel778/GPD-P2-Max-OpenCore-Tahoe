# `prebuilt-efi/` — the kexts this machine actually runs

The 21 redistributable kexts from the working EFI, at the exact versions in
[`NOTICE.md`](NOTICE.md), which also lists every licence and upstream.

⚠ **This is not a drop-in, bootable EFI.** Five kexts are deliberately missing — three because they
are Apple binaries and two because their upstreams grant no licence. Run
[`fetch-restricted.sh`](fetch-restricted.sh) to get them, or see the "Not included" table in
`NOTICE.md`.

`config.plist` and the ACPI tables are in the repository root and [`ACPI/`](../ACPI/); the
`config.plist` published there has **placeholder SMBIOS** — generate your own serials before booting.

Only `AirportItlwm-Tahoe.kext` is modified (see `NOTICE.md` for the GPL source pointer). Everything
else is an unmodified upstream release.
