#!/usr/bin/env node
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const html = fs.readFileSync(path.join(__dirname, '../src/index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
const stub = () => ({onclick: null, value: '', textContent: '', innerHTML: '', style: {}, dataset: {}, classList: {add() {}, remove() {}, toggle() {}, contains() { return false; }}, addEventListener() {}, setAttribute() {}, focus() {}, appendChild() {}, querySelector: stub, querySelectorAll: () => []});
const document = {documentElement: {lang: '', style: {setProperty() {}}}, body: {classList: {add() {}, toggle() {}, contains() { return false; }}}, querySelector: stub, querySelectorAll: () => [], addEventListener() {}, createElement: stub};
const api = {version: async () => '0.0.0', load: async () => null, save: async () => true, dirGet: async () => '', onUpd() {}, onState() {}, onThemePreview() {}, onSettingsTab() {}, setFontScale() {}, pushState() {}, releases: async () => [], updCheck: async () => false, updDownload: async () => false, quit: async () => true, openSettings: async () => true};
const ctx = {document, location: {search: ''}, navigator: {}, api, URLSearchParams, setTimeout, clearTimeout, console, Map, Set, Date, Math, JSON, Promise};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(script + '\nthis.__defaults=defaultShortcuts();\nthis.__order=SHORTCUT_ORDER.slice();\nthis.__same=sameShortcut;\nthis.__api={createPickHistory:createPickHistory,pickSlice:pickSlice};', ctx);

const hist = ctx.__order;
const defaults = ctx.__defaults;
if (hist.join(',') !== 'pick,undo,redo,copy,zoomIn,zoomOut,zoomReset') throw new Error('shortcut order ' + hist.join(','));
const want = {undo: {key: 'z', ctrl: true, alt: false, shift: false}, redo: {key: 'y', ctrl: true, alt: false, shift: false}};
for (const id of Object.keys(want)) {
  const got = defaults[id];
  if (!got || got.key !== want[id].key || got.ctrl !== true || got.alt || got.shift) throw new Error('default ' + id);
}
const ids = Object.keys(defaults);
for (let i = 0; i < ids.length; i++) {
  for (let j = i + 1; j < ids.length; j++) {
    if (ctx.__same(defaults[ids[i]], defaults[ids[j]])) throw new Error('clash ' + ids[i] + ' ' + ids[j]);
  }
}

function state() {
  return {
    cur: [null],
    used: [],
    characters: [],
    pickCounter: 0,
    prompts: [{id: 'p1', uses: 0, lastUsed: 0, lastPick: 0}, {id: 'p2', uses: 1, lastUsed: 5, lastPick: 1}]
  };
}
const {createPickHistory, pickSlice} = ctx.__api;
const h = createPickHistory();
const s = state();
if (h.canUndo() || h.canRedo()) throw new Error('empty history');
const before = pickSlice(s, 0);
s.cur[0] = 'p1';
s.used.push({promptId: 'p1', characterId: 'c1', at: 10, row: 1});
s.characters.push({id: 'c1', label: 'Boothill - HSR'});
s.pickCounter = 3;
s.prompts[0].uses = 2;
s.prompts[0].lastUsed = 20;
s.prompts[0].lastPick = 3;
if (!h.note(s, 0, before)) throw new Error('note');
if (!h.canUndo() || h.canRedo()) throw new Error('after pick');
s.used.push({promptId: 'p9', characterId: 'c9', at: 11, row: 9});
if (!h.undo(s)) throw new Error('undo');
if (s.cur[0] !== null) throw new Error('cur restored');
if (s.used.length !== 1 || s.used[0].promptId !== 'p9') throw new Error('log delta ' + JSON.stringify(s.used));
if (s.characters.length) throw new Error('character removed');
if (s.pickCounter !== 0 || s.prompts[0].uses !== 0 || s.prompts[0].lastPick !== 0) throw new Error('counters');
if (!h.canRedo()) throw new Error('redo armed');
if (!h.redo(s)) throw new Error('redo');
if (s.cur[0] !== 'p1') throw new Error('redo cur');
if (!s.used.some(u => u.promptId === 'p1') || !s.used.some(u => u.promptId === 'p9')) throw new Error('redo log');
if (!s.characters.some(c => c.id === 'c1')) throw new Error('redo character');
if (s.prompts[0].uses !== 2 || s.pickCounter !== 3) throw new Error('redo counters');
const again = pickSlice(s, 0);
s.cur[0] = 'p2';
if (!h.note(s, 0, again)) throw new Error('second pick');
if (h.canRedo()) throw new Error('new pick clears redo');
if (h.note(s, 0, pickSlice(s, 0))) throw new Error('noop noted');
console.log('pick history ok');
