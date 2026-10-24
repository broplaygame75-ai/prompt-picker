// electron-builder's assisted directory page appends "\Prompt Picker" whenever
// the chosen path does not already contain that name, and its per-user mode
// resets $INSTDIR to %LocalAppData%\Programs. The installer include finishes
// the folder itself, so those two spots call our macros instead.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const nsisDir = path.join(root, 'node_modules', 'app-builder-lib', 'templates', 'nsis');
const assisted = path.join(nsisDir, 'assistedInstaller.nsh');
const multi = path.join(nsisDir, 'multiUser.nsh');
const installUtil = path.join(nsisDir, 'include', 'installUtil.nsh');
const installerNsi = path.join(nsisDir, 'installer.nsi');

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
    !define MUI_PAGE_CUSTOMFUNCTION_LEAVE ppDirLeave
    !insertmacro MUI_PAGE_DIRECTORY

    # $INSTDIR is the folder from the directory page. ppPrepareInstallDir
    # keeps that folder. Setup does not relaunch itself.
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

// 0.1.13's uninstaller can sit on a page for the whole silent upgrade.
// Overwrite the folder in place instead of ExecWait on that uninstaller.
const skipOldFrom = `Function uninstallOldVersion
  Var /GLOBAL uninstallerFileName`;

const skipOldTo = `Function uninstallOldVersion
  !ifmacrodef ppSkipOldUninstall
    Pop $R0
    StrCpy $R0 0
    ClearErrors
    Return
  !endif
  Var /GLOBAL uninstallerFileName`;

// Setup must not ShellExecute itself. That relaunch is the Windows dialog
// "cannot access the specified device, path, or file" once the exe is locked.
function dropInstallerRelaunch(file) {
  let text = fs.readFileSync(file, 'utf8');
  if (text.includes('Never relaunch setup.exe')) return false;
  const begin = text.indexOf('          ${if} $hasPerMachineInstallation == "1"');
  const end = text.indexOf('      !endif\n    !endif\n    !include "installSection.nsh"');
  if (begin < 0 || end < 0 || begin > end) {
    throw new Error('install section elevation block missing: ' + path.basename(file));
  }
  const replacement = `          # Never relaunch setup.exe. A second start of that file is the Windows
          # "cannot access the specified device, path, or file" dialog.
          \${if} $hasPerMachineInstallation == "1"
          \${andIf} \${Silent}
            StrCpy $hasPerMachineInstallation "0"
            StrCpy $hasPerUserInstallation "1"
            !insertmacro setInstallModePerUser
          \${endIf}
`;
  text = text.slice(0, begin) + replacement + text.slice(end);
  if (text.includes('UAC_RunElevated')) {
    throw new Error('setup still relaunches itself');
  }
  fs.writeFileSync(file, text);
  return true;
}

function dropSelfCopy(file) {
  let text = fs.readFileSync(file, 'utf8');
  const marker = 'Leave the running setup exe where it was launched';
  if (text.includes(marker)) return false;
  const needle = '!insertmacro copyFile "$EXEPATH"';
  const at = text.indexOf(needle);
  if (at < 0) throw new Error('setup self-copy missing');
  const lineEnd = text.indexOf('\n', at);
  text = text.slice(0, at) + '# ' + marker + '. Do not copy or move it.' + text.slice(lineEnd);
  if (text.includes('copyFile "$EXEPATH"')) throw new Error('setup still copies itself');
  fs.writeFileSync(file, text);
  return true;
}

const leaveFrom = `    !define MUI_PAGE_CUSTOMFUNCTION_PRE ppDirPre
    !insertmacro MUI_PAGE_DIRECTORY`;

const leaveTo = `    !define MUI_PAGE_CUSTOMFUNCTION_PRE ppDirPre
    !define MUI_PAGE_CUSTOMFUNCTION_LEAVE ppDirLeave
    !insertmacro MUI_PAGE_DIRECTORY`;

function patchKnownFolder(file) {
  let text = fs.readFileSync(file, 'utf8');
  const marker = 'Do not call SHGetKnownFolderPath here';
  if (text.includes(marker)) return false;
  const from = `      StrCpy $0 "$LocalAppData\\Programs"
      System::Store S
      # Win7 has a per-user programfiles known folder and this can be a non-default location
      System::Call 'SHELL32::SHGetKnownFolderPath(g "\${FOLDERID_UserProgramFiles}", i \${KF_FLAG_CREATE}, p 0, *p .r2)i.r1'
      \${If} $1 == 0
        System::Call '*$2(&w\${NSIS_MAX_STRLEN} .s)'
        StrCpy $0 $1
        System::Call 'OLE32::CoTaskMemFree(p r2)'
      \${endif}
      System::Store L
      StrCpy $INSTDIR "$0\\\${APP_FILENAME}"`;
  if (!text.includes(from)) throw new Error('known-folder block missing');
  const to = `      # ${marker}. The stock call pushes the path onto the NSIS
      # stack and System::Store then reloads every register from the wrong
      # slot. The next plugin call can ShellExecute or terminate setup.exe.
      StrCpy $INSTDIR "$LocalAppData\\Programs\\\${APP_FILENAME}"`;
  text = text.replace(from, to);
  fs.writeFileSync(file, text);
  return true;
}

function neutralizeUac(file) {
  let text = fs.readFileSync(file, 'utf8');
  const marker = 'Never ShellExecute setup.exe';
  if (text.includes(marker)) return false;
  const from = `!macro UAC_RunElevated
UAC::_ 0
!macroend
!macro UAC_PageElevation_RunElevated
UAC::_ 0
!macroend`;
  if (!text.includes(from)) throw new Error('UAC_RunElevated macro missing');
  const to = `!macro UAC_RunElevated
  ; ${marker}. The Windows dialog is
  ; "cannot access the specified device, path, or file".
  StrCpy $0 1223
  StrCpy $1 0
  StrCpy $2 0
  StrCpy $3 0
!macroend
!macro UAC_PageElevation_RunElevated
  StrCpy $0 1223
  StrCpy $1 0
  StrCpy $2 0
  StrCpy $3 0
!macroend`;
  text = text.replace(from, to);
  const bodyStart = text.indexOf('!macro UAC_RunElevated');
  const bodyEnd = text.indexOf('!macroend', bodyStart);
  if (text.slice(bodyStart, bodyEnd).includes('UAC::_')) {
    throw new Error('setup still relaunches itself');
  }
  fs.writeFileSync(file, text);
  return true;
}

function dropModeElevation(file) {
  let text = fs.readFileSync(file, 'utf8');
  const marker = 'Never relaunch setup for all-users mode';
  if (text.includes(marker)) return false;
  const from = `\${if} $isForceMachineInstall == "1"
    \${OrIf} \${isForAllUsers}
      StrCpy $hasPerMachineInstallation "1"
      StrCpy $hasPerUserInstallation "0"
      \${ifNot} \${UAC_IsAdmin}
        ShowWindow $HWNDPARENT \${SW_HIDE}
        !insertmacro UAC_RunElevated
        Quit
      \${endIf}

      !insertmacro setInstallModePerAllUsers
      Abort
    \${endIf}`;
  if (!text.includes(from)) throw new Error('install-mode elevation block missing');
  const to = `\${if} $isForceMachineInstall == "1"
    \${OrIf} \${isForAllUsers}
      # Per-user install. ${marker}.
      StrCpy $hasPerMachineInstallation "0"
      StrCpy $hasPerUserInstallation "1"
      StrCpy $isForceMachineInstall "0"
      StrCpy $isForceCurrentInstall "1"
      !insertmacro setInstallModePerUser
      Abort
    \${endIf}`;
  text = text.replace(from, to);
  const un = `\${IfNot} \${UAC_IsAdmin}
          ShowWindow $HWNDPARENT \${SW_HIDE}
          !insertmacro UAC_RunElevated
          Quit
        \${endIf}
`;
  if (!text.includes(un)) throw new Error('uninstaller elevation block missing');
  text = text.replace(un, '');
  fs.writeFileSync(file, text);
  return true;
}

function dropPerMachineQuit(file) {
  let text = fs.readFileSync(file, 'utf8');
  const marker = 'Never relaunch or quit the uninstaller';
  if (text.includes(marker)) return false;
  const from = `      \${IfNot} \${UAC_IsAdmin}
        ShowWindow $HWNDPARENT \${SW_HIDE}
        !insertmacro UAC_RunElevated
        Quit
      \${endif}
`;
  if (!text.includes(from)) throw new Error('per-machine elevation quit missing');
  text = text.replace(from, `      # ${marker}.\n`);
  fs.writeFileSync(file, text);
  return true;
}

function patchEarlyLog(file) {
  let text = fs.readFileSync(file, 'utf8');
  const marker = 'PromptPicker-install.log';
  if (text.includes(marker)) return false;
  const from = `Function .onInit
  Call setInstallSectionSpaceRequired

  SetOutPath $INSTDIR
  \${LogSet} on
`;
  if (!text.includes(from)) throw new Error('.onInit block missing');
  const to = `Function .onInit
  !ifndef BUILD_UNINSTALLER
    ; First instructions. If setup dies, this file still exists.
    ClearErrors
    FileOpen $R9 "$TEMP\\PromptPicker-install.log" w
    IfErrors pp_early_log_done
      FileWrite $R9 "start$\\r$\\n"
      FileClose $R9
    pp_early_log_done:
    ; Do not sit in $INSTDIR. That folder is not created yet, and a later
    ; ShellExecute uses it as the working directory.
    SetOutPath $TEMP
  !else
    SetOutPath $INSTDIR
  !endif
  Call setInstallSectionSpaceRequired

  \${LogSet} on
`;
  text = text.replace(from, to);
  fs.writeFileSync(file, text);
  return true;
}

function patchAssisted(file) {
  let text = fs.readFileSync(file, 'utf8');
  if (text.includes('MUI_PAGE_CUSTOMFUNCTION_LEAVE ppDirLeave') && text.includes('!insertmacro ppPrepareInstallDir')) {
    return false;
  }
  if (text.includes(assistedFrom)) {
    text = text.replace(assistedFrom, assistedTo);
  } else if (text.includes(leaveFrom)) {
    text = text.replace(leaveFrom, leaveTo);
  } else {
    throw new Error('NSIS template no longer matches the patch: ' + path.basename(file));
  }
  fs.writeFileSync(file, text);
  return true;
}

const assistedChanged = patchAssisted(assisted);
const strChanged = dropUnusedStrContains(assisted);
const modeChanged = patchPerUserMode(multi);
assertPerUserHook(multi);
const skipChanged = patch(installUtil, [[skipOldFrom, skipOldTo]]);
const uacChanged = dropInstallerRelaunch(installerNsi);
const copyChanged = dropSelfCopy(path.join(nsisDir, 'include', 'installer.nsh'));
const folderChanged = patchKnownFolder(multi);
const elevateChanged = neutralizeUac(path.join(nsisDir, 'include', 'UAC.nsh'));
const modeUiChanged = dropModeElevation(path.join(nsisDir, 'multiUserUi.nsh'));
const perMachineChanged = dropPerMachineQuit(multi);
const logChanged = patchEarlyLog(installerNsi);
console.log('nsis directory patch', assistedChanged || strChanged || modeChanged || skipChanged || uacChanged || copyChanged || folderChanged || elevateChanged || modeUiChanged || perMachineChanged || logChanged ? 'applied' : 'already applied');
