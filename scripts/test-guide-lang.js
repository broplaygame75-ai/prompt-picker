#!/usr/bin/env node
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const html = fs.readFileSync(path.join(__dirname, '../src/index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
const stub = () => ({onclick: null, value: '', textContent: '', innerHTML: '', style: {}, dataset: {}, classList: {add() {}, remove() {}, toggle() {}, contains() { return false; }}, addEventListener() {}, setAttribute() {}, focus() {}, appendChild() {}, querySelector: stub, querySelectorAll: () => []});
const document = {documentElement: {lang: '', style: {setProperty() {}}}, body: {classList: {add() {}, toggle() {}, contains() { return false; }}}, querySelector: stub, querySelectorAll: () => [], addEventListener() {}, createElement: stub};
const api = {version: async () => '0.0.0', load: async () => null, save: async () => true, dirGet: async () => '', onUpd() {}, onState() {}, onThemePreview() {}, onSettingsTab() {}, setFontScale() {}, pushState() {}, releases: async () => [], updCheck: async () => false, updDownload: async () => false, quit: async () => true, openSettings: async () => true};
const ctx = {document, location: {search: ''}, navigator: {}, api, URLSearchParams, setTimeout, clearTimeout, console, Map, Set, Date, Math, JSON, Promise, Node: {DOCUMENT_POSITION_FOLLOWING: 4}};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(script + '\nthis.__api={mdHtml:mdHtml,releaseBody:releaseBody,hintsOn:hintsOn,setS:function(v){S=v}};', ctx);
const {mdHtml, releaseBody, hintsOn, setS} = ctx.__api;

const sample = [
  '## Update',
  '',
  '- Keep this note.',
  '',
  '# How to install 0.1.9',
  '',
  '![Download](en/01-download.png)',
  '',
  '# Cách cài 0.1.9',
  '',
  '![Tải về](https://github.com/broplaygame75-ai/prompt-picker-releases/raw/main/guide/vi/01-download.png)',
  '',
  '# 如何安装 0.1.9',
  '',
  '![下载](zh/01-download.png)',
  '',
  '# Prompt Picker 0.1.9 설치 방법',
  '',
  '![다운로드](ko/01-download.png)',
  ''
].join('\n');

setS({lang: 'en', prompts: []});
if (hintsOn()) throw new Error('hints should be off by default');
const en = mdHtml(sample);
if (/Cách cài|Tải về|如何安装|설치 방법/.test(en)) throw new Error('other language leaked into en: ' + en);
if (!en.includes('How to install')) throw new Error('missing en guide');
if (!en.includes('<img alt="Download" src="../install-guide/en/01-download.png">')) throw new Error('en image: ' + en);
if (en.includes('!Download') || en.includes('![')) throw new Error('bang image: ' + en);

setS({lang: 'vi', prompts: []});
const vi = mdHtml(sample);
if (!vi.includes('<img alt="Tải về" src="../install-guide/vi/01-download.png">')) throw new Error('vi image: ' + vi);
if (/How to install|如何安装|설치 방법/.test(vi)) throw new Error('other guide leaked into vi: ' + vi);
if (vi.includes('!Tải')) throw new Error('broken vi link');

setS({lang: 'zh', prompts: [], showHints: true});
if (!hintsOn()) throw new Error('showHints true');
const zh = mdHtml(sample);
if (!zh.includes('../install-guide/zh/01-download.png')) throw new Error('zh image');
if (/How to install|Cách cài|설치/.test(zh)) throw new Error('zh leak ' + zh);

setS({lang: 'ko', prompts: [], hintsOff: false});
if (!hintsOn()) throw new Error('legacy hintsOff false should show hints');
const ko = mdHtml(sample);
if (!ko.includes('../install-guide/ko/01-download.png')) throw new Error('ko image');

const marked = 'Changelog line.\n\n<!-- lang:en -->\n# How to install\n\n![Download](en/01-download.png)\n<!-- /lang:en -->\n\n<!-- lang:vi -->\n# Cách cài\n\n![Tải về](vi/01-download.png)\n<!-- /lang:vi -->\n';
setS({lang: 'en', prompts: [], showHints: false});
const markedEn = releaseBody(marked);
if (markedEn.includes('Cách') || markedEn.includes('Tải')) throw new Error('marked vi leaked');
if (!markedEn.includes('Changelog line')) throw new Error('changelog dropped');
if (!markedEn.includes('How to install')) throw new Error('marked en missing');
if (hintsOn()) throw new Error('showHints false');

console.log('guide lang ok');
