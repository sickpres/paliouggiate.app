import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home.dart';

// Colori del logo «Palio dei Rioni»
const bluNotte = Color(0xFF062246);
const oro = Color(0xFFFEAB06);
const crema = Color(0xFFFEF8E2);
const rosso = Color(0xFFC62B2B);

void main() => runApp(const PalioApp());

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
            surface: crema,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFFFFDF7),
            surfaceContainer: const Color(0xFFF8F0D8),
            surfaceContainerHigh: const Color(0xFFF3EACD),
            surfaceContainerHighest: const Color(0xFFEDE3C3),
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: chiaro ? Colors.white : schema.surfaceContainer,
        indicatorColor: chiaro ? oro : schema.secondaryContainer,
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
