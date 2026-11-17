# Group 02 - Database D3

Gói MySQL theo baseline 12 bảng. Bản seed đi kèm có ngày tham chiếu 14/11/2026 và đúng 2.000 dòng.

## Dựng database mẫu

1. Dùng MySQL 8.0.46 và tài khoản có quyền tạo database, bảng, trigger, procedure và event.
2. Trong MySQL Workbench, mở `rebuild.sql` và chạy toàn bộ file.
3. Kiểm tra kết quả có 12 bảng, tổng seed bằng 2.000 và thông báo cài đặt business rules.
4. Mở `test_business_rules.sql` trong một tab riêng, chạy toàn bộ file. Kết quả mong đợi là sáu cột PASS.
5. Chạy lại toàn bộ `rebuild.sql`, rồi chạy lại smoke test để kiểm tra khả năng dựng lại.
6. Các câu truy vấn nằm trong `QUERY/SQL 1.sql` đến `QUERY/SQL 12.sql`. Q12 gồm lệnh tạo VIEW; chạy file Q12 sau mỗi lần rebuild trước khi backend sử dụng `v_request_outstanding`.

`rebuild.sql` xóa và tạo lại riêng database `blood_bank_group2_d3`, bao gồm toàn bộ dữ liệu đang có trong database đó. Đây là điểm vào dành cho việc dựng lại database mẫu.

File rebuild đã ghép sẵn theo thứ tự tạo bảng, nạp seed và cài business rules. Các đoạn SQL khởi tạo nằm trong cùng một file để chạy từ đầu trong Workbench.

## Sinh lại seed theo ngày sử dụng

Trong thư mục này, cài thư viện và chạy generator bằng Python.

```powershell
python -m pip install -r requirements.txt
python generate_seed_2000.py
```

Generator mặc định dùng ngày hiện tại ở Việt Nam và tạo lại cả `seed_2000.sql` lẫn `rebuild.sql`.
Để kiểm tra với một ngày cụ thể, truyền tham số ngày. Ví dụ, khi chuẩn bị bộ dữ liệu cho ngày 22/11/2026, dùng lệnh sau.

```powershell
python generate_seed_2000.py --as-of 2026-11-22
```

Sau khi sinh lại, chạy `rebuild.sql` và cập nhật expected/actual của QD theo cùng ngày tham chiếu. Các query thời gian cần cùng một bộ seed và cùng ngày tham chiếu để đối chiếu được kết quả.

Thư mục `RA` trong gói này là bản chụp theo ngày 14/11/2026, gồm dữ liệu `Blood_Bank.txt`, bốn biểu thức Q1/Q2/Q3/Q8 và bốn query tree. Generator chỉ tạo lại seed và rebuild; khi dùng ngày khác, cần đồng bộ lại dữ liệu RA, các mốc ngày trong biểu thức và ảnh tree/kết quả bị thay đổi.

Seed có các issue lịch sử và trạng thái đã tính sẵn. File rebuild nạp chúng trước khi cài trigger nghiệp vụ cho thao tác vận hành.

## Dữ liệu phục vụ Query Matrix

- Có 22 request Critical, gồm 15 request đã có issue và 7 request chưa có issue.
- Q6 giữ tình huống AB+ Platelets trong Query Matrix gốc và liệt kê unit phù hợp còn khả dụng. `S2KR0077` là một request Critical tương ứng để minh họa tình huống này.
- Q8 dùng các request Critical chưa có issue. Q9 dùng các request Critical đã có issue.
- Q11 liệt kê các unit được cấp sai nhóm máu, Rh hoặc component. Kết quả kỳ vọng trên seed hợp lệ là 0 dòng. Ghi nhận đặc điểm này khi đối chiếu yêu cầu các query phải có kết quả trong đề.
- Q7 tính tỷ lệ unit Expired trên tổng unit theo ngân hàng và component, theo công thức trong bản query gốc.

## Khi kết nối Backend

Backend gọi `d309_issue_unit` và `d309_discard_unit` theo các tham số đã khai báo trong `business_rules.sql`. Khi sử dụng transaction JDBC, Backend sở hữu commit/rollback.

Mẫn cấu hình tài khoản database dùng cho app theo hướng dẫn ở đầu `business_rules.sql`. Tài khoản app cần quyền EXECUTE cho các procedure được sử dụng và quyền đọc/ghi cột cần thiết. Quyền cập nhật `BLOOD_UNIT.status` phải đi qua procedure để thao tác discard được kiểm tra staff cùng ngân hàng. Thông tin tài khoản thực tế do nhóm cấu hình khi tích hợp.

Đối với lịch hết hạn tự động, kiểm tra `SHOW VARIABLES LIKE 'event_scheduler';`. Nếu Event Scheduler đang OFF, quản trị viên bật nó hoặc sắp lịch gọi `d309_expire_units()` hằng ngày theo cách vận hành đã chọn.

## Các thay đổi trong gói này

- Khôi phục generator có Critical cho cả request đã cấp và chưa cấp, để Q8/Q9 có dữ liệu mẫu phù hợp.
- Generator xuất thêm `rebuild.sql`, giúp một lần chạy tạo đủ database, seed và cơ chế nghiệp vụ. Điểm vào này hỗ trợ chạy lại từ đầu hai lần.
- `requirements.txt` ghi phiên bản Faker và thay cho việc đóng gói môi trường Python cục bộ.
- `README.md` ghi cách dựng lại, sinh seed theo ngày và các bước tích hợp Backend.
- Giữ bộ 12 SQL và bốn RA từ `g2 (4)`, sửa duy nhất alias `eS` thành `e` trong Q4.
- Đồng bộ dữ liệu RA với seed ngày 14/11/2026 và tạo lại query tree Q8 với kết quả bảy request chưa được cấp.
- Xem `VALIDATION_20261114.md` để đối chiếu kết quả kiểm tra MySQL và các số dòng của Q1–Q12.

## Bản sửa cú pháp trigger

Hai trigger quản lý STAFF dùng `DROP TRIGGER IF EXISTS` rồi `CREATE TRIGGER`, giữ nguyên nội dung kiểm tra. MySQL hỗ trợ `CREATE TRIGGER IF NOT EXISTS` từ 8.0.29; bản này tránh dùng cú pháp đó.

Nếu DB đã có bảng STAFF, mở `fix_staff_triggers.sql` và chạy toàn bộ file để thay hai trigger. File vá không xóa bảng hoặc nạp lại seed. Khi dựng database mẫu từ đầu mới dùng `rebuild.sql`.
