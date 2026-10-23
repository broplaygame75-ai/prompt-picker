#!/usr/bin/env node
const fs = require('fs');
const vm = require('vm');
const html = fs.readFileSync(require('path').join(__dirname, '../src/index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
const stub = () => ({onclick: null, value: '', textContent: '', innerHTML: '', style: {}, dataset: {}, classList: {add() {}, remove() {}, toggle() {}, contains() { return false; }}, addEventListener() {}, setAttribute() {}, focus() {}, appendChild() {}, querySelector: stub, querySelectorAll: () => []});
const document = {documentElement: {lang: '', style: {setProperty() {}}}, body: {classList: {add() {}, toggle() {}, contains() { return false; }}}, querySelector: stub, querySelectorAll: () => [], addEventListener() {}, createElement: stub};
const api = {version: async () => '0.0.0', load: async () => null, save: async () => true, dirGet: async () => '', onUpd() {}, onState() {}, onThemePreview() {}, onSettingsTab() {}, setFontScale() {}, pushState() {}, releases: async () => [], updCheck: async () => false, updDownload: async () => false, quit: async () => true, openSettings: async () => true};
const ctx = {document, location: {search: ''}, navigator: {}, api, URLSearchParams, setTimeout, clearTimeout, console, Map, Set, Date, Math, JSON, Promise};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(script + '\nthis.I18N=I18N;', ctx);
const I = ctx.I18N;
const langs = ['en', 'vi', 'zh', 'ko'];
const sets = langs.map(l => Object.keys(I[l]).sort().join('\n'));
if (sets.some(s => s !== sets[0])) throw new Error('i18n key mismatch');
const diac = /[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ]/;
for (const l of ['en', 'zh', 'ko']) {
  for (const [k, v] of Object.entries(I[l])) {
    const s = typeof v === 'function' ? v('x', 1, 2, 3, 4) : String(v);
    if (diac.test(s) && !s.includes('(không tên)')) throw new Error('diacritic in ' + l + ' ' + k);
  }
}
if (I.en.helpKw !== 'Optional. Type a word (e.g. bath) to pick only prompts containing it, or a row number (e.g. 298) to get exactly that prompt.') throw new Error('helpKw en');
if (I.vi.helpKw !== 'Tuỳ chọn. Gõ từ (vd: bath) để chỉ bốc trong prompt có từ đó, hoặc gõ số hàng (vd: 298) để lấy đúng prompt đó.') throw new Error('helpKw vi');
const re = /data-i="([^"]+)"[^>]*>([^<]*)</g;
let m;
while ((m = re.exec(html))) {
  const inner = m[2].replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"');
  if (I.en[m[1]] !== inner) throw new Error('fallback ' + m[1]);
}
console.log('i18n ok', Object.keys(I.en).length);
