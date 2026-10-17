import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home.dart';

// Blu dello stemma di Uggiate
const coloreBase = Color(0xFF1F3F9A);

void main() => runApp(const PalioApp());

class PalioApp extends StatelessWidget {
  const PalioApp({super.key});

  ThemeData _tema(Brightness b) {
    final schema = ColorScheme.fromSeed(seedColor: coloreBase, brightness: b);
    return ThemeData(
      colorScheme: schema,
      useMaterial3: true,
      appBarTheme: AppBarTheme(centerTitle: false, backgroundColor: schema.surface, scrolledUnderElevation: 2),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palio Uggiate con Ronago',
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Home(),
    );
  }
}
