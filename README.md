# Blood Donation and Blood Bank Management System

PDM Group 02: ứng dụng desktop Java Swing + JDBC cho quản lý donor, hiến máu, sàng lọc, kho máu, yêu cầu của bệnh viện và cấp máu.

Source ứng dụng là bản đã hoàn thiện ngày 16/11/2026, dựa trên bản chức năng 15/11/2026. Database giữ baseline 12 bảng; dữ liệu đi kèm là dữ liệu mẫu được sinh để kiểm thử.

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| [`bloodbank-app/`](bloodbank-app/) | Source Java, Maven, 13 JUnit test và hướng dẫn chạy |
| [`database/g2/`](database/g2/) | Schema, seed 2.000 dòng, trigger/procedure/event và generator |
| [`database/g2/QUERY/`](database/g2/QUERY/) | Q1 đến Q12 bằng MySQL |
| [`database/g2/RA/`](database/g2/RA/) | Dữ liệu và biểu thức/tree RA theo snapshot 14/11/2026 |
| [`database/PDM_Group02_Setup_Workbench.sql`](database/PDM_Group02_Setup_Workbench.sql) | Lựa chọn khởi tạo DB trống, kèm VIEW |

## Chạy ứng dụng từ GitHub

Cần Java 17 trở lên (đã chạy với JDK 25.0.2), Maven, MySQL Connector/J 8.4.0 (Maven tự tải) và MySQL 8.0.31 trở lên (đã kiểm tra trên MySQL 8.0.46 và 26.10.0). Tải repository bằng **Code → Download ZIP** hoặc clone, rồi giải nén.

1. **Dựng DB mẫu:** mở `database/g2/rebuild.sql` trong MySQL Workbench và chạy toàn bộ file. File này xóa và tạo lại riêng schema `blood_bank_group2_d3`, bao gồm dữ liệu đang có trong schema đó; dùng khi chủ động dựng lại DB mẫu. Ngày trong dữ liệu mẫu tự dời theo ngày chạy, nên chạy hôm nào thì 12 query cũng có kết quả.
2. `rebuild.sql` đã tạo view `v_request_outstanding`. Có thể chạy `database/g2/test_business_rules.sql` và `database/g2/constraint_tests.sql` (với `--force`) để kiểm tra các rule; 12 query nằm trong `database/g2/QUERY/queries.sql`.
3. Trong thư mục `bloodbank-app`, sao chép `db.properties.sample` thành `db.properties`, điền URL, tài khoản và mật khẩu MySQL của máy đang dùng.
4. Chạy `build-and-test.cmd`. Script build, chạy 13 JUnit test và tạo `app.jar`.
5. Mở `run-app.cmd` để chạy ứng dụng.

JAR được tạo tại máy sau khi build. Các file `db.properties`, JAR, `target/`, log và cấu hình IDE được loại khỏi Git.

Trên hệ điều hành khác, trong `bloodbank-app` có thể dùng:

```sh
mvn clean verify
java -jar target/bloodbank-app.jar
```

Nếu đã có database hoạt động, cấu hình ứng dụng để kết nối vào database đó. Xem thêm [hướng dẫn app](bloodbank-app/README.md) và [hướng dẫn database](database/g2/README.md).

## Kết quả kiểm tra

- Maven build thành công; **13 JUnit test PASS**.
- **37 kiểm tra tích hợp MySQL thật PASS**, gồm commit/rollback và hai tình huống cấp máu đồng thời.
- Toàn bộ dòng Q1 đến Q12 khớp các SQL đã chốt theo các cột của SQL chuẩn.
- Ba dòng trên là kết quả ngày **16/11/2026**, trên bản source trước các sửa đổi 17 và 18/11 (Q11 EXCEPT, xóa donor/request, giao diện tiếng Anh, bắt buộc ít nhất một số điện thoại).
- Bản hiện tại đã chạy lại ngày **18/11/2026** trên MySQL 26.10.0: 24 kiểm tra tích hợp của service (LiveCheck) PASS, kiểm tra transaction cấp máu (IssuanceTxCheck) PASS, `test_business_rules.sql` sáu cột PASS, 10/10 câu trong `constraint_tests.sql` bị từ chối đúng, 12 query đều có kết quả. **13 JUnit test chưa chạy lại trên bản này** (máy kiểm tra không có Maven); cần chạy `mvn clean verify` trước khi nộp.

Chi tiết: [`bloodbank-app/VALIDATION.md`](bloodbank-app/VALIDATION.md). Maven tự chạy 13 JUnit test; các kiểm tra tích hợp được chạy riêng trên DB thử nghiệm.

## Collaboration

Create a branch for each change and open a pull request into `main`. State what changed, which business rule or query it affects, and how it was checked. Do not commit credentials or real donor/patient data.
