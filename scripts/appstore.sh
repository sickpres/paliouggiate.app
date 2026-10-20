#!/bin/bash
# Da eseguire SUL MAC, nella cartella del progetto: compila la versione Release, la firma per l'App Store e la carica
# su App Store Connect (poi compare in TestFlight e si sceglie nella versione da inviare alla verifica).
#
#   ASC_KEY_ID=... ASC_ISSUER_ID=... TEAM_ID=... bash scripts/appstore.sh
#
# La chiave API di App Store Connect (ruolo App Manager) va in ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8:
# xcodebuild la usa per creare da solo certificato e profilo di distribuzione (firma automatica), senza Apple ID in Xcode.
# Il numero di build (dopo il + in pubspec.yaml) deve crescere a ogni caricamento.

set -uo pipefail
export PATH="$HOME/flutter/bin:$PATH"
: "${ASC_KEY_ID:?manca ASC_KEY_ID}" "${ASC_ISSUER_ID:?manca ASC_ISSUER_ID}" "${TEAM_ID:?manca TEAM_ID}"
CHIAVE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[ -f "$CHIAVE" ] || { echo "!! manca $CHIAVE"; exit 1; }
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$CHIAVE" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
ARCHIVIO=build/Runner.xcarchive

echo "=== Dipendenze e analisi ==="
flutter pub get || exit 1
flutter analyze || { echo "!! Correggi gli errori dell'analisi."; exit 1; }

echo
echo "=== Configurazione Release (versione e build da pubspec.yaml) ==="
# senza firma: la fa xcodebuild con la chiave API
flutter build ios --release --config-only --no-codesign || exit 1

echo
echo "=== Portachiavi della build ==="
# Via SSH il portachiavi di login e' chiuso e xcodebuild non puo' salvarci i certificati che crea ("User interaction
# is not allowed"): se ne usa uno dedicato, sbloccato, come predefinito. La password serve solo su questo Mac.
PORTACHIAVI="$HOME/Library/Keychains/build.keychain-db"
PW_PORTACHIAVI="${PW_PORTACHIAVI:-palio-build}"
[ -f "$PORTACHIAVI" ] || security create-keychain -p "$PW_PORTACHIAVI" build.keychain
security unlock-keychain -p "$PW_PORTACHIAVI" build.keychain
security set-keychain-settings -t 7200 -u build.keychain
security list-keychains -d user -s build.keychain login.keychain
security default-keychain -s build.keychain
# i certificati creati qui si possono usare da codesign senza conferme
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PW_PORTACHIAVI" build.keychain >/dev/null 2>&1 || true

echo
echo "=== Archivio firmato ==="
rm -rf "$ARCHIVIO"
# l'archivio non si firma (servirebbe un certificato di sviluppo su questo Mac): la firma per la distribuzione
# la fa l'esportazione, con certificato e profilo che xcodebuild crea o scarica con la chiave API
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVIO" DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" archive -quiet \
  || { echo "!! Archivio non riuscito."; exit 1; }

echo
echo "=== Esportazione e caricamento su App Store Connect ==="
OPZIONI=$(mktemp -t opzioni).plist
cat > "$OPZIONI" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVIO" -exportOptionsPlist "$OPZIONI" -exportPath build/esportazione "${AUTH[@]}" \
  || { echo "!! Caricamento non riuscito."; exit 1; }
echo "Fatto: build caricata. Dopo l'elaborazione (10-30 minuti) compare in App Store Connect › TestFlight."
