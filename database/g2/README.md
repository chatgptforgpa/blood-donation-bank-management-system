# Group 02 - Database D3

Gói MySQL theo baseline 12 bảng. Bản seed đi kèm có đúng 2.000 dòng, sinh với ngày 14/11/2026. Kết quả trong report lấy ngày 17/11/2026 (ngày tham chiếu). Khi chạy `rebuild.sql`, mọi cột ngày được dời theo số ngày giữa 17/11/2026 và ngày chạy (`date_shift.sql`), nên chạy hôm nào thì dữ liệu cũng là "tính đến hôm nay" và 12 query đều có kết quả.

## Dựng database mẫu

1. Dùng MySQL 8.0.46 và tài khoản có quyền tạo database, bảng, trigger, procedure và event.
2. Trong MySQL Workbench, mở `rebuild.sql` và chạy toàn bộ file.
3. Kiểm tra kết quả có 12 bảng, tổng seed bằng 2.000 và thông báo cài đặt business rules.
4. Mở `test_business_rules.sql` trong một tab riêng, chạy toàn bộ file. Kết quả mong đợi là sáu cột PASS.
5. Chạy lại toàn bộ `rebuild.sql`, rồi chạy lại smoke test để kiểm tra khả năng dựng lại.
6. 12 query nằm trong `QUERY/queries.sql` (bản lẻ: `QUERY/SQL 1.sql` đến `SQL 12.sql`). View `v_request_outstanding` của Q12 đã được tạo trong `rebuild.sql`.

`rebuild.sql` xóa và tạo lại riêng database `blood_bank_group2_d3`, bao gồm toàn bộ dữ liệu đang có trong database đó. Đây là điểm vào dành cho việc dựng lại database mẫu.

File rebuild đã ghép sẵn theo thứ tự tạo bảng, nạp seed, dời ngày (`date_shift.sql`), cài business rules và bước cuối (`post_setup.sql`). Các đoạn SQL khởi tạo nằm trong cùng một file để chạy từ đầu trong Workbench.

## Sinh lại seed (không bắt buộc)

Không cần sinh lại seed để chạy vào ngày khác, vì `rebuild.sql` đã tự dời ngày. Chỉ sinh lại khi muốn một bộ dữ liệu mới; khi đó kết quả trong report sẽ không còn khớp. Trong thư mục này, cài thư viện và chạy generator bằng Python.

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

## Các script nộp kèm (D5)

Mục 2.3 "What to submit" của đề chỉ bắt nộp **hai script**: một script dựng database từ server trống, và một script thứ hai chứa 12 query có chú thích. Đề cũng bắt có các lệnh INSERT/UPDATE/DELETE, một transaction COMMIT/ROLLBACK và phải test constraint, nhưng không bắt tách thành file riêng. Cột cuối ghi rõ file nào ứng với yêu cầu nào.

| File | Nội dung | Theo đề (mục 2.3) |
|---|---|---|
| `rebuild.sql` | Script duy nhất chạy từ đầu đến cuối: DROP + CREATE database, 12 bảng, seed, trigger/procedure/event, index, view `v_request_outstanding`, rồi gọi `d309_expire_units()`. Chạy được hai lần liên tiếp. | **Bắt buộc**: script dựng DB |
| `QUERY/queries.sql` | 12 query trong một file, mỗi query có câu hỏi tiếng Anh và kỹ thuật SQL dùng. `QUERY/SQL 1.sql`… `SQL 12.sql` giữ nguyên để chạy lẻ. | **Bắt buộc**: script thứ hai |
| `dml_transactions.sql` | INSERT/UPDATE/DELETE cho từng bảng chính, một transaction COMMIT (cấp 2 unit) và một transaction ROLLBACK. Chạy một lần ngay sau `rebuild.sql`. | Nội dung bắt buộc; tách file riêng là nhóm chọn |
| `constraint_tests.sql` | 10 câu lệnh phải bị từ chối (trùng khóa, FK không tồn tại, CHECK, trigger). Chạy bằng `mysql --force`. | Đề bắt test, không bắt nộp file; nộp kèm làm bằng chứng |
| `setup.sql`, `seed_2000.sql`, `date_shift.sql`, `business_rules.sql`, `post_setup.sql` | Năm phần được `generate_seed_2000.py` ghép thành `rebuild.sql`. | Không cần nộp riêng: đã nằm trong `rebuild.sql` |
| `test_business_rules.sql` | Smoke test sáu rule nghiệp vụ, kết thúc bằng kiểm tra toàn vẹn “cấp sai nhóm máu” (luôn 0 dòng). | Không bắt buộc: test thêm của nhóm |

DBMS đã kiểm tra: MySQL 8.0.46 và MySQL Community Server 26.10.0 (macOS). Q11 dùng `EXCEPT`, cần MySQL 8.0.31 trở lên.

## Thay đổi ngày 18/11/2026

- Thêm `date_shift.sql` vào `rebuild.sql`, chạy sau seed và trước business rules. Trước đây seed là ảnh chụp cố định nên chạy ngày khác sẽ ra rỗng: từ 19/11 Q6 rỗng, từ 25/11 Q1 rỗng, sang tháng 12 Q3 và Q10 rỗng. Giờ mọi cột ngày được dời theo `DATEDIFF(CURRENT_DATE, '2026-11-17')`.
- Đã dựng lại DB và chạy 12 query cho từng ngày từ 18/11/2026 đến 30/06/2027 (giả lập ngày bằng `SET timestamp`): không lỗi, không query nào rỗng. 10 query cho số dòng không đổi; Q3 và Q10 tính theo tháng dương lịch nên số dòng thay đổi theo ngày trong tháng (ít nhất 6 và 9 dòng).
- `generate_seed_2000.py` có thêm `--reference-date`. Bản hiện tại tương ứng `--as-of 2026-11-14 --reference-date 2026-11-17`. Faker không cố định tên nên sinh lại sẽ ra tên và địa chỉ khác.
- Q9 là join 8 bảng (7 lệnh INNER JOIN); sửa lại chú thích trong `queries.sql`.

## Thay đổi ngày 17/11/2026

- Q11 đổi thành truy vấn tập hợp `EXCEPT`: tổ hợp nhóm máu/Rh/thành phần còn được yêu cầu nhưng không còn unit khả dụng. Q11 cũ luôn rỗng nên không đạt yêu cầu “mọi query phải có kết quả”; câu kiểm tra đó chuyển vào `test_business_rules.sql`.
- Bảng phone (thuộc tính đa trị) dùng `ON DELETE CASCADE ON UPDATE CASCADE`; các FK còn lại giữ `RESTRICT`.
- Thêm `CHECK (close_time > open_time)` cho `BLOOD_BANK` và index `ix_request_date` cho Q3/Q10.
- `rebuild.sql` tạo luôn view của Q12 và cập nhật unit đã quá hạn khi dựng lại vào ngày sau snapshot (`post_setup.sql`).

## Dữ liệu phục vụ Query Matrix

- Có 22 request Critical, gồm 15 request đã có issue và 7 request chưa có issue.
- Q6 giữ tình huống AB+ Platelets trong Query Matrix gốc và liệt kê unit phù hợp còn khả dụng. `S2KR0077` là một request Critical tương ứng để minh họa tình huống này.
- Q8 dùng các request Critical chưa có issue. Q9 dùng các request Critical đã có issue.
- Q11 (`EXCEPT`) trả về các tổ hợp còn nhu cầu nhưng hết kho; trên seed 14/11/2026 là B+ Platelets và O+ Platelets.
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
- Xem `VALIDATION_20261114.md` để đối chiếu kết quả kiểm tra MySQL và các số dòng của Q1 đến Q12.

## Bản sửa cú pháp trigger

Hai trigger quản lý STAFF dùng `DROP TRIGGER IF EXISTS` rồi `CREATE TRIGGER`, giữ nguyên nội dung kiểm tra. MySQL hỗ trợ `CREATE TRIGGER IF NOT EXISTS` từ 8.0.29; bản này tránh dùng cú pháp đó.

Nếu DB đã có bảng STAFF, mở `fix_staff_triggers.sql` và chạy toàn bộ file để thay hai trigger. File vá không xóa bảng hoặc nạp lại seed. Khi dựng database mẫu từ đầu mới dùng `rebuild.sql`.
