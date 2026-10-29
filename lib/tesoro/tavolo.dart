import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'api_tesoro.dart';

/// «Eravamo 4 amici al bar»: uno apre il tavolo nel bar e riceve un codice di 4 cifre, gli altri tre lo inseriscono.
/// Al completo ognuno fotografa i bicchieri vuoti e prova a toccare il bottone «Invia», che scappa: i 4 tocchi
/// devono arrivare insieme. Poi ognuno inserisce le 4 parole chiave. Lo stato si aggiorna ogni 2 secondi.
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
  int? _foto; // foto dei bicchieri caricata
  Json? _pos; // posizione presa prima del bottone, per non perdere tempo al tocco
  int _tentativi = 0;
  String? _avviso;
  final _codice = TextEditingController();
  final _parole = List.generate(4, (_) => TextEditingController());

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

  Future<void> _apri() => _fai(() async => TesoroApi.instance.tavolo('apri', await posizioneAttuale()));
  Future<void> _entra() => _fai(() async => TesoroApi.instance.tavolo('entra', {'codice': _codice.text.trim(), ...await posizioneAttuale()}));
  Future<void> _esci() => _fai(() async => TesoroApi.instance.tavolo('esci'));

  Future<void> _fotografa() async {
    final byte = await prova(context, scattaFoto);
    if (byte == null || !mounted) return;
    await _fai(() async {
      final pos = await posizioneAttuale();
      final id = await TesoroApi.instance.caricaFoto('bar', byte);
      setState(() => (_foto = id, _pos = pos));
    });
  }

  Future<void> _brinda() async {
    if (_foto == null || _pos == null) return;
    final r = await prova(context, () => TesoroApi.instance.tavolo('brinda', {'foto_id': _foto, ..._pos!}));
    if (r == null || !mounted) return;
    setState(() => _avviso = r['brindato'] == true ? null : 'Preso! Ora devono toccarlo anche gli altri entro ${r['finestra']} secondi.');
    _aggiorna();
  }

  Future<void> _inviaParole() => _fai(() async {
        final r = await TesoroApi.instance.tavolo('parole', {'parole': _parole.map((c) => c.text).toList()});
        if (r['giuste'] != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le parole non sono giuste: controllatele insieme.')));
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = _tavolo;
    return Scaffold(
      appBar: AppBar(title: const Text('4 amici al bar')),
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
        const Text('Trovatevi in 4 in uno dei bar «Amici del Palio». Uno di voi apre il tavolo, gli altri inseriscono il suo codice.',
            style: TextStyle(fontSize: 16)),
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
        Text('Tavolo al ${t['bar']}', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${t['codice']}', textAlign: TextAlign.center, style: const TextStyle(fontFamily: fontTitoli, fontSize: 72, fontWeight: FontWeight.w800, letterSpacing: 10)),
        Text('Siete in ${(t['membri'] as List).length} su 4: date questo codice agli altri.', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _membri(t),
        const SizedBox(height: 12),
        TextButton(onPressed: _lavoro ? null : _esci, child: const Text('Lascia il tavolo')),
      ]);

  Widget _brindisi(Json t) {
    if (_foto == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Siete in 4: brindate! Poi fotografate i 4 bicchieri vuoti.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _lavoro ? null : _fotografa,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Fotografa i bicchieri'),
        ),
        if (_lavoro) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        const SizedBox(height: 12),
        _membri(t),
      ]);
    }
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
        child: Text('Hanno toccato: ${(t['membri'] as List).where((m) => (m as Map)['tocco'] == true).length} su 4'),
      ),
    ]);
  }

  Widget _paroleChiave(Json t) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Avete brindato! Ora inserite le 4 parole chiave del tavolo, in qualunque ordine.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(controller: _parole[i], decoration: InputDecoration(border: const OutlineInputBorder(), labelText: 'Parola ${i + 1}')),
          ),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), onPressed: _lavoro ? null : _inviaParole, child: const Text('Apri il livello 3')),
        if (_lavoro) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ]);
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
