import 'package:flutter/material.dart';

import '../api.dart';
import '../stato.dart';
import 'password.dart';

class PaginaAccesso extends StatefulWidget {
  const PaginaAccesso({super.key});

  @override
  State<PaginaAccesso> createState() => _PaginaAccessoState();
}

class _PaginaAccessoState extends State<PaginaAccesso> {
  final _form = GlobalKey<FormState>();
  final _utente = TextEditingController();
  final _password = TextEditingController();
  bool _nascosta = true;
  bool _invio = false;
  String? _errore;

  @override
  void dispose() {
    _utente.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _accedi() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _invio = true;
      _errore = null;
    });
    final stato = StatoScope.of(context);
    final nav = Navigator.of(context);
    try {
      final cambia = await stato.accedi(_utente.text.trim(), _password.text);
      if (cambia) {
        // il portale chiede una password nuova al primo accesso
        await nav.push(MaterialPageRoute(builder: (_) => const PaginaPassword(obbligatoria: true)));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errore = e.message);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  void _social(String nome) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.construction),
        title: Text('Accesso con $nome'),
        content: Text(
          'L\'accesso con $nome non è ancora attivo: il portale del Palio deve prima essere collegato a $nome. '
          'Nel frattempo puoi entrare con email e password oppure consultare l\'app senza accedere.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Ho capito'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/logo.png', height: 120),
                      const SizedBox(height: 16),
                      Text('Palio Uggiate con Ronago', textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Calendario, classifiche e giochi dei rioni',
                          textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: _invio ? null : () => _social('Google'),
                        icon: const _LetteraG(),
                        label: const Text('Continua con Google'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _invio ? null : () => _social('Facebook'),
                        icon: const Icon(Icons.facebook),
                        label: const Text('Continua con Facebook'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('oppure', style: t.textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _utente,
                        enabled: !_invio,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email o nome utente', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Inserisci email o nome utente' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        enabled: !_invio,
                        obscureText: _nascosta,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _accedi(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _nascosta ? 'Mostra password' : 'Nascondi password',
                            icon: Icon(_nascosta ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _nascosta = !_nascosta),
                          ),
                        ),
                        validator: (v) => (v ?? '').isEmpty ? 'Inserisci la password' : null,
                      ),
                      if (_errore != null) ...[
                        const SizedBox(height: 12),
                        Text(_errore!, style: TextStyle(color: t.colorScheme.error), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _invio ? null : _accedi,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: _invio
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Text('Accedi'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _invio ? null : () => StatoScope.of(context).entraComeOspite(),
                        child: const Text('Continua senza accedere'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "G" disegnata a mano: il logo ufficiale di Google non e' incluso nel prototipo.
class _LetteraG extends StatelessWidget {
  const _LetteraG();

  @override
  Widget build(BuildContext context) => const Text('G',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4), height: 1));
}
