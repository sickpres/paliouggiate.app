import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'apri_pagina.dart';
import 'push.dart';
import 'screens/home.dart';
import 'tema.dart';

void main() {
  // solo in verticale (anche in Info.plist)
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // le licenze dei font vanno mostrate con le altre
  LicenseRegistry.addLicense(() async* {
    for (final f in ['Nunito', 'EncodeSans']) {
      yield LicenseEntryWithLineBreaks([f], await rootBundle.loadString('assets/fonts/OFL-$f.txt'));
    }
  });
  runApp(const PalioApp());
  Push.avvia(); // notifiche push del portale
}

class PalioApp extends StatelessWidget {
  const PalioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Il Palio dei Rioni',
      navigatorKey: navigatore, // per aprire una pagina dal tocco su una notifica
      debugShowCheckedModeBanner: false,
      theme: temaPalio(Brightness.light),
      darkTheme: temaPalio(Brightness.dark),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Home(),
    );
  }
}
