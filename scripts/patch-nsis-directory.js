// electron-builder's assisted directory page appends "\Prompt Picker" whenever
// the chosen path does not already contain that name, and its per-user mode
// resets $INSTDIR to %LocalAppData%\Programs. The installer include finishes
// the folder itself, so those two spots call our macros instead.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const assisted = path.join(root, 'node_modules', 'app-builder-lib', 'templates', 'nsis', 'assistedInstaller.nsh');
const multi = path.join(root, 'node_modules', 'app-builder-lib', 'templates', 'nsis', 'multiUser.nsh');

function patch(file, pairs) {
  let text = fs.readFileSync(file, 'utf8');
  let changed = false;
  for (const [from, to] of pairs) {
    if (text.includes(to)) continue;
    if (!text.includes(from)) {
      throw new Error('NSIS template no longer matches the patch: ' + path.basename(file));
    }
    text = text.replace(from, to);
    changed = true;
  }
  if (changed) fs.writeFileSync(file, text);
  return changed;
}

const assistedFrom = `    !insertmacro skipPageIfUpdated
    !insertmacro MUI_PAGE_DIRECTORY

    # pageDirectory leave doesn't work (it seems because $INSTDIR is set after custom leave function)
    # so, we use instfiles pre
    !define MUI_PAGE_CUSTOMFUNCTION_PRE instFilesPre

    # sanitize the MUI_PAGE_DIRECTORY result to make sure it has a application name sub-folder
    Function instFilesPre
      \${StrContains} $0 "\${APP_FILENAME}" $INSTDIR
      \${If} $0 == ""
        StrCpy $INSTDIR "$INSTDIR\\\${APP_FILENAME}"
      \${endIf}
    FunctionEnd`;

const assistedTo = `    !define MUI_PAGE_CUSTOMFUNCTION_PRE ppDirPre
    !insertmacro MUI_PAGE_DIRECTORY

    # $INSTDIR is the folder from the directory page. ppPrepareInstallDir
    # keeps that folder and elevates only when it is not writable.
    !define MUI_PAGE_CUSTOMFUNCTION_PRE instFilesPre

    Function instFilesPre
      !ifmacrodef ppPrepareInstallDir
        !insertmacro ppPrepareInstallDir
      !endif
    FunctionEnd`;

const modeFrom = `    \${If} $R0 != ""
      StrCpy $INSTDIR $R0
    \${endif}

  !macroend`;

const modeTo = `    \${If} $R0 != ""
      StrCpy $INSTDIR $R0
    \${endif}

    !ifmacrodef ppAfterInstallMode
      !insertmacro ppAfterInstallMode
    !endif

  !macroend`;

// The same /D= ending is in setInstallModePerAllUsers. Only the per-user
// macro resets a fresh install to %LocalAppData%\Programs.
function patchPerUserMode(file) {
  let text = fs.readFileSync(file, 'utf8');
  const start = text.indexOf('!macro setInstallModePerUser');
  const end = text.indexOf('!macroend', start);
  if (start < 0 || end < 0) throw new Error('setInstallModePerUser missing');
  const endPos = end + '!macroend'.length;
  let body = text.slice(start, endPos);
  if (body.includes('!insertmacro ppAfterInstallMode')) return false;
  if (!body.includes(modeFrom)) {
    throw new Error('NSIS template no longer matches the patch: ' + path.basename(file));
  }
  body = body.replace(modeFrom, modeTo);
  text = text.slice(0, start) + body + text.slice(endPos);
  fs.writeFileSync(file, text);
  return true;
}

function dropUnusedStrContains(file) {
  let text = fs.readFileSync(file, 'utf8');
  const line = '    !include StrContains.nsh\n\n';
  if (!text.includes(line) || text.includes('${StrContains}')) return false;
  text = text.replace(line, '');
  fs.writeFileSync(file, text);
  return true;
}

function assertPerUserHook(file) {
  const text = fs.readFileSync(file, 'utf8');
  const perUser = text.indexOf('!macro setInstallModePerUser');
  const perAll = text.indexOf('!macro setInstallModePerAllUsers');
  const hookAt = text.indexOf('!insertmacro ppAfterInstallMode');
  if (perUser < 0 || hookAt < perUser || (perAll >= 0 && hookAt > perAll)) {
    throw new Error('ppAfterInstallMode must be inserted in setInstallModePerUser');
  }
}

const assistedChanged = patch(assisted, [[assistedFrom, assistedTo]]);
const strChanged = dropUnusedStrContains(assisted);
const modeChanged = patchPerUserMode(multi);
assertPerUserHook(multi);
console.log('nsis directory patch', assistedChanged || strChanged || modeChanged ? 'applied' : 'already applied');
