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
!ifndef PP_MARKER_NAME
  !define PP_MARKER_NAME "prompt-picker.install.json"
!endif
!ifndef PP_APP_ID
  !ifdef APP_ID
    !define PP_APP_ID "${APP_ID}"
  !else
    !define PP_APP_ID "com.lineko.promptpicker"
  !endif
!endif
!ifndef VERSION
  !define VERSION "0.0.0"
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

; 1 when PATH sits inside a different verified Prompt Picker install.
; The folder being removed still loses its own data. AppData and a custom
; folder with no matching marker are not protected by this check.
!macro ppSkipForeignData PATH RESULT
  !define ppsf ${__COUNTER__}
  StrCpy ${RESULT} "0"
  StrCmp "${PATH}" "" pp_sf_end_${ppsf}
  StrLen $R8 "${PATH}"
  StrCpy $R5 $R8
  pp_sf_scan_${ppsf}:
    IntOp $R5 $R5 - 1
    IntCmp $R5 0 pp_sf_end_${ppsf} pp_sf_end_${ppsf}
    StrCpy $R7 "${PATH}" 1 $R5
    StrCmp $R7 "\" pp_sf_parent_${ppsf}
    Goto pp_sf_scan_${ppsf}
  pp_sf_parent_${ppsf}:
    StrCpy $R1 "${PATH}" $R5
    StrCmp $R1 "$InstallDir" pp_sf_end_${ppsf}
    StrCmp $R1 "$INSTDIR" pp_sf_end_${ppsf}
    !insertmacro ppMarkerAccepts $R1 $R9
    StrCmp $R9 "1" 0 pp_sf_end_${ppsf}
    StrCpy ${RESULT} "1"
  pp_sf_end_${ppsf}:
  !undef ppsf
!macroend

!macro ppDeleteOneData PATH
  !define ppdd ${__COUNTER__}
  !insertmacro ppPathBasicOk "${PATH}"
  StrCmp $R9 "1" 0 pp_dd_end_${ppdd}
  !insertmacro ppSkipForeignData "${PATH}" $R9
  StrCmp $R9 "1" pp_dd_end_${ppdd}
  RMDir /r "${PATH}"
  pp_dd_end_${ppdd}:
  !undef ppdd
!macroend

!macro ppDeleteDetectedData
  !insertmacro ppDeleteOneData $DataPath1
  !insertmacro ppDeleteOneData $DataPath2
  !insertmacro ppDeleteOneData $DataPath3
  !insertmacro ppDeleteOneData $DataPath4
  RMDir "$APPDATA\Prompt Picker"
!macroend

!macro ppCleanShortcuts
  SetOutPath $TEMP
  RMDir /r "$LOCALAPPDATA\prompt-picker-updater"
  RMDir /r "$TEMP\prompt-picker-updater"
  Delete "$DESKTOP\${PP_SHORTCUT_NAME}.lnk"
  Delete "$SMPROGRAMS\${PP_SHORTCUT_NAME}.lnk"
  Delete "$APPDATA\Microsoft\Windows\Start Menu\Programs\${PP_SHORTCUT_NAME}.lnk"
  SetShellVarContext all
  Delete "$SMPROGRAMS\${PP_SHORTCUT_NAME}.lnk"
  SetShellVarContext current
!macroend

; A folder we may record or reopen. Never a drive root or a shell folder.
!macro ppFolderOk PATH RESULT
  !define ppfo ${__COUNTER__}
  StrCpy ${RESULT} "0"
  StrCmp "${PATH}" "" pp_fo_end_${ppfo}
  StrLen $R8 "${PATH}"
  IntCmp $R8 4 pp_fo_len_${ppfo} pp_fo_end_${ppfo} pp_fo_len_${ppfo}
  pp_fo_len_${ppfo}:
  StrCpy $R7 "${PATH}" "" -2
  ${If} $R7 == ":\"
    Goto pp_fo_end_${ppfo}
  ${EndIf}
  ${If} "${PATH}" == "$APPDATA"
  ${OrIf} "${PATH}" == "$LOCALAPPDATA"
  ${OrIf} "${PATH}" == "$PROFILE"
  ${OrIf} "${PATH}" == "$DESKTOP"
  ${OrIf} "${PATH}" == "$PROGRAMFILES"
  ${OrIf} "${PATH}" == "$PROGRAMFILES64"
  ${OrIf} "${PATH}" == "$WINDIR"
  ${OrIf} "${PATH}" == "$SYSDIR"
  ${OrIf} "${PATH}" == "$TEMP"
  ${OrIf} "${PATH}" == "$LOCALAPPDATA\Programs"
    Goto pp_fo_end_${ppfo}
  ${EndIf}
  IfFileExists "${PATH}\*.*" 0 pp_fo_end_${ppfo}
  StrCpy ${RESULT} "1"
  pp_fo_end_${ppfo}:
  !undef ppfo
!macroend

!macro ppReadTextLine FILE OUT
  !define pprl ${__COUNTER__}
  StrCpy ${OUT} ""
  ClearErrors
  FileOpen $R4 "${FILE}" r
  IfErrors pp_rl_end_${pprl}
  FileRead $R4 ${OUT}
  FileClose $R4
  pp_rl_end_${pprl}:
  !undef pprl
!macroend

; 1 only when DIR contains our marker and its app id is Prompt Picker.
; The installDir field must name this same folder. Anything else is ignored.
!macro ppMarkerAccepts DIR RESULT
  !define ppma ${__COUNTER__}
  !insertmacro ppFolderOk "${DIR}" $R9
  StrCmp $R9 "1" 0 pp_ma_end_${ppma}
  StrCpy ${RESULT} "0"
  !insertmacro ppReadTextLine "${DIR}\${PP_MARKER_NAME}" $R8
  StrCmp $R8 "" pp_ma_end_${ppma}
  StrCpy $R2 '"appId":"'
  !insertmacro ppJsonField $R8 $R2 $R3
  StrCmp $R3 "${PP_APP_ID}" 0 pp_ma_end_${ppma}
  StrCpy $R2 '"installDir":"'
  !insertmacro ppJsonField $R8 $R2 $R3
  StrCmp $R3 "${DIR}" 0 pp_ma_end_${ppma}
  StrCpy ${RESULT} "1"
  pp_ma_end_${ppma}:
  !undef ppma
!macroend

!macro ppReadPointerInstallDir OUT
  !define pppi ${__COUNTER__}
  StrCpy ${OUT} ""
  !insertmacro ppReadTextLine "$APPDATA\Prompt Picker\${PP_MARKER_NAME}" $R8
  StrCmp $R8 "" pp_pi_end_${pppi}
  StrCpy $R2 '"installDir":"'
  !insertmacro ppJsonField $R8 $R2 ${OUT}
  pp_pi_end_${pppi}:
  !undef pppi
!macroend

; Used by the installer when no electron-builder install key exists.
; A verified marker becomes $INSTDIR. A mismatch leaves $INSTDIR alone.
!macro ppApplyKeptInstall
  !define ppap ${__COUNTER__}
  ReadRegStr $R1 HKCU "Software\Prompt Picker" InstallLocation
  !insertmacro ppMarkerAccepts $R1 $R9
  StrCmp $R9 "1" pp_ap_use_${ppap}
  !insertmacro ppReadPointerInstallDir $R1
  !insertmacro ppMarkerAccepts $R1 $R9
  StrCmp $R9 "1" 0 pp_ap_end_${ppap}
  pp_ap_use_${ppap}:
    StrCpy $INSTDIR $R1
  pp_ap_end_${ppap}:
  !undef ppap
!macroend

!macro ppJsonEscape SRC OUT
  !define pje ${__COUNTER__}
  StrCpy ${OUT} ""
  StrCpy $R5 0
  pp_je_${pje}:
    StrCpy $R7 "${SRC}" 1 $R5
    StrCmp $R7 "" pp_je_end_${pje}
    StrCmp $R7 "\" 0 pp_je_plain_${pje}
      StrCpy $R6 "\"
      StrCpy ${OUT} "${OUT}$R6$R6"
      Goto pp_je_next_${pje}
    pp_je_plain_${pje}:
      StrCpy ${OUT} "${OUT}$R7"
    pp_je_next_${pje}:
      IntOp $R5 $R5 + 1
      Goto pp_je_${pje}
  pp_je_end_${pje}:
  !undef pje
!macroend

; Prefer prompts kept inside the install folder. Otherwise the first detected path.
!macro ppKeptDataPath OUT
  !define ppkd ${__COUNTER__}
  StrCpy ${OUT} ""
  StrCmp $InstallDir "" pp_kd_fallback_${ppkd}
  IfFileExists "$InstallDir\PromptPickerData\prompts.json" 0 pp_kd_img_${ppkd}
    StrCpy ${OUT} "$InstallDir\PromptPickerData"
    Goto pp_kd_end_${ppkd}
  pp_kd_img_${ppkd}:
  IfFileExists "$InstallDir\PromptPickerData\images\*.*" 0 pp_kd_data_${ppkd}
    StrCpy ${OUT} "$InstallDir\PromptPickerData"
    Goto pp_kd_end_${ppkd}
  pp_kd_data_${ppkd}:
  IfFileExists "$InstallDir\data\prompts.json" 0 pp_kd_fallback_${ppkd}
    StrCpy ${OUT} "$InstallDir\data"
    Goto pp_kd_end_${ppkd}
  pp_kd_fallback_${ppkd}:
  StrCmp $DataPath1 "" pp_kd_inst_${ppkd}
    StrCpy ${OUT} $DataPath1
    Goto pp_kd_end_${ppkd}
  pp_kd_inst_${ppkd}:
  StrCmp $InstallDir "" pp_kd_end_${ppkd}
    StrCpy ${OUT} "$InstallDir\PromptPickerData"
  pp_kd_end_${ppkd}:
  !undef ppkd
!macroend

!macro ppWriteMarkerFile DEST
  !define ppwm ${__COUNTER__}
  ClearErrors
  FileOpen $R4 "${DEST}" w
  IfErrors pp_wm_end_${ppwm}
  FileWrite $R4 '{"appId":"${PP_APP_ID}","version":"${VERSION}","installDir":"'
  FileWrite $R4 $R1
  FileWrite $R4 '","dataPath":"'
  FileWrite $R4 $R2
  FileWrite $R4 '","desktopShortcut":"'
  FileWrite $R4 $R6
  FileWrite $R4 '","startMenuShortcut":"0","language":"'
  FileWrite $R4 $LANGUAGE
  FileWrite $R4 '"}$\r$\n'
  FileClose $R4
  pp_wm_end_${ppwm}:
  !undef ppwm
!macroend

; Leave the install folder in place and remember it for the next setup.
!macro ppWriteKeepPointers
  !define ppwk ${__COUNTER__}
  !insertmacro ppInstallDirOk $R9
  StrCmp $R9 "1" 0 pp_wk_end_${ppwk}
  !insertmacro ppKeptDataPath $R3
  ReadRegStr $R8 HKCU "Software\Prompt Picker" DesktopShortcut
  ${If} $R8 != "0"
    StrCpy $R8 "1"
  ${EndIf}
  !insertmacro ppJsonEscape $InstallDir $R1
  !insertmacro ppJsonEscape $R3 $R2
  StrCpy $R6 $R8
  CreateDirectory "$APPDATA\Prompt Picker"
  !insertmacro ppWriteMarkerFile "$InstallDir\${PP_MARKER_NAME}"
  !insertmacro ppWriteMarkerFile "$APPDATA\Prompt Picker\${PP_MARKER_NAME}"
  WriteRegStr HKCU "Software\Prompt Picker" InstallLocation "$InstallDir"
  WriteRegStr HKCU "Software\Prompt Picker" DataDir "$R3"
  WriteRegStr HKCU "Software\Prompt Picker" AppId "${PP_APP_ID}"
  WriteRegStr HKCU "Software\Prompt Picker" DesktopShortcut "$R6"
  WriteRegStr HKCU "Software\Prompt Picker" StartMenuShortcut "0"
  WriteRegStr HKCU "Software\Prompt Picker" "Installer Language" "$LANGUAGE"
  WriteRegStr HKCU "${INSTALL_REGISTRY_KEY}" InstallLocation "$InstallDir"
  WriteRegStr HKCU "${INSTALL_REGISTRY_KEY}" DataDir "$R3"
  ClearErrors
  FileOpen $R4 "$APPDATA\Prompt Picker\data.path" w
  IfErrors pp_wk_end_${ppwk}
  FileWrite $R4 "$R3$\r$\n"
  FileClose $R4
  pp_wk_end_${ppwk}:
  !undef ppwk
!macroend

; 1 when the saved pointer names a different verified Prompt Picker folder.
!macro ppPointerIsForeign RESULT
  !define pppf ${__COUNTER__}
  StrCpy ${RESULT} "0"
  ReadRegStr $R1 HKCU "Software\Prompt Picker" InstallLocation
  !insertmacro ppMarkerAccepts $R1 $R9
  StrCmp $R9 "1" 0 pp_pf_file_${pppf}
  StrCmp $R1 "$InstallDir" pp_pf_ours_${pppf}
  StrCmp $R1 "$INSTDIR" pp_pf_ours_${pppf}
  StrCpy ${RESULT} "1"
  Goto pp_pf_end_${pppf}
  pp_pf_file_${pppf}:
  !insertmacro ppReadPointerInstallDir $R1
  !insertmacro ppMarkerAccepts $R1 $R9
  StrCmp $R9 "1" 0 pp_pf_end_${pppf}
  StrCmp $R1 "$InstallDir" pp_pf_ours_${pppf}
  StrCmp $R1 "$INSTDIR" pp_pf_ours_${pppf}
  StrCpy ${RESULT} "1"
  Goto pp_pf_end_${pppf}
  pp_pf_ours_${pppf}:
  StrCpy ${RESULT} "0"
  pp_pf_end_${pppf}:
  !undef pppf
!macroend

!macro ppDeletePointers
  !define ppdp ${__COUNTER__}
  StrCmp $InstallDir "" pp_dp_own_${ppdp}
    Delete "$InstallDir\${PP_MARKER_NAME}"
  pp_dp_own_${ppdp}:
  !insertmacro ppPointerIsForeign $R9
  StrCmp $R9 "1" pp_dp_end_${ppdp}
  Delete "$APPDATA\Prompt Picker\${PP_MARKER_NAME}"
  Delete "$APPDATA\Prompt Picker\data.path"
  DeleteRegKey HKCU "Software\Prompt Picker"
  DeleteRegKey HKCU "${INSTALL_REGISTRY_KEY}"
  DeleteRegKey HKLM "${INSTALL_REGISTRY_KEY}"
  pp_dp_end_${ppdp}:
  !undef ppdp
!macroend

!macro ppCleanExtras
  !insertmacro ppCleanShortcuts
  !insertmacro ppDeletePointers
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
  StrCmp "${ID}" "paths" 0 pp_txt_keep_${pptxt}
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
  pp_txt_keep_${pptxt}:
  StrCmp "${ID}" "keep" 0 pp_txt_wipe_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Gỡ và giữ prompt, cài đặt, cùng lựa chọn cài đặt"
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "卸载并保留提示词、设置和安装选择"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "제거하고 프롬프트, 설정, 설치 선택을 유지"
    ${Else}
      StrCpy ${OUT} "Uninstall and keep prompts, settings, and install choices"
    ${EndIf}
    Goto pp_txt_end_${pptxt}
  pp_txt_wipe_${pptxt}:
  StrCmp "${ID}" "wipe" 0 pp_txt_wconf_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Gỡ và xoá tất cả"
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "卸载并清除全部内容"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "제거하고 모두 지우기"
    ${Else}
      StrCpy ${OUT} "Uninstall and wipe everything"
    ${EndIf}
    Goto pp_txt_end_${pptxt}
  pp_txt_wconf_${pptxt}:
  StrCmp "${ID}" "wipeConfirm" 0 pp_txt_desk_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Việc này xoá prompt, cài đặt, nhật ký, thư mục cài và lựa chọn cài đặt đã lưu. Không hoàn tác được. Tiếp tục?"
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "这将删除提示词、设置、日志、安装文件夹和已保存的安装选择。无法撤销。是否继续？"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "프롬프트, 설정, 로그, 설치 폴더, 저장된 설치 선택을 삭제합니다. 되돌릴 수 없습니다. 계속할까요?"
    ${Else}
      StrCpy ${OUT} "This deletes prompts, settings, logs, the install folder, and the saved install choices. It cannot be undone. Continue?"
    ${EndIf}
    Goto pp_txt_end_${pptxt}
  pp_txt_desk_${pptxt}:
  StrCmp "${ID}" "desktop" 0 pp_txt_nostart_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Tạo lối tắt trên Desktop"
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "创建桌面快捷方式"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "바탕 화면에 바로 가기 만들기"
    ${Else}
      StrCpy ${OUT} "Create a Desktop shortcut"
    ${EndIf}
    Goto pp_txt_end_${pptxt}
  pp_txt_nostart_${pptxt}:
  StrCmp "${ID}" "nostart" 0 pp_txt_none_${pptxt}
    ${If} $LANGUAGE == 1066
      StrCpy ${OUT} "Không tạo lối tắt Start Menu."
    ${ElseIf} $LANGUAGE == 2052
      StrCpy ${OUT} "不会创建开始菜单快捷方式。"
    ${ElseIf} $LANGUAGE == 1042
      StrCpy ${OUT} "시작 메뉴 바로 가기는 만들지 않습니다."
    ${Else}
      StrCpy ${OUT} "A Start Menu shortcut is not created."
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
