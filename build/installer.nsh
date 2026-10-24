!include LogicLib.nsh
!include nsDialogs.nsh
!include /CHARSET=UTF8 "uninstall-logic.nsh"

!ifndef BUILD_UNINSTALLER
Var ppKeepDir
Var ppDirChosen
!endif

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
    ${StdUtils.GetParameter} $R0 "D" ""
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

  ${StdUtils.GetParameter} $0 "D" ""
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

  !insertmacro ppChooseDefaultDir

  pp_init_ready:
  !insertmacro ppNormalizeInstDir
  ${If} $ppDirChosen == "1"
  ${OrIf} $ppKeepDir != ""
    StrCpy $ppKeepDir $INSTDIR
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
    Delete "$newDesktopLink"
    CreateShortCut "$newDesktopLink" "$appExe" "" "$appExe" 0
    StrCpy $launchLink "$newDesktopLink"
    IfFileExists "$launchLink" 0 pp_launch_exe
      Goto pp_launch_ok
    pp_launch_exe:
      StrCpy $launchLink "$appExe"
    pp_launch_ok:
    WriteRegStr HKCU "Software\Prompt Picker" "InstallLocation" "$INSTDIR"
    System::Call 'Shell32::SHChangeNotify(i 0x8000000, i 0, i 0, i 0)'
  pp_sc_skip:
!macroend

!ifdef BUILD_UNINSTALLER

!macro customUnInit
  StrCpy $DeleteData ${BST_CHECKED}
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
  !insertmacro ppResolveInstallDir
  !insertmacro ppCollectData
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}
  !insertmacro ppText "warn" $R9
  ${NSD_CreateLabel} 0 0 100% 52u "$R9"
  Pop $0
  !insertmacro ppText "delete" $R9
  ${NSD_CreateCheckbox} 0 56u 100% 18u "$R9"
  Pop $DeleteDataCheckbox
  ${NSD_SetState} $DeleteDataCheckbox ${BST_CHECKED}
  StrCpy $DeleteData ${BST_CHECKED}
  !insertmacro ppText "paths" $R9
  ${If} $DataList == ""
    !insertmacro ppText "none" $R8
    StrCpy $R9 "$R9$\r$\n$R8"
  ${Else}
    StrCpy $R9 "$R9$\r$\n$DataList"
  ${EndIf}
  ${NSD_CreateLabel} 0 78u 100% 64u "$R9"
  Pop $0
  nsDialogs::Show
FunctionEnd

Function un.promptDataLeave
  ${NSD_GetState} $DeleteDataCheckbox $DeleteData
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
      !insertmacro ppInstallDirOk $R9
      ${If} $R9 == "1"
        SetOutPath $TEMP
        RMDir "$InstallDir"
      ${EndIf}
    ${else}
      !insertmacro ppWriteKeepPointers
    ${endIf}
  ${endIf}
!macroend

!endif
