"""Primo piano dell'icona adattiva Android dal disegno assets/android/icona-primo-piano-android.png.

Android ritaglia l'icona adattiva (108 dp) con maschere diverse: cerchio, goccia, quadrato arrotondato. Si vede
sempre per intero solo la «zona sicura», un cerchio di 66 dp al centro. Il disegno del Palio arriva quasi ai bordi:
qui si riduce una volta sola, centrato, in modo che ogni pixel visibile stia dentro quel cerchio, e si salva in
assets/android/icona-primo-piano-adattiva.png (1024 x 1024, trasparente). In ic_launcher.xml il margine resta a zero
(adaptive_icon_foreground_inset: 0 in pubspec.yaml), cosi' il disegno non si rimpicciolisce due volte.

Uso (dalla cartella dell'app): python scripts/icona-adattiva.py
poi: dart run flutter_launcher_icons -f scripts/icona-android.yaml   (solo Android: l'icona iOS resta com'e')
"""
import math

from PIL import Image

ORIGINE = 'assets/android/icona-primo-piano-android.png'
DESTINAZIONE = 'assets/android/icona-primo-piano-adattiva.png'
LATO = 1024
RAGGIO_SICURO = 33 / 108  # zona sicura: cerchio di 66 dp su 108
SOGLIA = 40  # alfa oltre cui un pixel conta come disegno (sotto e' solo alone)

disegno = Image.open(ORIGINE).convert('RGBA')
alfa = disegno.getchannel('A')
riquadro = alfa.point(lambda v: 255 if v > SOGLIA else 0).getbbox()
cx, cy = (riquadro[0] + riquadro[2]) / 2, (riquadro[1] + riquadro[3]) / 2
punti = alfa.load()
raggio = max(math.hypot(x - cx, y - cy)
             for y in range(riquadro[1], riquadro[3])
             for x in range(riquadro[0], riquadro[2]) if punti[x, y] > SOGLIA)

scala = RAGGIO_SICURO * LATO / raggio
ritaglio = disegno.crop(riquadro)
ridotto = ritaglio.resize((round(ritaglio.width * scala), round(ritaglio.height * scala)), Image.LANCZOS)
tela = Image.new('RGBA', (LATO, LATO), (0, 0, 0, 0))
tela.paste(ridotto, (round(LATO / 2 - ridotto.width / 2), round(LATO / 2 - ridotto.height / 2)), ridotto)
tela.save(DESTINAZIONE, optimize=True)
print(f'{DESTINAZIONE}: disegno largo {ridotto.width / LATO:.0%} del lato, tutto nella zona sicura')
