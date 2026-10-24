"""Schermate per l'App Store in stile «panorama»: sfondo chiaro continuo con forme nei colori delle bandiere del Palio,
iPhone inclinati (a volte a cavallo tra due schermate) e un titolo breve in alto. Lo stile riprende il template
«3 Tilted iPhones» di previewed.app, rifatto qui senza servizi esterni.

Entrata: le schermate del simulatore (1206 x 2622, iPhone 6,3") fatte da scripts/schermate.sh, in una cartella.
Uscita: una immagine 1206 x 2622 per schermata (stesso ordine), pronte per App Store Connect.

Uso: python scripts/vetrina-appstore.py <cartella schermate> <cartella uscita> [--android]

Con --android (schermate di scripts/schermate-android.ps1) l'uscita e' 1080 x 2160: Google Play non accetta immagini
piu' lunghe di 2:1. Si compone su una pagina 1206 x 2412 (stesse misure, telefono tagliato un po' piu' in basso) e si
riduce alla fine.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

LARGO, ALTO = 1206, 2622
FONT = Path(__file__).resolve().parent.parent / 'assets' / 'fonts' / 'EncodeSansSemiCondensed-ExtraBold.ttf'
BLU = (6, 34, 70)            # bluNotte del tema
ORO = (254, 171, 6)
SFONDO = (246, 248, 253)
BANDIERE = [(214, 40, 40), (247, 196, 37), (30, 91, 216), (46, 158, 68)]  # rosso, giallo, blu, verde

# (file, titolo, inclinazione in gradi, spostamento orizzontale del telefono in pixel)
PAGINE = [
    ('home', 'Il Palio dei Rioni,\ntutto in un’app', -6, 40),
    ('calendario', 'Il programma\ngiorno per giorno', 5, -30),
    ('giochi', 'Trova il tuo gioco\ne la tua squadra', -5, 30),
    ('pallavolo-scheda', 'Regole, orari\ne risultati', 6, -40),
    ('rioni', 'Scegli il tuo rione\ne unisciti a noi', -5, 40),
    ('classifica', 'La classifica\nsempre aggiornata', 5, -30),
    ('pallavolo-mulini', 'Le partite\ndel tuo rione', -6, 30),
]


def telefono(schermata: Image.Image, larghezza: int) -> Image.Image:
    """La schermata dentro una cornice da iPhone (bordo scuro sottile, angoli molto arrotondati)."""
    bordo = round(larghezza * 0.035)
    interno = schermata.convert('RGBA').resize((larghezza, round(larghezza * schermata.height / schermata.width)), Image.LANCZOS)
    w, h = interno.width + 2 * bordo, interno.height + 2 * bordo
    raggio = round(larghezza * 0.15)
    tel = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(tel).rounded_rectangle((0, 0, w - 1, h - 1), radius=raggio, fill=(18, 20, 26, 255))
    maschera = Image.new('L', interno.size, 0)
    ImageDraw.Draw(maschera).rounded_rectangle((0, 0, interno.width - 1, interno.height - 1), radius=raggio - bordo, fill=255)
    tel.paste(interno, (bordo, bordo), maschera)
    # riflesso del bordo: una linea chiara sottile
    ImageDraw.Draw(tel).rounded_rectangle((3, 3, w - 4, h - 4), radius=raggio - 3, outline=(70, 74, 84, 255), width=3)
    return tel


def sfondo(n: int) -> Image.Image:
    """Panorama largo n schermate: tinta chiara, macchie morbide nei colori delle bandiere e qualche linea leggera."""
    W = LARGO * n
    img = Image.new('RGBA', (W, ALTO), SFONDO + (255,))
    caso = random.Random(2027)
    strato = Image.new('RGBA', (W, ALTO), (0, 0, 0, 0))
    d = ImageDraw.Draw(strato)
    # due nastri ondulati che attraversano tutto il panorama dietro ai telefoni: danno la continuita' tra le schermate
    for colore, base, amp, fase, spessore in [(ORO, 1500, 380, 0.0, 150), (BLU, 1750, 300, 2.1, 70)]:
        curva = [(x, base + amp * math.sin(x / LARGO * 2.2 + fase)) for x in range(-50, W + 50, 8)]
        sopra = [(x, y - spessore / 2) for x, y in curva]
        sotto = [(x, y + spessore / 2) for x, y in reversed(curva)]
        d.polygon(sopra + sotto, fill=colore + (55 if colore == BLU else 120,))
    # una forma morbida a cavallo di ogni bordo tra due schermate, alternata sopra e sotto, nei colori delle bandiere
    for k in range(n + 1):
        cx = k * LARGO + caso.uniform(-60, 60)
        cy = 820 if k % 2 else ALTO - 240
        r = caso.uniform(230, 300)
        punti = [(cx + r * (1 + 0.18 * math.sin(3 * a + k)) * math.cos(a), cy + r * (1 + 0.18 * math.cos(2 * a + k)) * math.sin(a))
                 for a in [j * math.pi / 40 for j in range(80)]]
        d.polygon(punti, fill=BANDIERE[k % 4] + (150,))
    # coriandoli
    for _ in range(n * 14):
        x, y = caso.uniform(0, W), caso.uniform(650, ALTO)
        r = caso.uniform(10, 22)
        d.ellipse((x - r, y - r, x + r, y + r), fill=caso.choice(BANDIERE + [ORO]) + (170,))
    img = Image.alpha_composite(img, strato.filter(ImageFilter.GaussianBlur(2)))
    festoni(img, 610, 900, 150, 0)
    festoni(img, ALTO - 570, 1100, 200, 450)
    return img


def festoni(img: Image.Image, y: int, campata: int, flessione: int, scarto: int):
    """Un filo di bandierine triangolari bianche, gialle e blu che attraversa tutto il panorama:
    pende tra un punto d'attacco e l'altro (ogni `campata` pixel) e ha una bandierina ogni 64 pixel."""
    W = img.width
    filo = lambda x: y + flessione * math.sin(math.pi * ((x + scarto) % campata) / campata)
    colori = [(255, 255, 255), ORO, (30, 80, 170)]
    ombre = Image.new('RGBA', img.size, (0, 0, 0, 0))
    bandiere = Image.new('RGBA', img.size, (0, 0, 0, 0))
    do, db = ImageDraw.Draw(ombre), ImageDraw.Draw(bandiere)
    db.line([(x, filo(x)) for x in range(-20, W + 20, 6)], fill=BLU + (150,), width=4)
    for i, x in enumerate(range(-40, W + 40, 64)):
        a, b = (x - 24, filo(x - 24)), (x + 24, filo(x + 24))
        # la punta scende perpendicolare al filo
        dx, dy = b[0] - a[0], b[1] - a[1]
        lung = math.hypot(dx, dy)
        punta = ((a[0] + b[0]) / 2 - dy / lung * 70, (a[1] + b[1]) / 2 + dx / lung * 70)
        colore = colori[i % 3]
        do.polygon([(p[0] + 6, p[1] + 8) for p in (a, b, punta)], fill=BLU + (45,))
        db.polygon([a, b, punta], fill=colore + (255,), outline=(205, 212, 226, 255) if colore == colori[0] else None)
    img.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(5)))
    img.alpha_composite(bandiere)


def titolo(img: Image.Image, testo: str, x0: int):
    font = ImageFont.truetype(str(FONT), 104)
    d = ImageDraw.Draw(img)
    y = 230
    for riga in testo.split('\n'):
        larg = d.textlength(riga, font=font)
        d.text((x0 + (LARGO - larg) / 2, y), riga, font=font, fill=BLU)
        y += 124
    # sottolineatura oro sotto il titolo
    d.rounded_rectangle((x0 + LARGO / 2 - 70, y + 24, x0 + LARGO / 2 + 70, y + 40), radius=8, fill=ORO)


def main(entrata: Path, uscita: Path):
    uscita.mkdir(parents=True, exist_ok=True)
    pagine = [p for p in PAGINE if (entrata / f'{p[0]}.png').exists()]
    pano = sfondo(len(pagine))
    for i, (nome, _, angolo, dx) in enumerate(pagine):
        tel = telefono(Image.open(entrata / f'{nome}.png'), 830).rotate(angolo, resample=Image.BICUBIC, expand=True)
        # ombra morbida sotto il telefono
        ombra = Image.new('RGBA', tel.size, (0, 0, 0, 0))
        ombra.paste((6, 34, 70, 70), (0, 0), tel.split()[3])
        ombra = ombra.filter(ImageFilter.GaussianBlur(28))
        cx = i * LARGO + LARGO // 2 + dx
        x, y = cx - tel.width // 2, 760
        pano.paste(ombra, (x + 18, y + 30), ombra)  # paste (non alpha_composite) accetta anche posizioni negative
        pano.paste(tel, (x, y), tel)
    for i, (nome, testo, _, _) in enumerate(pagine):
        titolo(pano, testo, i * LARGO)
    for i, (nome, *_rest) in enumerate(pagine):
        pagina = pano.crop((i * LARGO, 0, (i + 1) * LARGO, ALTO)).convert('RGB')
        if finale:
            pagina = pagina.resize(finale, Image.LANCZOS)
        pagina.save(uscita / f'{i + 1:02d}-{nome}.png', optimize=True)
        print('fatta', uscita / f'{i + 1:02d}-{nome}.png')


if __name__ == '__main__':
    finale = None
    if '--android' in sys.argv:
        ALTO, finale = 2412, (1080, 2160)
    main(Path(sys.argv[1]), Path(sys.argv[2]))
