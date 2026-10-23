# Prompt Picker

Ứng dụng Windows để bốc ngẫu nhiên và quản lý prompt (1 ô bốc, lọc SFW/NSFW, ba cột Bình thường / Loại trừ / Ưu tiên hiện cùng lúc, thư viện có ảnh kết quả). App cài ra là **trống**, không kèm prompt nào.

## Cài đặt
1. Vào trang Releases của repo `prompt-picker-releases`, tải `PromptPicker-Setup-x.y.z.exe`.
2. Mở file. Nếu Windows SmartScreen báo "Windows protected your PC", bấm **More info → Run anyway** (app chưa ký số).
3. Install. Nếu máy đã có bản cũ, bộ cài ghi đè đúng thư mục đó (không cần gỡ trước, không thêm một mục nữa trong *Settings → Apps*). Dữ liệu prompt không bị xoá. App có lối tắt ở Desktop và Start Menu.
4. Gỡ trong *Settings → Apps*. Ô xoá dữ liệu mặc định không được tick. Chỉ khi tự tick thì `%APPDATA%\Prompt Picker\data` mới bị xoá.

## Nhập prompt
- Trong **Cài đặt → Dán prompt**: dán `[SFW][Tên &New&&Halloween& "ghi chú"][prompt], [NSFW][Tên][prompt]` → Xem trước → Thêm tất cả. Trong tên, `&nhãn&` là nhãn, chữ trong dấu nháy kép là ghi chú nhỏ màu xám. Tag là các phần của nội dung prompt cách nhau bằng dấu phẩy. Ngoặc `()` `[]` `{}` là cú pháp TensorArt và được giữ nguyên trong prompt. Tên cũ dạng `{New}`, `(Nope)` hoặc `(JJK)` vẫn nhập được: New, Nope và nhãn ngày lễ thành nhãn lọc được, phần còn lại thành ghi chú. Nhãn có hai loại: **lọc được** (New, Nope và nhãn ngày lễ mặc định; hiện trong bộ lọc, Loại trừ theo nhãn và Ưu tiên) và **mô tả** (các nhãn khác, chỉ hiện thành chip mờ trên thẻ). Không còn ô nhãn ngày lễ trong **Cài đặt**. Nhãn lọc được lấy từ ô **Nhãn lọc được** của từng prompt. New, Nope và nhãn ngày lễ (halloween, christmas, valentine, easter, new year, lunar new year, tet, thanksgiving) mặc định vẫn lọc được. Loại trừ và Ưu tiên chỉ liệt kê nhãn lọc được đang có trên prompt. Trong **Cài đặt → Nhãn**, nhãn tìm thấy trên prompt có công tắc **Cho phép lọc** và có thể đổi tên.
- Trong **Cài đặt → Sao lưu & Nhập dữ liệu**: **Xuất** chọn sao lưu đầy đủ (kể cả ảnh) hoặc chỉ prompt dạng JSON dễ đọc. **Nhập** tự nhận loại file. JSON prompt cập nhật theo số hàng, thêm hàng mới, và hỏi trước khi ghi đè. **Tải file mẫu** lưu `prompt-template.json` (hướng dẫn tiếng Anh `_guide` và 3 prompt mẫu SFW, nhập được ngay). **Sao chép hướng dẫn cho AI** chép đoạn tiếng Anh để AI viết JSON đúng mẫu. Mỗi prompt có `row`, `rating`, `name`, `labels`, `themes`, `notes`, `prompt`. `labels` và `themes` cùng là nhãn trong tên; file cũ chỉ có `themes` hoặc `tags` vẫn nhập được. `labelRules` ghi từng nhãn và `filterable` (Cho phép lọc). Có thể kèm `characters` với `name`, `source`, `doneRows`. File sao lưu cũng giữ `labelRules`. File `.txt` theo mẫu dán cũng nhập được.

## Ngôn ngữ
Nút bánh răng trên header mở **Cài đặt**, chia tab: Ngôn ngữ (English mặc định, Tiếng Việt, 中文, 한국어), Dán prompt, Nhãn, Sao lưu & Nhập dữ liệu, và Dữ liệu (thư mục, phiên bản, đặt lại). Ngôn ngữ được nhớ trên máy và đổi mọi chữ kể cả dòng giải thích và hộp cập nhật. Chữ Latin và tiếng Việt dùng Be Vietnam Pro; tiếng Trung và tiếng Hàn lần lượt dùng Microsoft YaHei và Malgun Gothic trên Windows.

## Ba tab
- **Bốc prompt**: một ô bốc ngẫu nhiên và copy. Ba cột hiện cùng lúc: **Bình thường** (rating và lọc từ khoá hoặc số hàng), **Loại trừ** (thêm nhãn lọc được hoặc tag trong nội dung prompt; chip đang bật bị bỏ trước), **Ưu tiên** (thêm nhãn lọc được và một thanh %). Chip là viên thuốc bo tròn, nền tối, màu theo từng nhãn, chữ đậm; bấm để bật hoặc tắt, ✕ để gỡ. Cửa sổ hẹp thì ba cột xếp dọc. Khi chưa có prompt, tab này hiện **Nhập prompt để bắt đầu bốc** cùng nút mở **Cài đặt** để nhập file hoặc dán prompt. Trước khi copy phải chọn nhân vật `Name - Source`. Nút **Tới prompt** mở đúng thẻ trong Dữ liệu prompt và làm nổi nó. Nhật ký cũng có nút này. Ảnh kết quả thả hoặc dán vào đây hiện bên trái, cạnh tên `#165`, và cùng hiện trên thẻ trong Dữ liệu prompt. Nút **✕** hỏi rồi xoá file ảnh trên đĩa.
- **Dữ liệu prompt**: khi chưa có prompt, khung danh sách vẫn hiện với dòng **Chưa có dữ liệu prompt**, gợi ý ngắn, và nút nhập file hoặc dán prompt. Khi đã có dữ liệu, tab chỉ còn thanh lọc (tìm, rating, nhãn lọc được, xếp) ghim phía trên, nút **Làm mới**, tổng số (ví dụ `592 prompt`), và lưới thẻ cuộn trong khung riêng. Trang không cuộn theo. Lưới 2 cột khi khung hẹp, 3 cột khi rộng; ảnh nằm bên trái thẻ. Nút **Thêm prompt** và **Sửa** mở form riêng: tên, rating (SFW/NSFW/All), nội dung prompt (ngoặc `()` `[]` giữ nguyên), ghi chú, nhãn mô tả và nhãn lọc được. Ô nhãn là chip, gõ để gợi ý nhãn đã có; nhãn mới trong ô lọc được thì được đánh dấu lọc được. Lưu tách tên khỏi nhãn và ghi chú. Nhãn mô tả chỉ là chip mờ trên thẻ. Dán prompt, Sao lưu & Nhập dữ liệu, quản lý nhãn và thư mục dữ liệu nằm trong **Cài đặt**. **Làm mới** đọc lại `prompts.json` trên đĩa và phân tích lại tên, nhãn, ghi chú.
- **Nhật ký prompt**: khi chưa có prompt, tab hiện **Chưa có nhật ký prompt** và cùng hai nút nhập file / dán prompt. Khi đã có prompt, từng nhân vật và các hàng đã copy. Mỗi hàng có nút xoá. Hàng bị đánh dấu nếu prompt đã đổi sau lúc ghi. **Xuất JSON** / **Nhập JSON** ở tab này chỉ gồm nhật ký: nhân vật `name` + `source`, và mỗi hàng có `row`, `at`, `editedAfterLogging`. Nhập gộp theo nhân vật và số hàng, hỏi trước, rồi báo số hàng đã thêm và đã cập nhật.

## Phím tắt
`1` bốc · `Q` hoặc `C` copy prompt vừa bốc. Trước khi copy phải chọn nhân vật dạng `Name - Source` (ví dụ `Boothill - HSR`): **Chọn cũ** để lọc danh sách đã lưu, hoặc **Tạo mới** để thêm nhân vật. Danh sách nhân vật nằm trong file sao lưu.

Mỗi prompt có **số hàng** cố định (như số dòng Excel), hiện dạng `#12` và tìm được trong ô tìm kiếm. Copy cho một nhân vật sẽ ghi hàng đó vào danh sách đã xong của nhân vật. Prompt đã xong với nhân vật đang chọn được đánh dấu. Xoá prompt không đổi số hàng của prompt còn lại.

## Dữ liệu
Lưu cố định ở `%APPDATA%\Prompt Picker\data` (prompts.json + thư mục images). Thư mục đã có thì dùng lại, chưa có thì tạo mới. Cài đè và cập nhật tự động không xoá thư mục này. Mở thư mục trong **Cài đặt → Dữ liệu**. Nên **Xuất** bản sao lưu đầy đủ định kỳ (tab Sao lưu & Nhập dữ liệu).

## Cập nhật
App tự kiểm tra khi mở và mỗi 4 giờ; có bản mới sẽ hiện thông báo. **Cập nhật ngay** tải bản mới rồi cài đè đúng thư mục đang chạy, không hỏi thư mục và không xoá dữ liệu. Hoặc bấm **Kiểm tra cập nhật** trong **Cài đặt → Dữ liệu**.

## Dành cho người phát triển
`npm ci && npm start` để chạy thử. Đẩy tag `v*` để GitHub Actions build bộ cài NSIS và đăng lên repo public `prompt-picker-releases` (cần secret `RELEASES_TOKEN`: fine-grained token có quyền Contents: Read & write trên repo đó).
