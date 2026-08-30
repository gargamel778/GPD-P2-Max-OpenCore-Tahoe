# OpenCanopy picker assets

## macOS-Tahoe-VolumeIcon.icns

The round macOS Tahoe icon shown for **Macintosh HD** in the OpenCore graphical
picker. Source: `/Applications/Install macOS Tahoe.app/Contents/Resources/ProductPageIcon.icns`
(1024x1024, md5 `95d6d0b31f4fe97a75de524dbf7b0061`).

Kept here because the source disappears if the installer app is deleted, and
because **macOS updates rewrite the Preboot volume**, which is where it lives.

### Install / restore

```bash
sudo cp macOS-Tahoe-VolumeIcon.icns /System/Volumes/Preboot/.VolumeIcon.icns
sudo chmod 644 /System/Volumes/Preboot/.VolumeIcon.icns
```

⚠ It goes on **Preboot**, not `/`. The System volume is a sealed read-only
snapshot, so `/.VolumeIcon.icns` cannot be written without breaking the seal.
Preboot is the volume OpenCore actually boots (`<UUID>/System/Library/CoreServices/boot.efi`)
and is writable.

Requires `Misc > Boot > PickerAttributes` bit 1 (`USE_VOLUME_ICON`) — currently
`145` = `USE_VOLUME_ICON + USE_POINTER_CONTROL + USE_FLAVOUR_ICON`.

### Why a per-volume icon is needed at all

The Acidanthera themes (GoldenGate / Chardonnay / Syrah — 24 files each, all
identical) ship **no macOS and no Linux disk icon**:

```
HardDrive  ExtHardDrive  Windows  AppleRecv  ExtAppleRecv  AppleTM  ExtAppleTM
Tool  Shell  FirmwareSettings  NetworkBoot  + UI chrome
```

So macOS and Linux both correctly fall back to `HardDrive.icns` and look
identical. Windows getting its own icon is the proof `USE_FLAVOUR_ICON` works.

### Wrong candidates, so nobody repeats them

| file | what it actually is |
|---|---|
| `InstallAssistant.icns` | squircle with a **download-arrow badge** — the installer, not the OS |
| `CoreTypes.bundle/.../SystemFolderIcon.icns` | the old **folder-with-an-X** OS X System folder |
| **`ProductPageIcon.icns`** | **the clean round Tahoe artwork — this one** |

Filenames mislead. Render candidates and look at them before installing:

```bash
sips -s format png -Z 256 Some.icns --out /tmp/Some.png
```
