import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'api_tesoro.dart';

/// «Campo base» (fino alla build 15 «Eravamo 4 amici al bar»): i giocatori si trovano dove vogliono, uno apre il
/// tavolo e riceve un codice di 4 cifre, gli altri lo inseriscono. Al completo ognuno prova a toccare il bottone
/// «Invia», che scappa: tutti i tocchi devono arrivare insieme. Poi ognuno inserisce le parole chiave del tavolo e
/// vede quali sono giuste. Lo stato si aggiorna ogni 2 secondi.
/// Quanti si siedono al tavolo (4 di solito, almeno 2) lo decide il pannello: arriva con lo stato del giocatore.
class PaginaTavolo extends StatefulWidget {
  const PaginaTavolo({super.key});
  @override
  State<PaginaTavolo> createState() => _PaginaTavoloState();
}

class _PaginaTavoloState extends State<PaginaTavolo> {
  Json? _tavolo;
  int _livello = 2;
  bool _caricato = false;
  bool _lavoro = false;
  Timer? _giro;
  int _tentativi = 0;
  int _posti = 4; // giocatori del tavolo (quello aperto, o quelli delle impostazioni)
  String? _avviso;
  final _codice = TextEditingController();
  final _parole = List.generate(8, (_) => TextEditingController()); // al massimo 8 giocatori
  List<bool?>? _esiti; // quali parole erano giuste all'ultimo invio (si cancella cambiando una parola)

  @override
  void initState() {
    super.initState();
    _aggiorna();
    _giro = Timer.periodic(const Duration(seconds: 2), (_) => _aggiorna());
  }

  @override
  void dispose() {
    _giro?.cancel();
    super.dispose();
  }

  Future<void> _aggiorna() async {
    try {
      final io = await TesoroApi.instance.io();
      if (!mounted) return;
      final t = io['tavolo'] as Json?;
      setState(() {
        _livello = (io['giocatore'] as Json)['livello'] as int;
        if (t != null && (t['tentativi'] as int) > _tentativi && _tentativi > 0 && t['stato'] == 'pieno') {
          _avviso = 'Troppo tardi: i tocchi devono arrivare insieme. Riprovate tutti!';
        }
        if (t != null) _tentativi = t['tentativi'] as int;
        _posti = (t?['posti'] ?? io['posti_tavolo'] ?? 4) as int;
        _tavolo = t;
        _caricato = true;
      });
      if (_livello >= 3) {
        _giro?.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      // un giro perso non importa: riprova fra 2 secondi
    }
  }

  Future<void> _fai(Future<void> Function() fn) async {
    setState(() => _lavoro = true);
    await prova(context, fn);
    if (!mounted) return;
    setState(() => _lavoro = false);
    await _aggiorna();
  }

  Future<void> _apri() => _fai(() async => TesoroApi.instance.tavolo('apri'));
  Future<void> _entra() => _fai(() async => TesoroApi.instance.tavolo('entra', {'codice': _codice.text.trim()}));
  Future<void> _esci() => _fai(() async => TesoroApi.instance.tavolo('esci'));

  Future<void> _brinda() async {
    final r = await prova(context, () => TesoroApi.instance.tavolo('brinda'));
    if (r == null || !mounted) return;
    setState(() => _avviso = r['brindato'] == true ? null : 'Preso! Ora devono toccarlo anche gli altri entro ${r['finestra']} secondi.');
    _aggiorna();
  }

  Future<void> _inviaParole() => _fai(() async {
        final r = await TesoroApi.instance.tavolo('parole', {'parole': _parole.take(_posti).map((c) => c.text).toList()});
        if (r['giuste'] == true || !mounted) return;
        final esiti = (r['esiti'] as List?)?.map<bool?>((e) => e == true).toList();
        setState(() => _esiti = esiti);
        final ok = esiti?.where((e) => e == true).length ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(esiti == null
                ? 'Le parole non sono giuste: controllatele insieme.'
                : 'Giuste $ok su $_posti: correggete quelle in rosso.')));
      });

  @override
  Widget build(BuildContext context) {
    final t = _tavolo;
    return Scaffold(
      appBar: AppBar(title: const Text('Campo base')),
      body: !_caricato
          ? const Center(child: CircularProgressIndicator())
          : t == null
              ? _senzaTavolo()
              : t['stato'] == 'pieno'
                  ? _brindisi(t)
                  : t['stato'] == 'brindato'
                      ? _paroleChiave(t)
                      : _inAttesa(t),
    );
  }

  Widget _senzaTavolo() => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Trovatevi in $_posti, dove volete. Uno di voi apre il tavolo, ${_posti == 2 ? "l'altro inserisce" : 'gli altri inseriscono'} il suo codice.',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: _lavoro ? null : _apri,
            icon: const Icon(Icons.table_restaurant),
            label: const Text('Apri un tavolo')),
        const SizedBox(height: 28),
        TextField(
          controller: _codice,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: fontTitoli, fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Codice del tavolo', counterText: ''),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: _lavoro ? null : _entra, child: const Text('Siediti al tavolo')),
        if (_lavoro) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ]);

  Widget _membri(Json t) => Column(children: [
        for (final m in t['membri'] as List)
          ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(TesoroApi.instance.indirizzo((m as Map)['avatar_foto'] as String))),
            title: Text('${m['avatar']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${m['rione']}'),
            trailing: m['parole_ok'] == true || m['tocco'] == true ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : null,
          ),
      ]);

  Widget _inAttesa(Json t) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Il vostro tavolo', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${t['codice']}', textAlign: TextAlign.center, style: const TextStyle(fontFamily: fontTitoli, fontSize: 72, fontWeight: FontWeight.w800, letterSpacing: 10)),
        Text('Siete in ${(t['membri'] as List).length} su $_posti: date questo codice ${_posti == 2 ? "all'altro" : 'agli altri'}.', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _membri(t),
        const SizedBox(height: 12),
        TextButton(onPressed: _lavoro ? null : _esci, child: const Text('Lascia il tavolo')),
      ]);

  Widget _brindisi(Json t) {
    final mio = (t['membri'] as List).cast<Map>().where((m) => m['posto'] == t['mio_posto']).firstOrNull;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_avviso ?? (mio?['tocco'] == true ? 'Preso! Aspettate gli altri…' : 'Tutti insieme: al «via» toccate il bottone «Invia»!'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      Expanded(child: _BottoneUbriaco(onTocco: _brinda)),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Hanno toccato: ${(t['membri'] as List).where((m) => (m as Map)['tocco'] == true).length} su $_posti'),
      ),
    ]);
  }

  Widget _paroleChiave(Json t) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Ci siete! Ora inserite le $_posti parole chiave del tavolo, in qualunque ordine.',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        for (var i = 0; i < _posti; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _campoParola(i),
          ),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), onPressed: _lavoro ? null : _inviaParole, child: const Text('Apri il livello 3')),
        if (_lavoro) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ]);

  /// Una parola chiave: dopo un invio sbagliato, verde se era giusta e rossa se no (finché non la si cambia).
  Widget _campoParola(int i) {
    final esito = _esiti != null && i < _esiti!.length ? _esiti![i] : null;
    const verde = Color(0xFF2E7D32), rosso = Color(0xFFC62828);
    final colore = esito == null ? null : (esito ? verde : rosso);
    OutlineInputBorder bordo(double w) => OutlineInputBorder(borderSide: colore == null ? const BorderSide() : BorderSide(color: colore, width: w));
    return TextField(
      controller: _parole[i],
      onChanged: (_) {
        if (esito != null) setState(() => _esiti![i] = null);
      },
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        enabledBorder: colore == null ? null : bordo(2),
        focusedBorder: colore == null ? null : bordo(2.5),
        labelText: 'Parola ${i + 1}',
        labelStyle: colore == null ? null : TextStyle(color: colore),
        suffixIcon: esito == null ? null : Icon(esito ? Icons.check_circle : Icons.cancel, color: colore),
        helperText: esito == false ? 'Non è giusta' : null,
        helperStyle: const TextStyle(color: rosso),
      ),
    );
  }
}

/// Il bottone «Invia» che scappa: cambia posto ogni 450 millisecondi.
class _BottoneUbriaco extends StatefulWidget {
  final VoidCallback onTocco;
  const _BottoneUbriaco({required this.onTocco});
  @override
  State<_BottoneUbriaco> createState() => _BottoneUbriacoState();
}

class _BottoneUbriacoState extends State<_BottoneUbriaco> {
  final _caso = math.Random();
  Alignment _dove = Alignment.center;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _dove = Alignment(_caso.nextDouble() * 2 - 1, _caso.nextDouble() * 2 - 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedAlign(
        alignment: _dove,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutBack,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: oro, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18)),
          onPressed: widget.onTocco,
          child: const Text('Invia', style: TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
