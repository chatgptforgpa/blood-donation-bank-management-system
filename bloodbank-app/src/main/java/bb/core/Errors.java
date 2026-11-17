package bb.core;

import java.sql.SQLException;

public final class Errors {
    private Errors() {
    }

    public static AppException of(SQLException e) {
        if ("45000".equals(e.getSQLState())) {
            return new AppException(e.getMessage());
        }
        return switch (e.getErrorCode()) {
            case 1062 -> new AppException("Dữ liệu bị trùng khóa hoặc vi phạm ràng buộc UNIQUE.");
            case 1451 -> new AppException("Không thể xóa hoặc sửa: dữ liệu đang được bản ghi khác tham chiếu.");
            case 1452 -> new AppException("Tham chiếu không tồn tại hoặc sai ngân hàng/nhân viên/đơn vị máu.");
            case 3819 -> new AppException("Giá trị vi phạm ràng buộc CHECK của bảng.");
            case 1048 -> new AppException("Thiếu dữ liệu bắt buộc.");
            case 1213, 1205 -> new AppException("Hệ thống đang bận do thao tác đồng thời. Vui lòng thử lại.");
            default -> new AppException("Lỗi cơ sở dữ liệu (" + e.getSQLState() + "/" + e.getErrorCode() + "): " + e.getMessage());
        };
    }
}
