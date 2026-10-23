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
!macroend

!ifdef BUILD_UNINSTALLER

!macro customUnInit
  StrCpy $DeleteData ${BST_UNCHECKED}
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
  ${NSD_SetState} $DeleteDataCheckbox ${BST_UNCHECKED}
  StrCpy $DeleteData ${BST_UNCHECKED}
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

; Replaces electron-builder's RMDir /r $INSTDIR. Updates delete the shipped
; files in place and leave anything else. A real uninstall then removes the
; folder only when nothing the user added is still inside it.
!macro customRemoveFiles
  !insertmacro ppResolveInstallDir
  !insertmacro ppInstallDirOk $R9
  ${If} $R9 == "1"
    !insertmacro ppDeleteKnownAppFiles
    ${ifNot} ${isUpdated}
      SetOutPath $TEMP
      RMDir "$InstallDir"
    ${endIf}
  ${EndIf}
!macroend

!macro customUnInstall
  ${ifNot} ${isUpdated}
    !insertmacro ppCleanExtras
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}"
    !ifdef UNINSTALL_APP_KEY
      DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTALL_APP_KEY}"
    !endif
    ${if} $DeleteData == ${BST_CHECKED}
      !insertmacro ppDeleteDetectedData
    ${endIf}
  ${endIf}
!macroend

!endif
