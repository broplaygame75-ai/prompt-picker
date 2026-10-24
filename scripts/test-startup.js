#!/usr/bin/env node
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const {planShortcutRepair, shortcutLocations, samePath} = require('../src/shortcuts');
const {COPY} = require('../src/startupCopy');
const {installerUrl, installerName, versionFromRelease} = require('../src/repair');

const exe = 'C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Prompt Picker\\Prompt Picker.exe';
const opts = planShortcutRepair(null, exe, false);
assert.strictEqual(opts.operation, 'create');
assert.strictEqual(opts.options.target, exe);
assert.strictEqual(opts.options.cwd, 'C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Prompt Picker');
assert.strictEqual(opts.options.appUserModelId, 'com.lineko.promptpicker');

const stale = planShortcutRepair({target: 'C:\\missing\\Prompt Picker.exe', cwd: 'C:\\missing'}, exe, true);
assert.strictEqual(stale.operation, 'replace');
assert.strictEqual(stale.options.target, exe);

const wrongCwd = planShortcutRepair({target: exe, cwd: 'C:\\missing'}, exe, true);
assert.strictEqual(wrongCwd.operation, 'replace');

const ok = planShortcutRepair({target: exe, cwd: 'C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Prompt Picker'}, exe, true);
assert.strictEqual(ok, null);
assert.strictEqual(planShortcutRepair({target: exe.replace(/\\/g, '/'), cwd: opts.options.cwd + '\\'}, exe, true), null);
assert.strictEqual(samePath(exe, exe.toLowerCase()), true);

const locs = shortcutLocations('C:\\Users\\ADMIN\\AppData\\Roaming', 'C:\\Users\\ADMIN\\Desktop');
assert.strictEqual(locs.startMenu, 'C:\\Users\\ADMIN\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Prompt Picker.lnk');
assert.strictEqual(locs.desktop, 'C:\\Users\\ADMIN\\Desktop\\Prompt Picker.lnk');

assert.strictEqual(installerName('0.1.12'), 'PromptPicker-Setup-0.1.12.exe');
assert.strictEqual(installerUrl('v0.1.12'), 'https://github.com/broplaygame75-ai/prompt-picker-releases/releases/download/v0.1.12/PromptPicker-Setup-0.1.12.exe');
assert.strictEqual(installerUrl(''), 'https://github.com/broplaygame75-ai/prompt-picker-releases/releases/latest');
assert.strictEqual(versionFromRelease({tag_name: 'v0.1.12'}), '0.1.12');
assert.strictEqual(versionFromRelease({name: 'notes'}), '');

const html = fs.readFileSync(path.join(__dirname, '../src/index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
const stub = () => ({onclick: null, value: '', textContent: '', innerHTML: '', style: {}, dataset: {}, classList: {add() {}, remove() {}, toggle() {}, contains() { return false; }}, addEventListener() {}, setAttribute() {}, focus() {}, appendChild() {}, querySelector: stub, querySelectorAll: () => []});
const document = {documentElement: {lang: '', style: {setProperty() {}}}, body: {classList: {add() {}, toggle() {}, contains() { return false; }}}, querySelector: stub, querySelectorAll: () => [], addEventListener() {}, createElement: stub};
const api = {version: async () => '0.0.0', load: async () => null, save: async () => true, dirGet: async () => '', onUpd() {}, onState() {}, onThemePreview() {}, onSettingsTab() {}, setFontScale() {}, pushState() {}, releases: async () => [], updCheck: async () => false, updDownload: async () => false, quit: async () => true, openSettings: async () => true};
const ctx = {document, location: {search: ''}, navigator: {}, api, URLSearchParams, setTimeout, clearTimeout, console, Map, Set, Date, Math, JSON, Promise};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(script + '\nthis.I18N=I18N;', ctx);
for (const lang of ['en', 'vi', 'zh', 'ko']) {
  for (const key of ['repairTitle', 'repairBody', 'repairBtn', 'repairClose']) {
    assert.strictEqual(ctx.I18N[lang][key], COPY[lang][key], lang + ' ' + key);
  }
}

const nsh = fs.readFileSync(path.join(__dirname, '../build/installer.nsh'), 'utf8');
assert.ok(nsh.includes('!macro ppRejectMissingInstall'));
assert.ok(nsh.includes('DeleteRegValue HKCU "${INSTALL_REGISTRY_KEY}" "InstallLocation"'));
assert.ok(nsh.includes('!macro customInstall'));
assert.ok(nsh.includes('CreateShortCut "$newStartMenuLink"'));
assert.ok(nsh.includes('CreateShortCut "$newDesktopLink"'));
assert.ok(nsh.includes('IfFileExists "$appExe"'));
assert.ok(!/publisherName/.test(fs.readFileSync(path.join(__dirname, '../package.json'), 'utf8')));

const wf = fs.readFileSync(path.join(__dirname, '../.github/workflows/release.yml'), 'utf8');
assert.ok(wf.includes('clean-machine'));
assert.ok(wf.includes('windows-clean-machine.ps1'));
assert.ok(/publish:[\s\S]*needs:\s*\[clean-machine\]/.test(wf));

const clean = fs.readFileSync(path.join(__dirname, 'windows-clean-machine.ps1'), 'utf8');
assert.ok(clean.includes('/S _?=$installDir'), 'silent uninstall must wait on the NSIS process');
assert.ok(clean.includes('function Invoke-Uninstall'));
assert.ok(clean.includes('uninstall then reinstall'));
assert.ok(clean.includes('Assert-ShortcutsGone'));

console.log('startup ok');
