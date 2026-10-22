!macro customUnInstall
  ${ifNot} ${isUpdated}
    MessageBox MB_YESNO|MB_ICONQUESTION "Xoá luôn dữ liệu của Prompt Picker (prompt và ảnh) trong $APPDATA\Prompt Picker?$\r$\nNên xuất file sao lưu trước. Nếu bạn đã đổi thư mục dữ liệu sang nơi khác, thư mục đó sẽ được giữ nguyên." /SD IDNO IDNO skipDel
      RMDir /r "$APPDATA\Prompt Picker"
    skipDel:
  ${endIf}
!macroend
