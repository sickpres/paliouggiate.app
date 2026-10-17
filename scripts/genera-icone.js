'use strict';
// Genera lib/widgets/icone_tratto_dati.dart: le icone a tratto 24 x 24 dei giochi, le stesse del portale
// (server/icone.js del repository paliouggiate), e quelle dei menu da Lucide (il pacchetto del pannello).
//
//   node scripts/genera-icone.js <cartella del portale> lib/widgets/icone_tratto_dati.dart
const fs = require('fs');
const path = require('path');

const [portale, uscita] = process.argv.slice(2);
const giochi = require(path.join(portale, 'server', 'icone.js'));
const dirLucide = path.join(portale, 'admin', 'node_modules', 'lucide-react', 'dist', 'esm', 'icons');
const versione = require(path.join(portale, 'admin', 'node_modules', 'lucide-react', 'package.json')).version;

// nome nell'app -> icona Lucide
const LUCIDE = {
  home: 'house', calendario_menu: 'calendar-days', classifica_menu: 'trophy', giochi_menu: 'dices', social_menu: 'share-2',
  info: 'info', classifica_gioco: 'list-ordered', regolamento_gioco: 'scroll-text', criteri: 'list-checks', punteggio: 'medal',
  vista_elenco: 'list', vista_mese: 'calendar-days', freccia_sinistra: 'chevron-left', freccia_destra: 'chevron-right'
};

const attributi = (o) => Object.entries(o).filter(([k]) => k !== 'key').map(([k, v]) => `${k}="${v}"`).join(' ');
const tracce = {};
for (const [nome, file] of Object.entries(LUCIDE)) {
  const src = fs.readFileSync(path.join(dirLucide, file + '.js'), 'utf8');
  const m = /const __iconNode = (\[[\s\S]*?\]);\s*const /.exec(src);
  if (!m) throw new Error('icona non letta: ' + file);
  const nodi = new Function('return ' + m[1])();
  tracce[nome] = nodi.map(([tag, a]) => `<${tag} ${attributi(a)}/>`).join('');
}
for (const [tipo, svg] of Object.entries(giochi)) tracce['gioco_' + tipo] = svg.replace(/\s+/g, ' ').trim();

const BS = String.fromCharCode(92);
const dart = (s) => "'" + s.split(BS).join(BS + BS).split("'").join(BS + "'") + "'";
const righe = Object.entries(tracce).map(([k, v]) => `  '${k}': ${dart(v)},`);
fs.writeFileSync(uscita, `// File generato da scripts/genera-icone.js: non modificarlo a mano.
// Icone a tratto 24 x 24: quelle dei giochi sono le stesse del portale (server/icone.js del repository
// paliouggiate), le altre vengono da Lucide ${versione} (https://lucide.dev, licenza ISC).

const tracceIcone = <String, String>{
${righe.join('\n')}
};
`);
console.log(Object.keys(tracce).length, 'icone ->', uscita);
