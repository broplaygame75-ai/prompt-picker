# Prompt Picker

Ứng dụng Windows để bốc ngẫu nhiên và quản lý prompt (1 ô bốc, lọc SFW/NSFW, chế độ Bình thường / Loại trừ lễ / Theo tag có % ưu tiên, thư viện có ảnh kết quả). App cài ra là **trống**, không kèm prompt nào.

## Cài đặt
1. Vào trang Releases của repo `prompt-picker-releases`, tải `PromptPicker-Setup-x.y.z.exe`.
2. Mở file. Nếu Windows SmartScreen báo "Windows protected your PC", bấm **More info → Run anyway** (app chưa ký số).
3. Install. Nếu máy đã có bản cũ, bộ cài ghi đè đúng thư mục đó (không cần gỡ trước, không thêm một mục nữa trong *Settings → Apps*). Dữ liệu prompt không bị xoá. App có lối tắt ở Desktop và Start Menu.
4. Gỡ trong *Settings → Apps*. Ô xoá dữ liệu mặc định không được tick. Chỉ khi tự tick thì `%APPDATA%\Prompt Picker\data` mới bị xoá.

## Nhập prompt
- Tab **Dữ liệu prompt**: dán `[SFW][Tên {Tag}][prompt], [NSFW][Tên][prompt]` → Xem trước → Thêm tất cả.
- Hoặc bấm **📂 Nhập file** để chọn file sao lưu `.json` (hoặc file `.txt` theo mẫu trên).
- **Xuất JSON** / **Nhập JSON** (cùng tab Dữ liệu prompt): file JSON thụt dòng, sửa được. Mỗi prompt có `row`, `rating`, `name`, `themes`, `prompt`. Có thể kèm `characters` với `name`, `source`, `doneRows`. Nhập hỏi trước khi ghi đè, cập nhật prompt theo số hàng, thêm hàng mới, rồi báo số dòng đã thêm và đã cập nhật.

## Ngôn ngữ
Nút **VI / EN** trên header đổi toàn bộ giao diện giữa Tiếng Việt và English, kể cả hộp cập nhật. Mặc định là Tiếng Việt. Lựa chọn được nhớ trên máy, trong cùng file dữ liệu với prompt.

## Ba tab
- **Bốc prompt**: một ô bốc ngẫu nhiên và copy. Trước khi copy phải chọn nhân vật `Name - Source`.
- **Dữ liệu prompt**: sửa, xoá, thêm prompt, nhập/xuất JSON, sao lưu và thư mục dữ liệu. Danh sách hiện tổng số (ví dụ `592 prompt`) và tải thêm khi cuộn, không cắt ở 300 dòng.
- **Nhật ký prompt**: từng nhân vật và các hàng đã copy. Mỗi hàng có nút xoá. Hàng bị đánh dấu nếu prompt đã đổi sau lúc ghi.

## Phím tắt
`1` bốc · `Q` hoặc `C` copy prompt vừa bốc. Trước khi copy phải chọn nhân vật dạng `Name - Source` (ví dụ `Boothill - HSR`): **Chọn cũ** để lọc danh sách đã lưu, hoặc **Tạo mới** để thêm nhân vật. Danh sách nhân vật nằm trong file sao lưu.

Mỗi prompt có **số hàng** cố định (như số dòng Excel), hiện dạng `#12` và tìm được trong ô tìm kiếm. Copy cho một nhân vật sẽ ghi hàng đó vào danh sách đã xong của nhân vật. Prompt đã xong với nhân vật đang chọn được đánh dấu. Xoá prompt không đổi số hàng của prompt còn lại.

## Dữ liệu
Lưu cố định ở `%APPDATA%\Prompt Picker\data` (prompts.json + thư mục images). Thư mục đã có thì dùng lại, chưa có thì tạo mới. Cài đè và cập nhật tự động không xoá thư mục này. Mở thư mục trong tab **Dữ liệu prompt**. Nên **Xuất file sao lưu** định kỳ.

## Cập nhật
App tự kiểm tra khi mở và mỗi 4 giờ; có bản mới sẽ hiện thông báo. **Cập nhật ngay** tải bản mới rồi cài đè đúng thư mục đang chạy, không hỏi thư mục và không xoá dữ liệu. Hoặc bấm **Kiểm tra cập nhật** trong tab Dữ liệu prompt.

## Dành cho người phát triển
`npm ci && npm start` để chạy thử. Đẩy tag `v*` để GitHub Actions build bộ cài NSIS và đăng lên repo public `prompt-picker-releases` (cần secret `RELEASES_TOKEN`: fine-grained token có quyền Contents: Read & write trên repo đó).
