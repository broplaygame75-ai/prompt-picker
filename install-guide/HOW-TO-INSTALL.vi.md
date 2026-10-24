# Cách cài Prompt Picker {{version}}

**18+.** Prompt Picker dành cho người từ 18 tuổi trở lên. Lần đầu mở, app hỏi "Bạn đã đủ 18 tuổi chưa?" Có thì vào app và được nhớ trên máy. Không thì app đóng.

Ảnh trong thư mục này là hình minh hoạ các bước, không phải ảnh chụp máy của bạn.

Windows hiện "Windows protected your PC" vì app chưa được ký số. Cảnh báo này là bình thường, không có nghĩa file đã bị sửa. Đừng tắt SmartScreen hay Defender.

## 1. Tải về

Tải `PromptPicker-Setup-{{version}}.exe`, hoặc mở `PromptPicker-{{version}}-Windows.zip` rồi chạy file Setup bên trong. Giữ nguyên `latest.yml` trên trang release. Bản đã cài dùng file đó để tự cập nhật.

![Tải về](vi/01-download.png)

## 2. SmartScreen

Mở file Setup. Nếu Windows báo "Windows protected your PC":

1. Bấm **More info** (Thông tin thêm).
2. Bấm **Run anyway** (Vẫn chạy).

![SmartScreen](vi/02-smartscreen.png)

## 3. Cài đặt

Bộ cài hỏi thư mục để đặt Prompt Picker. Thư mục gợi ý là `C:\Prompt Picker` nếu tạo được, không thì là thư mục Prompt Picker trong hồ sơ người dùng. File chương trình nằm trong thư mục bạn chọn. Chỉ tạo lối tắt trên Desktop. Không tạo lối tắt Start Menu, và lối tắt Start Menu cũ tên Prompt Picker sẽ bị xóa. Nếu máy đã có Prompt Picker, bộ cài ghi đè đúng bản đó. Prompt vẫn nằm ở `%APPDATA%\Prompt Picker\data`.

![Cài đặt](vi/03-installer.png)

## 4. Mở lần đầu

Xác nhận bạn từ 18 tuổi trở lên, rồi bốc prompt.

![Mở lần đầu](vi/04-first-launch.png)

## 5. Cập nhật

Bản cập nhật cài vào đúng thư mục bạn đã chọn. Không hỏi lại thư mục, và không xoá prompt hay cài đặt.

## 6. Gỡ cài đặt

Cài đặt > Khác có hai lựa chọn. Windows Settings > Apps cũng hiện hai lựa chọn đó.

**Gỡ cài đặt, giữ dữ liệu** gỡ app, lối tắt, mục gỡ cài đặt, file tạm và bộ nhớ cập nhật. Prompt, ngôn ngữ, giao diện, cách xếp, gợi ý và mọi tuỳ chọn khác được giữ, cùng thư mục đã chọn và lựa chọn lối tắt Desktop. Lần cài sau mở sẵn thư mục đó và các lựa chọn đó, rồi app khôi phục cài đặt. Hãy xuất bản sao lưu JSON trước (Cài đặt > Sao lưu & Nhập dữ liệu) nếu bạn muốn một bản sao.

**Gỡ cài đặt và xoá tất cả** gỡ app, prompt, cài đặt, thư mục cài và lựa chọn cài đặt đã lưu. Không hoàn tác được.

## 7. Liên hệ

Discord là cách được ưu tiên, trả lời nhanh nhất: https://discord.gg/yH5AAdj5qY

Patreon: https://www.patreon.com/c/linekoaiart447658

X: https://x.com/lyht111222333

Telegram được kiểm tra ít hơn: https://t.me/linekoaiart
