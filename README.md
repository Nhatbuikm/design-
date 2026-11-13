# Buinhat Studio 3.0 — iOS

Ứng dụng thiết kế website và giao diện app, bằng tiếng Việt. Trình thiết kế V3 được đóng gói trong WKWebView (không cần máy chủ); SwiftUI/UIKit cung cấp vỏ ứng dụng iOS, trình chọn tệp, lưu dự án và bảng chia sẻ. Hỗ trợ iOS/iPadOS 16 trở lên.

## Build từ Windows 11

1. Tạo repository Private mới, ví dụ `Buinhat-Studio` trên GitHub.
2. Giải nén ZIP. Upload hai thư mục `BuinhatStudio`, `BuinhatStudio.xcodeproj` và `README.md` vào gốc repo. Giữ nguyên cấu trúc thư mục, không upload nguyên ZIP.
3. Vì trang upload có thể bỏ qua thư mục ẩn `.github`, chọn **Add file → Create new file** và nhập chính xác `.github/workflows/build-studio.yml` ở ô tên file. Dán toàn bộ nội dung từ `workflow-copies/build-studio.yml`. Commit lên nhánh `main`.
4. Mở Actions → Build Buinhat Studio IPA. Nếu chưa tự chạy, dùng Run workflow trên main.
5. Khi dấu tích xanh xuất hiện, vào Summary → Artifacts → `BuinhatStudio-unsigned-IPA`, tải ZIP rồi giải nén. File `BuinhatStudio-unsigned.ipa` chứa app thật nếu Xcode build thành công. Đây là IPA chưa ký; cần chữ ký/provisioning hợp lệ để cài iPhone.
6. Nếu build lỗi, tải `Xcode-build-log` trong Artifacts hoặc gửi dòng `error:` từ bước Build iOS app.

## Sử dụng sau khi cài app

- **Các lớp:** thêm thành phần, đổi mẫu, thêm màn hình.
- **Bản vẽ:** chạm chọn, kéo di chuyển, kéo tay nắm để đổi kích thước.
- **Thuộc tính:** kiểu dáng, màu, chuyển động và tương tác.
- **Tự sắp xếp:** hàng/cột/lưới; **Thư viện:** màu liên kết và thành phần mẫu.
- **Xem trước:** thử điều hướng, hiệu ứng. Liên kết web nếu mở sẽ cần Internet.
- **Xuất tệp → Xuất HTML** hoặc **Lưu JSON**: bảng chia sẻ iOS, chọn Lưu vào Tệp.
- Nhập lại JSON qua cài đặt dự án. Với lớp ảnh, chọn ảnh từ trình chọn tệp (PNG/JPEG/WebP/GIF, dưới 3 MB).
- Dự án hiện tại lưu tự động trong thư mục dữ liệu riêng của app; nên xuất JSON để sao lưu và lưu nhiều thiết kế. Nhập JSON tối đa 12 MB; lưu tự động tối đa 24 MB, xuất tệp tối đa 64 MB.

## Kiểm tra và giới hạn

- Đã kiểm tra cú pháp Swift bằng `swiftc -frontend -parse`, project bằng `plutil`, JavaScript bằng `node --check`.
- Đã kiểm tra trình chỉnh sửa trong Chromium với cầu nối iOS mô phỏng: gửi lưu, xuất HTML/JSON, nhập JSON và khôi phục dự án.
- Chưa chạy Xcode/macOS hay thiết bị iPhone thật trong môi trường hiện tại. Các thao tác UIKit/WebKit thật cần kiểm thử sau build.
- Đây là ứng dụng iOS hybrid, không phải bản viết lại toàn bộ UI bằng SwiftUI. Kế thừa giới hạn V3: bố cục tự động cấp màn hình, animation hai mốc, chưa có vector Bézier, nhóm lồng nhau hay xuất SwiftUI/React. Không xuất IPA của thiết kế.
- Không cần token GitHub để sử dụng app. GitHub Actions chỉ dùng để biên dịch app từ mã nguồn. Hạn mức Actions phụ thuộc tài khoản.
