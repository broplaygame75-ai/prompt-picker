# Prompt Picker

Ứng dụng Windows để bốc ngẫu nhiên và quản lý prompt (1 ô bốc, lọc SFW/NSFW, chế độ Bình thường / Loại trừ lễ / Theo tag có % ưu tiên, thư viện có ảnh kết quả). App cài ra là **trống**, không kèm prompt nào.

## Cài đặt
1. Vào trang Releases của repo `prompt-picker-releases`, tải `PromptPicker-Setup-x.y.z.exe`.
2. Mở file. Nếu Windows SmartScreen báo "Windows protected your PC", bấm **More info → Run anyway** (app chưa ký số).
3. Chọn thư mục cài → Install. App có lối tắt ở Desktop, Start Menu, và gỡ được trong *Settings → Apps*.

## Nhập prompt
- Tab **Thêm prompt**: dán `[SFW][Tên {Tag}][prompt], [NSFW][Tên][prompt]` → Xem trước → Thêm tất cả.
- Hoặc bấm **📂 Nhập file** để chọn file sao lưu `.json` (hoặc file `.txt` theo mẫu trên).
- **Xuất JSON** / **Nhập JSON** (tab Thêm prompt hoặc Cài đặt): file JSON thụt dòng, sửa được. Mỗi prompt có `row`, `rating`, `name`, `themes`, `prompt`. Có thể kèm `characters` với `name`, `source`, `doneRows`. Nhập hỏi trước khi ghi đè, cập nhật prompt theo số hàng, thêm hàng mới, rồi báo số dòng đã thêm và đã cập nhật.

## Ngôn ngữ
Nút **VI / EN** trên header đổi toàn bộ giao diện giữa Tiếng Việt và English, kể cả hộp cập nhật. Mặc định là Tiếng Việt. Lựa chọn được nhớ trên máy, trong cùng file dữ liệu với prompt.

## Phím tắt
`1` bốc · `Q` hoặc `C` copy prompt vừa bốc. Trước khi copy phải chọn nhân vật dạng `Name - Source` (ví dụ `Boothill - HSR`): **Chọn cũ** để lọc danh sách đã lưu, hoặc **Tạo mới** để thêm nhân vật. Danh sách nhân vật nằm trong file sao lưu.

Mỗi prompt có **số hàng** cố định (như số dòng Excel), hiện dạng `#12` và tìm được trong ô tìm kiếm. Copy cho một nhân vật sẽ ghi hàng đó vào danh sách đã xong của nhân vật. Prompt đã xong với nhân vật đang chọn được đánh dấu. Xoá prompt không đổi số hàng của prompt còn lại.

## Dữ liệu
Lưu trên máy bạn: `%APPDATA%\Prompt Picker\data` (prompts.json + thư mục images). Đổi/mở thư mục trong **Cài đặt**. Nên **Xuất file sao lưu** định kỳ.

## Cập nhật
App tự kiểm tra khi mở và mỗi 4 giờ; có bản mới sẽ hiện thông báo. Hoặc bấm **Kiểm tra cập nhật** trong Cài đặt.

## Dành cho người phát triển
`npm ci && npm start` để chạy thử. Đẩy tag `v*` để GitHub Actions build bộ cài NSIS và đăng lên repo public `prompt-picker-releases` (cần secret `RELEASES_TOKEN`: fine-grained token có quyền Contents: Read & write trên repo đó).
