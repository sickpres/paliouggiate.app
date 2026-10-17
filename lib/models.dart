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
  final bool haLogo;
  final String logoVersione;
  Rione({required this.id, required this.nome, required this.colore, required this.haLogo, required this.logoVersione});

  factory Rione.fromJson(Map<String, dynamic> j) => Rione(
        id: _i(j['id']),
        nome: _s(j['nome']),
        colore: _s(j['colore']),
        haLogo: j['ha_logo'] == true,
        logoVersione: _s(j['logo_versione']),
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
  final String note;
  Voce({
    required this.genere,
    this.giocoId,
    required this.tipo,
    required this.titolo,
    required this.data,
    required this.ora,
    required this.chi,
    required this.luogo,
    required this.note,
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
        note: _s(j['note']),
      );
}

class RigaClassifica {
  final int id;
  final String nome;
  final String colore;
  final int punti;
  final Map<int, int> perGioco;
  RigaClassifica({required this.id, required this.nome, required this.colore, required this.punti, required this.perGioco});

  factory RigaClassifica.fromJson(Map<String, dynamic> j) {
    final pg = <int, int>{};
    final raw = j['per_gioco'];
    if (raw is Map) raw.forEach((k, v) => pg[_i(k)] = _i(v));
    return RigaClassifica(id: _i(j['id']), nome: _s(j['nome']), colore: _s(j['colore']), punti: _i(j['punti']), perGioco: pg);
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
  final int punti;
  final String dettaglio;
  PostoGioco(this.rioneId, this.posizione, this.nome, this.colore, this.punti, this.dettaglio);
}

class GruppoRisultati {
  final String gruppo;
  final List<String> righe;
  GruppoRisultati(this.gruppo, this.righe);
}

/// Un gioco pubblicato, con la sua classifica (GET /api/giochi).
class Gioco {
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
  Gioco({
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
  });

  factory Gioco.fromJson(Map<String, dynamic> j) => Gioco(
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
            PostoGioco(_i(c['rione_id']), _i(c['posizione']), _s(c['nome']), _s(c['colore']), _i(c['punti']), _s(c['dettaglio']))
        ],
        dettaglio: [
          for (final d in (j['dettaglio'] as List? ?? const []))
            GruppoRisultati(_s(d['gruppo']), [for (final r in (d['righe'] as List? ?? const [])) _s(r)])
        ],
      );
}

class Sponsor {
  final int id;
  final String nome;
  final String sito;
  Sponsor(this.id, this.nome, this.sito);

  factory Sponsor.fromJson(Map<String, dynamic> j) => Sponsor(_i(j['id']), _s(j['nome']), _s(j['sito']));
}

/// Utente collegato (GET /api/sessione).
class Sessione {
  final int id;
  final String utente;
  final List<String> ruoli;
  final String rione;
  final bool cambiaPassword;
  Sessione({required this.id, required this.utente, required this.ruoli, required this.rione, required this.cambiaPassword});

  factory Sessione.fromJson(Map<String, dynamic> j) => Sessione(
        id: _i(j['id']),
        utente: _s(j['utente']),
        ruoli: [for (final r in (j['ruoli'] as List? ?? const [])) _s(r)],
        rione: _s(j['rione']),
        cambiaPassword: j['cambiaPassword'] == true,
      );
}

/// Dati personali modificabili (GET/PUT /api/profilo).
class Profilo {
  final String nome;
  final String cognome;
  final String telefono;
  Profilo({required this.nome, required this.cognome, required this.telefono});

  factory Profilo.fromJson(Map<String, dynamic> j) =>
      Profilo(nome: _s(j['nome']), cognome: _s(j['cognome']), telefono: _s(j['telefono']));
}
