#!/usr/bin/env node
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const {planShortcutRepair, shortcutLocations, samePath, diagnoseShortcut, startMenuPaths} = require('../src/shortcuts');
const {COPY} = require('../src/startupCopy');
const {installerUrl, installerName, versionFromRelease} = require('../src/repair');
const {formatStartupEntry} = require('../src/startupLog');
const {parseRegSz, installDirFromUninstallString, chooseInstallDir, updateArgs, uninstallArgs, readInstallCandidates} = require('../src/installDir');
const {TELEGRAM_URL, CONTACTS, contactHosts} = require('../src/contact');

const exe = 'C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Prompt Picker\\Prompt Picker.exe';
const opts = planShortcutRepair(null, exe, false);
assert.strictEqual(opts.operation, 'create');
assert.strictEqual(opts.options.target, exe);
assert.strictEqual(opts.options.cwd, 'C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Prompt Picker');
assert.strictEqual(opts.options.appUserModelId, undefined);

const stale = planShortcutRepair({target: 'C:\\missing\\Prompt Picker.exe', cwd: 'C:\\missing'}, exe, true);
assert.strictEqual(stale.operation, 'replace');
assert.strictEqual(stale.options.target, exe);

const wrongCwd = planShortcutRepair({target: exe, cwd: 'C:\\missing'}, exe, true);
assert.strictEqual(wrongCwd.operation, 'replace');

const ok = planShortcutRepair({target: exe, cwd: 'C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Prompt Picker'}, exe, true);
assert.strictEqual(ok, null);
const aumi = planShortcutRepair({target: exe, cwd: 'C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Prompt Picker', appUserModelId: 'com.lineko.promptpicker'}, exe, true);
assert.strictEqual(aumi.operation, 'replace');
assert.strictEqual(aumi.options.appUserModelId, undefined);
const broken = diagnoseShortcut({exists: true, appUserModelId: 'com.lineko.promptpicker', target: exe, targetExists: true});
assert.ok(broken.includes('Unspecified error'));
assert.ok(diagnoseShortcut({exists: true, target: exe, targetExists: false}).includes('does not exist'));
assert.strictEqual(startMenuPaths('C:\\Users\\ADMIN\\AppData\\Roaming', 'C:\\ProgramData')[1], 'C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\Prompt Picker.lnk');
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
const api = {version: async () => '0.0.0', load: async () => ({prompts: [], lang: 'vi', langChosen: true, themeColors: {pri: '#112233'}, showHints: true, logSort: 'name-desc', fontScale: 1.3, ageOk: true}), save: async () => true, dirGet: async () => '', onUpd() {}, onState() {}, onThemePreview() {}, onSettingsTab() {}, setFontScale() {}, pushState() {}, releases: async () => [], updCheck: async () => false, updDownload: async () => false, quit: async () => true, openSettings: async () => true};
const ctx = {document, location: {search: ''}, navigator: {}, api, URLSearchParams, setTimeout, clearTimeout, console, Map, Set, Date, Math, JSON, Promise};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(script + '\nthis.I18N=I18N;this.__snap=function(){return S};', ctx);
for (const lang of ['en', 'vi', 'zh', 'ko']) {
  for (const key of ['repairTitle', 'repairBody', 'repairBtn', 'repairClose']) {
    assert.strictEqual(ctx.I18N[lang][key], COPY[lang][key], lang + ' ' + key);
  }
}

const nsh = fs.readFileSync(path.join(__dirname, '../build/installer.nsh'), 'utf8');
assert.ok(nsh.includes('!macro ppChooseDefaultDir'));
assert.ok(nsh.includes('CreateDirectory "C:\\Prompt Picker"'));
assert.ok(nsh.includes('StrCpy $INSTDIR "$PROFILE\\Prompt Picker"'));
assert.ok(nsh.includes('Delete "$SMPROGRAMS\\${SHORTCUT_NAME}.lnk"'));
assert.ok(nsh.includes('CreateShortCut "$newDesktopLink"'));
assert.ok(!nsh.includes('SetLnkAUMI'));
assert.ok(!nsh.includes('CreateShortCut "$newStartMenuLink"'));
assert.ok(nsh.includes('PendingInstallDir'));
assert.ok(nsh.includes('GetCommandLineW'));
assert.ok(!nsh.includes('GetParameter'));
assert.ok(nsh.includes('MUI_LANGDLL_ALWAYSSHOW'));
assert.ok(nsh.includes('ppHasSwitch "KEEP"'));
assert.ok(nsh.includes('ppHasSwitch "WIPE"'));
assert.ok(nsh.includes('ppFinishUninstall'));
assert.strictEqual(TELEGRAM_URL, 'https://t.me/linekoaiart');
assert.deepStrictEqual(CONTACTS.map(c => c.id), ['discord', 'patreon', 'x', 'telegram']);
assert.ok(contactHosts().includes('t.me'));
assert.ok(html.includes('data-contact="discord"'));
assert.ok(html.includes('id="aboutdiscord"'));
assert.ok(html.includes('id="unkeep"'));
assert.ok(html.includes('id="unwipe"'));
const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '../package.json'), 'utf8'));
assert.strictEqual(pkg.version, '0.1.13');
assert.strictEqual(pkg.build.nsis.oneClick, false);
assert.strictEqual(pkg.build.nsis.perMachine, false);
assert.strictEqual(pkg.build.nsis.allowToChangeInstallationDirectory, true);
assert.strictEqual(pkg.build.nsis.createDesktopShortcut, 'always');
assert.strictEqual(pkg.build.nsis.createStartMenuShortcut, false);
assert.ok(!/publisherName/.test(JSON.stringify(pkg)));

const wf = fs.readFileSync(path.join(__dirname, '../.github/workflows/release.yml'), 'utf8');
assert.ok(wf.includes('clean-machine'));
assert.ok(wf.includes('windows-clean-machine.ps1'));
assert.ok(wf.includes('patch-nsis-directory.js'));
const patchSrc = fs.readFileSync(path.join(__dirname, 'patch-nsis-directory.js'), 'utf8');
assert.ok(patchSrc.includes('ppDirPre'));
assert.ok(patchSrc.includes('ppPrepareInstallDir'));
assert.ok(patchSrc.includes('ppAfterInstallMode'));
assert.ok(patchSrc.includes('StrContains.nsh'));
assert.ok(/publish:[\s\S]*needs:\s*\[clean-machine\]/.test(wf));
const main = fs.readFileSync(path.join(__dirname, '../src/main.js'), 'utf8');
const preload = fs.readFileSync(path.join(__dirname, '../src/preload.js'), 'utf8');
assert.ok(main.includes("mode==='keep'?'keep':'wipe'"));
assert.ok(main.includes('contactHosts'));
assert.ok(main.includes('contacts-sync'));
assert.ok(preload.includes("sendSync('contacts-sync')"));
assert.ok(!preload.includes("require('./contact')"));
assert.ok(main.includes('windowsVerbatimArguments:true'));
assert.ok(!main.includes('quitAndInstall'));
assert.ok(main.includes("setAppUserModelId('com.lineko.promptpicker')"));
assert.ok(main.includes('startup.log'));

const clean = fs.readFileSync(path.join(__dirname, 'windows-clean-machine.ps1'), 'utf8');
assert.ok(clean.includes('_?=$installDir'), 'silent uninstall must wait on the NSIS process');
assert.ok(clean.includes("'/KEEP'"));
assert.ok(clean.includes("'/WIPE'"));
assert.ok(clean.includes('keep data, settings, and install choices'));
assert.ok(clean.includes('wipe everything'));
assert.ok(clean.includes('function Invoke-Uninstall'));
assert.ok(clean.includes('for ($try = 1; $try -le 3; $try++)'));
assert.ok(clean.includes('uninstall then reinstall'));
assert.ok(clean.includes('Assert-ShortcutsGone'));
assert.ok(clean.includes('C:\\Prompt Picker'));
assert.ok(clean.includes('custom folder'));
assert.ok(clean.includes('upgrade did not stay'));
assert.ok(clean.includes('startup.log'));
assert.ok(clean.includes('com.lineko.promptpicker'));

assert.strictEqual(parseRegSz('    InstallLocation    REG_SZ    C:\\Prompt Picker\r\n', 'InstallLocation'), 'C:\\Prompt Picker');
assert.strictEqual(installDirFromUninstallString('"C:\\Prompt Picker\\Uninstall Prompt Picker.exe" /currentuser'), 'C:\\Prompt Picker');
assert.strictEqual(chooseInstallDir({registryDir: 'C:\\Prompt Picker', uninstallDir: 'C:\\Prompt Picker', exeDir: 'C:\\Prompt Picker'}), 'C:\\Prompt Picker');
assert.strictEqual(chooseInstallDir({registryDir: 'C:\\missing', exeDir: 'C:\\Users\\ADMIN\\Prompt Picker'}), 'C:\\Users\\ADMIN\\Prompt Picker');
assert.strictEqual(chooseInstallDir({registryDir: 'C:\\Prompt Picker', uninstallDir: '', exeDir: ''}), 'C:\\Prompt Picker');
const args = updateArgs('C:\\Prompt Picker');
assert.strictEqual(args[args.length - 1], '/D=C:\\Prompt Picker');
assert.ok(args.includes('/currentuser'));
assert.ok(args.indexOf('/currentuser') < args.length - 1);
assert.ok(!args[args.length - 1].includes('"'));
const keepArgs = uninstallArgs('keep', 'C:\\Prompt Picker');
assert.deepStrictEqual(keepArgs, ['/S', '/KEEP', '_?=C:\\Prompt Picker']);
assert.deepStrictEqual(uninstallArgs('wipe', 'C:\\Users\\ADMIN\\Prompt Picker'), ['/S', '/WIPE', '_?=C:\\Users\\ADMIN\\Prompt Picker']);
assert.deepStrictEqual(uninstallArgs('other', ''), ['/S', '/WIPE']);
const publish = fs.readFileSync(path.join(__dirname, 'publish-extras.js'), 'utf8');
assert.ok(publish.includes('releases-public'));
assert.ok(publish.includes('setup_sha256'));
assert.ok(publish.includes('prompt-picker'));
assert.ok(publish.includes('https://discord.gg/yH5AAdj5qY'));
assert.ok(fs.existsSync(path.join(__dirname, '../releases-public/README.md')));
assert.ok(fs.existsSync(path.join(__dirname, '../releases-public/.github/social-preview.png')));
const queried = readInstallCandidates('C:\\Users\\ADMIN\\Prompt Picker', (key, name) => {
  if (name === 'UninstallString') return '"C:\\Users\\ADMIN\\Prompt Picker\\Uninstall Prompt Picker.exe" /currentuser';
  if (name === 'InstallLocation' && key.endsWith('Prompt Picker')) return 'C:\\Users\\ADMIN\\Prompt Picker';
  return '';
});
assert.strictEqual(chooseInstallDir(queried), 'C:\\Users\\ADMIN\\Prompt Picker');
const entry = formatStartupEntry({
  at: '2026-10-24T00:00:00.000Z',
  version: '0.1.13',
  execPath: exe,
  execExists: true,
  execBytes: 10,
  zone: 'absent',
  registryDir: 'C:\\Prompt Picker',
  installDir: 'C:\\Prompt Picker',
  startMenu: {path: locs.startMenu, exists: true, appUserModelId: 'com.lineko.promptpicker', target: exe, targetExists: false, diagnosis: broken},
  desktop: {path: locs.desktop, exists: true, target: exe, targetExists: true, diagnosis: 'Target exists and AppUserModelID is empty.'}
});
assert.ok(entry.includes('startup.log') === false);
assert.ok(entry.includes('AppUserModelID: com.lineko.promptpicker'));
assert.ok(entry.includes('TargetExists: false'));
assert.ok(entry.includes(broken));

setImmediate(() => {
  try {
    const kept = ctx.__snap();
    if (!kept || kept.lang !== 'vi' || kept.logSort !== 'name-desc' || kept.showHints !== true) throw new Error('settings were not kept on load ' + JSON.stringify(kept && {lang: kept.lang, logSort: kept.logSort, showHints: kept.showHints}));
    if (!kept.themeColors || kept.themeColors.pri !== '#112233') throw new Error('theme was not kept on load');
    console.log('startup ok');
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
});
