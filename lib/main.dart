import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'promemoria.dart';
import 'screens/home.dart';

// Colori del logo «Palio dei Rioni»
const bluNotte = Color(0xFF062246);
const oro = Color(0xFFFEAB06);
const crema = Color(0xFFFEF8E2);
// azzurro del cielo del logo (#63B9F2) schiarito con il 75% di bianco
const cielo = Color(0xFFD8EDFC);
const rosso = Color(0xFFC62B2B);
const menuSpento = Color(0xFF5C7491); // voci del menu non scelte

void main() {
  // solo in verticale (anche in Info.plist)
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PalioApp());
  Promemoria.aggiorna();
}

class PalioApp extends StatelessWidget {
  const PalioApp({super.key});

  ThemeData _tema(Brightness b) {
    final chiaro = b == Brightness.light;
    final base = ColorScheme.fromSeed(seedColor: bluNotte, brightness: b);
    final schema = chiaro
        ? base.copyWith(
            primary: bluNotte,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFDCE4F5),
            onPrimaryContainer: bluNotte,
            secondary: const Color(0xFFB87800),
            onSecondary: Colors.white,
            secondaryContainer: const Color(0xFFFFE2A3),
            onSecondaryContainer: const Color(0xFF3D2A00),
            tertiary: rosso,
            tertiaryContainer: const Color(0xFFFADAD7),
            onTertiaryContainer: const Color(0xFF5C0F0F),
            // sfondo delle pagine: il cielo del logo, piu' chiaro; schede bianche sopra
            surface: cielo,
            onSurface: const Color(0xFF0B1B33),
            onSurfaceVariant: const Color(0xFF1C3554), // testi secondari leggibili anche sull'azzurro
            outline: const Color(0xFF2F5C86),
            outlineVariant: const Color(0xFFB9D9F2),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFF7FBFF),
            surfaceContainer: const Color(0xFFEFF6FD),
            surfaceContainerHigh: const Color(0xFFE6F1FB),
            surfaceContainerHighest: const Color(0xFFDCEBF8),
          )
        : base.copyWith(
            primary: const Color(0xFFAFC6F2),
            secondary: oro,
            onSecondary: bluNotte,
            secondaryContainer: const Color(0xFF5C4200),
            onSecondaryContainer: const Color(0xFFFFE2A3),
            tertiary: const Color(0xFFFFB4AB),
          );
    return ThemeData(
      colorScheme: schema,
      useMaterial3: true,
      scaffoldBackgroundColor: schema.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: chiaro ? bluNotte : schema.surfaceContainer,
        foregroundColor: chiaro ? Colors.white : schema.onSurface,
        scrolledUnderElevation: 2,
      ),
      // menu in basso blu notte: voce scelta in oro, le altre in bianco
      // menu in basso in stile app Sisal: barra bianca alta 60, nessuna pillola, icone a tratto da 24,
      // etichette da 13; la voce scelta in blu notte e grassetto, le altre in grigio-azzurro
      navigationBarTheme: NavigationBarThemeData(
        height: 60,
        elevation: 0,
        backgroundColor: chiaro ? Colors.white : schema.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24, color: s.contains(WidgetState.selected) ? (chiaro ? bluNotte : oro) : (chiaro ? menuSpento : Colors.white70))),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 13,
            height: 1.1,
            color: s.contains(WidgetState.selected) ? (chiaro ? bluNotte : oro) : (chiaro ? menuSpento : Colors.white70),
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: chiaro ? Colors.white : null,
      ),
      chipTheme: ChipThemeData(selectedColor: chiaro ? const Color(0xFFFFD77A) : schema.secondaryContainer),
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
