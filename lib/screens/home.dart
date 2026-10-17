import 'package:flutter/material.dart';

import 'calendario.dart';
import 'classifica.dart';
import 'giochi.dart';
import 'sponsor.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // --dart-define=PROVA_SCHEDA=n apre direttamente la scheda n (schermate di prova)
  int _scheda = const int.fromEnvironment('PROVA_SCHEDA');

  static const _pagine = [PaginaCalendario(), PaginaClassifica(), PaginaGiochi(), PaginaSponsor()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _scheda, children: _pagine),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _scheda,
        onDestinationSelected: (i) => setState(() => _scheda = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Classifica'),
          NavigationDestination(icon: Icon(Icons.sports_outlined), selectedIcon: Icon(Icons.sports), label: 'Giochi'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Sponsor'),
        ],
      ),
    );
  }
}
