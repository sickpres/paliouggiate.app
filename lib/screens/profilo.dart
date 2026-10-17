import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../stato.dart';
import '../widgets/comuni.dart';
import 'password.dart';

const _nomiRuoli = {'amministratore': 'Amministratore', 'capo_rione': 'Caporione', 'utente': 'Staff'};

class PaginaProfilo extends StatelessWidget {
  const PaginaProfilo({super.key});

  @override
  Widget build(BuildContext context) {
    final stato = StatoScope.of(context);
    final s = stato.sessione;
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: s == null
          ? ListView(children: [
              Messaggio(
                icona: Icons.account_circle_outlined,
                titolo: 'Non hai effettuato l\'accesso',
                testo: 'Calendario, classifiche, giochi e sponsor sono consultabili da tutti. '
                    'Accedi per gestire i tuoi dati personali.',
                azione: FilledButton.icon(onPressed: stato.esci, icon: const Icon(Icons.login), label: const Text('Accedi')),
              ),
            ])
          : _Profilo(s),
    );
  }
}

class _Profilo extends StatefulWidget {
  final Sessione s;
  const _Profilo(this.s);

  @override
  State<_Profilo> createState() => _ProfiloState();
}

class _ProfiloState extends State<_Profilo> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _cognome = TextEditingController();
  final _telefono = TextEditingController();
  bool _caricato = false;
  bool _invio = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _leggi();
  }

  @override
  void dispose() {
    _nome.dispose();
    _cognome.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _mostra(Profilo p) {
    _nome.text = p.nome;
    _cognome.text = p.cognome;
    _telefono.text = p.telefono;
  }

  String _messaggio(ApiException e) => e.status == 404
      ? 'La modifica dei dati personali non è ancora attiva sul portale.'
      : e.status == 401
          ? 'La sessione è scaduta: esci e accedi di nuovo.'
          : e.message;

  Future<void> _leggi() async {
    setState(() => _errore = null);
    try {
      _mostra(await Api.instance.profilo());
      if (mounted) setState(() => _caricato = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errore = _messaggio(e));
    }
  }

  Future<void> _salva() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final avvisi = ScaffoldMessenger.of(context);
    setState(() {
      _invio = true;
      _errore = null;
    });
    try {
      _mostra(await Api.instance.salvaProfilo(
          Profilo(nome: _nome.text.trim(), cognome: _cognome.text.trim(), telefono: _telefono.text.trim())));
      avvisi.showSnackBar(const SnackBar(content: Text('Dati salvati')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _errore = _messaggio(e));
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  Future<void> _esci() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vuoi uscire?'),
        content: const Text('Potrai continuare a consultare l\'app oppure accedere di nuovo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Esci')),
        ],
      ),
    );
    if (ok == true && mounted) await StatoScope.of(context).esci();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = widget.s;
    final ruoli = s.ruoli.map((r) => _nomiRuoli[r] ?? r).join(', ');
    final iniziale = s.utente.isEmpty ? '?' : s.utente.substring(0, 1).toUpperCase();
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: t.colorScheme.primaryContainer,
              child: Text(iniziale, style: t.textTheme.headlineMedium?.copyWith(color: t.colorScheme.onPrimaryContainer)),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(s.utente, style: t.textTheme.titleLarge)),
          if (ruoli.isNotEmpty || s.rione.isNotEmpty)
            Center(
              child: Text([ruoli, if (s.rione.isNotEmpty) 'Rione ${s.rione}'].where((x) => x.isNotEmpty).join(' · '),
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ),
          const Sezione('Dati personali'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              TextFormField(
                controller: _nome,
                enabled: _caricato && !_invio,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v ?? '').trim().length > 60 ? 'Massimo 60 caratteri' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cognome,
                enabled: _caricato && !_invio,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.familyName],
                decoration: const InputDecoration(labelText: 'Cognome'),
                validator: (v) => (v ?? '').trim().length > 60 ? 'Massimo 60 caratteri' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                enabled: _caricato && !_invio,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(labelText: 'Telefono'),
                validator: (v) {
                  final x = (v ?? '').trim();
                  if (x.isEmpty) return null;
                  final cifre = RegExp(r'[0-9]').allMatches(x).length;
                  return RegExp(r'^\+?[0-9 ()./-]{5,25}$').hasMatch(x) && cifre >= 5 ? null : 'Numero di telefono non valido';
                },
              ),
              if (_errore != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Expanded(child: Text(_errore!, style: TextStyle(color: t.colorScheme.error))),
                    if (!_caricato) TextButton(onPressed: _leggi, child: const Text('Riprova')),
                  ]),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _caricato && !_invio ? _salva : null,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _invio
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Salva i dati'),
              ),
            ]),
          ),
          const Sezione('Sicurezza'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Cambia password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaPassword())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: t.colorScheme.error),
                title: Text('Esci', style: TextStyle(color: t.colorScheme.error)),
                onTap: _esci,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
