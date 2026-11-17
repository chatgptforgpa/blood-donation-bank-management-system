# Kết quả kiểm tra ngày 16/11/2026

Nguồn: `bloodbank-app-fixed-20261115.zip`. Gói ngày 16/11 bổ sung JAR đã build và cập nhật tài liệu; giữ nguyên source Java, POM và các file chạy của bản 15/11. Baseline DB vẫn là 12 bảng.

Bản source trên GitHub giữ nguyên source đã kiểm tra. JAR của gói đã build được tạo lại bằng `build-and-test.cmd` khi tải source; JAR và cấu hình tài khoản cục bộ được loại khỏi Git.

## Build và JUnit

- Maven 3.9.9, JDK 25.0.2, biên dịch release Java 17.
- `mvn verify`: BUILD SUCCESS.
- **13 JUnit test PASS, 0 failure, 0 error, 0 skipped**: bảy biên ngày inventory, một test chạy chín assertion transaction có sẵn, bốn test tải dữ liệu/count và một test reset donor.
- Test transaction dùng fake JDBC; các test UI chạy headless. Chúng tự chạy trong Maven, không cần MySQL.
- `app.jar` được sao chép từ `target/bloodbank-app.jar` đã build thành công. JAR có MySQL Connector/J 8.4.0 và dependency cần thiết, khai báo Main-Class `bb.ui.App` và JDBC driver service.
- Toàn bộ 31 class của app trong JAR khớp byte với kết quả build, class version Java 17. Không chứa tài khoản database.

## MySQL thật

MySQL 8.0.46 thử nghiệm riêng, seed ngày 14/11/2026, ngày chạy 16/11/2026. Đã chạy **37 kiểm tra tích hợp**, tất cả PASS, gồm:

- Browse 250 donor, 200 donation event, 180 unit và 85 request.
- Q1–Q12 được so sánh toàn bộ dòng kết quả theo các cột của SQL đã duyệt; bỏ qua thứ tự trả dòng và giữ nguyên số lần xuất hiện của từng dòng. Kết quả khớp, không chỉ khớp số dòng. Q8 và Q9 có thêm cột hiển thị trong app; phép đối chiếu dùng các cột của SQL chuẩn.
- Q7 có mã và tên manager, công thức wastage giữ đúng số đếm.
- Đăng ký/sửa donor có phone; tên có dấu nháy đơn được xử lý bằng tham số.
- Donor mới được hiến lần đầu; khoảng cách 56 ngày vẫn được DB chặn.
- Chặn nhập unit trước khi event Passed; đủ năm Negative cho event Passed.
- Expiry nhập tùy chọn hai ngày sau collection được lưu đúng nguyên giá trị; expiry bằng collection hoặc để trống bị từ chối.
- Batch có unit thứ hai sai component: không để lại issue hoặc trạng thái cập nhật dở.
- Batch hợp lệ commit đủ unit và trạng thái request; request đã Fulfilled không được cấp thêm.
- Hai lần cấp cùng một unit, hoặc cùng lấy slot cuối của request: chính xác một bên commit.
- Discard qua procedure tiếp tục hoạt động.

| Report | Số dòng khi chạy ngày 16/11 trên seed 14/11 |
|---|---:|
| Q1 | 4 |
| Q2 | 10 |
| Q3 | 25 |
| Q4 | 1 |
| Q5 | 3 |
| Q6 | 4 |
| Q7 | 75 |
| Q8 | 7 |
| Q9 | 15 |
| Q10 | 25 |
| Q11 | 0 |
| Q12 | 24 |
| Tồn kho khả dụng | 97 |

Số dòng có thể thay đổi khi ngày tham chiếu hoặc dữ liệu thay đổi. Các report được so sánh trước khi thêm bản ghi dùng để kiểm tra chức năng.

Q6 dùng phạm vi AB+ Platelets của câu hỏi đã chốt. Q11 là truy vấn tìm trường hợp cấp sai nhóm máu, Rh hoặc thành phần; 0 dòng là kết quả phù hợp khi dữ liệu không có vi phạm.

## Phạm vi kiểm tra giao diện và đóng gói

- Các test UI chạy headless: reset donor, số dòng browse, bỏ kết quả hoặc lỗi của yêu cầu đọc đã cũ. Test dùng latch để điều khiển thứ tự hoàn thành.
- Đợt kiểm tra ngày 16/11 không chạy lại toàn bộ giao diện bằng tay. Các file UI production giống bản 14/11 đã được kiểm tra trực quan trước đó.
- Gói mới có `app.jar`, `run-app.cmd`, `build-and-test.cmd`, source và `db.properties.sample`. Để mở app cần Java 17 trở lên và cấu hình kết nối MySQL của nhóm; không cần Maven để chạy JAR đã kèm.
- Maven chỉ tự chạy 13 JUnit test. 37 kiểm tra MySQL được thực hiện bằng harness riêng trên database thử nghiệm, không nằm trong lệnh `mvn verify` mặc định.

Các kiểm tra tích hợp được thực hiện trên DB thử riêng; không xóa hoặc sửa DB người dùng đang sử dụng. Gói giao không chứa cấu hình tài khoản của môi trường kiểm tra.
