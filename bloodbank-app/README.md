# Blood Bank App Group 02

Gói hoàn thiện ngày 16/11/2026, từ `bloodbank-app-fixed-20261115.zip`. Java Swing, JDBC, baseline DB 12 bảng. Gói này bổ sung `app.jar` từ đúng source đã kiểm tra và cập nhật tài liệu kiểm tra.

## Chạy bản đã build

**Nếu tải source từ GitHub:** máy cần Java 17 trở lên và Maven; chạy `build-and-test.cmd` trong thư mục này trước để tạo `app.jar`, rồi thực hiện các bước cấu hình và mở app dưới đây. JAR được tạo sau khi build và được `.gitignore` loại khỏi Git. Với ZIP đã build ngày 16/11, JAR đã có sẵn.

1. Giải nén ZIP và mở thư mục `bloodbank-app`.
2. Máy cần Java 17 trở lên. `app.jar` đã kèm Connector/J nên chạy app không cần Maven.
3. Sao chép `db.properties.sample` thành `db.properties`, điền URL, user và password do nhóm DB cấp.
4. Mở `run-app.cmd` hoặc chạy `java -jar app.jar`. Nếu cấu hình chưa hợp lệ, app hiện hộp thoại nhập kết nối.

DB đã hoạt động thì kết nối trực tiếp; không chạy rebuild mỗi lần mở app. Gói app không tự xóa hoặc tạo lại database.

## Chuẩn bị database khi chưa có

- Dùng gói DB đã chốt, ví dụ `g2_fixed_20261114_trigger_compat`. `rebuild.sql` chỉ dùng để dựng lại DB mẫu và thay dữ liệu trong schema đó.
- Schema mặc định là `blood_bank_group2_d3`. App không thay bảng hoặc business rule DB.
- Mẫn cấp quyền SELECT và INSERT/UPDATE/DELETE cần thiết theo chức năng; EXECUTE cho `d309_issue_unit`, `d309_discard_unit`, `d309_expire_units`. Không cấp UPDATE trực tiếp cột trạng thái dẫn xuất cho app.
- Nếu Event Scheduler OFF, có thể dùng nút “Cập nhật đơn vị hết hạn” hoặc để quản trị viên vận hành lịch theo kế hoạch của nhóm.

## Build và test

Đã kiểm tra bằng Maven 3.9.9, JDK 25.0.2 với target Java 17. Compiler 3.13.0, Surefire 3.2.5 và dependency được pin trong POM.

```powershell
mvn clean verify
```

Maven tự chạy JUnit cho transaction, biên ngày expiry và hồi quy UI. Các test này không cần MySQL. Transaction harness cũ vẫn chạy thủ công được trên Windows:

```powershell
mvn test-compile
java -cp "target/test-classes;target/classes" bb.service.IssuanceTxCheck
```

JAR đầy đủ sau build là `target/bloodbank-app.jar`. `build-and-test.cmd` chạy build/test rồi cập nhật `app.jar`. Đóng app trước khi thay JAR nếu Windows báo file đang được sử dụng. Chạy source qua Maven bằng `mvn compile exec:java` vẫn được.

## Các phần đã sửa

- 17/11/2026: tab Donor có nút xóa (hỏi xác nhận; donor đã hiến máu bị FK chặn và app báo lý do bằng câu dễ hiểu). Tab Requests có sửa mức khẩn cấp/số lượng và xóa yêu cầu. Q11 đổi sang `EXCEPT`, Q12 đọc từ view `v_request_outstanding`. `Errors` giải thích vi phạm theo tên constraint.

- 17/11/2026 (2): toàn bộ giao diện và thông báo lỗi chuyển sang tiếng Anh (tab Donor, Donations & Screening, Inventory, Requests, Issuance, Reports); tên báo cáo dạng `Q1. ...`, không dùng dấu gạch dài.
- Tab Reports có đủ Q1 đến Q12 theo Query Matrix (Q6 cố định AB+ Platelets, Q7 có manager) và báo cáo tồn kho.
- Reset donor xóa dữ liệu và selection; browse có số dòng; kết quả đọc cũ không đè lên filter/selection mới.
- Nhập kho nhận expiry do người dùng nhập, bắt buộc sau collection. Collection không ở tương lai; expiry ở tương lai được phép. Không áp cứng 35/365/5 ngày từ generator.
- Maven tự chạy test và tạo JAR có dependency, kèm file mở app.

## Kiểm tra trên MySQL thật

JUnit không thay thế test tích hợp. Trên DB mẫu riêng, đối chiếu:

1. Cả Q1–Q12 khớp toàn bộ dòng theo các cột của SQL đã duyệt. Kiểm tra ngày 16/11/2026 trên seed 14/11/2026; số dòng từng report nằm trong `VALIDATION.md`. Ngày hoặc dữ liệu thay đổi thì số dòng có thể đổi.
2. Donor mới vẫn hiến lần đầu được; đủ năm Negative làm event Passed. Nhập unit với expiry hợp lệ không trùng các mốc 35/365/5 cũng được lưu đúng.
3. Cấp nhiều unit hợp lệ thì commit; một unit sai thì rollback toàn bộ lần cấp.
4. Hai app cùng cấp một unit hoặc cùng lấy slot cuối: chính xác một bên thành công.
5. Reset form, số dòng browse và kết quả tải về sai thứ tự được kiểm tra bằng JUnit headless; đây là phần kiểm tra riêng với các luồng MySQL thật.

Kết quả ngày 16/11/2026: **13 JUnit test và 37 kiểm tra tích hợp MySQL đều PASS**. Maven tự chạy 13 JUnit test; 37 kiểm tra tích hợp được chạy riêng trên database thử nghiệm.

Xem `VALIDATION.md` để biết các kiểm tra đã thực hiện. `CHANGES.md` ghi các thay đổi và lý do; `docs/D3-18_screen_flow_va_hop_dong_UI_Backend.md` mô tả hợp đồng thao tác.

ZIP không chứa tài khoản DB thực tế. `db.properties.sample` để trống user/password; cấu hình riêng nằm ngoài source.
