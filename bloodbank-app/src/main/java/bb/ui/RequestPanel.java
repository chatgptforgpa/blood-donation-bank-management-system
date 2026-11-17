package bb.ui;

import bb.core.Biz;
import bb.core.Option;
import bb.service.InventoryService;
import bb.service.LookupService;
import bb.service.RequestService;
import java.awt.BorderLayout;
import java.time.LocalDate;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JSplitPane;
import javax.swing.JTable;
import javax.swing.JTextField;

final class RequestPanel extends JPanel implements Reloadable {
    private final RequestService service = new RequestService();
    private final LookupService lookup = new LookupService();
    private final JComboBox<String> filterStatus = Ui.comboAll(RequestService.STATUSES);
    private final JComboBox<String> filterUrgency = Ui.comboAll(RequestService.URGENCIES);
    private final JComboBox<Option> hospital = new JComboBox<>();
    private final JComboBox<String> group = Ui.combo("A", "B", "AB", "O");
    private final JComboBox<String> rh = Ui.combo("+", "-");
    private final JComboBox<String> component = Ui.combo(InventoryService.COMPONENTS);
    private final JComboBox<String> urgency = Ui.combo(RequestService.URGENCIES);
    private final JTextField quantity = new JTextField("1", 5);
    private final JTextField date = new JTextField(Biz.today().toString(), 10);
    private final JTable requests = Ui.table();
    private final JTable issues = Ui.table();
    private final Ui.LoadGuard hospitalLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard requestLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard issueLoad = new Ui.LoadGuard();

    RequestPanel() {
        setLayout(new BorderLayout(6, 6));
        setBorder(Ui.pad());
        JButton search = new JButton("Lọc");
        search.addActionListener(e -> search());
        add(Ui.flow(new JLabel("Trạng thái"), filterStatus, new JLabel("Mức khẩn cấp"), filterUrgency, search), BorderLayout.NORTH);

        JPanel lower = Ui.stack(new JLabel("Các phiếu cấp của yêu cầu đang chọn:"), Ui.browse(issues));
        JSplitPane split = new JSplitPane(JSplitPane.VERTICAL_SPLIT, Ui.browse(requests), lower);
        split.setResizeWeight(0.65);
        add(split, BorderLayout.CENTER);

        JButton create = new JButton("Tạo yêu cầu máu");
        create.addActionListener(e -> create());
        JPanel south = Ui.stack(
                Ui.form(4, "Bệnh viện", hospital, "Nhóm máu", group, "Rh", rh, "Thành phần", component,
                        "Số lượng", quantity, "Mức khẩn cấp", urgency, "Ngày yêu cầu", date, "", new JLabel()),
                Ui.flow(create, new JLabel("Yêu cầu mới luôn bắt đầu Pending; trạng thái tự cập nhật khi cấp máu.")));
        add(south, BorderLayout.SOUTH);

        requests.getSelectionModel().addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting()) {
                loadIssues();
            }
        });
    }

    @Override
    public void reload() {
        Ui.latest(this, hospitalLoad, lookup::hospitals, list -> Ui.setOptions(hospital, list, false));
        search();
    }

    private void search() {
        String status = Ui.value(filterStatus);
        String level = Ui.value(filterUrgency);
        issueLoad.invalidate();
        Ui.clear(issues);
        Ui.latest(this, requestLoad, () -> service.list(status, level), rows -> Ui.fill(requests, rows));
    }

    private void loadIssues() {
        String id = Ui.selected(requests, "request_id");
        issueLoad.invalidate();
        Ui.clear(issues);
        if (id == null) {
            return;
        }
        Ui.latest(this, issueLoad, () -> service.issues(id), rows -> {
            if (id.equals(Ui.selected(requests, "request_id"))) {
                Ui.fill(issues, rows);
            }
        });
    }

    private void create() {
        Ui.guard(this, () -> {
            String hospitalId = Ui.id(hospital);
            String g = (String) group.getSelectedItem();
            String r = (String) rh.getSelectedItem();
            String c = (String) component.getSelectedItem();
            int qty = Ui.integer(quantity, "Số lượng");
            String level = (String) urgency.getSelectedItem();
            LocalDate d = Ui.date(date, "Ngày yêu cầu");
            Ui.async(this, () -> service.create(hospitalId, g, r, c, qty, level, d), id -> {
                Ui.info(this, "Đã tạo yêu cầu " + id + ".");
                search();
            });
        });
    }
}
