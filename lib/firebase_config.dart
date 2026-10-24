import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Progetto Firebase del Palio (solo per le notifiche push, Firebase Cloud Messaging).
// I valori si leggono nella console Firebase: Impostazioni progetto > Generali > Le tue app (Android e iOS).
// Non sono segreti: identificano l'app presso Firebase, come i file google-services.json e GoogleService-Info.plist,
// che qui non servono. Finche' sono vuoti l'app funziona senza notifiche.
const _progetto = '';
const _mittente = ''; // «ID mittente» (Cloud Messaging)
const _chiaveAndroid = '';
const _appAndroid = ''; // es. 1:1234567890:android:abc...
const _chiaveIos = '';
const _appIos = ''; // es. 1:1234567890:ios:abc...

bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

bool get firebaseConfigurato =>
    _progetto.isNotEmpty && _mittente.isNotEmpty && (_ios ? _appIos.isNotEmpty && _chiaveIos.isNotEmpty : _appAndroid.isNotEmpty && _chiaveAndroid.isNotEmpty);

FirebaseOptions get opzioniFirebase => _ios
    ? const FirebaseOptions(apiKey: _chiaveIos, appId: _appIos, messagingSenderId: _mittente, projectId: _progetto, iosBundleId: 'it.uggiateconronago.palio')
    : const FirebaseOptions(apiKey: _chiaveAndroid, appId: _appAndroid, messagingSenderId: _mittente, projectId: _progetto);
