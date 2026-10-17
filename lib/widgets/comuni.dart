import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';

// ---------- date in italiano (il portale manda giorni gia' in ora italiana) ----------
const giorni = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
const mesi = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];

String giornoLungo(DateTime d) => '${giorni[d.weekday - 1]} ${d.day} ${mesi[d.month - 1]}';
String dataBreve(DateTime d) => '${d.day} ${mesi[d.month - 1]} ${d.year}';

String intervallo(DateTime? a, DateTime? b) {
  if (a == null) return '';
  if (b == null || b == a) return dataBreve(a);
  if (a.year == b.year && a.month == b.month) return '${a.day}–${b.day} ${mesi[a.month - 1]} ${a.year}';
  return '${dataBreve(a)} – ${dataBreve(b)}';
}

bool stessoGiorno(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Color coloreHex(String hex, [Color altrimenti = Colors.grey]) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  if (h.length != 6 || v == null) return altrimenti;
  return Color(0xFF000000 | v);
}

IconData iconaGioco(String tipo) => switch (tipo) {
      'pallavolo' => Icons.sports_volleyball,
      'calcio_bambini' || 'faigol' => Icons.sports_soccer,
      'calcio_balilla' => Icons.table_bar,
      'ping_pong' => Icons.sports_tennis,
      'scacchi' => Icons.grid_on,
      'burraco' || 'scala40' => Icons.style,
      'memory' => Icons.psychology,
      'quizzone' => Icons.quiz,
      'balli' => Icons.music_note,
      'staffetta' || 'staffetta_simpaticona' => Icons.directions_run,
      'caccia_al_tesoro' => Icons.travel_explore,
      'tappeto_volante' => Icons.airline_seat_flat,
      'passa_la_palla' => Icons.sports_handball,
      'infila_la_penna' => Icons.edit,
      _ => Icons.emoji_events_outlined,
    };

// ---------- rioni: si caricano una volta e servono per stemmi e colori ----------
Future<List<Rione>>? _rioni;

Future<List<Rione>> rioniInCache({bool aggiorna = false}) {
  if (aggiorna || _rioni == null) {
    _rioni = Api.instance.rioni();
    _rioni!.catchError((_) {
      _rioni = null;
      return <Rione>[];
    });
  }
  return _rioni!;
}

Rione? rionePerNome(List<Rione> rioni, String nome) {
  for (final r in rioni) {
    if (r.nome.toLowerCase() == nome.toLowerCase()) return r;
  }
  return null;
}

/// Stemma del rione, oppure un cerchio del suo colore se lo stemma manca.
class SegnoRione extends StatelessWidget {
  final Rione? rione;
  final String colore;
  final double lato;
  const SegnoRione({super.key, this.rione, required this.colore, this.lato = 36});

  @override
  Widget build(BuildContext context) {
    final cerchio = Container(
      width: lato,
      height: lato,
      decoration: BoxDecoration(color: coloreHex(colore), shape: BoxShape.circle),
    );
    final r = rione;
    if (r == null || !r.haLogo) return cerchio;
    return SizedBox(
      width: lato,
      height: lato,
      child: Image.network(
        Api.instance.logoRione(r),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => cerchio,
      ),
    );
  }
}

/// Messaggio a tutta pagina: vuoto, errore, informazione.
class Messaggio extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String? testo;
  final Widget? azione;
  const Messaggio({super.key, required this.icona, required this.titolo, this.testo, this.azione});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icona, size: 56, color: t.colorScheme.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(titolo, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
          if (testo != null) ...[
            const SizedBox(height: 8),
            Text(testo!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (azione != null) ...[const SizedBox(height: 20), azione!],
        ],
      ),
    );
  }
}

/// Carica dati dal portale con indicatore, errore con "Riprova" e trascina-per-aggiornare.
/// [costruisci] deve restituire una lista scorrevole.
class DatiRemoti<T> extends StatefulWidget {
  final Future<T> Function() carica;
  final Widget Function(BuildContext context, T dati) costruisci;
  const DatiRemoti({super.key, required this.carica, required this.costruisci});

  @override
  State<DatiRemoti<T>> createState() => _DatiRemotiState<T>();
}

class _DatiRemotiState<T> extends State<DatiRemoti<T>> {
  late Future<T> _futuro = widget.carica();

  Future<void> _ricarica() async {
    final f = widget.carica();
    setState(() => _futuro = f);
    try {
      await f;
    } catch (_) {
      // l'errore lo mostra il FutureBuilder
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, s) {
        if (s.hasError) {
          final msg = s.error is ApiException ? s.error.toString() : 'Dati non leggibili. Riprova più tardi.';
          return RefreshIndicator(
            onRefresh: _ricarica,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Messaggio(
                  icona: Icons.cloud_off,
                  titolo: 'Impossibile caricare i dati',
                  testo: msg,
                  azione: FilledButton.tonalIcon(onPressed: _ricarica, icon: const Icon(Icons.refresh), label: const Text('Riprova')),
                ),
              ],
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(onRefresh: _ricarica, child: widget.costruisci(context, s.data as T));
      },
    );
  }
}

/// Intestazione di sezione nelle liste.
class Sezione extends StatelessWidget {
  final String testo;
  final Widget? coda;
  const Sezione(this.testo, {super.key, this.coda});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(testo, style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
          ),
          if (coda != null) coda!,
        ],
      ),
    );
  }
}
