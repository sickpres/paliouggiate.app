# Palio Uggiate con Ronago — app

App Flutter (per ora solo iOS) che mostra calendario, classifiche, giochi e sponsor
del Palio dei rioni, leggendo i dati reali dal portale
<https://palio.comune.uggiateconronago.co.it> (repository `sickpres/paliouggiate`).

L'app è pubblica e in sola lettura: nessun accesso, nessun account. Usa solo le
API pubbliche del portale.

## Schermate

| scheda | API del portale | note |
| --- | --- | --- |
| Home | `GET /api/config`, `GET /api/calendario`, `GET /api/telecronaca` | in testa, ferma, l'immagine `assets/header.webp` (Uggiate al tramonto con il logo) che sale dietro ora e batteria (bianche); «Il Palio in diretta» (testo dell'IA del portale), appuntamenti di oggi (o il prossimo giorno di gare), conto alla rovescia, riquadro «Rioni» che apre la pagina dei rioni (mappa come sul portale, tocco = scheda del rione, bottone «Mappa» per Google Maps); in fondo gli sponsor (`GET /api/sponsor`, se il portale ne pubblica) e le pagine Facebook e Instagram del Palio (loghi in `assets/facebook.png` e `assets/instagram.png`) |
| Calendario | `GET /api/config`, `GET /api/calendario` | vista a mese di partenza (griglia fissa con le sole settimane del Palio, sotto scorrono gli appuntamenti del giorno scelto) oppure elenco completo; «Filtra» per età (categorie dei giochi del pannello, campo `categoria` delle voci: con un'età scelta solo i giochi di quella categoria; i giochi «per tutti» e gli eventi solo con «Tutti»). Vista e filtro ricordati sul telefono; con un filtro il titolo diventa «Calendario • Bambini» |
| Pallavolo | `GET /api/config`, `GET /api/partite/pallavolo`, `GET /api/rioni` | vista a mese (come il Calendario) oppure elenco completo; «Filtra» per rione, con il nome del rione nel titolo. Rione ricordato sul telefono (`SharedPreferences`, chiave `rione_pallavolo`), come la vista |
| Regolamento e moduli | `GET /api/documenti`, `/api/documenti/:id/file?scarica=1` | dal riquadro oro in fondo alla Home, dopo i social: i documenti caricati nel pannello (pagina «Documenti»), nel loro ordine; un tocco (anche sull'icona di scaricamento) apre il documento dentro l'app, nel visore di Safari, da cui si salva o si condivide |
| Classifica | `GET /api/classifica/dettaglio`, `GET /api/archivio`, `GET /api/rioni` | edizione in corso (punti per gioco) e albo d'oro, con gli stemmi dei rioni |
| Giochi | `GET /api/giochi`, `GET /api/calendario` | i giochi del programma in ordine alfabetico, con la ricerca e «Filtra» per età (come il Calendario, campo `categoria`: con un'età scelta solo i giochi di quella categoria, quelli «per tutti» solo con «Tutti»); ogni gioco apre la sua pagina |
| Pagina del gioco | `GET /api/giochi/:id` | menu in basso: Info (data, orario, luogo), Classifica (provvisoria o definitiva), Regole, Criteri, Punteggio |
| Mappa dei rioni | `GET /api/mappa` | Google Maps a tutta pagina (dal pulsante «Mappa» della pagina «Rioni») con i confini dei rioni colorati e gli stemmi; chiave iOS e stile (map ID) dal pannello, Amministrazione sistema |

## Promemoria (notifiche)

Notifiche **locali**: l'app è installata con un Apple ID gratuito, che non permette le push dal server. A ogni
apertura (e quando cambia il rione scelto nella pallavolo) l'app scarica `GET /api/notifiche` e programma sul
telefono le notifiche del piano, al massimo una al giorno (`lib/promemoria.dart`, `flutter_local_notifications`).
Il piano lo decide il pannello del portale, alla voce «Notifiche app»: promemoria automatico nei giorni di gara
all'ora scelta, oppure un messaggio scritto a mano per un giorno, che prende il posto del promemoria automatico.
Un messaggio nuovo arriva solo a chi apre l'app dopo che è stato programmato.

Colori dell'interfaccia ripresi dal logo (`lib/main.dart`): barra in alto e menu blu notte, voce attiva in oro, sfondo azzurro chiaro (il cielo del logo schiarito, `#D8EDFC`), schede bianche.
Il logo (`assets/logo.png`) e l'icona (`assets/icona.png`, 1024 × 1024, sfondo azzurro `#D8EDFC` come le pagine) sono
ricavati dal logo «Palio dei Rioni».

## Google Maps

La chiave non è scritta nell'app: la manda il portale (`/api/mappa`) e `AppDelegate.swift` la passa a
`GMSServices.provideAPIKey` prima della prima mappa (canale `palio/mappa`). Si usa
`google_maps_flutter_ios_sdk10` perché l'SDK 10 si installa con Swift Package Manager; per questo l'app richiede
iOS 16. Se in `ios/` ricompaiono `Podfile` o include di `Pods` nei `.xcconfig`, vanno tolti: CocoaPods non c'è.

## Build dell'.ipa (Mac remoto)

Il Mac (Scaleway, utente `m1`) serve solo a compilare: i sorgenti stanno sul PC e nel repository, sul Mac non c'è
niente da salvare e si può eliminare e ricreare quando serve. La chiave SSH è `~/.ssh/macincloud`, registrata nel
progetto Scaleway, che la installa da sola sulle macchine nuove.

1. Preparare il Mac nuovo, una volta (Flutter 3.47.7 in `~/flutter`, piattaforma iOS, Swift Package Manager; niente
   sudo, Homebrew o CocoaPods; la piattaforma iOS sono ~8,5 GB da scaricare):

   ```bash
   ssh -i ~/.ssh/macincloud m1@<indirizzo> 'bash -s' < scripts/bootstrap-mac.sh
   ```

2. Ogni volta, dal PC: invia i sorgenti, compila (`scripts/build-ipa.sh` sul Mac) e riporta l'.ipa in `dist/`:

   ```bash
   bash scripts/ipa-remota.sh m1@<indirizzo>
   ```

`dist/PalioUggiate.ipa` non è firmato: si installa con Sideloadly.

Per fotografare una scheda nel simulatore senza toccarlo:
`flutter build ios --simulator --debug --dart-define=PROVA_SCHEDA=n` (0–4). Altri interruttori di prova:
`PROVA_OGGI=2027-07-03` (data simulata), `PROVA_PALLAVOLO=true` (apre la pallavolo), `PROVA_RIONE=id` (sceglie un rione nel filtro), `PROVA_TELECRONACA=testo` (telecronaca finta), `PROVA_FONDO=true` (Home in fondo), `PROVA_MAPPA=Somoca` (rione scelto sulla mappa), `PROVA_CERCA=testo` (ricerca nei giochi), `PROVA_GIOCO=id` e `PROVA_TAB_GIOCO=n` (pagina di un gioco), `PROVA_ELENCO=true` (calendario a elenco), `PROVA_ETA=bambini` (filtro per età in Calendario e Giochi), `PROVA_DOCUMENTI=true` (apre «Regolamento e moduli»), `PROVA_APRI_DOCUMENTO=true` (apre anche il primo documento), `PROVA_RIONI=true` (apre la pagina «Rioni»), `PROVA_MAPPA_GOOGLE=true` (apre la mappa di Google), `PROVA_SENZA_STILE=true` (mappa senza stile cloud), `PROVA_ZOOM=11.5` (zoom della mappa), `PROVA_RIONE_MAPPA=Somoca` (rione scelto sulla mappa di Google).
