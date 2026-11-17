# Thay đổi của gói ứng dụng

## Bổ sung đóng gói ngày 16/11/2026

Nguồn trực tiếp: `bloodbank-app-fixed-20261115.zip`.

| Phần | Bổ sung | Lý do |
|---|---|---|
| `app.jar` | JAR đã build từ đúng source bản 15/11, kèm JDBC driver và dependency | `run-app.cmd` cần file này để mở app; ZIP nguồn đang thiếu |
| `VALIDATION.md` | Kết quả ngày 16/11: 13 JUnit test, 37 kiểm tra MySQL và đối chiếu Q1–Q12 | Tài liệu cũ chỉ phản ánh lần kiểm tra 14/11 và Q1–Q5 |
| `README.md` | Cập nhật phiên bản đóng gói và phạm vi kiểm tra | Hướng dẫn khớp với ZIP mới |

Source Java, POM và các file chạy được giữ nguyên từ ZIP 15/11.

## Các thay đổi chức năng có sẵn trong bản 15/11/2026

Nguồn: `bloodbank-app (1).zip`. Bản sửa giữ schema 12 bảng, ngày Việt Nam và cơ chế cấp máu của DB.

| Phần | Đã sửa | Lý do |
|---|---|---|
| ReportService | Q1–Q5 khớp SQL đã duyệt; Q7 có manager; bổ sung Q6, Q9, Q10, Q11 (ngày tham chiếu theo ngày Việt Nam) | Đáp ứng query bắt buộc và đúng phạm vi đã chốt |
| DonorPanel | Reset xóa các ô nhập và bỏ selection | Tránh giữ dữ liệu donor cũ khi đăng ký mới |
| Ui và các panel | Số dòng cho browse, bỏ kết quả tải cũ | Hiển thị đúng số dòng và đúng parent/filter hiện tại |
| InventoryService và InventoryPanel | Nhập expiry, kiểm tra expiry sau collection | Bám baseline thay vì áp quy tắc 35/365/5 của fixture |
| Biz | Bỏ hàm hạn dùng cố định không còn dùng | Tránh hai nguồn quy định hạn dùng |
| POM và test | Pin compiler, tự chạy JUnit, tạo JAR kèm dependency | Build/test rõ ràng và mở app thuận tiện |
| README cùng hợp đồng UI–Backend | Cập nhật chữ ký nhập kho, query và lệnh test | Tài liệu khớp code đã giao |

Không thay mục đích các query nghiệp vụ; không thêm bảng, transfer hoặc sửa trigger/procedure của DB.
