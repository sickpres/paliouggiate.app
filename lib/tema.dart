import 'package:flutter/material.dart';

// Colori del logo «Palio dei Rioni»
const bluNotte = Color(0xFF062246);
const oro = Color(0xFFFEAB06);
// oro scurito per testi e icone su fondo chiaro: contrasto 4,9:1 sul bianco (l'oro del logo si ferma a 1,9:1)
const oroScuro = Color(0xFF9A6500);
const crema = Color(0xFFFEF8E2);
// oro chiaro e caldo del motto della Home, come nel mockup
const oroChiaro = Color(0xFFF5C66E);
const rosso = Color(0xFFC62B2B);
const menuSpento = Color(0xFF5C7491); // voci del menu non scelte
// blu del fondo della foto della Home (assets/home.webp), per continuarla sotto la foto senza stacchi
const notte = Color(0xFF01112D);
// schede sul fondo notte della Home
const notteScheda = Color(0xFF0E2647);

const _raggio = 20.0;
// font dei titoli e delle scritte della Home: Encode Sans Semi Condensed ExtraBold, stretto e pieno come nel mockup
const fontTitoli = 'EncodeSansSemiCondensed';
const _spaziaturaTitoli = 0.2;

/// Tema dell'app: fondo chiaro e neutro, schede bianche molto arrotondate, titoli marcati, oro per le azioni.
ThemeData temaPalio(Brightness b) {
  final chiaro = b == Brightness.light;
  final base = ColorScheme.fromSeed(seedColor: bluNotte, brightness: b);
  final schema = chiaro
      ? base.copyWith(
          primary: bluNotte,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDCE4F5),
          onPrimaryContainer: bluNotte,
          secondary: oroScuro,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFFFE2A3),
          onSecondaryContainer: const Color(0xFF3D2A00),
          tertiary: rosso,
          tertiaryContainer: const Color(0xFFFADAD7),
          onTertiaryContainer: const Color(0xFF5C0F0F),
          // sfondo delle pagine grigio-azzurro chiarissimo; le schede bianche ci si staccano sopra
          surface: const Color(0xFFF3F5F9),
          onSurface: const Color(0xFF0B1B33),
          onSurfaceVariant: const Color(0xFF4A5B73),
          outline: const Color(0xFF8292A8),
          outlineVariant: const Color(0xFFE1E6EE),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: const Color(0xFFF7F9FC),
          surfaceContainerHigh: const Color(0xFFEDF1F6),
          surfaceContainerHighest: const Color(0xFFE5EAF1),
        )
      : base.copyWith(
          primary: const Color(0xFFAFC6F2),
          secondary: oro,
          onSecondary: bluNotte,
          secondaryContainer: const Color(0xFF5C4200),
          onSecondaryContainer: const Color(0xFFFFE2A3),
          tertiary: const Color(0xFFFFB4AB),
        );
  final menuScelto = chiaro ? oroScuro : oro;
  final t = ThemeData(
    // Nunito per i testi, Encode Sans Semi Condensed per i titoli grandi (assets/fonts)
    fontFamily: 'Nunito',
    colorScheme: schema,
    useMaterial3: true,
    scaffoldBackgroundColor: schema.surface,
    // barra in alto chiara come la pagina, titolo grande e marcato a sinistra
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: schema.surface,
      foregroundColor: chiaro ? bluNotte : schema.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: Colors.black26,
      titleTextStyle: TextStyle(
          fontFamily: fontTitoli, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: _spaziaturaTitoli, color: chiaro ? bluNotte : schema.onSurface),
    ),
    // menu in basso bianco senza pillola: la voce scelta in oro e grassetto, le altre in grigio-azzurro
    navigationBarTheme: NavigationBarThemeData(
      height: 60,
      elevation: 0,
      backgroundColor: chiaro ? Colors.white : schema.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          size: 24, color: s.contains(WidgetState.selected) ? menuScelto : (chiaro ? menuSpento : Colors.white70))),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 13,
          height: 1.1,
          color: s.contains(WidgetState.selected) ? menuScelto : (chiaro ? menuSpento : Colors.white70),
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
    ),
    // schede senza bordo, con un'ombra morbida appena accennata
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: chiaro ? Colors.white : null,
      surfaceTintColor: Colors.transparent,
      elevation: chiaro ? 3 : 0,
      shadowColor: bluNotte.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_raggio)),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: chiaro ? Colors.white : schema.surfaceContainerHigh,
      selectedColor: oro,
      checkmarkColor: bluNotte,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: chiaro ? bluNotte : schema.onSurface),
      secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w700, color: bluNotte),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    // pulsante principale: pillola oro con testo blu notte (contrasto 8:1)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: oro,
        foregroundColor: bluNotte,
        // angoli come nel mockup: raggio 14 su un pulsante alto 54
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        // stesso font dei titoli
        textStyle: const TextStyle(fontFamily: fontTitoli, fontSize: 19, fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: oro,
        selectedForegroundColor: bluNotte,
        side: BorderSide(color: schema.outlineVariant),
      ),
    ),
    listTileTheme: const ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(_raggio)))),
  );
  // titoli piu' marcati e compatti
  final x = t.textTheme;
  return t.copyWith(
    textTheme: x.copyWith(
      displayMedium: x.displayMedium?.copyWith(fontFamily: fontTitoli, fontWeight: FontWeight.w800, letterSpacing: _spaziaturaTitoli),
      displaySmall: x.displaySmall?.copyWith(fontFamily: fontTitoli, fontWeight: FontWeight.w800, letterSpacing: _spaziaturaTitoli),
      headlineMedium: x.headlineMedium?.copyWith(fontFamily: fontTitoli, fontWeight: FontWeight.w800, letterSpacing: _spaziaturaTitoli),
      headlineSmall: x.headlineSmall?.copyWith(fontFamily: fontTitoli, fontWeight: FontWeight.w800, letterSpacing: _spaziaturaTitoli),
      titleLarge: x.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: x.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// Tema della scheda Home: scuro, sul blu notte della foto della piazza; vale anche per il menu in basso
/// quando la Home e' la scheda scelta. Si crea una volta sola, alla prima richiesta.
final ThemeData temaHome = _creaTemaHome();

ThemeData _creaTemaHome() {
  final t = temaPalio(Brightness.dark);
  final schema = t.colorScheme.copyWith(
    primary: oro, // intestazioni di sezione in oro
    surface: notte,
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xFFB9C6DA),
    surfaceContainerLowest: notteScheda,
    surfaceContainerLow: notteScheda,
    surfaceContainer: notteScheda,
    surfaceContainerHigh: const Color(0xFF173259),
    surfaceContainerHighest: const Color(0xFF1F3D68),
  );
  return t.copyWith(
    colorScheme: schema,
    scaffoldBackgroundColor: notte,
    cardTheme: t.cardTheme.copyWith(color: notteScheda),
    navigationBarTheme: t.navigationBarTheme.copyWith(backgroundColor: notte),
  );
}
