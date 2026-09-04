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
echo "    Apple binary. See ../README.md — it comes from your own macOS installation."
echo
echo "Done. See NOTICE.md for why each of these is not bundled."
