import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/comuni.dart';

/// Pagina «Regolamento e moduli»: i documenti del portale nell'ordine scelto nel pannello; un tocco li scarica.
class PaginaDocumenti extends StatelessWidget {
  const PaginaDocumenti({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regolamento e moduli')),
      body: DatiRemoti<List<Documento>>(
        carica: Api.instance.documenti,
        costruisci: (context, lista) => ListView(
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
        ),
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

  // il file si apre nel browser del telefono, che lo scarica (il portale lo manda come allegato)
  Future<void> _scarica(BuildContext context) async {
    final avvisi = ScaffoldMessenger.of(context);
    if (!await launchUrl(Uri.parse(Api.instance.fileDocumento(d)), mode: LaunchMode.externalApplication)) {
      avvisi.showSnackBar(const SnackBar(content: Text('Impossibile scaricare il documento')));
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
        onTap: () => _scarica(context),
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
          onPressed: () => _scarica(context),
        ),
      ),
    );
  }
}
