# Palio Uggiate con Ronago — app

App Flutter (per ora solo iOS) che mostra calendario, classifiche, giochi e sponsor
del Palio dei rioni, leggendo i dati reali dal portale
<https://palio.comune.uggiateconronago.co.it> (repository `sickpres/paliouggiate`).

L'app è pubblica e in sola lettura: nessun accesso, nessun account. Usa solo le
API pubbliche del portale.

## Schermate

| scheda | API del portale | note |
| --- | --- | --- |
| Home | `GET /api/config`, `GET /api/calendario`, `GET /api/telecronaca` | «Il Palio in diretta» (testo dell'IA del portale), appuntamenti di oggi (o il prossimo giorno di gare), conto alla rovescia, mappa dei rioni come sul portale (tocco = scheda del rione) |
| Calendario | `GET /api/config`, `GET /api/calendario` | vista a mese di partenza (griglia fissa con le sole settimane del Palio, sotto scorrono gli appuntamenti del giorno scelto) oppure elenco completo, scelta ricordata sul telefono; da qui si apre la pallavolo |
| Partite di pallavolo | `GET /api/partite/pallavolo`, `GET /api/rioni` | filtro per rione, ricordato sul telefono (`SharedPreferences`, chiave `rione_pallavolo`) |
| Classifica | `GET /api/classifica/dettaglio`, `GET /api/archivio`, `GET /api/rioni` | edizione in corso (punti per gioco) e albo d'oro, con gli stemmi dei rioni |
| Giochi | `GET /api/giochi`, `GET /api/calendario` | i giochi del programma con la ricerca; ogni gioco apre la sua pagina |
| Pagina del gioco | `GET /api/giochi/:id` | menu in basso: Info (data, orario, luogo), Classifica (provvisoria o definitiva), Regole, Criteri, Punteggio |
| Mappa dei rioni | `GET /api/mappa` | Google Maps a tutta pagina (dal pulsante «Mappa» della Home) con i confini dei rioni colorati e gli stemmi; chiave iOS e stile (map ID) dal pannello, Amministrazione sistema |
| Social | `GET /api/sponsor`, `/api/sponsor/:id/logo` | pagine Facebook e Instagram del Palio (`lib/screens/social.dart`), sotto i loghi degli sponsor se il portale ne pubblica |

## Promemoria (notifiche)

Notifiche **locali**: l'app è installata con un Apple ID gratuito, che non permette le push dal server. A ogni
apertura (e quando cambia il rione scelto nella pallavolo) l'app scarica `GET /api/notifiche` e programma sul
telefono le notifiche del piano, al massimo una al giorno (`lib/promemoria.dart`, `flutter_local_notifications`).
Il piano lo decide il pannello del portale, alla voce «Notifiche app»: promemoria automatico nei giorni di gara
all'ora scelta, oppure un messaggio scritto a mano per un giorno, che prende il posto del promemoria automatico.
Un messaggio nuovo arriva solo a chi apre l'app dopo che è stato programmato.

Colori dell'interfaccia ripresi dal logo (`lib/main.dart`): barra in alto e menu blu notte, voce attiva in oro, sfondo azzurro chiaro (il cielo del logo schiarito, `#D8EDFC`), schede bianche.
Il logo (`assets/logo.png`) e l'icona (`assets/icona.png`, 1024 × 1024) sono
ricavati dal logo «Palio dei Rioni».

## Google Maps

La chiave non è scritta nell'app: la manda il portale (`/api/mappa`) e `AppDelegate.swift` la passa a
`GMSServices.provideAPIKey` prima della prima mappa (canale `palio/mappa`). Si usa
`google_maps_flutter_ios_sdk10` perché l'SDK 10 si installa con Swift Package Manager; per questo l'app richiede
iOS 16. Se in `ios/` ricompaiono `Podfile` o include di `Pods` nei `.xcconfig`, vanno tolti: CocoaPods non c'è.

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
`PROVA_OGGI=2027-07-03` (data simulata), `PROVA_PALLAVOLO=true` (apre la pallavolo), `PROVA_RIONE=id` (sceglie un rione nel filtro), `PROVA_TELECRONACA=testo` (telecronaca finta), `PROVA_FONDO=true` (Home in fondo), `PROVA_MAPPA=Somoca` (rione scelto sulla mappa), `PROVA_CERCA=testo` (ricerca nei giochi), `PROVA_GIOCO=id` e `PROVA_TAB_GIOCO=n` (pagina di un gioco), `PROVA_ELENCO=true` (calendario a elenco), `PROVA_MAPPA_GOOGLE=true` (apre la mappa di Google), `PROVA_SENZA_STILE=true` (mappa senza stile cloud), `PROVA_ZOOM=11.5` (zoom della mappa).
