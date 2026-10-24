function installerName(version) {
  return 'PromptPicker-Setup-' + version + '.exe';
}

function installerUrl(version) {
  const v = String(version || '').replace(/^v/i, '');
  if (!/^\d+\.\d+\.\d+$/.test(v)) return 'https://github.com/broplaygame75-ai/prompt-picker-releases/releases/latest';
  return 'https://github.com/broplaygame75-ai/prompt-picker-releases/releases/download/v' + v + '/' + installerName(v);
}

function versionFromRelease(json) {
  const tag = json && (json.tag_name || json.name) || '';
  const v = String(tag).replace(/^v/i, '');
  return /^\d+\.\d+\.\d+$/.test(v) ? v : '';
}

module.exports = {installerName, installerUrl, versionFromRelease};
