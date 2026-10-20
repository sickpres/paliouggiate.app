#!/bin/bash
# Sul Mac: compila l'app per il simulatore con le opzioni di prova e fotografa ogni schermata in ~/schermate.
# Ogni argomento e' "nome:opzioni" (opzioni --dart-define separate da virgola), per esempio:
#
#   bash scripts/schermate.sh home: calendario:PROVA_SCHEDA=1 calendario-mese:PROVA_SCHEDA=1,PROVA_MESE=true
#
# Le schermate di prova usano i dati veri del portale: aspetta qualche secondo prima di fotografare.

set -uo pipefail
export PATH="$HOME/flutter/bin:$PATH"
cd "$(dirname "$0")/.."
SIM="${SIM:-iPhone 17 Pro}"
ID=it.uggiateconronago.palio
ATTESA="${ATTESA:-8}"
mkdir -p ~/schermate

xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl bootstatus "$SIM" -b >/dev/null
# ora fissa nella barra di stato, come nelle schermate dell'App Store
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

for voce in "$@"; do
  nome="${voce%%:*}"
  opzioni="${voce#*:}"
  # bash 3.2 del Mac: con set -u un array vuoto da' errore, quindi si parte da un'opzione innocua
  definizioni=(--dart-define=SCHERMATA="$nome")
  for c in ${opzioni//,/ }; do definizioni+=(--dart-define="$c"); done
  echo "=== $nome ${definizioni[*]} ==="
  flutter build ios --simulator --debug "${definizioni[@]}" > "/tmp/schermata-$nome.log" 2>&1 \
    || { echo "!! build non riuscita, vedi /tmp/schermata-$nome.log"; continue; }
  xcrun simctl terminate "$SIM" $ID 2>/dev/null
  xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
  xcrun simctl launch "$SIM" $ID >/dev/null
  sleep "$ATTESA"
  xcrun simctl io "$SIM" screenshot --type=png ~/schermate/"$nome".png >/dev/null 2>&1 && echo "fatta: ~/schermate/$nome.png"
done
