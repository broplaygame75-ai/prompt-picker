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
vm.runInContext(script + '\nthis.__api={logCharHit,logEntryHit,labelLike,promptHasLabel,planLogClear,applyLogClear,createLogHistory,compareLogCharacters,normCharacters,newCharacter,touchCharacter,logSortMode,uiKeep,restoreUi,fresh};this.__setS=function(v){S=v};this.__getS=function(){return S};', ctx);
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

console.log('log tab ok');
