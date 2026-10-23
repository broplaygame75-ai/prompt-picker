Unicode true
RequestExecutionLevel user
SilentInstall silent
AutoCloseWindow true
Name "Prompt Picker uninstall test"
OutFile "/tmp/pp-un-test.exe"

!define PRODUCT_FILENAME "Prompt Picker"
!define PP_APP_EXE "Prompt Picker.exe"
!define PP_UNINSTALL_EXE "Uninstall Prompt Picker.exe"
!define PP_SHORTCUT_NAME "Prompt Picker"
!define INSTALL_REGISTRY_KEY "Software\05ae8bdf-b478-52b5-acc4-ac809166ef4d"
!define VERSION "0.1.8"
!define APP_ID "com.lineko.promptpicker"
!define PP_LOGIC_TEST
!include /CHARSET=UTF8 "../build/uninstall-logic.nsh"

Var Fail
Var Log

!macro note TEXT
  FileWrite $Log "${TEXT}$\r$\n"
  DetailPrint "${TEXT}"
!macroend

!macro dumpWide PATH
  StrLen $R8 $R9
  IntOp $R8 $R8 * 2
  System::Call 'kernel32::CreateFileW(w "${PATH}", i 0x40000000, i 0, p 0, i 2, i 0, p 0) p.R7'
  System::Call 'kernel32::WriteFile(p R7, w R9, i R8, *i .R6, p 0)'
  System::Call 'kernel32::CloseHandle(p R7)'
!macroend

!macro fail TEXT
  StrCpy $Fail "1"
  !insertmacro note "FAIL ${TEXT}"
!macroend

!macro assertEq GOT WANT NAME
  !define ae ${__COUNTER__}
  StrCmp "${GOT}" "${WANT}" ae_ok_${ae}
  !insertmacro fail "${NAME}"
  ae_ok_${ae}:
  !undef ae
!macroend

!macro assertExists PATH NAME
  !define ax ${__COUNTER__}
  IfFileExists "${PATH}" ax_ok_${ax}
  !insertmacro fail "missing ${NAME}"
  ax_ok_${ax}:
  !undef ax
!macroend

!macro assertGone PATH NAME
  !define ag ${__COUNTER__}
  IfFileExists "${PATH}" 0 ag_ok_${ag}
  !insertmacro fail "still ${NAME}"
  ag_ok_${ag}:
  !undef ag
!macroend

!macro assertDir PATH NAME
  !define ad ${__COUNTER__}
  IfFileExists "${PATH}\*.*" ad_ok_${ad}
  !insertmacro fail "missing-dir ${NAME}"
  ad_ok_${ad}:
  !undef ad
!macroend

!macro assertDirGone PATH NAME
  !define dg ${__COUNTER__}
  IfFileExists "${PATH}\*.*" 0 dg_ok_${dg}
  !insertmacro fail "dir ${NAME}"
  dg_ok_${dg}:
  !undef dg
!macroend

!macro touch PATH BODY
  ClearErrors
  FileOpen $R1 "${PATH}" w
  IfErrors +3
  FileWrite $R1 "${BODY}"
  FileClose $R1
!macroend

Section
  StrCpy $Fail "0"
  ClearErrors
  FileOpen $Log "W:\uninstall-result.txt" w
  IfErrors done

  StrCpy $INSTDIR "C:\DecoyPromptPicker"
  CreateDirectory "C:\DecoyPromptPicker\locales"
  CreateDirectory "C:\DecoyPromptPicker\resources"
  !insertmacro touch "C:\DecoyPromptPicker\Prompt Picker.exe" "decoy"
  !insertmacro touch "C:\DecoyPromptPicker\locales\en-US.pak" "decoy"
  !insertmacro touch "C:\DecoyPromptPicker\resources\app.asar" "decoy"
  !insertmacro touch "C:\DecoyPromptPicker\USER-KEEP.txt" "decoy"

  CreateDirectory "W:\AI Work"
  !insertmacro touch "W:\AI Work\notes-outside.txt" "keep"
  CreateDirectory "W:\AI Work\Prompt Picker\locales"
  CreateDirectory "W:\AI Work\Prompt Picker\resources"
  CreateDirectory "W:\AI Work\Prompt Picker\My Notes"
  CreateDirectory "W:\AI Work\Prompt Picker\PromptPickerData\images"
  CreateDirectory "W:\AI Work\Prompt Picker\data\images"
  !insertmacro touch "W:\AI Work\Prompt Picker\Prompt Picker.exe" "app"
  !insertmacro touch "W:\AI Work\Prompt Picker\Uninstall Prompt Picker.exe" "un"
  !insertmacro touch "W:\AI Work\Prompt Picker\uninstallerIcon.ico" "ico"
  !insertmacro touch "W:\AI Work\Prompt Picker\ffmpeg.dll" "dll"
  !insertmacro touch "W:\AI Work\Prompt Picker\chrome_100_percent.pak" "pak"
  !insertmacro touch "W:\AI Work\Prompt Picker\resources.pak" "pak"
  !insertmacro touch "W:\AI Work\Prompt Picker\icudtl.dat" "dat"
  !insertmacro touch "W:\AI Work\Prompt Picker\locales\en-US.pak" "pak"
  !insertmacro touch "W:\AI Work\Prompt Picker\resources\app.asar" "asar"
  !insertmacro touch "W:\AI Work\Prompt Picker\extra.dll" "user"
  !insertmacro touch "W:\AI Work\Prompt Picker\readme.pdf" "user"
  !insertmacro touch "W:\AI Work\Prompt Picker\USER-KEEP.txt" "user"
  !insertmacro touch "W:\AI Work\Prompt Picker\My Notes\song.txt" "user"
  !insertmacro touch "W:\AI Work\Prompt Picker\PromptPickerData\prompts.json" "{}"
  !insertmacro touch "W:\AI Work\Prompt Picker\PromptPickerData\images\a.webp" "img"
  !insertmacro touch "W:\AI Work\Prompt Picker\data\prompts.json" "{}"

  CreateDirectory "$APPDATA\Prompt Picker\data\images"
  !insertmacro touch "$APPDATA\Prompt Picker\data\prompts.json" "{}"
  ClearErrors
  FileOpen $R1 "$APPDATA\Prompt Picker\config.json" w
  FileWrite $R1 '{"activeDataDir":"W:\\CustomPrompts","dataDir":"W:\\AI Work"}'
  FileClose $R1
  !insertmacro touch "$APPDATA\Prompt Picker\data.path" "W:\CustomPrompts$\r$\n"
  CreateDirectory "W:\CustomPrompts\images"
  !insertmacro touch "W:\CustomPrompts\prompts.json" "{}"
  !insertmacro touch "W:\CustomPrompts\images\b.webp" "img"

  CreateDirectory "$LOCALAPPDATA\prompt-picker-updater\pending"
  !insertmacro touch "$LOCALAPPDATA\prompt-picker-updater\pending\stub.bin" "cache"
  !insertmacro touch "$DESKTOP\Prompt Picker.lnk" "shortcut"

  WriteRegStr HKCU "${INSTALL_REGISTRY_KEY}" InstallLocation "W:\AI Work\Prompt Picker"
  WriteRegStr HKCU "Software\Prompt Picker" InstallLocation "W:\AI Work\Prompt Picker"
  WriteRegStr HKCU "Software\Prompt Picker" DataDir "W:\CustomPrompts"
  WriteRegStr HKCU "${INSTALL_REGISTRY_KEY}" DataDir "W:\CustomPrompts"
  WriteRegStr HKCU "Software\Prompt Picker" "Installer Language" "1066"

  ReadRegStr $0 HKCU "Software\Prompt Picker" "Installer Language"
  StrCpy $LANGUAGE $0
  !insertmacro ppText "warn" $R9
  !insertmacro note "warn-vi=$R9"
  !insertmacro dumpWide "W:\warn-vi.bin"
  StrCpy $LANGUAGE "1033"
  !insertmacro ppText "warn" $R9
  !insertmacro note "warn-en=$R9"
  !insertmacro dumpWide "W:\warn-en.bin"
  StrCpy $LANGUAGE "2052"
  !insertmacro ppText "warn" $R9
  !insertmacro note "warn-zh=$R9"
  !insertmacro dumpWide "W:\warn-zh.bin"
  StrCpy $LANGUAGE "1042"
  !insertmacro ppText "warn" $R9
  !insertmacro note "warn-ko=$R9"
  !insertmacro dumpWide "W:\warn-ko.bin"
  StrCpy $LANGUAGE "1033"
  !insertmacro ppText "delete" $R9
  !insertmacro note "delete-en=$R9"
  !insertmacro ppText "paths" $R9
  !insertmacro note "paths-en=$R9"
  StrCpy $LANGUAGE "1066"
  !insertmacro ppText "delete" $R9
  !insertmacro note "delete-vi=$R9"
  StrCpy $LANGUAGE "2052"
  !insertmacro ppText "none" $R9
  !insertmacro note "none-zh=$R9"
  StrCpy $LANGUAGE "1042"
  !insertmacro ppText "paths" $R9
  !insertmacro note "paths-ko=$R9"
  StrCpy $DeleteData "0"

  !insertmacro ppResolveInstallDir
  !insertmacro assertEq $InstallDir "W:\AI Work\Prompt Picker" "installDir"
  !insertmacro ppCollectData
  !insertmacro assertEq $DataPath1 "$APPDATA\Prompt Picker\data" "data1"
  !insertmacro assertEq $DataPath2 "W:\AI Work\Prompt Picker\PromptPickerData" "data2"
  !insertmacro assertEq $DataPath3 "W:\AI Work\Prompt Picker\data" "data3"
  !insertmacro assertEq $DataPath4 "W:\CustomPrompts" "data4"

  !insertmacro ppDeleteKnownAppFiles
  SetOutPath $TEMP
  RMDir "$InstallDir"
  !insertmacro assertGone "W:\AI Work\Prompt Picker\Prompt Picker.exe" "exe"
  !insertmacro assertGone "W:\AI Work\Prompt Picker\Uninstall Prompt Picker.exe" "uninstaller"
  !insertmacro assertGone "W:\AI Work\Prompt Picker\ffmpeg.dll" "ffmpeg"
  !insertmacro assertGone "W:\AI Work\Prompt Picker\chrome_100_percent.pak" "pak"
  !insertmacro assertDirGone "W:\AI Work\Prompt Picker\locales" "locales"
  !insertmacro assertDirGone "W:\AI Work\Prompt Picker\resources" "resources"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\extra.dll" "user-dll"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\readme.pdf" "user-pdf"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\USER-KEEP.txt" "user-note"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\My Notes\song.txt" "user-sub"
  !insertmacro assertDir "W:\AI Work\Prompt Picker" "install-folder"
  !insertmacro assertExists "W:\AI Work\notes-outside.txt" "outside"
  !insertmacro assertExists "C:\DecoyPromptPicker\Prompt Picker.exe" "decoy-exe"
  !insertmacro assertExists "C:\DecoyPromptPicker\USER-KEEP.txt" "decoy-note"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\PromptPickerData\prompts.json" "instdata-kept"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\data\prompts.json" "inst-data-kept"
  !insertmacro assertExists "$APPDATA\Prompt Picker\data\prompts.json" "appdata-kept"
  !insertmacro assertExists "W:\CustomPrompts\prompts.json" "custom-kept"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\PromptPickerData\images\a.webp" "instdata-img"

  !insertmacro ppWriteKeepPointers
  !insertmacro assertExists "W:\AI Work\Prompt Picker\prompt-picker.install.json" "marker"
  !insertmacro assertExists "$APPDATA\Prompt Picker\prompt-picker.install.json" "pointer"
  !insertmacro assertDir "W:\AI Work\Prompt Picker" "kept-folder"
  ReadRegStr $0 HKCU "Software\Prompt Picker" InstallLocation
  !insertmacro assertEq $0 "W:\AI Work\Prompt Picker" "kept-reg"
  ReadRegStr $0 HKCU "Software\Prompt Picker" DataDir
  !insertmacro assertEq $0 "W:\AI Work\Prompt Picker\PromptPickerData" "kept-data-reg"
  ReadRegStr $0 HKCU "Software\Prompt Picker" AppId
  !insertmacro assertEq $0 "com.lineko.promptpicker" "kept-appid"
  !insertmacro ppReadTextLine "W:\AI Work\Prompt Picker\prompt-picker.install.json" $R8
  StrCpy $R2 '"appId":"'
  !insertmacro ppJsonField $R8 $R2 $R3
  !insertmacro assertEq $R3 "com.lineko.promptpicker" "marker-id"
  StrCpy $R2 '"version":"'
  !insertmacro ppJsonField $R8 $R2 $R3
  !insertmacro assertEq $R3 "0.1.8" "marker-ver"
  StrCpy $R2 '"installDir":"'
  !insertmacro ppJsonField $R8 $R2 $R3
  !insertmacro assertEq $R3 "W:\AI Work\Prompt Picker" "marker-dir"
  StrCpy $R2 '"dataPath":"'
  !insertmacro ppJsonField $R8 $R2 $R3
  !insertmacro assertEq $R3 "W:\AI Work\Prompt Picker\PromptPickerData" "marker-data"
  !insertmacro ppMarkerAccepts "W:\AI Work\Prompt Picker" $R9
  !insertmacro assertEq $R9 "1" "marker-ok"
  !insertmacro ppMarkerAccepts "C:\DecoyPromptPicker" $R9
  !insertmacro assertEq $R9 "0" "decoy-not-ours"
  CreateDirectory "W:\Not Ours"
  ClearErrors
  FileOpen $R1 "W:\Not Ours\prompt-picker.install.json" w
  FileWrite $R1 '{"appId":"other.app","version":"0.1.8","installDir":"W:\\Not Ours","dataPath":"W:\\Not Ours"}$\r$\n'
  FileClose $R1
  !insertmacro ppMarkerAccepts "W:\Not Ours" $R9
  !insertmacro assertEq $R9 "0" "foreign-app"
  !insertmacro ppApplyKeptInstall
  !insertmacro assertEq $INSTDIR "W:\AI Work\Prompt Picker" "apply-kept"

  ; A checked uninstall of some other copy must not remove this folder's data.
  StrCpy $0 $InstallDir
  StrCpy $1 $INSTDIR
  StrCpy $InstallDir "C:\DecoyPromptPicker"
  StrCpy $INSTDIR "C:\DecoyPromptPicker"
  !insertmacro ppDeleteOneData "W:\AI Work\Prompt Picker\PromptPickerData"
  StrCpy $InstallDir $0
  StrCpy $INSTDIR $1
  !insertmacro assertExists "W:\AI Work\Prompt Picker\PromptPickerData\prompts.json" "foreign-data-kept"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\PromptPickerData\images\a.webp" "foreign-img-kept"
  !insertmacro ppSkipForeignData "$APPDATA\Prompt Picker\data" $R9
  !insertmacro assertEq $R9 "0" "appdata-not-foreign"
  !insertmacro ppSkipForeignData "W:\CustomPrompts" $R9
  !insertmacro assertEq $R9 "0" "custom-not-foreign"
  !insertmacro ppSkipForeignData "W:\AI Work\Prompt Picker\PromptPickerData" $R9
  !insertmacro assertEq $R9 "0" "own-data-not-skipped"

  StrCpy $DeleteData "1"
  !insertmacro ppDeleteDetectedData
  !insertmacro assertDirGone "$APPDATA\Prompt Picker\data" "appdata-data"
  !insertmacro assertDirGone "W:\AI Work\Prompt Picker\PromptPickerData" "instdata"
  !insertmacro assertDirGone "W:\AI Work\Prompt Picker\data" "inst-data-dir"
  !insertmacro assertDirGone "W:\CustomPrompts" "custom"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\extra.dll" "user-dll-after"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\USER-KEEP.txt" "user-note-after"
  !insertmacro assertExists "W:\AI Work\Prompt Picker\My Notes\song.txt" "user-sub-after"
  !insertmacro assertExists "W:\AI Work\notes-outside.txt" "outside-after"
  !insertmacro assertExists "C:\DecoyPromptPicker\Prompt Picker.exe" "decoy-after"
  !insertmacro assertExists "$APPDATA\Prompt Picker\config.json" "config-kept"
  !insertmacro assertDir "W:\AI Work\Prompt Picker" "install-folder-after"

  StrCpy $0 $InstallDir
  StrCpy $1 $INSTDIR
  StrCpy $InstallDir "C:\DecoyPromptPicker"
  StrCpy $INSTDIR "C:\DecoyPromptPicker"
  !insertmacro ppDeletePointers
  StrCpy $InstallDir $0
  StrCpy $INSTDIR $1
  !insertmacro assertExists "W:\AI Work\Prompt Picker\prompt-picker.install.json" "foreign-marker-kept"
  !insertmacro assertExists "$APPDATA\Prompt Picker\prompt-picker.install.json" "foreign-pointer-kept"
  ReadRegStr $0 HKCU "Software\Prompt Picker" InstallLocation
  !insertmacro assertEq $0 "W:\AI Work\Prompt Picker" "foreign-reg-kept"

  !insertmacro ppCleanExtras
  !insertmacro assertGone "W:\AI Work\Prompt Picker\prompt-picker.install.json" "marker-removed"
  !insertmacro assertGone "$APPDATA\Prompt Picker\prompt-picker.install.json" "pointer-removed"
  !insertmacro assertDirGone "$LOCALAPPDATA\prompt-picker-updater" "updater-cache"
  !insertmacro assertGone "$DESKTOP\Prompt Picker.lnk" "shortcut"
  !insertmacro assertGone "$APPDATA\Prompt Picker\data.path" "data-path-file"
  ReadRegStr $0 HKCU "Software\Prompt Picker" DataDir
  !insertmacro assertEq $0 "" "reg-data"
  ReadRegStr $0 HKCU "${INSTALL_REGISTRY_KEY}" InstallLocation
  !insertmacro assertEq $0 "" "reg-install"

  StrCmp $Fail "1" fail ok
  ok:
    !insertmacro note "PASS"
    FileClose $Log
    SetErrorLevel 0
    Goto done
  fail:
    !insertmacro note "FAILED"
    FileClose $Log
    SetErrorLevel 1
  done:
SectionEnd
