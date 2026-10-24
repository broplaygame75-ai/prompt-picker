!include LogicLib.nsh
!include nsDialogs.nsh
!include /CHARSET=UTF8 "uninstall-logic.nsh"

; The language dialog is shown after this header is included. A saved choice
; fills $LANGUAGE, and ALWAYSSHOW keeps the dialog on an interactive install.
; Defines stay off the uninstaller build so its silent generator is unchanged.
!ifndef BUILD_UNINSTALLER
  !define MUI_LANGDLL_REGISTRY_ROOT HKCU
  !define MUI_LANGDLL_REGISTRY_KEY "Software\Prompt Picker"
  !define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"
  !define MUI_LANGDLL_ALWAYSSHOW
Var ppKeepDir
Var ppDirChosen
Var ppDesktopShortcut
Var ppDesktopCheckbox
!endif

; The stock parameter reader stops at the first space, so "C:\Prompt Picker"
; became "C:\Prompt". Read the raw command line and keep everything after /D=.
!macro ppReadDSwitch OUT
  !define pprd ${__COUNTER__}
  StrCpy ${OUT} ""
  System::Call 'kernel32::GetCommandLineW()w .r1'
  StrCpy $3 0
  pp_rd_scan_${pprd}:
    StrCpy $4 $1 3 $3
    StrCmp $4 "" pp_rd_end_${pprd}
    StrCmp $4 "/D=" 0 pp_rd_next_${pprd}
    ${If} $3 <> 0
      IntOp $2 $3 - 1
      StrCpy $2 $1 1 $2
      StrCmp $2 " " pp_rd_take_${pprd}
      StrCmp $2 '"' pp_rd_take_${pprd}
      Goto pp_rd_next_${pprd}
    ${EndIf}
    Goto pp_rd_take_${pprd}
  pp_rd_next_${pprd}:
    IntOp $3 $3 + 1
    Goto pp_rd_scan_${pprd}
  pp_rd_take_${pprd}:
    IntOp $3 $3 + 3
    StrCpy ${OUT} $1 "" $3
    StrCpy $2 ${OUT} 1
    StrCmp $2 '"' 0 pp_rd_end_${pprd}
    StrCpy ${OUT} ${OUT} "" 1
    StrCpy $2 ${OUT} 1 -1
    StrCmp $2 '"' 0 pp_rd_end_${pprd}
    StrLen $3 ${OUT}
    IntOp $3 $3 - 1
    StrCpy ${OUT} ${OUT} $3
  pp_rd_end_${pprd}:
  !undef pprd
!macroend

; /NAME is present when it is its own switch: end, space, or quote after it.
; OUT must not be $1-$4. /WIPE and /KEEP are read this way.
!macro ppHasSwitch NAME OUT
  !define pphs ${__COUNTER__}
  StrCpy ${OUT} "0"
  System::Call 'kernel32::GetCommandLineW()w .r1'
  StrLen $2 "/${NAME}"
  StrCpy $3 0
  pp_hs_scan_${pphs}:
    StrCpy $4 $1 $2 $3
    StrCmp $4 "" pp_hs_end_${pphs}
    StrCmp $4 "/${NAME}" 0 pp_hs_next_${pphs}
    ${If} $3 <> 0
      IntOp $4 $3 - 1
      StrCpy $4 $1 1 $4
      StrCmp $4 " " pp_hs_edge_${pphs}
      StrCmp $4 '"' pp_hs_edge_${pphs}
      Goto pp_hs_next_${pphs}
    ${EndIf}
  pp_hs_edge_${pphs}:
    IntOp $4 $3 + $2
    StrCpy $4 $1 1 $4
    StrCmp $4 "" pp_hs_yes_${pphs}
    StrCmp $4 " " pp_hs_yes_${pphs}
    StrCmp $4 '"' pp_hs_yes_${pphs}
    Goto pp_hs_next_${pphs}
  pp_hs_yes_${pphs}:
    StrCpy ${OUT} "1"
    Goto pp_hs_end_${pphs}
  pp_hs_next_${pphs}:
    IntOp $3 $3 + 1
    Goto pp_hs_scan_${pphs}
  pp_hs_end_${pphs}:
  !undef pphs
!macroend

; C:\Prompt Picker when this user can create it. Otherwise the profile folder.
; Never ask for administrator just to reach the default.
!macro ppChooseDefaultDir
  !define ppcd ${__COUNTER__}
  ClearErrors
  CreateDirectory "C:\Prompt Picker"
  IfErrors pp_cd_user_${ppcd}
    StrCpy $INSTDIR "C:\Prompt Picker"
    Goto pp_cd_end_${ppcd}
  pp_cd_user_${ppcd}:
    StrCpy $INSTDIR "$PROFILE\Prompt Picker"
  pp_cd_end_${ppcd}:
  !undef ppcd
!macroend

!macro ppNormalizeInstDir
  !define ppnd ${__COUNTER__}
  StrLen $R7 $INSTDIR
  ${If} $R7 > 3
    StrCpy $R8 $INSTDIR 1 -1
    ${If} $R8 == "\"
      IntOp $R7 $R7 - 1
      StrCpy $INSTDIR $INSTDIR $R7
    ${EndIf}
  ${EndIf}
  StrLen $R7 $INSTDIR
  ${If} $R7 < 4
    StrCpy $R8 $INSTDIR 1
    StrCpy $INSTDIR "$R8:\Prompt Picker"
  ${EndIf}
  !undef ppnd
!macroend

!macro ppCanWriteInstDir RESULT
  !define ppcw ${__COUNTER__}
  ClearErrors
  CreateDirectory "$INSTDIR"
  IfErrors pp_cw_no_${ppcw}
  ClearErrors
  FileOpen $R8 "$INSTDIR\pp-write-test.tmp" w
  IfErrors pp_cw_no_${ppcw}
  FileClose $R8
  Delete "$INSTDIR\pp-write-test.tmp"
  StrCpy ${RESULT} "1"
  Goto pp_cw_end_${ppcw}
  pp_cw_no_${ppcw}:
    StrCpy ${RESULT} "0"
  pp_cw_end_${ppcw}:
  !undef ppcw
!macroend

; Runs at the end of setInstallModePerUser, which would otherwise put a fresh
; install in %LocalAppData%\Programs. /D= and an existing folder already won.
; A writable probe of C:\Prompt Picker is removed when that is not the folder.
!macro ppAfterInstallMode
  !ifndef BUILD_UNINSTALLER
    !define ppa ${__COUNTER__}
    !insertmacro ppReadDSwitch $R0
    ${If} $R0 != ""
      StrCpy $INSTDIR $R0
      StrCpy $ppDirChosen "1"
      Goto pp_after_norm_${ppa}
    ${EndIf}
    ${If} $ppDirChosen == "1"
      StrCpy $INSTDIR $ppKeepDir
      Goto pp_after_norm_${ppa}
    ${EndIf}
    ${If} $ppKeepDir != ""
      StrCpy $INSTDIR $ppKeepDir
      Goto pp_after_norm_${ppa}
    ${EndIf}
    IfFileExists "$INSTDIR\${APP_EXECUTABLE_FILENAME}" pp_after_norm_${ppa}
    !insertmacro ppChooseDefaultDir
    pp_after_norm_${ppa}:
    !insertmacro ppNormalizeInstDir
    ${If} $ppDirChosen == "1"
    ${OrIf} $ppKeepDir != ""
      StrCpy $ppKeepDir $INSTDIR
    ${EndIf}
    ${If} $INSTDIR != "C:\Prompt Picker"
      RMDir "C:\Prompt Picker"
    ${EndIf}
    !undef ppa
  !endif
!macroend

; Keep the folder from the directory page. Elevate only when it cannot be written.
!macro ppPrepareInstallDir
  !insertmacro ppNormalizeInstDir
  ${If} $INSTDIR != "C:\Prompt Picker"
    RMDir "C:\Prompt Picker"
  ${EndIf}
  !insertmacro ppCanWriteInstDir $R9
  ${If} $R9 == "0"
    ${IfNot} ${UAC_IsAdmin}
      WriteRegStr HKCU "Software\Prompt Picker" "PendingInstallDir" "$INSTDIR"
      ShowWindow $HWNDPARENT ${SW_HIDE}
      !insertmacro UAC_RunElevated
      ${If} $0 = 0
      ${AndIf} $1 = 1
        Quit
      ${EndIf}
      DeleteRegValue HKCU "Software\Prompt Picker" "PendingInstallDir"
      MessageBox MB_ICONSTOP|MB_OK "Prompt Picker could not get permission to install in $INSTDIR." /SD IDOK
      ShowWindow $HWNDPARENT ${SW_SHOW}
      Abort
    ${Else}
      MessageBox MB_ICONSTOP|MB_OK "Prompt Picker cannot write to $INSTDIR." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
!macroend

!macro ppMaybeElevateSilent
  !insertmacro ppCanWriteInstDir $R9
  ${If} $R9 == "0"
    ${IfNot} ${UAC_IsAdmin}
      WriteRegStr HKCU "Software\Prompt Picker" "PendingInstallDir" "$INSTDIR"
      !insertmacro UAC_RunElevated
      ${If} $0 = 0
      ${AndIf} $1 = 1
        Quit
      ${EndIf}
      DeleteRegValue HKCU "Software\Prompt Picker" "PendingInstallDir"
      MessageBox MB_ICONSTOP|MB_OK "Prompt Picker could not get permission to install in $INSTDIR." /SD IDOK
      Quit
    ${Else}
      MessageBox MB_ICONSTOP|MB_OK "Prompt Picker cannot write to $INSTDIR." /SD IDOK
      Quit
    ${EndIf}
  ${EndIf}
!macroend

; Defined from customHeader, after NSIS plugins are on the search path.
; A function in this include runs while the header is still loading, and
; ${isUpdated} calls StdUtils before that plugin directory exists.
!macro customHeader
  !ifndef BUILD_UNINSTALLER
    Function ppDirPre
      ${If} ${Silent}
      ${OrIf} ${isUpdated}
      ${OrIf} $ppDirChosen == "1"
        Abort
      ${EndIf}
    FunctionEnd

    ; Same reason as ppDirPre: ${isUpdated} needs StdUtils, which is not
    ; on the plugin path while this include is still loading.
    Function ppShortcutPage
      ${If} ${Silent}
      ${OrIf} ${isUpdated}
        Abort
      ${EndIf}
      nsDialogs::Create 1018
      Pop $0
      ${If} $0 == error
        Abort
      ${EndIf}
      !insertmacro ppText "desktop" $R9
      ${NSD_CreateCheckbox} 0 0 100% 18u "$R9"
      Pop $ppDesktopCheckbox
      ${If} $ppDesktopShortcut == "0"
        ${NSD_SetState} $ppDesktopCheckbox ${BST_UNCHECKED}
      ${Else}
        ${NSD_SetState} $ppDesktopCheckbox ${BST_CHECKED}
      ${EndIf}
      !insertmacro ppText "nostart" $R9
      ${NSD_CreateLabel} 0 28u 100% 32u "$R9"
      Pop $0
      nsDialogs::Show
    FunctionEnd

    Function ppShortcutLeave
      ${NSD_GetState} $ppDesktopCheckbox $0
      ${If} $0 == ${BST_CHECKED}
        StrCpy $ppDesktopShortcut "1"
      ${Else}
        StrCpy $ppDesktopShortcut "0"
      ${EndIf}
      WriteRegStr HKCU "Software\Prompt Picker" DesktopShortcut "$ppDesktopShortcut"
      WriteRegStr HKCU "Software\Prompt Picker" StartMenuShortcut "0"
    FunctionEnd
  !endif
!macroend

; Per-user install. Administrator is requested later, and only for a folder
; this user cannot write.
!macro customInstallMode
  !ifndef BUILD_UNINSTALLER
    StrCpy $isForceCurrentInstall "1"
  !else
    ${if} $hasPerUserInstallation == "1"
    ${andIf} $hasPerMachineInstallation == "0"
      StrCpy $isForceCurrentInstall "1"
    ${elseif} $hasPerMachineInstallation == "1"
    ${andIf} $hasPerUserInstallation == "0"
      StrCpy $isForceMachineInstall "1"
    ${endIf}
  !endif
!macroend

!macro customInit
  StrCpy $ppKeepDir ""
  StrCpy $ppDirChosen "0"
  WriteRegStr HKCU "Software\Prompt Picker" "Installer Language" "$LANGUAGE"

  ReadRegStr $0 HKCU "Software\Prompt Picker" "PendingInstallDir"
  ${If} $0 != ""
    StrCpy $INSTDIR $0
    StrCpy $ppKeepDir $0
    StrCpy $ppDirChosen "1"
    DeleteRegValue HKCU "Software\Prompt Picker" "PendingInstallDir"
    Goto pp_init_ready
  ${EndIf}

  !insertmacro ppReadDSwitch $0
  ${If} $0 != ""
    StrCpy $INSTDIR $0
    StrCpy $ppKeepDir $0
    StrCpy $ppDirChosen "1"
    Goto pp_init_ready
  ${EndIf}

  ${If} $hasPerUserInstallation == "1"
    IfFileExists "$perUserInstallationFolder\*.*" 0 pp_stale_user
      StrCpy $ppKeepDir $perUserInstallationFolder
      StrCpy $INSTDIR $perUserInstallationFolder
      Goto pp_init_ready
    pp_stale_user:
      DeleteRegValue HKCU "${INSTALL_REGISTRY_KEY}" "InstallLocation"
      DeleteRegValue HKCU "Software\Prompt Picker" "InstallLocation"
      ClearErrors
      DeleteRegValue HKLM "${INSTALL_REGISTRY_KEY}" "InstallLocation"
      ClearErrors
      StrCpy $hasPerUserInstallation "0"
      StrCpy $perUserInstallationFolder ""
  ${EndIf}

  ${If} $hasPerMachineInstallation == "1"
    IfFileExists "$perMachineInstallationFolder\*.*" 0 pp_stale_machine
      StrCpy $ppKeepDir $perMachineInstallationFolder
      StrCpy $INSTDIR $perMachineInstallationFolder
      Goto pp_init_ready
    pp_stale_machine:
      ClearErrors
      DeleteRegValue HKLM "${INSTALL_REGISTRY_KEY}" "InstallLocation"
      ClearErrors
      StrCpy $hasPerMachineInstallation "0"
  ${EndIf}

  ; A keep-data uninstall leaves the folder and the marker, but the exe is
  ; already gone, so the per-user key may not have been restored yet.
  ; Prefill $INSTDIR. Do not set ppDirChosen: the directory page stays visible.
  ReadRegStr $0 HKCU "Software\Prompt Picker" InstallLocation
  !insertmacro ppMarkerAccepts $0 $R9
  ${If} $R9 == "1"
    StrCpy $INSTDIR $0
    StrCpy $ppKeepDir $0
    Goto pp_init_ready
  ${EndIf}
  !insertmacro ppReadPointerInstallDir $0
  !insertmacro ppMarkerAccepts $0 $R9
  ${If} $R9 == "1"
    StrCpy $INSTDIR $0
    StrCpy $ppKeepDir $0
    Goto pp_init_ready
  ${EndIf}

  !insertmacro ppChooseDefaultDir

  pp_init_ready:
  !insertmacro ppNormalizeInstDir
  ${If} $ppDirChosen == "1"
  ${OrIf} $ppKeepDir != ""
    StrCpy $ppKeepDir $INSTDIR
  ${EndIf}
  StrCpy $ppDesktopShortcut "1"
  ${If} ${isNoDesktopShortcut}
    StrCpy $ppDesktopShortcut "0"
  ${Else}
    ReadRegStr $R8 HKCU "Software\Prompt Picker" DesktopShortcut
    ${If} $R8 == "0"
      StrCpy $ppDesktopShortcut "0"
    ${EndIf}
  ${EndIf}
  ${If} ${Silent}
  ${OrIf} ${isUpdated}
  ${OrIf} $ppDirChosen == "1"
    !insertmacro ppMaybeElevateSilent
  ${EndIf}
  ${If} $INSTDIR != "C:\Prompt Picker"
    RMDir "C:\Prompt Picker"
  ${EndIf}
!macroend

; Folder page, then the saved desktop-shortcut choice. Start Menu stays off.
!macro customPageAfterChangeDir
  !ifndef BUILD_UNINSTALLER
    Page custom ppShortcutPage ppShortcutLeave
  !endif
!macroend

; Desktop shortcut only, with no AppUserModelID. A Start Menu link that carries
; that id opens with "Unspecified error" even when the exe is on disk.
!macro customInstall
  StrCpy $appExe "$INSTDIR\${APP_EXECUTABLE_FILENAME}"
  SetShellVarContext current
  Delete "$SMPROGRAMS\${SHORTCUT_NAME}.lnk"
  Delete "$APPDATA\Microsoft\Windows\Start Menu\Programs\${SHORTCUT_NAME}.lnk"
  SetShellVarContext all
  Delete "$SMPROGRAMS\${SHORTCUT_NAME}.lnk"
  ClearErrors
  ${If} $installMode == "all"
    SetShellVarContext all
  ${Else}
    SetShellVarContext current
  ${EndIf}
  IfFileExists "$appExe" 0 pp_sc_skip
    ${If} $ppDesktopShortcut != "0"
      StrCpy $ppDesktopShortcut "1"
    ${EndIf}
    Delete "$newDesktopLink"
    ${If} $ppDesktopShortcut != "0"
      ; CreateShortCut uses $OUTDIR as the shortcut's Start In folder.
      SetOutPath $INSTDIR
      CreateShortCut "$newDesktopLink" "$appExe" "" "$appExe" 0
      StrCpy $launchLink "$newDesktopLink"
    ${Else}
      StrCpy $launchLink "$appExe"
    ${EndIf}
    IfFileExists "$launchLink" 0 pp_launch_exe
      Goto pp_launch_ok
    pp_launch_exe:
      StrCpy $launchLink "$appExe"
    pp_launch_ok:
    WriteRegStr HKCU "Software\Prompt Picker" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "Software\Prompt Picker" DesktopShortcut "$ppDesktopShortcut"
    WriteRegStr HKCU "Software\Prompt Picker" StartMenuShortcut "0"
    ; Remember the folder even if the app has not finished opening yet.
    StrCpy $R3 "$APPDATA\Prompt Picker\data"
    !insertmacro ppJsonEscape $INSTDIR $R1
    !insertmacro ppJsonEscape $R3 $R2
    StrCpy $R6 "$ppDesktopShortcut"
    CreateDirectory "$APPDATA\Prompt Picker"
    !insertmacro ppWriteMarkerFile "$INSTDIR\${PP_MARKER_NAME}"
    !insertmacro ppWriteMarkerFile "$APPDATA\Prompt Picker\${PP_MARKER_NAME}"
    System::Call 'Shell32::SHChangeNotify(i 0x8000000, i 0, i 0, i 0)'
  pp_sc_skip:
!macroend

!ifdef BUILD_UNINSTALLER

Var DeleteKeepRadio
Var DeleteWipeRadio

!macro customUnInit
  ; Silent with no flag wipes, so a scripted uninstall still starts clean.
  ; /WIPE overrides /KEEP. An interactive page can still switch to keep.
  StrCpy $DeleteData ${BST_CHECKED}
  !insertmacro ppHasSwitch "WIPE" $R0
  !insertmacro ppHasSwitch "KEEP" $R1
  ${If} $R0 == "1"
    StrCpy $DeleteData ${BST_CHECKED}
  ${ElseIf} $R1 == "1"
    StrCpy $DeleteData ${BST_UNCHECKED}
  ${EndIf}
  ReadRegStr $0 HKCU "Software\Prompt Picker" "Installer Language"
  ${If} $0 != ""
    StrCpy $LANGUAGE $0
  ${EndIf}
  !insertmacro ppResolveInstallDir
  !insertmacro ppCollectData
!macroend

!macro customUnWelcomePage
  UninstPage custom un.promptDataPage un.promptDataLeave
!macroend

Function un.promptDataPage
  ${If} ${Silent}
    Abort
  ${EndIf}
  !insertmacro ppResolveInstallDir
  !insertmacro ppCollectData
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}
  !insertmacro ppText "warn" $R9
  ${NSD_CreateLabel} 0 0 100% 48u "$R9"
  Pop $0
  !insertmacro ppText "keep" $R9
  ${NSD_CreateRadioButton} 0 52u 100% 14u "$R9"
  Pop $DeleteKeepRadio
  ${NSD_AddStyle} $DeleteKeepRadio 0x00020000
  !insertmacro ppText "wipe" $R9
  ${NSD_CreateRadioButton} 0 68u 100% 14u "$R9"
  Pop $DeleteWipeRadio
  ${If} $DeleteData == ${BST_CHECKED}
    ${NSD_SetState} $DeleteWipeRadio ${BST_CHECKED}
  ${Else}
    ${NSD_SetState} $DeleteKeepRadio ${BST_CHECKED}
  ${EndIf}
  !insertmacro ppText "paths" $R9
  ${If} $DataList == ""
    !insertmacro ppText "none" $R8
    StrCpy $R9 "$R9$\r$\n$R8"
  ${Else}
    StrCpy $R9 "$R9$\r$\n$DataList"
  ${EndIf}
  ${NSD_CreateLabel} 0 88u 100% 64u "$R9"
  Pop $0
  nsDialogs::Show
FunctionEnd

Function un.promptDataLeave
  ${NSD_GetState} $DeleteWipeRadio $DeleteData
  ${If} $DeleteData == ${BST_CHECKED}
    !insertmacro ppText "wipeConfirm" $R9
    MessageBox MB_ICONEXCLAMATION|MB_YESNO "$R9" /SD IDYES IDYES un_pp_wipe_ok
    Abort
  un_pp_wipe_ok:
  ${EndIf}
FunctionEnd

; Replaces electron-builder's RMDir /r $INSTDIR. Known program files are
; removed in place. The folder itself is removed only when data deletion
; was requested and nothing the user added is still inside it.
!macro customRemoveFiles
  !insertmacro ppResolveInstallDir
  !insertmacro ppInstallDirOk $R9
  ${If} $R9 == "1"
    !insertmacro ppDeleteKnownAppFiles
  ${EndIf}
!macroend

; The running uninstaller is locked when _?= keeps it in the install folder.
; A short cmd finishes after this process exits. Keep deletes only that exe.
; Wipe removes the folder. Skip this during an in-place update.
!macro ppFinishUninstall
  ${If} ${isUpdated}
  ${Else}
    !insertmacro ppInstallDirOk $R9
    ${If} $R9 == "1"
      SetOutPath $TEMP
      ClearErrors
      Delete "$TEMP\pp-finish-uninstall.cmd"
      FileOpen $R4 "$TEMP\pp-finish-uninstall.cmd" w
      ${IfNot} ${Errors}
        FileWrite $R4 "@echo off$\r$\n"
        FileWrite $R4 "ping 127.0.0.1 -n 3 >nul$\r$\n"
        ${If} $DeleteData == ${BST_CHECKED}
          FileWrite $R4 'rmdir /s /q "'
          FileWrite $R4 $InstallDir
          FileWrite $R4 '"$\r$\n'
        ${Else}
          FileWrite $R4 'del /f /q "'
          FileWrite $R4 "$InstallDir\${PP_UNINSTALL_EXE}"
          FileWrite $R4 '"$\r$\n'
        ${EndIf}
        FileWrite $R4 'del "%~f0"$\r$\n'
        FileClose $R4
        Exec '"$SYSDIR\cmd.exe" /c "$TEMP\pp-finish-uninstall.cmd"'
      ${EndIf}
    ${EndIf}
  ${EndIf}
!macroend

!macro customUnInstall
  ${ifNot} ${isUpdated}
    !insertmacro ppCleanShortcuts
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}"
    !ifdef UNINSTALL_APP_KEY
      DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTALL_APP_KEY}"
    !endif
    ${if} $DeleteData == ${BST_CHECKED}
      !insertmacro ppDeleteDetectedData
      !insertmacro ppDeletePointers
      RMDir /r "$APPDATA\Prompt Picker"
      !insertmacro ppInstallDirOk $R9
      ${If} $R9 == "1"
        SetOutPath $TEMP
        RMDir /r "$InstallDir"
      ${EndIf}
    ${else}
      !insertmacro ppWriteKeepPointers
    ${endIf}
    !insertmacro ppFinishUninstall
  ${endIf}
!macroend

!endif
