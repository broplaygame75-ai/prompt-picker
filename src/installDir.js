const {execFileSync} = require('child_process');
const {INSTALL_GUID, normalizeDataPath} = require('./dataDir');

const UNINSTALL_KEY = 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\' + INSTALL_GUID;

function sameInstall(a, b) {
  const na = normalizeDataPath(a || '');
  const nb = normalizeDataPath(b || '');
  return na.length > 0 && na.toLowerCase() === nb.toLowerCase();
}

function parseRegSz(text, name) {
  const needle = String(name || '').toLowerCase();
  for (const line of String(text || '').split(/\r?\n/)) {
    const m = line.match(/^\s*(\S+)\s+REG_\w+\s+(.*)$/);
    if (m && m[1].toLowerCase() === needle) return m[2].trim();
  }
  return '';
}

function installDirFromUninstallString(value) {
  const text = String(value || '').trim();
  const quoted = text.match(/^"([^"]+)"/);
  const exe = quoted ? quoted[1] : (text.split(/\s+/)[0] || '');
  if (!exe || !/[\\/]/.test(exe)) return '';
  return normalizeDataPath(exe.replace(/[\\/][^\\/]*$/, ''));
}

// Prefer the registry or uninstall-key folder when it is the folder of the
// running exe. A stale key must not move an update away from that exe.
function cleanInstall(dir) {
  const s = String(dir || '').trim();
  if (!s) return '';
  return normalizeDataPath(s);
}

function chooseInstallDir(input) {
  const src = input || {};
  const reg = cleanInstall(src.registryDir);
  const un = cleanInstall(src.uninstallDir);
  const exe = cleanInstall(src.exeDir);
  if (exe && reg && sameInstall(exe, reg)) return reg;
  if (exe && un && sameInstall(exe, un)) return un;
  if (exe) return exe;
  return reg || un || '';
}

// NSIS honors /D= only when it is last and unquoted. The caller must pass
// this array with windowsVerbatimArguments so the space in the folder survives.
function updateArgs(installDir) {
  const dir = normalizeDataPath(installDir || '');
  const args = ['/S', '/currentuser', '--updated', '--force-run'];
  if (dir) args.push('/D=' + dir);
  return args;
}

function queryReg(key, name) {
  if (process.platform !== 'win32') return '';
  try {
    const out = execFileSync('reg', ['query', key, '/v', name], {encoding: 'utf8', windowsHide: true});
    return parseRegSz(out, name);
  } catch (e) {
    return '';
  }
}

function readInstallCandidates(exeDir, query) {
  const read = query || queryReg;
  const registryDir = read('HKCU\\Software\\' + INSTALL_GUID, 'InstallLocation')
    || read('HKCU\\Software\\Prompt Picker', 'InstallLocation');
  const uninstallDir = installDirFromUninstallString(read(UNINSTALL_KEY, 'UninstallString'));
  return {registryDir, uninstallDir, exeDir: exeDir || ''};
}

module.exports = {
  UNINSTALL_KEY,
  parseRegSz,
  installDirFromUninstallString,
  chooseInstallDir,
  updateArgs,
  readInstallCandidates,
  queryReg
};
