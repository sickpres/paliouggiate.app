import 'package:flutter_test/flutter_test.dart';
import 'package:palio_uggiate/models.dart';
import 'package:palio_uggiate/promemoria.dart';

void main() {
  final rioni = {8: 'Pastura', 9: 'Ronago Centro', 10: 'Somoca'};
  final n = Notifica(
    id: 'auto-2027-07-03',
    quando: DateTime.utc(2027, 7, 3, 10),
    titolo: 'Oggi al Palio',
    testo: 'In programma: 21:30 Pallavolo.',
    partite: [PartitaPromemoria('21:30', 8, 9, 10)],
  );

  test('il rione che gioca riceve la sua partita', () {
    expect(Promemoria.testoPer(n, 8, rioni), 'In programma: 21:30 Pallavolo. Pallavolo: alle 21:30 Pastura gioca contro Ronago Centro.');
    expect(Promemoria.testoPer(n, 9, rioni), endsWith('Ronago Centro gioca contro Pastura.'));
  });

  test('il rione che arbitra non riceve la partita', () {
    expect(Promemoria.testoPer(n, 10, rioni), 'In programma: 21:30 Pallavolo.');
  });

  test('senza rione scelto resta il testo del portale', () {
    expect(Promemoria.testoPer(n, null, rioni), 'In programma: 21:30 Pallavolo.');
  });
}
