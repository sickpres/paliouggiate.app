// Disegna assets/mappa_tesoro.webp, lo sfondo della mappa del «Tesoro del Palio», nello stile di assets/mappa_rioni.webp:
// prati, isolati di case, strade bianche, boschi e il lago. Le tappe e il sentiero li disegna l'app sopra.
// Numeri casuali con seme fisso: rilanciandolo esce sempre la stessa mappa.
//
//   node scripts/mappa-tesoro.js   (serve sharp: lo prende da ../paliouggiate/server/node_modules)
const path = require('path');
const sharp = require(path.join(__dirname, '../../paliouggiate/server/node_modules/sharp'));

const W = 1080, H = 1600;
let seme = 20271;
const caso = () => ((seme = (seme * 16807) % 2147483647) - 1) / 2147483646;
const tra = (a, b) => a + caso() * (b - a);

// strade principali (spezzate morbide) e secondarie
const strade = [
  [[-40, 1250], [260, 1150], [520, 1120], [760, 980], [1120, 900]],
  [[300, 1650], [330, 1300], [420, 1000], [520, 760], [560, 420], [620, -40]],
  [[-40, 560], [240, 600], [560, 640], [820, 560], [1120, 620]],
  [[760, 1650], [700, 1300], [760, 980]],
  [[120, -40], [180, 300], [240, 600], [200, 900], [260, 1150]]
];
const secondarie = [
  [[520, 1120], [600, 1400], [580, 1650]], [[420, 1000], [160, 980], [-40, 1000]], [[820, 560], [880, 420]],
  [[560, 420], [380, 360], [180, 300]], [[760, 980], [900, 1200], [1120, 1260]], [[240, 600], [320, 800], [420, 1000]]
];
const linea = (p) => 'M' + p.map(([x, y]) => `${x} ${y}`).join(' L');

// isolati di case: piccoli rettangoli ruotati lungo le strade, fuori dal lago e dai boschi
const fuori = (x, y) => !(x > 640 && y < 420) && !(x < 200 && y > 1320) && !(x > 820 && y > 1300);
function case_() {
  let s = '';
  for (const st of [...strade, ...secondarie]) {
    for (let i = 1; i < st.length; i++) {
      const [x0, y0] = st[i - 1], [x1, y1] = st[i];
      const ang = (Math.atan2(y1 - y0, x1 - x0) * 180) / Math.PI;
      const n = Math.floor(Math.hypot(x1 - x0, y1 - y0) / 46);
      for (let k = 0; k < n; k++) {
        for (const lato of [-1, 1]) {
          if (caso() < 0.35) continue;
          const t = (k + 0.5) / n;
          const nx = -(y1 - y0), ny = x1 - x0, l = Math.hypot(nx, ny);
          const d = lato * tra(34, 60);
          const x = x0 + (x1 - x0) * t + (nx / l) * d, y = y0 + (y1 - y0) * t + (ny / l) * d;
          if (!fuori(x, y)) continue;
          const w = tra(20, 34), h = tra(16, 26);
          s += `<rect x="${(x - w / 2).toFixed(1)}" y="${(y - h / 2).toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}" rx="3" transform="rotate(${ang.toFixed(1)} ${x.toFixed(1)} ${y.toFixed(1)})"/>`;
        }
      }
    }
  }
  return s;
}
// alberi: cerchi verdi a gruppi
function bosco(cx, cy, r, n) {
  let s = '';
  for (let i = 0; i < n; i++) {
    const a = tra(0, Math.PI * 2), d = Math.sqrt(caso()) * r;
    const x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d, rr = tra(14, 24);
    s += `<circle cx="${x.toFixed(1)}" cy="${(y + 4).toFixed(1)}" r="${rr.toFixed(1)}" fill="#7fae5c" opacity="0.5"/><circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${rr.toFixed(1)}" fill="#8fc46a"/>`;
  }
  return s;
}
// prati chiari sparsi
function prati() {
  let s = '';
  for (let i = 0; i < 26; i++) {
    const x = tra(0, W), y = tra(0, H), w = tra(90, 200), h = tra(60, 140);
    s += `<rect x="${x.toFixed(0)}" y="${y.toFixed(0)}" width="${w.toFixed(0)}" height="${h.toFixed(0)}" rx="18" fill="${caso() < 0.5 ? '#d9e8bf' : '#e6efcf'}" transform="rotate(${tra(-20, 20).toFixed(0)} ${x.toFixed(0)} ${y.toFixed(0)})"/>`;
  }
  return s;
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="${W}" height="${H}" fill="#eef2e1"/>
  ${prati()}
  <!-- il lago in alto a destra, con il riflesso -->
  <path d="M700 -20 C 690 120 760 230 860 300 C 960 370 1060 380 1100 360 L 1100 -20 Z" fill="#a9d8ef"/>
  <path d="M700 -20 C 690 120 760 230 860 300 C 960 370 1060 380 1100 360" fill="none" stroke="#86c3e3" stroke-width="10"/>
  <path d="M800 60 q 40 -12 80 0 M860 140 q 40 -12 80 0 M940 230 q 30 -10 60 0" stroke="#ffffff" stroke-opacity="0.7" stroke-width="6" fill="none" stroke-linecap="round"/>
  <!-- il torrente che scende verso il lago -->
  <path d="M-20 820 C 120 760 160 640 300 600 S 560 520 700 360 S 790 300 830 280" fill="none" stroke="#a9d8ef" stroke-width="16" stroke-linecap="round"/>
  <!-- boschi -->
  ${bosco(110, 1450, 120, 26)}${bosco(950, 1450, 120, 24)}${bosco(980, 760, 70, 12)}${bosco(70, 420, 80, 14)}
  <!-- strade: bordo grigio e corsia bianca, come nella mappa dei rioni -->
  <g fill="none" stroke-linecap="round" stroke-linejoin="round">
    ${secondarie.map((p) => `<path d="${linea(p)}" stroke="#d3d6cf" stroke-width="22"/>`).join('')}
    ${strade.map((p) => `<path d="${linea(p)}" stroke="#d3d6cf" stroke-width="34"/>`).join('')}
    ${secondarie.map((p) => `<path d="${linea(p)}" stroke="#ffffff" stroke-width="14"/>`).join('')}
    ${strade.map((p) => `<path d="${linea(p)}" stroke="#ffffff" stroke-width="24"/>`).join('')}
  </g>
  <g fill="#d9d6cf" stroke="#c2beb4" stroke-width="2">${case_()}</g>
  <!-- rosa dei venti in basso a destra -->
  <g transform="translate(960 1160)" opacity="0.85">
    <circle r="62" fill="#fff8e6" stroke="#9a6500" stroke-width="4"/>
    <path d="M0 -54 L12 0 L0 54 L-12 0 Z" fill="#9a6500"/><path d="M-54 0 L0 -12 L54 0 L0 12 Z" fill="#c9a227"/>
    <text y="-66" text-anchor="middle" font-family="DejaVu Serif" font-weight="bold" font-size="30" fill="#6b4219">N</text>
  </g>
</svg>`;

sharp(Buffer.from(svg)).webp({ quality: 82 }).toFile(path.join(__dirname, '../assets/mappa_tesoro.webp'))
  .then((i) => console.log('assets/mappa_tesoro.webp', i.width + 'x' + i.height, Math.round(i.size / 1024) + ' KB'));
