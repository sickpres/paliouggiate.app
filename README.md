# Palio Uggiate con Ronago — app

App Flutter (per ora solo iOS) che mostra calendario, classifiche, giochi e sponsor
del Palio dei rioni, leggendo i dati reali dal portale
<https://palio.comune.uggiateconronago.co.it> (repository `sickpres/paliouggiate`).

L'app è pubblica e in sola lettura: nessun accesso, nessun account. Usa solo le
API pubbliche del portale.

## Schermate

| scheda | API del portale | note |
| --- | --- | --- |
| Home | `GET /api/config`, `GET /api/calendario`, `GET /api/telecronaca` | telecronaca scritta dall'IA del portale, appuntamenti di oggi (o il prossimo giorno di gare), conto alla rovescia |
| Calendario | `GET /api/config`, `GET /api/calendario` | giorni e orari in ora italiana, così come li manda il portale; da qui si apre la pallavolo |
| Partite di pallavolo | `GET /api/partite/pallavolo`, `GET /api/rioni` | filtro per rione, ricordato sul telefono (`SharedPreferences`, chiave `rione_pallavolo`) |
| Classifica | `GET /api/classifica/dettaglio`, `GET /api/archivio`, `GET /api/rioni` | edizione in corso (punti per gioco) e albo d'oro, con gli stemmi dei rioni |
| Giochi | `GET /api/giochi`, `GET /api/calendario` | i giochi del programma; classifica provvisoria appena c'è un risultato (con le partite che mancano), definitiva quando il gioco è pubblicato |
| Sponsor | `GET /api/sponsor`, `/api/sponsor/:id/logo` | tocco sul logo = sito dello sponsor |

Colori dell'interfaccia ripresi dal logo (`lib/main.dart`): barra in alto e menu blu notte, voce attiva in oro, sfondo azzurro come il cielo del logo, schede bianche.
Il logo (`assets/logo.png`) e l'icona (`assets/icona.png`, 1024 × 1024) sono
ricavati dal logo «Palio dei Rioni».

## Build dell'.ipa (Mac remoto)

Sul Mac servono Xcode con la piattaforma iOS e Flutter in `~/flutter`
(`git clone --depth 1 -b stable https://github.com/flutter/flutter.git`, nessun
sudo). CocoaPods non serve: i plugin si risolvono con Swift Package Manager
(`flutter config --enable-swift-package-manager`).

```bash
bash scripts/build-ipa.sh
```

produce `dist/PalioUggiate.ipa`, non firmato, da installare con Sideloadly.

Per fotografare una scheda nel simulatore senza toccarlo:
`flutter build ios --simulator --debug --dart-define=PROVA_SCHEDA=n` (0–4). Altri interruttori di prova:
`PROVA_OGGI=2027-07-03` (data simulata), `PROVA_PALLAVOLO=true` (apre la pallavolo), `PROVA_RIONE=id` (sceglie un rione nel filtro), `PROVA_TELECRONACA=testo` (telecronaca finta).
