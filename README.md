# Palio Uggiate con Ronago — app

App Flutter (per ora solo iOS) che mostra calendario, classifiche, giochi e sponsor
del Palio dei rioni, leggendo i dati reali dal portale
<https://palio.comune.uggiateconronago.co.it> (repository `sickpres/paliouggiate`).

L'app è in sola lettura; l'unica parte modificabile è il **Profilo** (dati
personali e password) di chi ha un account sul portale.

## Schermate

| scheda | API del portale | note |
| --- | --- | --- |
| Accesso | `POST /api/login`, `GET /api/sessione` | Google e Facebook: pulsanti presenti ma **non ancora attivi** (vedi sotto). «Continua senza accedere» per consultare senza account |
| Calendario | `GET /api/config`, `GET /api/calendario` | giorni in ora italiana, così come li manda il portale |
| Classifica | `GET /api/classifica/dettaglio`, `GET /api/archivio`, `GET /api/rioni` | edizione in corso (punti per gioco) e albo d'oro |
| Giochi | `GET /api/giochi`, `GET /api/calendario` | i giochi del programma; la classifica compare quando il gioco è pubblicato |
| Sponsor | `GET /api/sponsor`, `/api/sponsor/:id/logo` | tocco sul logo = sito dello sponsor |
| Profilo | `GET`/`PUT /api/profilo`, `POST /api/password`, `POST /api/logout` | `/api/profilo` è **nuovo**: va pubblicato sul portale (vedi sotto) |

La sessione è il cookie `sess` del portale (8 ore, decade se cambia la password):
l'app lo conserva in `SharedPreferences` e lo rimanda a ogni richiesta.

## Cosa manca per la versione completa

- **Endpoint `/api/profilo`**: aggiunto in `server/server.js` del portale, *non
  ancora committato né pubblicato*. Finché non è online, la scheda Profilo mostra
  «La modifica dei dati personali non è ancora attiva sul portale»; il cambio
  password invece funziona già.
- **Accesso con Google / Facebook**: richiede lavoro su entrambi i lati.
  1. Credenziali, che solo il proprietario può creare: un client OAuth iOS in
     Google Cloud Console e un'app Meta con Facebook Login (c'è già l'app «Palio»,
     in modalità sviluppo, usata per Instagram).
  2. Sul portale: un endpoint che verifica il token di Google/Facebook e apre la
     sessione, più la gestione degli utenti che entrano così. Oggi gli utenti sono
     solo lo staff creato dagli amministratori e il login è per **nome utente**
     (la tabella `utenti` non ha un campo email).
  3. Nell'app: i pacchetti `google_sign_in` / `flutter_facebook_auth` e gli URL
     scheme in `Info.plist`. Attenzione: Sideloadly cambia il bundle id, e i
     client OAuth sono legati al bundle id.
- **Logo definitivo**: `assets/logo.png` e `assets/icona.png` sono provvisori,
  ricavati dagli stemmi del portale (`assets/favicon-192.png`, 192 px). Per
  l'icona serve un'immagine quadrata di almeno 1024 × 1024 px.

## Build dell'.ipa (Mac remoto)

Sul Mac servono Xcode con la piattaforma iOS e Flutter in `~/flutter`
(`git clone --depth 1 -b stable https://github.com/flutter/flutter.git`, nessun
sudo). CocoaPods non serve: i plugin si risolvono con Swift Package Manager
(`flutter config --enable-swift-package-manager`).

La cartella `ios/` la genera `flutter create --platforms ios --org it.uggiateconronago --project-name palio_uggiate .`
la prima volta; poi:

```bash
bash scripts/build-ipa.sh
```

produce `dist/PalioUggiate.ipa`, non firmato, da installare con Sideloadly.
