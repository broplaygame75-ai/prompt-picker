# Changelog

## 0.1.14

- Cập nhật từ 0.1.12 ghi đè đúng thư mục đang cài, kể cả `%LOCALAPPDATA%\Programs\Prompt Picker`. Không tạo thêm một bản ở `C:\Prompt Picker`.
- Lần mở đầu của bản mới gỡ bản cài trùng ở thư mục khác và trỏ lối tắt Desktop vào file đang chạy.
- Bộ gỡ chỉ mở một cửa sổ, đóng app trước, và không mở lại app.
- App chờ bản cũ thoát khi được mở lại sau cập nhật, nên không tự đóng giữa chừng.

## 0.1.13

- Bộ cài hỏi thư mục. Mặc định là `C:\Prompt Picker` nếu tạo được, không thì thư mục Prompt Picker trong hồ sơ. Quyền quản trị chỉ được hỏi khi thư mục đã chọn không ghi được. File chương trình nằm trong thư mục đó.
- Đường dẫn `/D=` có dấu cách được đọc nguyên, kể cả khi cập nhật tại chỗ.
- Chỉ có lối tắt Desktop, không gắn AppUserModelID. Lối tắt Start Menu cũ bị xoá lúc cài và mỗi lần mở. Lỗi "Unspecified error" của lối tắt Start Menu đến từ id `com.lineko.promptpicker` trên file `.lnk`.
- Mỗi lần mở ghi `%APPDATA%\Prompt Picker\startup.log`.
- Prompt vừa bốc có nhãn khớp "New" thì chip trên kết quả có nút ×. Bấm là gỡ nhãn, cập nhật thời điểm sửa, hoàn tác bằng Ctrl+Z và làm lại bằng Ctrl+Y.
- Gỡ cài đặt có hai lựa chọn. Giữ dữ liệu thì giữ prompt, cài đặt (ngôn ngữ, giao diện, cách xếp, gợi ý và mọi tuỳ chọn khác) và lựa chọn cài đặt. Lần cài sau điền sẵn thư mục và các lựa chọn đó, rồi khôi phục cài đặt. Xoá tất cả thì xoá những thứ này.
- Cài đặt > Khác có mục Liên hệ: Discord, Patreon, X, Telegram.
- Repo phát hành công khai được cập nhật tài liệu, cộng đồng và checksum. Repo mã nguồn vẫn riêng tư.

## 0.1.12

- Lối tắt tự sửa khi mở app. Bộ cài không dùng lại thư mục đã mất. Lỗi khởi động có hộp thoại sửa. Có cổng kiểm tra máy sạch trước khi phát hành.
