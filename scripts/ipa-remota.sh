#!/bin/bash
# Dal PC: manda i sorgenti al Mac, compila l'.ipa con scripts/build-ipa.sh e la riporta in dist/.
#
#   bash scripts/ipa-remota.sh m1@<indirizzo del Mac>
#
# Il Mac va preparato una volta con scripts/bootstrap-mac.sh. La chiave e' ~/.ssh/macincloud: e' quella registrata
# nel progetto Scaleway, che la installa da sola sulle macchine nuove (~/.ssh/scw_authorized_keys).
# La build gira in background sul Mac e qui si aspetta la fine: una connessione SSH lunga e silenziosa a volte cade.

set -uo pipefail
MAC="${1:?indica il Mac, es. m1@62.210.194.160}"
CHIAVE="$HOME/.ssh/macincloud"
SSH=(ssh -i "$CHIAVE" -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new)
CARTELLA='~/Desktop/paliouggiate.app'

cd "$(dirname "$0")/.."
echo "=== invio dei sorgenti ==="
# lib si sostituisce per intero (file tolti sul PC spariscono anche sul Mac); il resto si sovrascrive
tar cf - lib assets ios pubspec.yaml pubspec.lock analysis_options.yaml scripts README.md \
  | "${SSH[@]}" "$MAC" "mkdir -p $CARTELLA && cd $CARTELLA && rm -rf lib && tar xf -" || exit 1

echo "=== build sul Mac ==="
"${SSH[@]}" "$MAC" "cd $CARTELLA && rm -f /tmp/ipa.log && (bash scripts/build-ipa.sh > /tmp/ipa.log 2>&1; echo FINE \$? >> /tmp/ipa.log) > /dev/null 2>&1 &" || exit 1
for _ in $(seq 1 90); do
  sleep 10
  LOG=$("${SSH[@]}" "$MAC" 'cat /tmp/ipa.log 2>/dev/null') || continue
  grep -q '^FINE' <<< "$LOG" && break
done
grep -E 'No issues|issue|error|Fatto|!!' <<< "$LOG"
grep -q 'Fatto:' <<< "$LOG" || { echo "!! build non riuscita: log completo sul Mac in /tmp/ipa.log"; exit 1; }

echo "=== .ipa sul PC ==="
mkdir -p dist
scp -q -i "$CHIAVE" "$MAC:Desktop/paliouggiate.app/dist/PalioUggiate.ipa" dist/ && ls -la dist/PalioUggiate.ipa
