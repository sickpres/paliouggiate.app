import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Progetto Firebase del Palio (solo per le notifiche push, Firebase Cloud Messaging).
// I valori si leggono nella console Firebase: Impostazioni progetto > Generali > Le tue app (Android e iOS).
// Non sono segreti: identificano l'app presso Firebase, come i file google-services.json e GoogleService-Info.plist,
// che qui non servono. Senza valori l'app funzionerebbe senza notifiche.
const _progetto = 'palio-uggiate';
const _mittente = '700969387324'; // «ID mittente» (Cloud Messaging)
const _chiaveAndroid = 'AIzaSyBFDc1qBQ-7_HaRUaurm0chfw6UbRB03_E';
const _appAndroid = '1:700969387324:android:32f58ac312df4e1a760a39';
const _chiaveIos = 'AIzaSyDOZwUIVr1w8Uny-8HIdAYD9QqQUEahq9Q';
const _appIos = '1:700969387324:ios:75c0a05549c21cca760a39';

bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

bool get firebaseConfigurato =>
    _progetto.isNotEmpty && _mittente.isNotEmpty && (_ios ? _appIos.isNotEmpty && _chiaveIos.isNotEmpty : _appAndroid.isNotEmpty && _chiaveAndroid.isNotEmpty);

FirebaseOptions get opzioniFirebase => _ios
    ? const FirebaseOptions(apiKey: _chiaveIos, appId: _appIos, messagingSenderId: _mittente, projectId: _progetto, iosBundleId: 'it.uggiateconronago.palio')
    : const FirebaseOptions(apiKey: _chiaveAndroid, appId: _appAndroid, messagingSenderId: _mittente, projectId: _progetto);
