function formatStartupEntry(info) {
  const i = info || {};
  const lines = [
    '--- ' + (i.at || '') + ' Prompt Picker ' + (i.version || '') + ' ---',
    'exec: ' + (i.execPath || ''),
    'execExists: ' + (i.execExists ? 'true' : 'false'),
    'execBytes: ' + (i.execBytes == null ? '' : String(i.execBytes)),
    'zone: ' + (i.zone || 'absent'),
    'registryInstall: ' + (i.registryDir || ''),
    'uninstallDir: ' + (i.uninstallDir || ''),
    'chosenInstallDir: ' + (i.installDir || '')
  ];
  for (const key of ['startMenu', 'desktop']) {
    const s = i[key] || {};
    lines.push(key + ': ' + (s.path || ''));
    lines.push(key + 'Exists: ' + (s.exists ? 'true' : 'false'));
    lines.push(key + 'Target: ' + (s.target || ''));
    lines.push(key + 'TargetExists: ' + (s.targetExists ? 'true' : 'false'));
    lines.push(key + 'Cwd: ' + (s.cwd || ''));
    lines.push(key + 'AppUserModelID: ' + (s.appUserModelId || ''));
    lines.push(key + 'ReadError: ' + (s.readError || ''));
    lines.push(key + 'Diagnosis: ' + (s.diagnosis || ''));
  }
  if (i.note) lines.push('note: ' + i.note);
  return lines.join('\n') + '\n';
}

module.exports = {formatStartupEntry};
