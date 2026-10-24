// Modelli delle risposte JSON del portale (server/server.js, server/giochi.js,
// server/contabilita.js nel repository paliouggiate).

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;

class Edizione {
  final String nome;
  final DateTime? inizio;
  final DateTime? fine;
  Edizione({required this.nome, this.inizio, this.fine});

  factory Edizione.fromJson(Map<String, dynamic> j) => Edizione(
        nome: _s(j['edizione']),
        inizio: DateTime.tryParse(_s(j['inizio'])),
        fine: DateTime.tryParse(_s(j['fine'])),
      );
}

class Rione {
  final int id;
  final String nome;
  final String colore;
  final String descrizione;
  final String capoRione; // nome e cognome (piu' d'uno separati da virgola), vuoto se non c'e'
  final bool haLogo;
  final String logoVersione;
  final bool haSimbolo; // foto «simbolo» 16:9 caricata dal pannello
  final String simboloVersione;
  final String whatsapp; // link del gruppo WhatsApp del rione (dal pannello), vuoto se non c'e'
  Rione({required this.id, required this.nome, required this.colore, this.descrizione = '', this.capoRione = '', required this.haLogo, required this.logoVersione, this.haSimbolo = false, this.simboloVersione = '', this.whatsapp = ''});

  factory Rione.fromJson(Map<String, dynamic> j) => Rione(
        id: _i(j['id']),
        nome: _s(j['nome']),
        colore: _s(j['colore']),
        descrizione: _s(j['descrizione']),
        capoRione: _s(j['capo_rione']),
        haLogo: j['ha_logo'] == true,
        logoVersione: _s(j['logo_versione']),
        haSimbolo: j['ha_simbolo'] == true,
        simboloVersione: _s(j['simbolo_versione']),
        whatsapp: _s(j['whatsapp']),
      );
}

/// Una voce del programma: una sessione di gioco oppure un evento.
class Voce {
  final String genere; // 'gioco' | 'evento'
  final int? giocoId;
  final String tipo;
  final String titolo;
  final DateTime data;
  final String ora;
  final String chi;
  final String luogo;
  final String luogoPioggia; // dove si fa se piove, vuoto se non indicato
  final String note;
  // categoria d'eta' del gioco dal portale: 'tutti' | 'adulti' (adulti e ragazzi) | 'bambini' | 'anziani'; vuota per gli eventi
  final String categoria;
  Voce({
    required this.genere,
    this.giocoId,
    required this.tipo,
    required this.titolo,
    required this.data,
    required this.ora,
    required this.chi,
    required this.luogo,
    this.luogoPioggia = '',
    required this.note,
    this.categoria = '',
  });

  bool get evento => genere == 'evento';

  factory Voce.fromJson(Map<String, dynamic> j) => Voce(
        genere: _s(j['genere']),
        giocoId: j['gioco_id'] == null ? null : _i(j['gioco_id']),
        tipo: _s(j['tipo']),
        titolo: _s(j['titolo']),
        data: DateTime.tryParse(_s(j['data'])) ?? DateTime(1970),
        ora: _s(j['ora']),
        chi: _s(j['chi']),
        luogo: _s(j['luogo']),
        luogoPioggia: _s(j['luogo_pioggia']),
        note: _s(j['note']),
        categoria: _s(j['categoria']),
      );
}

/// Punti assegnati a mano a un rione (pagina «Punteggi manuali» del pannello), con il motivo.
class PuntiManuali {
  final int punti;
  final String motivo;
  final DateTime? data;
  PuntiManuali(this.punti, this.motivo, this.data);
}

class RigaClassifica {
  final int id;
  final String nome;
  final String colore;
  final int punti;
  final Map<int, int> perGioco; // punti del Palio in ogni gioco pubblicato
  final Map<int, int> posizioni; // posizione del rione in ogni gioco pubblicato
  final List<PuntiManuali> manuali;
  RigaClassifica({required this.id, required this.nome, required this.colore, required this.punti, required this.perGioco,
      this.posizioni = const {}, this.manuali = const []});

  bool get haDettaglio => perGioco.isNotEmpty || manuali.isNotEmpty;

  factory RigaClassifica.fromJson(Map<String, dynamic> j) {
    Map<int, int> mappa(dynamic raw) {
      final m = <int, int>{};
      if (raw is Map) raw.forEach((k, v) => m[_i(k)] = _i(v));
      return m;
    }

    return RigaClassifica(
      id: _i(j['id']),
      nome: _s(j['nome']),
      colore: _s(j['colore']),
      punti: _i(j['punti']),
      perGioco: mappa(j['per_gioco']),
      posizioni: mappa(j['posizioni']),
      manuali: [
        for (final x in (j['manuali'] as List? ?? const [])) PuntiManuali(_i(x['punti']), _s(x['motivo']), DateTime.tryParse(_s(x['data'])))
      ],
    );
  }
}

class GiocoBreve {
  final int id;
  final String nome;
  GiocoBreve(this.id, this.nome);
}

class ClassificaDettaglio {
  final List<GiocoBreve> giochi;
  final List<RigaClassifica> righe;
  ClassificaDettaglio(this.giochi, this.righe);

  factory ClassificaDettaglio.fromJson(Map<String, dynamic> j) => ClassificaDettaglio(
        [for (final g in (j['giochi'] as List? ?? const [])) GiocoBreve(_i(g['id']), _s(g['nome']))],
        [for (final r in (j['righe'] as List? ?? const [])) RigaClassifica.fromJson(Map<String, dynamic>.from(r as Map))],
      );

  bool get iniziata => righe.any((r) => r.punti != 0);
}

class PostoArchivio {
  final int posizione;
  final String nome;
  final String colore;
  final int punti;
  PostoArchivio(this.posizione, this.nome, this.colore, this.punti);
}

class AnnoArchivio {
  final int anno;
  final List<PostoArchivio> classifica;
  AnnoArchivio(this.anno, this.classifica);

  factory AnnoArchivio.fromJson(Map<String, dynamic> j) => AnnoArchivio(
        _i(j['anno']),
        [
          for (final c in (j['classifica'] as List? ?? const []))
            PostoArchivio(_i(c['posizione']), _s(c['nome']), _s(c['colore']), _i(c['punti']))
        ],
      );
}

class PostoGioco {
  final int rioneId;
  final int posizione;
  final String nome;
  final String colore;
  final int? punti; // null nei giochi in corso: i punti del Palio arrivano a gioco concluso
  final String dettaglio;
  PostoGioco(this.rioneId, this.posizione, this.nome, this.colore, this.punti, this.dettaglio);
}

class GruppoRisultati {
  final String gruppo;
  final List<String> righe;
  GruppoRisultati(this.gruppo, this.righe);
}

/// Un gioco con la sua classifica (GET /api/giochi): concluso e pubblicato, oppure in corso (parziale).
class Gioco {
  final bool parziale;
  final int mancanti;
  final String unita; // 'partite' | 'risultati'
  final int id;
  final String tipo;
  final String nome;
  final String chi;
  final DateTime? dataInizio;
  final DateTime? dataFine;
  final String ora;
  final String luogo;
  final List<PostoGioco> classifica;
  final List<GruppoRisultati> dettaglio;
  final String categoria; // categoria d'eta' dal portale, come in Voce
  Gioco({
    this.parziale = false,
    this.mancanti = 0,
    this.unita = 'risultati',
    required this.id,
    required this.tipo,
    required this.nome,
    required this.chi,
    this.dataInizio,
    this.dataFine,
    required this.ora,
    required this.luogo,
    required this.classifica,
    required this.dettaglio,
    this.categoria = '',
  });

  factory Gioco.fromJson(Map<String, dynamic> j) => Gioco(
        parziale: j['parziale'] == true,
        mancanti: _i(j['mancanti']),
        unita: _s(j['unita']).isEmpty ? 'risultati' : _s(j['unita']),
        id: _i(j['id']),
        tipo: _s(j['tipo']),
        nome: _s(j['nome']),
        chi: _s(j['chi']),
        dataInizio: DateTime.tryParse(_s(j['data_inizio'])),
        dataFine: DateTime.tryParse(_s(j['data_fine'])),
        ora: _s(j['ora']),
        luogo: _s(j['luogo']),
        classifica: [
          for (final c in (j['classifica'] as List? ?? const []))
            PostoGioco(_i(c['rione_id']), _i(c['posizione']), _s(c['nome']), _s(c['colore']), c['punti'] == null ? null : _i(c['punti']), _s(c['dettaglio']))
        ],
        dettaglio: [
          for (final d in (j['dettaglio'] as List? ?? const []))
            GruppoRisultati(_s(d['gruppo']), [for (final r in (d['righe'] as List? ?? const [])) _s(r)])
        ],
        categoria: _s(j['categoria']),
      );
}

/// Un documento del portale (GET /api/documenti): regolamento, moduli, ... nell'ordine scelto nel pannello.
class Documento {
  final int id;
  final String titolo;
  final String nomeFile;
  final int dimensione; // byte
  final DateTime? caricato;
  Documento({required this.id, required this.titolo, required this.nomeFile, required this.dimensione, this.caricato});

  /// estensione del file in maiuscolo (PDF, DOCX, ...), vuota se il nome non ne ha
  String get formato {
    final i = nomeFile.lastIndexOf('.');
    return i < 0 ? '' : nomeFile.substring(i + 1).toUpperCase();
  }

  factory Documento.fromJson(Map<String, dynamic> j) => Documento(
        id: _i(j['id']),
        titolo: _s(j['titolo']),
        nomeFile: _s(j['nome_file']),
        dimensione: _i(j['dimensione']),
        caricato: DateTime.tryParse(_s(j['caricato']))?.toLocal(),
      );
}

class Sponsor {
  final int id;
  final String nome;
  final String sito;
  Sponsor(this.id, this.nome, this.sito);

  factory Sponsor.fromJson(Map<String, dynamic> j) => Sponsor(_i(j['id']), _s(j['nome']), _s(j['sito']));
}

/// Una partita di un gioco a squadre (GET /api/partite/pallavolo).
class Partita {
  final int id;
  final DateTime? data;
  final String ora;
  final int? campo;
  final int rioneA;
  final int rioneB;
  final int? arbitro;
  final String risultato; // vuoto finche' il gioco non e' pubblicato
  Partita({
    required this.id,
    this.data,
    required this.ora,
    this.campo,
    required this.rioneA,
    required this.rioneB,
    this.arbitro,
    required this.risultato,
  });

  bool gioca(int rione) => rioneA == rione || rioneB == rione;

  factory Partita.fromJson(Map<String, dynamic> j) => Partita(
        id: _i(j['id']),
        data: DateTime.tryParse(_s(j['data'])),
        ora: _s(j['ora']),
        campo: j['campo'] == null ? null : _i(j['campo']),
        rioneA: _i(j['rione_a']),
        rioneB: _i(j['rione_b']),
        arbitro: j['arbitro_id'] == null ? null : _i(j['arbitro_id']),
        risultato: _s(j['risultato']),
      );
}

class CalendarioPartite {
  final String nome;
  final String luogo;
  final String luogoPioggia;
  final String chi;
  final bool arbitri;
  final int mancanti; // partite ancora da giocare
  final List<Partita> partite;
  CalendarioPartite({required this.nome, required this.luogo, this.luogoPioggia = '', required this.chi, required this.arbitri, required this.mancanti, required this.partite});

  factory CalendarioPartite.fromJson(Map<String, dynamic> j) {
    final g = j['gioco'] is Map ? Map<String, dynamic>.from(j['gioco'] as Map) : const <String, dynamic>{};
    return CalendarioPartite(
      nome: _s(g['nome']),
      luogo: _s(g['luogo']),
      luogoPioggia: _s(g['luogo_pioggia']),
      chi: _s(g['chi']),
      arbitri: j['arbitri'] == true,
      mancanti: _i(j['mancanti']),
      partite: [for (final p in (j['partite'] as List? ?? const [])) Partita.fromJson(Map<String, dynamic>.from(p as Map))],
    );
  }
}

/// Telecronaca scritta dall'IA del portale (GET /api/telecronaca).
class Telecronaca {
  final String testo;
  final DateTime? creato;
  Telecronaca(this.testo, this.creato);

  factory Telecronaca.fromJson(Map<String, dynamic> j) => Telecronaca(_s(j['testo']), DateTime.tryParse(_s(j['creato']))?.toLocal());
}

/// «mancano ancora 3 partite» / «manca ancora 1 risultato»
String ancoraDaGiocare(int n, String unita) {
  final u = unita == 'partite' ? (n == 1 ? 'partita' : 'partite') : (n == 1 ? 'risultato' : 'risultati');
  return '${n == 1 ? 'manca' : 'mancano'} ancora $n $u';
}

/// Un appuntamento di un gioco (giorno, ora, luogo).
class Appuntamento {
  final DateTime data;
  final String ora;
  final String luogo;
  final String chi;
  final String note;
  Appuntamento(this.data, this.ora, this.luogo, this.chi, this.note);
}

/// Classifica di un gioco nella sua scheda: definitiva (con i punti del Palio) o provvisoria.
class ClassificaGioco {
  final bool definitiva;
  final int mancanti;
  final String unita;
  final List<PostoGioco> righe;
  final List<GruppoRisultati> dettaglio;
  ClassificaGioco(this.definitiva, this.mancanti, this.unita, this.righe, this.dettaglio);
}

/// Scheda completa di un gioco (GET /api/giochi/:id).
class SchedaGioco {
  final int id;
  final String tipo;
  final String nome;
  final String chi;
  final String luogo;
  final String luogoPioggia;
  final String regolamento; // HTML dell'editor del pannello oppure testo semplice
  final String criteri;
  final List<int> puntiPosizioni;
  final bool haPartite;
  final List<Appuntamento> appuntamenti;
  final ClassificaGioco? classifica;
  final bool haFoto; // foto 16:9 caricata dal pannello, in testa alla pagina del gioco
  final String fotoVersione;
  SchedaGioco({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.chi,
    required this.luogo,
    this.luogoPioggia = '',
    required this.regolamento,
    required this.criteri,
    required this.puntiPosizioni,
    required this.haPartite,
    required this.appuntamenti,
    required this.classifica,
    this.haFoto = false,
    this.fotoVersione = '',
  });

  factory SchedaGioco.fromJson(Map<String, dynamic> j) {
    final c = j['classifica'] is Map ? Map<String, dynamic>.from(j['classifica'] as Map) : null;
    return SchedaGioco(
      id: _i(j['id']),
      tipo: _s(j['tipo']),
      nome: _s(j['nome']),
      chi: _s(j['chi']),
      luogo: _s(j['luogo']),
      luogoPioggia: _s(j['luogo_pioggia']),
      regolamento: _s(j['regolamento']),
      criteri: _s(j['criteri']),
      puntiPosizioni: [for (final x in (j['punti_posizioni'] as List? ?? const [])) _i(x)],
      haPartite: j['partite'] == true,
      haFoto: j['ha_foto'] == true,
      fotoVersione: _s(j['foto_versione']),
      appuntamenti: [
        for (final a in (j['sessioni'] as List? ?? const []))
          if (DateTime.tryParse(_s(a['data'])) != null)
            Appuntamento(DateTime.parse(_s(a['data'])), _s(a['ora']), _s(a['luogo']), _s(a['chi']), _s(a['note']))
      ],
      classifica: c == null
          ? null
          : ClassificaGioco(
              c['definitiva'] == true,
              _i(c['mancanti']),
              _s(c['unita']).isEmpty ? 'risultati' : _s(c['unita']),
              [
                for (final r in (c['righe'] as List? ?? const []))
                  PostoGioco(_i(r['rione_id']), _i(r['posizione']), _s(r['nome']), _s(r['colore']),
                      r['punti'] == null ? null : _i(r['punti']), _s(r['dettaglio']))
              ],
              [
                for (final d in (c['dettaglio'] as List? ?? const []))
                  GruppoRisultati(_s(d['gruppo']), [for (final x in (d['righe'] as List? ?? const [])) _s(x)])
              ],
            ),
    );
  }
}

/// Video «Ricordi» della Home (GET /api/ricordi): l'indirizzo cambia a ogni nuovo caricamento.
class VideoRicordi {
  final String titolo;
  final String descrizione;
  final String url; // es. /api/ricordi/video?v=123, sul portale
  VideoRicordi(this.titolo, this.descrizione, this.url);

  factory VideoRicordi.fromJson(Map<String, dynamic> j) => VideoRicordi(_s(j['titolo']), _s(j['descrizione']), _s(j['url']));
}
