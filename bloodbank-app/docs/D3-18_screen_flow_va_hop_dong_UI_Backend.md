# D3-18 | Screen flow và hợp đồng UI–Backend

Framework UI: Java Swing (có sẵn trong JDK, không cần thư viện UI ngoài). Backend: JDBC thuần, MySQL Connector/J 8.4.0, Java 17+.

## 1. Danh sách màn hình (tab)

| Tab | Class UI | Service | Chức năng |
|---|---|---|---|
| Donor | DonorPanel | DonorService | Tìm, đăng ký, sửa tên/địa chỉ/ngày sinh/SĐT |
| Hiến máu & sàng lọc | DonationPanel | DonationService | Kiểm tra điều kiện 56 ngày, ghi nhận đợt hiến, nhập/xóa kết quả xét nghiệm |
| Kho máu | InventoryPanel | InventoryService | Lọc kho, nhập kho đơn vị từ đợt hiến Passed, hủy bỏ, cập nhật hết hạn |
| Yêu cầu máu | RequestPanel | RequestService | Tạo/lọc yêu cầu, xem các phiếu cấp |
| Cấp máu | IssuancePanel | IssuanceService | Chọn yêu cầu + nhân viên, chọn nhiều đơn vị, cấp trong một transaction |
| Báo cáo | ReportPanel | ReportService | 13 report gồm Q1–Q12 và tồn kho |

Luồng chính: Donor → Hiến máu (Pending) → Xét nghiệm đủ 5 Negative (Passed) → Nhập kho (Available) → Yêu cầu máu (Pending) → Cấp máu (Partially Filled/Fulfilled, đơn vị thành Issued).

## 2. Hợp đồng thao tác

Ngày nghiệp vụ là Asia/Ho_Chi_Minh. UI nhập ngày dạng yyyy-MM-dd. Mọi lỗi trả về dưới dạng `AppException` có thông điệp hiển thị trực tiếp; UI không tự diễn giải mã lỗi.

| Thao tác | Input | Output | Validation ở app | Ràng buộc do DB chặn |
|---|---|---|---|---|
| DonorService.register | tên, nhóm máu, Rh, địa chỉ, ngày sinh, danh sách SĐT | donor_id mới | tên/địa chỉ không rỗng; nhóm A/B/AB/O; Rh +/-; ngày sinh trước hôm nay; SĐT đúng định dạng, bỏ trùng | CHECK nhóm máu/Rh, NOT NULL |
| DonorService.update | donor_id, tên, địa chỉ, ngày sinh, SĐT | không | như trên | Đổi nhóm máu/Rh bị trigger chặn (BR37), nên app không cho sửa |
| DonationService.nextEligibleDate | donor_id | ngày được hiến lại, hoặc null nếu chưa từng hiến | donor tồn tại | không |
| DonationService.record | donor_id, bank_id, ngày hiến, thể tích ml | event_id mới, trạng thái Pending | ngày không ở tương lai; thể tích lớn hơn 0 | BR18: cách nhau tối thiểu 56 ngày (hai phía); UNIQUE (donor_id, donation_date) |
| DonationService.saveTests | event_id, ngày XN, map loại→Positive/Negative | không | loại thuộc 5 loại; kết quả hợp lệ; ngày không ở tương lai | BR39: ngày XN không trước ngày hiến; mỗi loại một lần; screening_result do DB tự tính |
| DonationService.deleteTest | event_id, loại XN | không | loại hợp lệ | Chỉ xóa được khi đợt hiến còn Pending |
| InventoryService.register | bank_id, event_id, thành phần, ngày thu thập, ngày hết hạn | unit_id mới, trạng thái Available | collection bắt buộc và không ở tương lai; expiry bắt buộc và sau collection; expiry ở tương lai được phép | BR23: đợt hiến phải Passed; BR34: thu thập không trước ngày hiến |
| InventoryService.discard | bank_id, unit_id, staff_id | không | không rỗng | Procedure d309_discard_unit: nhân viên cùng ngân hàng; đơn vị Available hoặc Expired |
| InventoryService.expireNow | không | số đơn vị chuyển Expired | không | d309_expire_units |
| RequestService.create | hospital_id, nhóm, Rh, thành phần, số lượng, mức khẩn cấp, ngày | request_id mới, trạng thái Pending | số lượng lớn hơn 0; ngày không ở tương lai | CHECK các miền giá trị |
| IssuanceService.candidateUnits | request_id, staff_id | các đơn vị Available, còn hạn, khớp nhóm/Rh/thành phần, thuộc ngân hàng của nhân viên, sắp hết hạn trước | không | không |
| IssuanceService.issue | request_id, staff_id, danh sách unit_id | danh sách issue_id | có đơn vị; không trùng mã; số đơn vị không vượt số còn thiếu | d309_issue_unit và trigger: BR15, BR17, BR19–22, BR32, BR38 |

## 3. Quy ước transaction (D3-10)

- `IssuanceService.issue` mở một transaction JDBC (autocommit tắt), khóa dòng REQUEST bằng `SELECT ... FOR UPDATE`, rồi gọi `d309_issue_unit` lần lượt cho từng đơn vị. Trigger của DB khóa tiếp BLOOD_UNIT theo thứ tự request trước, unit sau, đúng thiết kế D3-06.
- Backend sở hữu commit/rollback. Một đơn vị lỗi thì rollback toàn bộ các phiếu của lần cấp đó.
- Form không cho sửa trực tiếp các trạng thái dẫn xuất. App chỉ gửi trạng thái khởi tạo hợp lệ Pending/Available khi tạo bản ghi; các chuyển trạng thái tiếp theo do trigger và procedure duy trì.
- Mọi truy vấn dùng PreparedStatement có tham số. Thông tin đăng nhập nằm ngoài source (db.properties hoặc hộp thoại kết nối).

## 4. Ánh xạ lỗi

| Nguồn | Hiển thị |
|---|---|
| SQLSTATE 45000 (SIGNAL từ trigger/procedure) | Nguyên văn MESSAGE_TEXT |
| Mã 1062, 1451, 1452, 3819, 1048 | Thông báo tiếng Việt tương ứng (trùng khóa, đang được tham chiếu, tham chiếu sai, vi phạm CHECK, thiếu dữ liệu) |
| Mã 1213, 1205 (deadlock, lock wait) | Báo hệ thống bận, thử lại |
| Khác | Mã lỗi và thông điệp gốc |

## 5. Ghi chú phạm vi

- Báo cáo Q1–Q5 khớp các query đã duyệt. Q2 chỉ lấy donor đã từng hiến; luồng ghi nhận hiến máu vẫn cho phép lần hiến đầu.
- Expiry của unit được nhập theo baseline `expiry_date > collection_date`; các mốc sinh sample data không phải quy tắc cứng trong app.
- Browse có số dòng; mỗi kênh tải dữ liệu đọc dùng mã lượt tải để bỏ kết quả cũ khi filter/selection thay đổi. Thao tác ghi vẫn báo kết quả commit hoặc lỗi riêng.
- Trạng thái Reserved, transfer và lịch sử chuyển unit thuộc Future work, UI không có.
