#!/bin/bash
# Da eseguire SUL MAC, nella cartella del progetto Flutter.
#
# Produce dist/PalioUggiate.ipa NON firmato: lo firma Sideloadly, sul PC Windows,
# con l'Apple ID gratuito al momento dell'installazione.
#
#   bash scripts/build-ipa.sh
#
set -uo pipefail
export PATH="$HOME/flutter/bin:$PATH"

NOME="Palio Uggiate"
OUT="dist/PalioUggiate.ipa"

if [ ! -f pubspec.yaml ] || [ ! -d ios ]; then
  echo "!! Esegui lo script dalla cartella del progetto (serve ios/, generata da flutter create)."
  exit 1
fi

# nome sotto l'icona (CFBundleDisplayName) e nome del bundle
PLIST=ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $NOME" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $NOME" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $NOME" "$PLIST"

echo "=== Dipendenze e icona ==="
flutter pub get || exit 1
dart run flutter_launcher_icons || exit 1

echo
echo "=== Analisi ==="
flutter analyze || { echo "!! Correggi gli errori dell'analisi."; exit 1; }

echo
echo "=== Build Release per dispositivo, senza firma ==="
flutter build ios --release --no-codesign || { echo "!! Build fallita."; exit 1; }

APP=build/ios/iphoneos/Runner.app
[ -d "$APP" ] || { echo "!! Non trovo $APP"; exit 1; }

# Ogni dipendenza @rpath deve essere nel bundle, altrimenti l'app si chiude
# all'avvio senza messaggi (successo con FioriSwiftUI nel prototipo SwiftUI).
echo
echo "=== Verifica delle dipendenze dinamiche ==="
MANCA=0
for dep in $(otool -L "$APP/Runner" | awk '/@rpath/ {print $1}' | sed 's|@rpath/||'); do
  if [ -e "$APP/Frameworks/$dep" ]; then echo "  ok:       $dep"; else echo "  MANCANTE: $dep"; MANCA=1; fi
done
[ "$MANCA" -eq 0 ] || { echo "!! Bundle incompleto: non genero l'.ipa."; exit 1; }

echo
echo "=== Impacchettamento ==="
rm -rf build/Payload "$OUT"
mkdir -p build/Payload dist
cp -R "$APP" build/Payload/
(cd build && zip -qr "../$OUT" Payload)
rm -rf build/Payload
echo "Fatto: $(pwd)/$OUT  ($(du -h "$OUT" | cut -f1))"
