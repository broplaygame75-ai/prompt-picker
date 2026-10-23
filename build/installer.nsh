!include LogicLib.nsh
!include nsDialogs.nsh

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

!ifdef BUILD_UNINSTALLER
Var DeleteDataCheckbox
Var DeleteData

!macro customUnWelcomePage
  UninstPage custom un.promptDataPage un.promptDataLeave
!macroend

Function un.promptDataPage
  ; /S upgrades never show this page. The delete itself is guarded in customUnInstall.
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}
  ${NSD_CreateLabel} 0 0 100% 48u "Gỡ Prompt Picker chỉ xoá chương trình. Prompt và ảnh được giữ nguyên, trừ khi bạn tick ô bên dưới."
  Pop $1
  ${NSD_CreateCheckbox} 0 56u 100% 24u "Xoá dữ liệu prompt trong $APPDATA\Prompt Picker\data"
  Pop $DeleteDataCheckbox
  ${NSD_SetState} $DeleteDataCheckbox ${BST_UNCHECKED}
  nsDialogs::Show
FunctionEnd

Function un.promptDataLeave
  ${NSD_GetState} $DeleteDataCheckbox $DeleteData
FunctionEnd

; deleteAppDataOnUninstall is off. Data is removed only when a real uninstall
; shows this page and the box is ticked. Upgrades pass --updated and /S.
!macro customUnInstall
  ${ifNot} ${isUpdated}
  ${andIfNot} ${Silent}
  ${andIf} $DeleteData == ${BST_CHECKED}
    RMDir /r "$APPDATA\Prompt Picker\data"
  ${endIf}
!macroend
!endif
