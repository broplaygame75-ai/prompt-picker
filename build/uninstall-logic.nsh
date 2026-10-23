; Shared uninstall rules. Macros only, so the installer test and the
; NSIS uninstaller run the same file list, path checks, and data discovery.
!include LogicLib.nsh

!ifndef PP_APP_EXE
  !define PP_APP_EXE "${PRODUCT_FILENAME}.exe"
!endif
!ifndef PP_UNINSTALL_EXE
  !define PP_UNINSTALL_EXE "Uninstall ${PRODUCT_FILENAME}.exe"
!endif
!ifndef PP_SHORTCUT_NAME
  !ifdef SHORTCUT_NAME
    !define PP_SHORTCUT_NAME "${SHORTCUT_NAME}"
  !else
    !define PP_SHORTCUT_NAME "Prompt Picker"
  !endif
!endif
!ifndef INSTALL_REGISTRY_KEY
  !define INSTALL_REGISTRY_KEY "Software\05ae8bdf-b478-52b5-acc4-ac809166ef4d"
!endif

!ifdef BUILD_UNINSTALLER
  !define PP_DECLARE_VARS
!endif
!ifdef PP_LOGIC_TEST
  !define PP_DECLARE_VARS
!endif
!ifdef PP_DECLARE_VARS
Var InstallDir
Var DataPath1
Var DataPath2
Var DataPath3
Var DataPath4
Var DataList
Var DeleteData
Var DeleteDataCheckbox
!endif

!macro ppDirHasApp DIR RESULT
  !define ppdha ${__COUNTER__}
  StrCpy ${RESULT} "0"
  StrCmp "${DIR}" "" pp_dha_end_${ppdha}
  IfFileExists "${DIR}\${PP_APP_EXE}" 0 pp_dha_un_${ppdha}
    StrCpy ${RESULT} "1"
    Goto pp_dha_end_${ppdha}
  pp_dha_un_${ppdha}:
  IfFileExists "${DIR}\${PP_UNINSTALL_EXE}" 0 pp_dha_asar_${ppdha}
    StrCpy ${RESULT} "1"
    Goto pp_dha_end_${ppdha}
  pp_dha_asar_${ppdha}:
  IfFileExists "${DIR}\resources\app.asar" 0 pp_dha_end_${ppdha}
    StrCpy ${RESULT} "1"
  pp_dha_end_${ppdha}:
  !undef ppdha
!macroend

; Prefer the folder recorded at install time. Fall back to this uninstaller
; directory only when the registry entry is missing or does not contain the app.
!macro ppResolveInstallDir
  !define ppres ${__COUNTER__}
  StrCpy $InstallDir ""

  ReadRegStr $0 HKCU "${INSTALL_REGISTRY_KEY}" InstallLocation
  !insertmacro ppDirHasApp $0 $R9
  StrCmp $R9 "1" 0 pp_res_hklm_${ppres}
    StrCpy $InstallDir $0
    Goto pp_res_done_${ppres}
  pp_res_hklm_${ppres}:
  ReadRegStr $0 HKLM "${INSTALL_REGISTRY_KEY}" InstallLocation
  !insertmacro ppDirHasApp $0 $R9
  StrCmp $R9 "1" 0 pp_res_pp_${ppres}
    StrCpy $InstallDir $0
    Goto pp_res_done_${ppres}
  pp_res_pp_${ppres}:
  ReadRegStr $0 HKCU "Software\Prompt Picker" InstallLocation
  !insertmacro ppDirHasApp $0 $R9
  StrCmp $R9 "1" 0 pp_res_inst_${ppres}
    StrCpy $InstallDir $0
    Goto pp_res_done_${ppres}
  pp_res_inst_${ppres}:
  !insertmacro ppDirHasApp $INSTDIR $R9
  StrCmp $R9 "1" 0 pp_res_exe_${ppres}
    StrCpy $InstallDir $INSTDIR
    Goto pp_res_done_${ppres}
  pp_res_exe_${ppres}:
  !insertmacro ppDirHasApp $EXEDIR $R9
  StrCmp $R9 "1" 0 pp_res_stale_${ppres}
    StrCpy $InstallDir $EXEDIR
    Goto pp_res_done_${ppres}
  pp_res_stale_${ppres}:
  ReadRegStr $0 HKCU "${INSTALL_REGISTRY_KEY}" InstallLocation
  StrCmp $0 "" pp_res_stale_lm_${ppres}
  IfFileExists "$0\*.*" 0 pp_res_stale_lm_${ppres}
    StrCpy $InstallDir $0
    Goto pp_res_done_${ppres}
  pp_res_stale_lm_${ppres}:
  ReadRegStr $0 HKLM "${INSTALL_REGISTRY_KEY}" InstallLocation
  StrCmp $0 "" pp_res_stale_pp_${ppres}
  IfFileExists "$0\*.*" 0 pp_res_stale_pp_${ppres}
    StrCpy $InstallDir $0
    Goto pp_res_done_${ppres}
  pp_res_stale_pp_${ppres}:
  ReadRegStr $0 HKCU "Software\Prompt Picker" InstallLocation
  StrCmp $0 "" pp_res_fallback_${ppres}
  IfFileExists "$0\*.*" 0 pp_res_fallback_${ppres}
    StrCpy $InstallDir $0
    Goto pp_res_done_${ppres}
  pp_res_fallback_${ppres}:
  StrCpy $InstallDir $INSTDIR
  pp_res_done_${ppres}:
  !undef ppres
!macroend

; 1 when DIR is a specific folder we are allowed to remove. Never a drive root,
; a shell folder, or a parent of the install directory.
!macro ppPathBasicOk PATH
  !define ppok ${__COUNTER__}
  StrCpy $R9 "0"
  StrCmp "${PATH}" "" pp_ok_end_${ppok}
  StrLen $R8 "${PATH}"
  IntCmp $R8 4 pp_ok_len_${ppok} pp_ok_end_${ppok} pp_ok_len_${ppok}
  pp_ok_len_${ppok}:
  StrCpy $R7 "${PATH}" "" -2
  ${If} $R7 == ":\"
    Goto pp_ok_end_${ppok}
  ${EndIf}
  ${If} "${PATH}" == "$InstallDir"
  ${OrIf} "${PATH}" == "$INSTDIR"
  ${OrIf} "${PATH}" == "$APPDATA"
  ${OrIf} "${PATH}" == "$LOCALAPPDATA"
  ${OrIf} "${PATH}" == "$PROFILE"
  ${OrIf} "${PATH}" == "$DESKTOP"
  ${OrIf} "${PATH}" == "$PROGRAMFILES"
  ${OrIf} "${PATH}" == "$PROGRAMFILES64"
  ${OrIf} "${PATH}" == "$WINDIR"
  ${OrIf} "${PATH}" == "$SYSDIR"
  ${OrIf} "${PATH}" == "$TEMP"
  ${OrIf} "${PATH}" == "$LOCALAPPDATA\Programs"
    Goto pp_ok_end_${ppok}
  ${EndIf}
  ${If} $InstallDir != ""
    StrCpy $R7 "${PATH}\"
    StrLen $R8 $R7
    StrCpy $R6 "$InstallDir" $R8
    ${If} $R6 == $R7
      Goto pp_ok_end_${ppok}
    ${EndIf}
  ${EndIf}
  IfFileExists "${PATH}\*.*" 0 pp_ok_end_${ppok}
  StrCpy $R9 "1"
  pp_ok_end_${ppok}:
  !undef ppok
!macroend

!macro ppInstallDirOk RESULT
  !define ppinst ${__COUNTER__}
  StrCpy ${RESULT} "0"
  StrCmp $InstallDir "" pp_inst_end_${ppinst}
  StrLen $R8 $InstallDir
  IntCmp $R8 4 pp_inst_len_${ppinst} pp_inst_end_${ppinst} pp_inst_len_${ppinst}
  pp_inst_len_${ppinst}:
  StrCpy $R7 $InstallDir "" -2
  ${If} $R7 == ":\"
    Goto pp_inst_end_${ppinst}
  ${EndIf}
  ${If} $InstallDir == "$PROGRAMFILES"
  ${OrIf} $InstallDir == "$PROGRAMFILES64"
  ${OrIf} $InstallDir == "$WINDIR"
  ${OrIf} $InstallDir == "$SYSDIR"
  ${OrIf} $InstallDir == "$APPDATA"
  ${OrIf} $InstallDir == "$LOCALAPPDATA"
  ${OrIf} $InstallDir == "$PROFILE"
  ${OrIf} $InstallDir == "$DESKTOP"
  ${OrIf} $InstallDir == "$TEMP"
  ${OrIf} $InstallDir == "$LOCALAPPDATA\Programs"
    Goto pp_inst_end_${ppinst}
  ${EndIf}
  IfFileExists "$InstallDir\*.*" 0 pp_inst_end_${ppinst}
  StrCpy ${RESULT} "1"
  pp_inst_end_${ppinst}:
  !undef ppinst
!macroend

!macro ppPushData PATH
  !define pppush ${__COUNTER__}
  !insertmacro ppPathBasicOk "${PATH}"
  StrCmp $R9 "1" 0 pp_push_end_${pppush}
  ${If} $DataPath1 == "${PATH}"
  ${OrIf} $DataPath2 == "${PATH}"
  ${OrIf} $DataPath3 == "${PATH}"
  ${OrIf} $DataPath4 == "${PATH}"
    Goto pp_push_end_${pppush}
  ${EndIf}
  ${If} $DataPath1 == ""
    StrCpy $DataPath1 "${PATH}"
  ${ElseIf} $DataPath2 == ""
    StrCpy $DataPath2 "${PATH}"
  ${ElseIf} $DataPath3 == ""
    StrCpy $DataPath3 "${PATH}"
  ${ElseIf} $DataPath4 == ""
    StrCpy $DataPath4 "${PATH}"
  ${Else}
    Goto pp_push_end_${pppush}
  ${EndIf}
  ${If} $DataList == ""
    StrCpy $DataList "${PATH}"
  ${Else}
    StrCpy $DataList "$DataList$\r$\n${PATH}"
  ${EndIf}
  pp_push_end_${pppush}:
  !undef pppush
!macroend

; Custom folders must look like prompt data. A registry value that points at a
; drive or at the install folder itself is ignored.
!macro ppPushCustom PATH
  !define ppcus ${__COUNTER__}
  StrCmp "${PATH}" "" pp_cus_end_${ppcus}
  !insertmacro ppPathBasicOk "${PATH}"
  StrCmp $R9 "1" 0 pp_cus_end_${ppcus}
  IfFileExists "${PATH}\prompts.json" pp_cus_yes_${ppcus} 0
  IfFileExists "${PATH}\images\*.*" pp_cus_yes_${ppcus} pp_cus_end_${ppcus}
  pp_cus_yes_${ppcus}:
  !insertmacro ppPushData "${PATH}"
  pp_cus_end_${ppcus}:
  !undef ppcus
!macroend

!macro ppJsonField HAYSTACK KEY OUT
  !define ppjs ${__COUNTER__}
  StrCpy ${OUT} ""
  StrLen $R5 "${KEY}"
  StrCpy $R6 0
  pp_js_scan_${ppjs}:
    StrCpy $R7 ${HAYSTACK} $R5 $R6
    StrCmp $R7 "" pp_js_end_${ppjs}
    StrCmp $R7 "${KEY}" pp_js_hit_${ppjs}
    IntOp $R6 $R6 + 1
    Goto pp_js_scan_${ppjs}
  pp_js_hit_${ppjs}:
    IntOp $R6 $R6 + $R5
    StrCpy ${OUT} ""
  pp_js_char_${ppjs}:
    StrCpy $R7 ${HAYSTACK} 1 $R6
    StrCmp $R7 "" pp_js_end_${ppjs}
    StrCmp $R7 '"' pp_js_end_${ppjs}
    StrCmp $R7 "\" 0 pp_js_plain_${ppjs}
      IntOp $R6 $R6 + 1
      StrCpy $R7 ${HAYSTACK} 1 $R6
      StrCmp $R7 "" pp_js_end_${ppjs}
    pp_js_plain_${ppjs}:
    StrCpy ${OUT} "${OUT}$R7"
    IntOp $R6 $R6 + 1
    Goto pp_js_char_${ppjs}
  pp_js_end_${ppjs}:
  !undef ppjs
!macroend

!macro ppTrimLine VAR
  !define pptrim ${__COUNTER__}
  pp_trim_${pptrim}:
    StrCpy $R5 ${VAR} 1 -1
    StrCmp $R5 "$\r" 0 pp_trim_n_${pptrim}
      StrCpy ${VAR} ${VAR} -1
      Goto pp_trim_${pptrim}
    pp_trim_n_${pptrim}:
    StrCmp $R5 "$\n" 0 pp_trim_end_${pptrim}
      StrCpy ${VAR} ${VAR} -1
      Goto pp_trim_${pptrim}
  pp_trim_end_${pptrim}:
  !undef pptrim
!macroend

!macro ppReadActiveDataDir OUT
  !define ppcfg ${__COUNTER__}
  StrCpy ${OUT} ""
  ClearErrors
  FileOpen $R4 "$APPDATA\Prompt Picker\config.json" r
  IfErrors pp_cfg_end_${ppcfg}
  FileRead $R4 $R8
  FileClose $R4
  StrCpy $R2 '"activeDataDir":"'
  !insertmacro ppJsonField $R8 $R2 $R3
  StrCpy ${OUT} $R3
  pp_cfg_end_${ppcfg}:
  !undef ppcfg
!macroend

!macro ppReadDataPathFile OUT
  !define ppdp ${__COUNTER__}
  StrCpy ${OUT} ""
  ClearErrors
  FileOpen $R4 "$APPDATA\Prompt Picker\data.path" r
  IfErrors pp_dp_end_${ppdp}
  FileRead $R4 $R8
  FileClose $R4
  !insertmacro ppTrimLine $R8
  StrCpy ${OUT} $R8
  pp_dp_end_${ppdp}:
  !undef ppdp
!macroend

!macro ppCollectData
  !define ppcol ${__COUNTER__}
  StrCpy $DataPath1 ""
  StrCpy $DataPath2 ""
  StrCpy $DataPath3 ""
  StrCpy $DataPath4 ""
  StrCpy $DataList ""
  !insertmacro ppPushData "$APPDATA\Prompt Picker\data"
  StrCmp $InstallDir "" pp_col_reg_${ppcol}
  !insertmacro ppPushData "$InstallDir\PromptPickerData"
  IfFileExists "$InstallDir\data\prompts.json" 0 pp_col_reg_${ppcol}
    !insertmacro ppPushData "$InstallDir\data"
  pp_col_reg_${ppcol}:
  ReadRegStr $0 HKCU "Software\Prompt Picker" DataDir
  !insertmacro ppPushCustom $0
  ReadRegStr $0 HKCU "${INSTALL_REGISTRY_KEY}" DataDir
  !insertmacro ppPushCustom $0
  !insertmacro ppReadActiveDataDir $0
  !insertmacro ppPushCustom $0
  !insertmacro ppReadDataPathFile $0
  !insertmacro ppPushCustom $0
  !undef ppcol
!macroend

!macro ppDeleteOne DIR NAME
  Delete "${DIR}\${NAME}"
!macroend

; Only the files this app ships. A dll, exe, or note the user dropped in the
; folder is left alone. locales\ and resources\ belong to the app.
!macro ppDeleteKnownAppFiles
  !define ppdel ${__COUNTER__}
  !insertmacro ppInstallDirOk $R9
  StrCmp $R9 "1" 0 pp_del_end_${ppdel}
  SetOutPath $TEMP
  !insertmacro ppDeleteOne $InstallDir "${PP_APP_EXE}"
  !insertmacro ppDeleteOne $InstallDir "${PP_UNINSTALL_EXE}"
  !insertmacro ppDeleteOne $InstallDir "uninstallerIcon.ico"
  !insertmacro ppDeleteOne $InstallDir "chrome_100_percent.pak"
  !insertmacro ppDeleteOne $InstallDir "chrome_200_percent.pak"
  !insertmacro ppDeleteOne $InstallDir "resources.pak"
  !insertmacro ppDeleteOne $InstallDir "icudtl.dat"
  !insertmacro ppDeleteOne $InstallDir "snapshot_blob.bin"
  !insertmacro ppDeleteOne $InstallDir "v8_context_snapshot.bin"
  !insertmacro ppDeleteOne $InstallDir "vk_swiftshader_icd.json"
  !insertmacro ppDeleteOne $InstallDir "LICENSE.electron.txt"
  !insertmacro ppDeleteOne $InstallDir "LICENSES.chromium.html"
  !insertmacro ppDeleteOne $InstallDir "LICENSE"
  !insertmacro ppDeleteOne $InstallDir "d3dcompiler_47.dll"
  !insertmacro ppDeleteOne $InstallDir "ffmpeg.dll"
  !insertmacro ppDeleteOne $InstallDir "libEGL.dll"
  !insertmacro ppDeleteOne $InstallDir "libGLESv2.dll"
  !insertmacro ppDeleteOne $InstallDir "vk_swiftshader.dll"
  !insertmacro ppDeleteOne $InstallDir "vulkan-1.dll"
  !insertmacro ppDeleteOne $InstallDir "dxcompiler.dll"
  !insertmacro ppDeleteOne $InstallDir "dxil.dll"
  !insertmacro ppDeleteOne $InstallDir "chrome_elf.dll"
  RMDir /r "$InstallDir\locales"
  RMDir /r "$InstallDir\resources"
  pp_del_end_${ppdel}:
  !undef ppdel
!macroend

!macro ppDeleteDetectedData
  !insertmacro ppPathBasicOk $DataPath1
  StrCmp $R9 "1" 0 +2
    RMDir /r "$DataPath1"
  !insertmacro ppPathBasicOk $DataPath2
  StrCmp $R9 "1" 0 +2
    RMDir /r "$DataPath2"
  !insertmacro ppPathBasicOk $DataPath3
  StrCmp $R9 "1" 0 +2
    RMDir /r "$DataPath3"
  !insertmacro ppPathBasicOk $DataPath4
  StrCmp $R9 "1" 0 +2
    RMDir /r "$DataPath4"
  RMDir "$APPDATA\Prompt Picker"
!macroend

!macro ppCleanExtras
  SetOutPath $TEMP
  RMDir /r "$LOCALAPPDATA\prompt-picker-updater"
  Delete "$DESKTOP\${PP_SHORTCUT_NAME}.lnk"
  Delete "$SMPROGRAMS\${PP_SHORTCUT_NAME}.lnk"
  Delete "$APPDATA\Prompt Picker\data.path"
  DeleteRegKey HKCU "Software\Prompt Picker"
  DeleteRegKey HKCU "${INSTALL_REGISTRY_KEY}"
  DeleteRegKey HKLM "${INSTALL_REGISTRY_KEY}"
!macroend

!macro ppText ID OUT
  !define pptxt ${__COUNTER__}
  StrCmp "${ID}" "warn" 0 pp_txt_del_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Nếu bạn còn dữ liệu prompt, hãy mở Prompt Picker và xuất bản sao lưu JSON (Cài đặt > Sao lưu & Nhập dữ liệu) trước khi gỡ cài đặt."
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "如果仍有提示词数据，请在卸载前打开 Prompt Picker，并导出 JSON 备份（设置 > 备份与导入）。"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "프롬프트 데이터가 남아 있다면, 제거하기 전에 Prompt Picker를 열고 JSON 백업을 내보내세요(설정 > 백업 및 가져오기)."
    ${Else}
      StrCpy ${OUT} "If you still have prompt data, open Prompt Picker and export a JSON backup (Settings > Backup & Import) before uninstalling."
    ${EndIf}
    Goto pp_txt_end_${pptxt}
  pp_txt_del_${pptxt}:
  StrCmp "${ID}" "delete" 0 pp_txt_paths_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Xoá các thư mục dữ liệu prompt liệt kê bên dưới"
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "删除下面列出的提示词数据文件夹"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "아래에 나열된 프롬프트 데이터 폴더를 삭제"
    ${Else}
      StrCpy ${OUT} "Delete the prompt data folders listed below"
    ${EndIf}
    Goto pp_txt_end_${pptxt}
  pp_txt_paths_${pptxt}:
  StrCmp "${ID}" "paths" 0 pp_txt_none_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Thư mục dữ liệu tìm thấy:"
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "检测到的数据文件夹："
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "찾은 데이터 폴더:"
    ${Else}
      StrCpy ${OUT} "Detected data folders:"
    ${EndIf}
    Goto pp_txt_end_${pptxt}
  pp_txt_none_${pptxt}:
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Không thấy thư mục dữ liệu prompt."
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "未找到提示词数据文件夹。"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "프롬프트 데이터 폴더를 찾지 못했습니다."
    ${Else}
      StrCpy ${OUT} "No prompt data folder was found."
    ${EndIf}
  pp_txt_end_${pptxt}:
  !undef pptxt
!macroend
