import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/accesso.dart';
import 'screens/home.dart';
import 'stato.dart';

// Blu dello stemma di Uggiate
const coloreBase = Color(0xFF1F3F9A);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final stato = Stato()..avvia();
  runApp(StatoScope(stato: stato, child: const PalioApp()));
}

class PalioApp extends StatelessWidget {
  const PalioApp({super.key});

  ThemeData _tema(Brightness b) {
    final schema = ColorScheme.fromSeed(seedColor: coloreBase, brightness: b);
    return ThemeData(
      colorScheme: schema,
      useMaterial3: true,
      appBarTheme: AppBarTheme(centerTitle: false, backgroundColor: schema.surface, scrolledUnderElevation: 2),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stato = StatoScope.of(context);
    return MaterialApp(
      title: 'Palio Uggiate con Ronago',
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: switch (stato.accesso) {
        Accesso.avvio => const Scaffold(body: Center(child: CircularProgressIndicator())),
        Accesso.fuori => const PaginaAccesso(),
        Accesso.ospite || Accesso.dentro => const Home(),
      },
    );
  }
}
