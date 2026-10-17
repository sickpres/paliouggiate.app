import 'package:flutter/material.dart';

import '../promemoria.dart';
import '../widgets/icone_tratto.dart';
import 'calendario.dart';
import 'classifica.dart';
import 'giochi.dart';
import 'oggi.dart';
import 'pallavolo.dart';
import 'social.dart';

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_PALLAVOLO=true
const _provaPallavolo = bool.fromEnvironment('PROVA_PALLAVOLO');

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // --dart-define=PROVA_SCHEDA=n apre direttamente la scheda n (schermate di prova)
  int _scheda = const int.fromEnvironment('PROVA_SCHEDA');

  static const _pagine = [PaginaOggi(), PaginaCalendario(), PaginaClassifica(), PaginaGiochi(), PaginaSocial()];

  // a ogni ritorno nell'app si riscarica il piano dei promemoria
  late final AppLifecycleListener _ciclo;

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: Promemoria.aggiorna);
    if (_provaPallavolo) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaginaPallavolo())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _scheda, children: _pagine),
      bottomNavigationBar: MenuInBasso(
        scelta: _scheda,
        onScegli: (i) => setState(() => _scheda = i),
        voci: const [
          VoceMenu('home', 'Home'),
          VoceMenu('calendario_menu', 'Calendario'),
          VoceMenu('classifica_menu', 'Classifica'),
          VoceMenu('giochi_menu', 'Giochi'),
          VoceMenu('social_menu', 'Social'),
        ],
      ),
    );
  }
}
