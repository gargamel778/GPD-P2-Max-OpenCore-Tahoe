# Permanent unlock — patched BIOS

Makes Advanced/Chipset visible on every boot, with no CMOS re-arming.

> **This document was rewritten after the first version was found to be wrong.**
> The original procedure (rename the patched image to `P2MAX.0.29.bin`, run GPD's `F.BAT`) would
> have **silently reflashed the stock BIOS** and never applied the patch. See "What was wrong" below.

## The patch itself — verified, and independently re-derived

In `AMITSE` (GUID `B1DA0ADF-4F77-4070-A88E-BFFE1C60529A`), PE32 offset `0x32C2B`: `0x74` (je) →
`0xEB` (jmp).

```
0x32C27  41 80 FE AA        cmp  r14b, 0xAA
0x32C2B  74 16  ->  EB 16   je/jmp +0x16     <-- patched
0x32C2D  B8 12 27 00 00     mov  eax, 0x2712   (Advanced)
0x32C36  74 51              je   skip
0x32C38  B8 13 27 00 00     mov  eax, 0x2713   (Chipset)
0x32C41  74 46              je   skip
0x32C43                     <-- promote path; the je already targets exactly here
```

Making it unconditional means the CMOS gate is ignored and both pages are always promoted.
Re-derived independently: 226 PE32 modules per image, identical key sets, exactly one module
differs, same length (428384), one byte, branch target past both compares.

## ⚠ Correction: this is a REBUILT image, not a one-byte flash

`AMITSE` is LZMA-compressed, so the patch required a decompress/patch/recompress/rebuild.
**At image level, 2,582,061 bytes differ across 10,038 runs** (all inside `0x2992D8-0x5121F9`).
"Exactly one byte differs" is true only at the *extracted-module* level, which is a weaker claim.

Any argument of the form "only one byte changes on the chip, so this is low risk" is **invalid**.
The whole BIOS region gets rewritten. Verification is structural, not byte-level:

- Both images fully extracted; all 5837 files compared.
- Exactly one module's content differs, and only by the intended byte.
- No module added, removed or otherwise altered.
- No pad files exist in this image, so UEFIPatch's pad-file warning does not apply.
- Descriptor and ME regions are **byte-identical** between stock and patched.

## What was wrong in the first version

`FPTW64.exe -f P2MAX.0.29.bin -ME` — **`-ME` is a region selector**, not a modifier. FPT's own
option table reads "Load/verify/dump Descriptor region. / …BIOS region. / …Intel ME region. /
…Legacy GbE region. / …PDR region."

So GPD's flow is:

- `V029.exe` — **AFUWINx64 5.11.06.1854 with a complete 8 MiB BIOS image appended as a PE overlay**
  (PE sections end at `0x97A00` = 620544 bytes; overlay = 4973120 bytes; module chain
  `@UAF`/`@UII`/`@W64`/`@ROM`/`@CMD` with every size link exact; the `@ROM` uncompressed-size field
  is `0x00800000`). It self-invokes `/P /B /N /R /K` **with no filename**, so it flashes the BIOS
  region from its *own embedded image*.
- `FPTW64.exe -f … -ME` — writes only the **ME** region.

And the patched image is byte-identical to stock in the ME and Descriptor regions. So substituting
the file could not have changed a single byte FPT writes. The result would have been: stock BIOS
reflashed, patch absent, no Advanced tab, and the natural conclusion that the analysis was wrong.

## What is NOT in the way

- **Intel BIOS Guard is present but unprovisioned.** The FIT Key Manifest (`0x7E1200`) and Boot
  Policy Manifest (`0x7E0180`) are **100% zero-filled**; the "Intel Bios Guard Support" setup
  question (`Setup:0x1098`) defaults to `0` and the factory Setup image byte there is `0x00`; there
  is no `_AMIPFAT` container and no BGUP package in the ROM. AFU's
  "[Intel Bios Guard Technology Is Enabled]" banner is a static build-variant string in V029.exe,
  not a platform report.
- **The flash descriptor is fully unlocked.** `FLMSTR1 = 0xFFFFFF00` — host has read+write to
  Descriptor, BIOS and ME. BIOS Lock (BLE) defaults Disabled.

So an unsigned, modified image can be written. GPD's own flow depends on that too.

## ⚠ The remaining real risk: per-unit data

`P2MAX029.bin` is md5-identical to the image inside GPD's updater, so it is the **vendor's generic
image, not a dump of this machine**. Writing it wholesale would overwrite whatever per-unit content
currently lives in this unit's BIOS region. AFU's `/R /K` switches and its `Id_SMBIOS_Store` /
`Id_SMBIOS_ReStore` routines exist precisely because vendors preserve such data across updates.

**Therefore: do not flash the vendor image at all. Patch this machine's own BIOS region.**

## Procedure

Windows, via the drive swap. The UEFI-shell route is rejected: GPD's package contains **no EFI
binaries**, and this platform is **CSME 11.8.55.3510** (`$MN2` at ME+`0x1494`) — not 12.x as first
assumed — so a mismatched `Fpt.efi` sourced from a forum would be the one component with no
provenance *and* full SPI write authority. Windows keeps every binary in the trust path to ones GPD
shipped and this machine has already run once.

### 1. Prepare (before touching anything)

- Put the ADATA M.2 back in so Windows boots.
- Copy `P2MAX029.bin` (stock) **off** the machine. It is useless sitting on a device that won't boot.
- AC power connected. Do not let it sleep or close the lid during any step.

### 2. Dump this machine's actual BIOS region — read-only, no risk

From an Administrator command prompt in GPD's unpacked folder:

```
FPTW64.exe -d mybios.bin -BIOS
```

This proves read access works and tells us exactly what is on the chip. **Send me `mybios.bin`.**

### 3. Patch the dump, not the vendor image

I will apply the same one-byte `UEFIPatch` transform to *your* dump and verify it the same
structural way (full extraction, module-by-module comparison). That preserves every per-unit byte
and changes only the AMITSE branch.

Nothing gets written until that verification passes.

### 4. Write it back

```
FPTW64.exe -f mybios-unlocked.bin -BIOS
```

Only the BIOS region. ME and descriptor are never touched, so the classic unrecoverable
ME-corruption brick is off the table.

**If it errors before writing** — permission denied, region locked — that is a clean failure.
Nothing has been erased. Stop and report.

**If it errors during writing** — do not power off. Report immediately.

### 5. Verify the patch actually landed

```
FPTW64.exe -d after.bin -BIOS
```

Send it to me. I will confirm the AMITSE byte is `0xEB` in the image read back off the chip —
not merely that the tool printed success.

### 6. Expect NVRAM to be reset

A BIOS-region write clears UEFI boot variables. You will likely have to re-select the boot device
in setup, exactly as after the 0.24 → 0.29 update. That is expected, not a failure.

## Rollback

`P2MAX029.bin` is the untouched stock image. Better: the `mybios.bin` dump from step 2 is *this
machine's own* pre-patch BIOS region, and is the more faithful restore. Keep both off-machine.

---

## OUTCOME — flashed successfully 2026-08-29

Intel FPT 11.6.1.1142. Flash device **GD25B64B** (`ID:0xC84017`, 8192 KB). Descriptor reported Valid.

```
- Reading Flash    [0x0800000] 6144KB of 6144KB - 100 percent complete.
- Erasing Flash Block [0x513000]        - 100 percent complete.
- Programming Flash [0x0513000] 2536KB of 2536KB - 100 percent complete.
- Verifying Flash  [0x0800000] 6144KB of 6144KB - 100 percent complete.
RESULT: The data is identical.
FPT Operation Successful.
```

FPT wrote **differentially** — 2536 KB, matching our changed range (`0x2992D8-0x5121F9` ≈ 2531 KB)
rather than rewriting the untouched 3.5 MB.

**Independent verification, not just the tool's success message:**

| Check | Result |
|---|---|
| `after.bin` (read back off the chip) md5 | `98c2e767810a8a9f5d3aee013f1e9abd` |
| Intended image md5 | `98c2e767810a8a9f5d3aee013f1e9abd` — **identical** |
| Bytes differing from intended | **0** |
| AMITSE `0x32C2B` extracted from the read-back | **`0xEB`** |
| Old gated pattern `4180FEAA7416` on chip | 0 occurrences |
| Patched pattern `4180FEAAEB16` on chip | 1 occurrence |

### Obstacle hit along the way

`FPTW64.exe` first failed with `err: -2146762484` = **`0x800B010C` `CERT_E_REVOKED`** —
"Error 366: Fail to load driver (PCI access for Windows)". The message blames privileges but the
prompt was already elevated. The real cause is that FPT's helper kernel driver (arbitrary PCI /
physical memory access) has had its signing certificate **revoked** and is caught by Windows'
vulnerable-driver blocklist. It worked for the 0.24 → 0.29 update because Windows had not yet
picked the revocation up.

Resolved by relaxing driver signature enforcement for the flash. **Re-enable Memory Integrity and
the vulnerable-driver blocklist afterwards.**

### Rollback

`mybios.bin` (md5 `88a33423cd2db00730605d03909389c4`) is this machine's own pre-patch BIOS region.
It is deliberately **not committed** — it contains per-unit data. Keep it off-machine.
Restore with `FPTW64.exe -f mybios.bin -BIOS`.
