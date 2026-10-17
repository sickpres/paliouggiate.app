import 'package:flutter/material.dart';

import '../promemoria.dart';
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _scheda,
        onDestinationSelected: (i) => setState(() => _scheda = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Classifica'),
          NavigationDestination(icon: Icon(Icons.sports_outlined), selectedIcon: Icon(Icons.sports), label: 'Giochi'),
          NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public), label: 'Social'),
        ],
      ),
    );
  }
}
