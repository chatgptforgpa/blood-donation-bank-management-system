package bb.ui;

import bb.core.Option;
import bb.service.IssuanceService;
import bb.service.LookupService;
import bb.service.RequestService;
import java.awt.BorderLayout;
import java.util.List;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JSplitPane;
import javax.swing.JTable;
import javax.swing.ListSelectionModel;

final class IssuancePanel extends JPanel implements Reloadable {
    private final IssuanceService service = new IssuanceService();
    private final RequestService requestService = new RequestService();
    private final LookupService lookup = new LookupService();
    private final JComboBox<Option> staff = new JComboBox<>();
    private final JTable requests = Ui.table();
    private final JTable units = Ui.table();
    private final JLabel info = new JLabel(" ");
    private final Ui.LoadGuard staffLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard requestLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard unitLoad = new Ui.LoadGuard();

    IssuancePanel() {
        setLayout(new BorderLayout(6, 6));
        setBorder(Ui.pad());
        units.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
        JButton refresh = new JButton("Tải lại");
        refresh.addActionListener(e -> reload());
        add(Ui.flow(new JLabel("Nhân viên cấp máu:"), staff, refresh,
                new JLabel("Đơn vị máu chỉ lấy từ ngân hàng của nhân viên (BR22).")), BorderLayout.NORTH);

        JPanel left = Ui.stack(new JLabel("Yêu cầu còn thiếu (ưu tiên khẩn cấp trước):"), Ui.browse(requests));
        JPanel right = Ui.stack(new JLabel("Đơn vị phù hợp, còn hạn, sắp hết hạn trước (chọn nhiều dòng):"), Ui.browse(units));
        JSplitPane split = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, left, right);
        split.setResizeWeight(0.5);
        add(split, BorderLayout.CENTER);

        JButton issue = new JButton("Cấp các đơn vị đã chọn");
        issue.addActionListener(e -> issue());
        add(Ui.stack(info, Ui.flow(issue)), BorderLayout.SOUTH);

        requests.getSelectionModel().addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting()) {
                loadUnits();
            }
        });
        staff.addActionListener(e -> loadUnits());
    }

    @Override
    public void reload() {
        clearUnits();
        Ui.latest(this, staffLoad, lookup::staff, list -> Ui.setOptions(staff, list, false));
        Ui.latest(this, requestLoad, requestService::open, rows -> Ui.fill(requests, rows));
    }

    private void loadUnits() {
        String requestId = Ui.selected(requests, "request_id");
        Option option = (Option) staff.getSelectedItem();
        clearUnits();
        if (requestId == null || option == null) {
            return;
        }
        String remaining = Ui.selected(requests, "remaining");
        info.setText("Yêu cầu " + requestId + " còn thiếu " + remaining + " đơn vị.");
        Ui.latest(this, unitLoad, () -> service.candidateUnits(requestId, option.id()), rows -> {
            if (requestId.equals(Ui.selected(requests, "request_id"))
                    && option.id().equals(Ui.id(staff))) {
                Ui.fill(units, rows);
            }
        });
    }

    private void clearUnits() {
        unitLoad.invalidate();
        Ui.clear(units);
        info.setText(" ");
    }

    private void issue() {
        String requestId = Ui.selected(requests, "request_id");
        Option option = (Option) staff.getSelectedItem();
        List<String> unitIds = Ui.selectedAll(units, "unit_id");
        if (requestId == null || option == null || unitIds.isEmpty()) {
            Ui.info(this, "Chọn yêu cầu, nhân viên và ít nhất một đơn vị máu.");
            return;
        }
        if (!Ui.confirm(this, "Cấp " + unitIds.size() + " đơn vị cho yêu cầu " + requestId + "? Nếu một đơn vị lỗi, toàn bộ lần cấp sẽ bị hủy.")) {
            return;
        }
        Ui.async(this, () -> service.issue(requestId, option.id(), unitIds), ids -> {
            Ui.info(this, "Đã cấp thành công: " + String.join(", ", ids));
            reload();
            Ui.clear(units);
        });
    }
}
