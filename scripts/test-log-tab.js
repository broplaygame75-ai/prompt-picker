#!/usr/bin/env node
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const html = fs.readFileSync(path.join(__dirname, '../src/index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
const stub = () => ({onclick: null, value: '', textContent: '', innerHTML: '', style: {}, dataset: {}, classList: {add() {}, remove() {}, toggle() {}, contains() { return false; }}, addEventListener() {}, setAttribute() {}, focus() {}, appendChild() {}, querySelector: stub, querySelectorAll: () => [], options: []});
const document = {documentElement: {lang: '', style: {setProperty() {}}}, body: {classList: {add() {}, toggle() {}, contains() { return false; }}}, querySelector: stub, querySelectorAll: () => [], addEventListener() {}, createElement: stub};
const api = {version: async () => '0.0.0', load: async () => null, save: async () => true, dirGet: async () => '', onUpd() {}, onState() {}, onThemePreview() {}, onSettingsTab() {}, setFontScale() {}, pushState() {}, releases: async () => [], updCheck: async () => false, updDownload: async () => false, quit: async () => true, openSettings: async () => true};
const ctx = {document, location: {search: ''}, navigator: {}, api, URLSearchParams, setTimeout, clearTimeout, console, Map, Set, Date, Math, JSON, Promise};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(script + '\nthis.__api={logCharHit,logEntryHit,labelLike,promptHasLabel,planLogClear,applyLogClear,createLogHistory,compareLogCharacters,normCharacters,newCharacter,touchCharacter,logSortMode,logRowSortMode,visibleEntries,doneRows,charRowSpan,charRowHit,characterFromJson,characterLogFromJson,parseLogLines,formatLogLines,exportLogDoc,planLogImport,applyLogImport,manualUpdateUrl,shouldAutoPrompt,rememberUpdLater,uiKeep,restoreUi,fresh};this.__setS=function(v){S=v};this.__getS=function(){return S};this.__setPrompted=function(v){updPrompted=v};', ctx);
const A = ctx.__api;

function fail(msg) { throw new Error(msg); }

const adrian = {id: 'c1', label: 'Adrian - How to Survive as a Maid in a Horror Game', createdAt: 1000, updatedAt: 5000};
const ahn = {id: 'c2', label: 'Ahn Jiwon - BJ Alex', createdAt: 3000, updatedAt: 3000};
if (!A.logCharHit(adrian, '')) fail('empty char');
if (!A.logCharHit(adrian, 'adrian')) fail('name');
if (!A.logCharHit(adrian, 'horror game')) fail('source');
if (A.logCharHit(adrian, 'turning')) fail('char prompt text');
if (A.logCharHit(ahn, 'adrian')) fail('other char');
if (!A.logCharHit(ahn, 'bj alex')) fail('source 2');

const bunny = {id: 'p1', row: 245, name: 'Bunny get Drunk', tags: ['New'], prompt: 'fake animal ears, turning head, blush', notes: ['secret note']};
const other = {id: 'p2', row: 12, name: 'Quiet', tags: ['old'], prompt: 'standing, smile', notes: []};
if (!A.logEntryHit(bunny, '')) fail('empty entry');
if (!A.logEntryHit(bunny, 'bunny')) fail('prompt name');
if (!A.logEntryHit(bunny, 'new')) fail('label');
if (!A.logEntryHit(bunny, 'turning')) fail('prompt tag');
if (!A.logEntryHit(bunny, '245') || !A.logEntryHit(bunny, '#245')) fail('row');
if (A.logEntryHit(bunny, 'secret')) fail('notes should not match');
if (A.logEntryHit(bunny, 'blush only')) fail('non tag');
if (A.logEntryHit(other, 'turning')) fail('other prompt');
if (!A.labelLike('New', 'new')) fail('exact label');
if (!A.labelLike('New Year', '%new%')) fail('wild');
if (A.labelLike('Old', '%new%')) fail('wild miss');
if (A.labelLike('New Year', 'new')) fail('exact is not contains');
if (!A.promptHasLabel(bunny, '') || !A.promptHasLabel(bunny, '%new%') || A.promptHasLabel(bunny, 'old')) fail('prompt label');

const state = {
  prompts: [bunny, other],
  characters: [Object.assign({}, adrian), Object.assign({}, ahn)],
  used: [
    {promptId: 'p1', characterId: 'c1', at: 10, row: 245},
    {promptId: 'p2', characterId: 'c1', at: 11, row: 12},
    {promptId: 'p2', characterId: 'c2', at: 12, row: 12}
  ]
};
const all = A.planLogClear(state, ['c1', 'c2'], '');
if (all.hits.length !== 3 || all.chars.length !== 2) fail('clear all ' + JSON.stringify(all));
const one = A.planLogClear(state, ['c1'], '%new%');
if (one.hits.length !== 1 || one.hits[0].promptId !== 'p1' || one.chars.length !== 1) fail('clear label');
const none = A.planLogClear(state, ['c2'], 'new');
if (none.hits.length) fail('no label');

const hist = A.createLogHistory();
const beforeUpdated = state.characters[0].updatedAt;
const entry = A.applyLogClear(state, one.hits, 9000);
if (state.used.some(u => u.promptId === 'p1')) fail('row removed');
if (state.used.length !== 2) fail('other rows stay');
if (state.characters[0].updatedAt !== 9000 || state.characters[1].updatedAt !== 3000) fail('dates ' + state.characters.map(c => c.updatedAt).join(','));
hist.note(entry);
if (!hist.undo(state)) fail('undo');
if (!state.used.some(u => u.promptId === 'p1' && u.characterId === 'c1')) fail('row restored');
if (state.characters[0].updatedAt !== beforeUpdated) fail('date restored ' + state.characters[0].updatedAt);
if (!hist.redo(state)) fail('redo');
if (state.used.some(u => u.promptId === 'p1')) fail('redo removed');
if (state.characters[0].updatedAt !== 9000) fail('redo date');

const sorted = [ahn, adrian].slice().sort((a, b) => A.compareLogCharacters(a, b, 'name-asc')).map(c => c.id);
if (sorted.join() !== 'c1,c2') fail('name asc ' + sorted);
const newest = [ahn, adrian].slice().sort((a, b) => A.compareLogCharacters(a, b, 'added-newest')).map(c => c.id);
if (newest.join() !== 'c2,c1') fail('added ' + newest);
const mod = [ahn, adrian].slice().sort((a, b) => A.compareLogCharacters(a, b, 'modified-newest')).map(c => c.id);
if (mod.join() !== 'c1,c2') fail('modified ' + mod);

const blank = A.fresh();
blank.characters = [{id: 'c9', label: 'Boothill - HSR'}];
blank.used = [];
ctx.__setS(blank);
const filled = A.normCharacters();
if (!filled) fail('backfill');
const kept = ctx.__getS().characters[0];
if (!kept.createdAt || kept.updatedAt !== kept.createdAt || kept.label !== 'Boothill - HSR') fail('stamped ' + JSON.stringify(kept));
const again = A.normCharacters();
if (again) fail('second norm should keep dates');
if (ctx.__getS().characters[0].createdAt !== kept.createdAt) fail('date changed');

ctx.__getS().logSort = 'modified-oldest';
const keep = A.uiKeep();
ctx.__setS(A.fresh());
A.restoreUi(keep, false);
if (ctx.__getS().logSort !== 'modified-oldest') fail('sort remembered');
if (A.fresh().logSort != null) fail('fresh has sort');
ctx.__getS().logSort = 'nope';
if (A.logSortMode() !== 'name-asc') fail('default sort');

const orderState = {
  prompts: [
    {id: 'p70', row: 70, name: 'Later', tags: [], prompt: 'a'},
    {id: 'p63', row: 63, name: 'Early', tags: [], prompt: 'b'},
    {id: 'p64', row: 64, name: 'Mid', tags: [], prompt: 'c'}
  ],
  characters: [{id: 'c1', label: 'Boothill - HSR', createdAt: 1, updatedAt: 1}],
  used: [
    {promptId: 'p70', characterId: 'c1', at: 1, row: 70},
    {promptId: 'p63', characterId: 'c1', at: 2, row: 63},
    {promptId: 'p64', characterId: 'c1', at: 3, row: 64}
  ],
  activeCharacter: 'c1',
  logRowSort: 'pick-oldest'
};
ctx.__setS(orderState);
if (A.doneRows('c1').join() !== '70,63,64') fail('logged order ' + A.doneRows('c1'));
if (!A.formatLogLines().includes('[70, 63, 64]')) fail('copy order ' + A.formatLogLines());
const exported = A.exportLogDoc().characters[0].entries.map(e => e.row).join();
if (exported !== '70,63,64') fail('export order ' + exported);
if (A.visibleEntries(orderState.characters[0], '').map(x => x.p.row).join() !== '70,63,64') fail('pick oldest');
ctx.__getS().logRowSort = 'pick-newest';
if (A.visibleEntries(orderState.characters[0], '').map(x => x.p.row).join() !== '64,63,70') fail('pick newest');
ctx.__getS().logRowSort = 'row-asc';
if (A.visibleEntries(orderState.characters[0], '').map(x => x.p.row).join() !== '63,64,70') fail('row asc');
ctx.__getS().logRowSort = 'row-desc';
if (A.visibleEntries(orderState.characters[0], '').map(x => x.p.row).join() !== '70,64,63') fail('row desc');
const fromFile = A.characterFromJson({name: 'Boothill', source: 'HSR', doneRows: [70, 63, 64]});
if (!fromFile || fromFile.doneRows.join() !== '70,63,64') fail('import keeps order');
const parsed = A.parseLogLines('[Boothill][HSR][70, 63, 64]');
if (parsed.length !== 1 || parsed[0].rows.join() !== '70,63,64') fail('paste order ' + JSON.stringify(parsed));
const logged = A.characterLogFromJson({name: 'Boothill', source: 'HSR', entries: [{row: 70}, {row: 63}, {row: 64}]});
if (!logged || logged.entries.map(e => e.row).join() !== '70,63,64') fail('log json order');

const clearOrder = {
  prompts: orderState.prompts,
  characters: [{id: 'c1', label: 'Boothill - HSR', createdAt: 1, updatedAt: 1}],
  used: orderState.used.map(u => Object.assign({}, u))
};
const mid = A.applyLogClear(clearOrder, [clearOrder.used[1]], 50);
if (clearOrder.used.map(u => u.row).join() !== '70,64') fail('cleared middle');
const hist2 = A.createLogHistory();
hist2.note(mid);
if (!hist2.undo(clearOrder)) fail('undo order');
if (clearOrder.used.map(u => u.row).join() !== '70,63,64') fail('restored order ' + clearOrder.used.map(u => u.row));
if (clearOrder.used.some(u => u._i != null)) fail('index leaked');

if (A.charRowSpan('') !== null || A.charRowSpan('   ') !== null) fail('empty span');
const single = A.charRowSpan('#63');
if (!single || single.a !== 63 || single.b !== 63) fail('single row');
const range = A.charRowSpan('64–63');
if (!range || range.a !== 63 || range.b !== 64) fail('range ' + JSON.stringify(range));
if (!A.charRowSpan('abc').none || !A.charRowSpan('63-').none || !A.charRowSpan('63-64-65').none) fail('bad span');
if (!A.charRowHit([12], '') || A.charRowHit([12], '1') || !A.charRowHit([63, 80], '63-64') || A.charRowHit([12], '63-64') || A.charRowHit([63], 'abc')) fail('row hit');
const booth = {id: 'c1', label: 'Boothill - HSR'};
if (!(A.logCharHit(booth, 'hsr') && A.charRowHit([63, 80], '63-64'))) fail('and match');
if (A.logCharHit(booth, 'hsr') && A.charRowHit([12], '63-64')) fail('and row miss');
if (A.logCharHit(booth, 'nope') && A.charRowHit([63], '')) fail('and name miss');

ctx.__setS(A.fresh());
ctx.__getS().logRowSort = 'row-desc';
ctx.__getS().updLater = '0.1.11';
const keep2 = A.uiKeep();
ctx.__setS(A.fresh());
A.restoreUi(keep2, false);
if (ctx.__getS().logRowSort !== 'row-desc' || ctx.__getS().updLater !== '0.1.11') fail('ui keep ' + ctx.__getS().logRowSort + ' ' + ctx.__getS().updLater);
if (A.fresh().logRowSort != null || A.fresh().updLater != null) fail('fresh prefs');
ctx.__setS(A.fresh());
if (!A.shouldAutoPrompt('0.1.11')) fail('auto before later');
A.rememberUpdLater('v0.1.11');
if (A.shouldAutoPrompt('0.1.11') || !A.shouldAutoPrompt('0.1.12')) fail('later version');
ctx.__setPrompted('0.1.12');
if (A.shouldAutoPrompt('0.1.12')) fail('once per version');
if (A.manualUpdateUrl('0.1.11') !== 'https://github.com/broplaygame75-ai/prompt-picker-releases/releases/download/v0.1.11/PromptPicker-Setup-0.1.11.exe') fail('manual url');
if (A.manualUpdateUrl('nope') !== 'https://github.com/broplaygame75-ai/prompt-picker-releases/releases') fail('manual fallback');

console.log('log tab ok');
