# Kiểm tra gói ngày 14/11/2026

Ngày tham chiếu truy vấn: 14/11/2026. Seed đi kèm: 14/11/2026.

Đã chạy trên MySQL 8.0.46, trong database kiểm tra riêng. Các số dòng mong đợi dưới đây được đối chiếu với các tình huống trong fixture; đây là bằng chứng kiểm tra gói, không thay thế phần giải thích từng query trong final report.

- Dựng lại bằng `rebuild.sql` hai lần liên tiếp: PASS. Mỗi lần có 12 bảng và 2.000 dòng.
- Sáu kiểm tra nghiệp vụ trong `test_business_rules.sql`: PASS.
- Critical: 22 request, gồm 7 chưa có issue và 15 đã có issue.
- VIEW Q12: tổng outstanding là 100, khớp tổng requested trừ tổng issue.

| Query | Expected rows | Actual rows | Kết quả |
|---|---:|---:|---|
| Q1 | 4 | 4 | PASS |
| Q2 | 10 | 10 | PASS |
| Q3 | 25 | 25 | PASS |
| Q4 | 1 | 1 | PASS |
| Q5 | 3 | 3 | PASS |
| Q6 | 4 | 4 | PASS |
| Q7 | 75 | 75 | PASS |
| Q8 | 7 | 7 | PASS |
| Q9 | 15 | 15 | PASS |
| Q10 | 25 | 25 | PASS |
| Q11 | 0 | 0 | PASS |
| Q12 | 24 | 24 | PASS |

Q11 là audit compatibility. Không có vi phạm trên seed hợp lệ nên kết quả 0 dòng là đúng.

RA và tree chọn Q1, Q2, Q3, Q8. Kết quả tương ứng: 4, 10, 25 và 7 dòng. Các ảnh tree có số dòng phải dùng cùng ngày và dataset với lần chạy SQL.

Generator giữ nguyên phiên bản đã sửa trước đó: chạy lại sẽ sinh `seed_2000.sql` và `rebuild.sql`. Các file RA và ảnh tree là snapshot, cần cập nhật riêng khi thay ngày hoặc dữ liệu.

## Kiểm tra bản sửa cú pháp trigger

- Đã dựng gói sửa trên MySQL 8.0.46.
- `fix_staff_triggers.sql` chạy hai lần liên tiếp: PASS; chỉ thay hai trigger kiểm tra STAFF tự quản lý.
- Checksum dữ liệu cả 12 bảng trước/sau chạy file vá không đổi.
- INSERT hoặc UPDATE để staff tự quản lý đều bị chặn đúng bằng SQLSTATE 45000.
- Sáu kiểm tra nghiệp vụ tiếp tục PASS; Q8 có 7 dòng và Q9 có 15 dòng.
- Seed, generator, SQL query và RA giữ nguyên so với gói ngày 14/11; sửa cú pháp tạo trigger trong setup và rebuild.
