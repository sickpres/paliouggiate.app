import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

enum Accesso { avvio, fuori, ospite, dentro }

// solo per le schermate di prova nel simulatore: --dart-define=PROVA_OSPITE=true
const _provaOspite = bool.fromEnvironment('PROVA_OSPITE');

/// Chi sta usando l'app: nessuno (schermata di accesso), un ospite che consulta
/// senza account, oppure un utente del portale con la sua sessione.
class Stato extends ChangeNotifier {
  static const _kOspite = 'ospite';

  Accesso accesso = Accesso.avvio;
  Sessione? sessione;

  Future<void> avvia() async {
    await Api.instance.carica();
    final p = await SharedPreferences.getInstance();
    if (Api.instance.haSessione) {
      try {
        sessione = await Api.instance.sessione();
      } on ApiException {
        sessione = null; // senza rete si entra come ospite e si riprova al prossimo avvio
      }
    }
    accesso = sessione != null ? Accesso.dentro : (p.getBool(_kOspite) == true || _provaOspite ? Accesso.ospite : Accesso.fuori);
    notifyListeners();
  }

  /// Restituisce true se il portale chiede di cambiare la password.
  Future<bool> accedi(String utente, String password) async {
    final cambia = await Api.instance.accedi(utente, password);
    sessione = await Api.instance.sessione();
    if (sessione == null) throw ApiException(401, 'Accesso non riuscito, riprova.');
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOspite);
    accesso = Accesso.dentro;
    notifyListeners();
    return cambia;
  }

  Future<void> entraComeOspite() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOspite, true);
    accesso = Accesso.ospite;
    notifyListeners();
  }

  Future<void> aggiornaSessione() async {
    sessione = await Api.instance.sessione();
    if (sessione == null) accesso = Accesso.fuori;
    notifyListeners();
  }

  Future<void> esci() async {
    await Api.instance.esci();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOspite);
    sessione = null;
    accesso = Accesso.fuori;
    notifyListeners();
  }
}

class StatoScope extends InheritedNotifier<Stato> {
  const StatoScope({super.key, required Stato stato, required super.child}) : super(notifier: stato);

  static Stato of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StatoScope>()!.notifier!;
}
