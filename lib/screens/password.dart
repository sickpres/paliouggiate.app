import 'package:flutter/material.dart';

import '../api.dart';
import '../stato.dart';

/// Cambio password. [obbligatoria]: richiesto dal portale al primo accesso.
class PaginaPassword extends StatefulWidget {
  final bool obbligatoria;
  const PaginaPassword({super.key, this.obbligatoria = false});

  @override
  State<PaginaPassword> createState() => _PaginaPasswordState();
}

class _PaginaPasswordState extends State<PaginaPassword> {
  final _form = GlobalKey<FormState>();
  final _vecchia = TextEditingController();
  final _nuova = TextEditingController();
  final _conferma = TextEditingController();
  bool _invio = false;
  String? _errore;

  @override
  void dispose() {
    _vecchia.dispose();
    _nuova.dispose();
    _conferma.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _invio = true;
      _errore = null;
    });
    final stato = StatoScope.of(context);
    final nav = Navigator.of(context);
    final avvisi = ScaffoldMessenger.of(context);
    try {
      await Api.instance.cambiaPassword(_vecchia.text, _nuova.text);
      await stato.aggiornaSessione();
      avvisi.showSnackBar(const SnackBar(content: Text('Password aggiornata')));
      nav.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errore = e.message);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  Widget _campo(TextEditingController c, String etichetta, {String? Function(String?)? controllo, List<String>? autofill}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          enabled: !_invio,
          obscureText: true,
          autofillHints: autofill,
          decoration: InputDecoration(labelText: etichetta),
          validator: controllo ?? (v) => (v ?? '').isEmpty ? 'Campo obbligatorio' : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PopScope(
      canPop: !widget.obbligatoria,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cambia password'),
          automaticallyImplyLeading: !widget.obbligatoria,
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.obbligatoria)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: t.colorScheme.secondaryContainer,
                    child: const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Scegli una password nuova'),
                      subtitle: Text('È il tuo primo accesso, oppure la password è stata reimpostata da un amministratore.'),
                    ),
                  ),
                _campo(_vecchia, 'Password attuale', autofill: const [AutofillHints.password]),
                _campo(_nuova, 'Nuova password', autofill: const [AutofillHints.newPassword]),
                _campo(_conferma, 'Ripeti la nuova password',
                    controllo: (v) => v != _nuova.text ? 'Le due password non coincidono' : null),
                if (_errore != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_errore!, style: TextStyle(color: t.colorScheme.error)),
                  ),
                FilledButton(
                  onPressed: _invio ? null : _salva,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: _invio
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Salva la password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
