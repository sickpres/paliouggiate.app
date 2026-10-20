import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

/// Pagina «Documenti» (regolamento e moduli): i documenti del portale nell'ordine scelto nel pannello. Un tocco sulla riga o
/// sull'icona di scaricamento apre il documento dentro l'app (il visore di Safari, da cui si salva o si condivide).
// solo per le schermate di prova nel simulatore: --dart-define=PROVA_APRI_DOCUMENTO=true apre il primo documento
const _provaApri = bool.fromEnvironment('PROVA_APRI_DOCUMENTO');

class PaginaDocumenti extends StatelessWidget {
  const PaginaDocumenti({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documenti')),
      body: DatiRemoti<List<Documento>>(
        carica: Api.instance.documenti,
        costruisci: (context, lista) {
          if (_provaApri && lista.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _RigaDocumento(lista.first)._apri(context));
          }
          return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 10, bottom: 24),
          children: [
            if (lista.isEmpty)
              const Messaggio(
                icona: Icons.description_outlined,
                titolo: 'Nessun documento',
                testo: 'Regolamento e moduli compariranno qui appena saranno pubblicati.',
              ),
            for (final d in lista) _RigaDocumento(d),
          ],
        );
        },
      ),
    );
  }
}

String _peso(int byte) => byte < 1024 * 1024
    ? '${(byte / 1024).ceil()} KB'
    : '${(byte / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';

class _RigaDocumento extends StatelessWidget {
  final Documento d;
  const _RigaDocumento(this.d);

  // dentro l'app: SFSafariViewController su iOS, che mostra PDF e documenti Office
  Future<void> _apri(BuildContext context) async {
    final avvisi = ScaffoldMessenger.of(context);
    if (!await launchUrl(Uri.parse(Api.instance.fileDocumento(d)), mode: LaunchMode.inAppBrowserView)) {
      avvisi.showSnackBar(const SnackBar(content: Text('Impossibile aprire il documento')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dettagli = [
      if (d.caricato != null) dataBreve(d.caricato!),
      if (d.formato.isNotEmpty) d.formato,
      _peso(d.dimensione),
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        onTap: () => _apri(context),
        leading: CircleAvatar(
          backgroundColor: t.colorScheme.secondaryContainer,
          child: Icon(d.formato == 'PDF' ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
              color: t.colorScheme.onSecondaryContainer),
        ),
        title: Text(d.titolo, style: t.textTheme.titleMedium),
        subtitle: Text(dettagli),
        trailing: IconButton(
          tooltip: 'Scarica',
          icon: const Icon(Icons.download),
          onPressed: () => _apri(context),
        ),
      ),
    );
  }
}
