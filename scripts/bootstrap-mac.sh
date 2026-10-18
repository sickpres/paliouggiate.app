#!/bin/bash
# Prepara un Mac appena creato (Scaleway o altro) a compilare l'app. Idempotente: rieseguirlo non rompe nulla.
# Si lancia dal PC, senza copiare niente prima:
#
#   ssh -i ~/.ssh/macincloud m1@<indirizzo> 'bash -s' < scripts/bootstrap-mac.sh
#
# Non installa Xcode (l'immagine Scaleway lo include) e non usa sudo, Homebrew o CocoaPods.

set -uo pipefail

FLUTTER_VERSIONE=3.47.7   # quella con cui l'app e' stata compilata l'ultima volta (ottobre 2026)
MIN_XCODE_MAJOR=26
CARTELLA="$HOME/Desktop/paliouggiate.app"

echo "=== macOS e Xcode ==="
sw_vers | tr '\n' ' '; echo "($(uname -m))"
if ! xcodebuild -version 2>/dev/null; then
  echo "!! xcodebuild non disponibile (se Xcode c'e': sudo xcode-select -s /Applications/Xcode.app)"
  exit 1
fi
XCODE_MAJOR=$(xcodebuild -version | head -1 | sed -E 's/Xcode ([0-9]+).*/\1/')
[ "${XCODE_MAJOR:-0}" -ge "$MIN_XCODE_MAJOR" ] || { echo "!! serve Xcode $MIN_XCODE_MAJOR o piu' recente"; exit 1; }

echo
echo "=== piattaforma iOS ==="
# L'immagine Scaleway ha Xcode ma non la piattaforma iOS (~8,5 GB, una volta per macchina): senza, la build fallisce
if xcrun simctl list runtimes 2>/dev/null | grep -qi ios; then
  echo "gia' presente: $(xcrun simctl list runtimes | grep -i ios | head -1)"
else
  echo "assente: la scarico (~8,5 GB, qualche minuto)..."
  xcodebuild -downloadPlatform iOS > /tmp/downloadPlatform.log 2>&1 \
    && echo "installata: $(xcrun simctl list runtimes | grep -i ios | head -1)" \
    || { echo "!! download non riuscito, vedi /tmp/downloadPlatform.log"; exit 1; }
fi

echo
echo "=== Flutter $FLUTTER_VERSIONE in ~/flutter ==="
if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  git clone --depth 1 -b "$FLUTTER_VERSIONE" https://github.com/flutter/flutter.git "$HOME/flutter" \
    || git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter" \
    || { echo "!! clone di Flutter non riuscito"; exit 1; }
fi
export PATH="$HOME/flutter/bin:$PATH"
flutter --version 2>&1 | head -1
flutter config --no-analytics >/dev/null 2>&1
# i plugin si risolvono con Swift Package Manager: niente CocoaPods
flutter config --enable-swift-package-manager >/dev/null
flutter precache --ios >/dev/null 2>&1 && echo "motore iOS scaricato"

echo
echo "=== cartella dell'app ==="
mkdir -p "$CARTELLA"
echo "pronta: $CARTELLA (i sorgenti li manda scripts/ipa-remota.sh dal PC)"

echo
echo "=== spazio disco ==="
df -h "$HOME" | tail -1
echo
echo "Fatto. Dal PC: bash scripts/ipa-remota.sh m1@<indirizzo>"
