!include LogicLib.nsh
!include nsDialogs.nsh
!include /CHARSET=UTF8 "uninstall-logic.nsh"

; An existing install stays on its current per-user or per-machine directory.
; Do not offer a second copy beside it.
!macro customInstallMode
  ${if} $hasPerUserInstallation == "1"
  ${andIf} $hasPerMachineInstallation == "0"
    StrCpy $isForceCurrentInstall "1"
  ${elseif} $hasPerMachineInstallation == "1"
  ${andIf} $hasPerUserInstallation == "0"
    StrCpy $isForceMachineInstall "1"
  ${endIf}
!macroend

!macro customInit
  WriteRegStr HKCU "Software\Prompt Picker" "Installer Language" "$LANGUAGE"
  ; /D= is an explicit folder. A real electron-builder install key is an
  ; in-place upgrade. Otherwise reopen a folder left behind only when its
  ; marker app id is Prompt Picker.
  ${StdUtils.GetParameter} $0 "D" ""
  ${If} $0 == ""
    !ifndef ONE_CLICK
      ${If} $hasPerUserInstallation == "0"
      ${AndIf} $hasPerMachineInstallation == "0"
        !insertmacro ppApplyKeptInstall
      ${EndIf}
    !endif
  ${EndIf}
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
