const path = require('path');

const SHORTCUT_NAME = 'Prompt Picker.lnk';

function samePath(a, b) {
  const norm = s => String(s || '').replace(/\//g, '\\').replace(/[\\]+$/, '').toLowerCase();
  const na = norm(a);
  const nb = norm(b);
  return na.length > 0 && na === nb;
}

function shortcutOptions(execPath) {
  const target = String(execPath || '').replace(/\//g, '\\');
  return {
    target,
    cwd: target ? path.win32.dirname(target) : '',
    description: 'Prompt Picker',
    appUserModelId: 'com.lineko.promptpicker'
  };
}

// 'create' overwrites nothing that is missing. 'replace' rewrites a link that
// is already on disk. A correct target and working directory needs no write.
function planShortcutRepair(existing, execPath, fileExists) {
  const options = shortcutOptions(execPath);
  if (!options.target) return null;
  const cwdOk = existing && samePath(existing.cwd || '', options.cwd);
  const targetOk = existing && samePath(existing.target, options.target);
  if (fileExists && targetOk && cwdOk) return null;
  return {operation: fileExists ? 'replace' : 'create', options};
}

function shortcutLocations(appData, desktop) {
  return {
    startMenu: path.win32.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', SHORTCUT_NAME),
    desktop: path.win32.join(desktop, SHORTCUT_NAME)
  };
}

module.exports = {SHORTCUT_NAME, samePath, shortcutOptions, planShortcutRepair, shortcutLocations};
