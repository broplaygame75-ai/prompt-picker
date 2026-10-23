const assert = require('assert');
const { UUID } = require('builder-util-runtime');
const {
  INSTALL_GUID,
  APP_ID,
  withActiveDataDir,
  windowsRememberCommands,
  normalizeDataPath,
  markerFromText,
  reuseSources
} = require('../src/dataDir');

const ns = UUID.parse('50e065bc-3134-11e6-9bab-38c9862bdaf3');
assert.strictEqual(String(UUID.v5('com.lineko.promptpicker', ns)), INSTALL_GUID);

assert.strictEqual(normalizeDataPath('W:/AI Work/Prompt Picker/'), 'W:\\AI Work\\Prompt Picker');
const next = withActiveDataDir({ dataDir: 'D:\\old', theme: 1 }, 'W:\\CustomPrompts');
assert.strictEqual(next.activeDataDir, 'W:\\CustomPrompts');
assert.strictEqual(next.dataDir, 'D:\\old');
assert.strictEqual(Object.keys(next)[0], 'activeDataDir');
assert.strictEqual(JSON.parse(JSON.stringify(next)).activeDataDir, 'W:\\CustomPrompts');

const cmds = windowsRememberCommands('W:\\CustomPrompts', 'W:\\AI Work\\Prompt Picker');
assert.strictEqual(cmds.length, 4);
assert.deepStrictEqual(cmds[0], ['add', 'HKCU\\Software\\Prompt Picker', '/v', 'DataDir', '/t', 'REG_SZ', '/d', 'W:\\CustomPrompts', '/f']);
assert.strictEqual(cmds[1][1], 'HKCU\\Software\\' + INSTALL_GUID);
assert.strictEqual(cmds[2][3], 'InstallLocation');
assert.strictEqual(cmds[3][7], 'W:\\AI Work\\Prompt Picker');
const dataOnly = windowsRememberCommands('C:\\Users\\me\\AppData\\Roaming\\Prompt Picker\\data', '');
assert.strictEqual(dataOnly.length, 2);

const marker = '{"appId":"com.lineko.promptpicker","version":"0.1.8","installDir":"W:\\\\AI Work\\\\Prompt Picker","dataPath":"W:\\\\AI Work\\\\Prompt Picker\\\\PromptPickerData"}';
const parsed = markerFromText(marker);
assert.strictEqual(parsed.appId, APP_ID);
assert.strictEqual(parsed.installDir, 'W:\\AI Work\\Prompt Picker');
assert.strictEqual(parsed.dataPath, 'W:\\AI Work\\Prompt Picker\\PromptPickerData');
assert.strictEqual(markerFromText('{"appId":"other.app","installDir":"W:\\\\Not Ours"}'), null);
assert.deepStrictEqual(reuseSources('W:\\AI Work\\Prompt Picker', marker, ''), [
  'W:\\AI Work\\Prompt Picker\\PromptPickerData',
  'W:\\AI Work\\Prompt Picker\\data'
]);
assert.deepStrictEqual(reuseSources('C:\\Users\\me\\AppData\\Local\\Programs\\Prompt Picker', marker, ''), []);

console.log('data remember ok');
