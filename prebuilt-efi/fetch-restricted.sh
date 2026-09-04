#!/bin/bash
# Fetch the kexts this repo deliberately does not redistribute.
# Run from prebuilt-efi/ ; results land in Kexts/.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p Kexts && cd Kexts

echo "==> ECEnabler (no licence upstream — fetched, not redistributed)"
gh release download --repo 1Revenger1/ECEnabler --pattern '*.zip' --clobber -O /tmp/ec.zip \
  && unzip -oq /tmp/ec.zip -d /tmp/ec && cp -R /tmp/ec/ECEnabler.kext . || echo "    manual: https://github.com/1Revenger1/ECEnabler/releases"

echo "==> AirportItlwm + Apple's IOSkywalkFamily / IO80211FamilyLegacy"
echo "    These ship inside OpenIntelWireless' AirportItlwm release archives."
echo "    Download the release matching your macOS and copy the kexts in:"
echo "      https://github.com/OpenIntelWireless/itlwm/releases"
echo "    NOTE: IOSkywalkFamily and IO80211FamilyLegacy are Apple binaries. Obtain them"
echo "    yourself; they are not redistributed by this repository."

echo "==> NullEthernet"
echo "    manual: https://github.com/RehabMan/OS-X-Null-Ethernet"

echo "==> AMFIPass"
echo "    ships with OpenCore Legacy Patcher: https://github.com/dortania/OpenCore-Legacy-Patcher"

echo "==> AppleHDA (audio root patch)"
echo "    NOT from your running macOS. Tahoe removed AppleHDA entirely, and every installed"
echo "    macOS since Big Sur ships STRIPPED kext bundles with no Contents/MacOS — a running"
echo "    Sequoia Mac, BaseSystem, createinstallmedia output and the sealed installer payload"
echo "    are all dead ends."
echo
echo "    The only source that ships unstripped kexts is a Kernel Debug Kit. You need TWO:"
echo "      1. Sequoia 15.7.x KDK  -> supplies AppleHDA.kext 600.2 (x86_64, incl. layout100)"
echo "      2. a KDK whose ProductBuildVersion string-matches your RUNNING build, so that"
echo "         kmutil will relink the kernel collections"
echo
echo "    Download them yourself from Apple (developer account required):"
echo "      https://developer.apple.com/download/all/?q=Kernel%20Debug%20Kit"
echo "    Community mirrors of KDKs exist that do not need an Apple login; this repository"
echo "    does not link to them."
echo
echo "    The kext is stock, Apple-signed and UNMODIFIED — \"root patch\" refers to patching the"
echo "    root VOLUME, not the kext. It is Apple-copyrighted and is not redistributed here."
echo "    Full procedure: ../README.md, section \"Audio on Tahoe\"."
echo
echo "Done. See NOTICE.md for why each of these is not bundled."
