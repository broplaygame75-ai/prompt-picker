const path = require('path');

const SHORTCUT_NAME = 'Prompt Picker.lnk';

function samePath(a, b) {
  const norm = s => String(s || '').replace(/\//g, '\\').replace(/[\\]+$/, '').toLowerCase();
  const na = norm(a);
  const nb = norm(b);
  return na.length > 0 && na === nb;
}

// Do not set appUserModelId. Windows Start Menu activates a shortcut that
// carries System.AppUserModel.ID and returns E_FAIL, shown as "Unspecified
// error", for this unpackaged app. The running process still calls
// app.setAppUserModelId so the taskbar can group windows.
function shortcutOptions(execPath) {
  const target = String(execPath || '').replace(/\//g, '\\');
  return {
    target,
    cwd: target ? path.win32.dirname(target) : '',
    description: 'Prompt Picker'
  };
}

function planShortcutRepair(existing, execPath, fileExists) {
  const options = shortcutOptions(execPath);
  if (!options.target) return null;
  const cwdOk = existing && samePath(existing.cwd || '', options.cwd);
  const targetOk = existing && samePath(existing.target, options.target);
  const aumi = existing && String(existing.appUserModelId || '').trim();
  if (fileExists && targetOk && cwdOk && !aumi) return null;
  return {operation: fileExists ? 'replace' : 'create', options};
}

function shortcutLocations(appData, desktop) {
  return {
    startMenu: path.win32.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', SHORTCUT_NAME),
    desktop: path.win32.join(desktop, SHORTCUT_NAME)
  };
}

function startMenuPaths(appData, programData) {
  const paths = [shortcutLocations(appData, '').startMenu];
  if (programData) {
    paths.push(path.win32.join(programData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', SHORTCUT_NAME));
  }
  return paths;
}

function diagnoseShortcut(info) {
  if (!info || !info.exists) return 'Shortcut file is absent.';
  if (info.readError) return 'Shortcut could not be read (' + info.readError + '). Windows reports Unspecified error for a broken link.';
  const reasons = [];
  if (info.appUserModelId) {
    reasons.push('AppUserModelID is ' + info.appUserModelId + '. Windows Start Menu returns Unspecified error when this unpackaged app shortcut carries that id.');
  }
  if (!info.target) reasons.push('Shortcut has no target.');
  else if (!info.targetExists) reasons.push('Target does not exist (' + info.target + '). A removed or quarantined program file makes the shortcut fail.');
  if (!reasons.length) return 'Target exists and AppUserModelID is empty.';
  return reasons.join(' ');
}

module.exports = {
  SHORTCUT_NAME,
  samePath,
  shortcutOptions,
  planShortcutRepair,
  shortcutLocations,
  startMenuPaths,
  diagnoseShortcut
};
