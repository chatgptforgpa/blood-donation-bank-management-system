package bb.ui;

import bb.core.Biz;
import bb.core.Option;
import bb.core.Rows;
import bb.service.DonationService;
import bb.service.LookupService;
import java.awt.BorderLayout;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JSplitPane;
import javax.swing.JTable;
import javax.swing.JTextField;

final class DonationPanel extends JPanel implements Reloadable {
    private static final String NONE = "—";

    private final DonationService service = new DonationService();
    private final LookupService lookup = new LookupService();
    private final JTextField filter = new JTextField(14);
    private final JTextField donorId = new JTextField(14);
    private final JComboBox<Option> bank = new JComboBox<>();
    private final JTextField date = new JTextField(Biz.today().toString(), 10);
    private final JTextField volume = new JTextField("450", 6);
    private final JTable events = Ui.table();
    private final JTable tests = Ui.table();
    private final Map<String, JComboBox<String>> testBoxes = new LinkedHashMap<>();
    private final JTextField testDate = new JTextField(Biz.today().toString(), 10);
    private final Ui.LoadGuard bankLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard eventLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard testLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard eligibilityLoad = new Ui.LoadGuard();

    DonationPanel() {
        setLayout(new BorderLayout(6, 6));
        setBorder(Ui.pad());

        JButton check = new JButton("Kiểm tra điều kiện hiến");
        JButton record = new JButton("Ghi nhận đợt hiến máu");
        check.addActionListener(e -> checkEligibility());
        record.addActionListener(e -> record());
        JPanel top = Ui.stack(
                Ui.form(4, "Mã donor", donorId, "Ngân hàng", bank, "Ngày hiến", date, "Thể tích (ml)", volume),
                Ui.flow(check, record, new JLabel("Trạng thái sàng lọc do hệ thống tự tính từ kết quả xét nghiệm.")));
        add(top, BorderLayout.NORTH);

        JButton find = new JButton("Lọc");
        find.addActionListener(e -> reload());
        filter.addActionListener(e -> reload());
        JPanel upper = Ui.stack(Ui.flow(new JLabel("Lọc theo donor:"), filter, find), Ui.browse(events));

        JPanel testForm = new JPanel(new java.awt.FlowLayout(java.awt.FlowLayout.LEFT, 6, 4));
        for (String type : DonationService.TEST_TYPES) {
            JComboBox<String> box = Ui.combo(NONE, "Negative", "Positive");
            testBoxes.put(type, box);
            testForm.add(new JLabel(type));
            testForm.add(box);
        }
        testForm.add(new JLabel("Ngày XN"));
        testForm.add(testDate);
        JButton save = new JButton("Lưu kết quả xét nghiệm");
        JButton delete = new JButton("Xóa xét nghiệm đã chọn");
        save.addActionListener(e -> saveTests());
        delete.addActionListener(e -> deleteTest());
        testForm.add(save);
        testForm.add(delete);
        JPanel lower = new JPanel(new BorderLayout(0, 4));
        lower.add(new JLabel("Xét nghiệm của đợt hiến đang chọn (chỉ sửa được khi còn Pending):"), BorderLayout.NORTH);
        lower.add(Ui.browse(tests), BorderLayout.CENTER);
        lower.add(testForm, BorderLayout.SOUTH);

        JSplitPane split = new JSplitPane(JSplitPane.VERTICAL_SPLIT, upper, lower);
        split.setResizeWeight(0.55);
        add(split, BorderLayout.CENTER);

        events.getSelectionModel().addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting()) {
                loadTests();
            }
        });
        clearTests();
    }

    @Override
    public void reload() {
        String keyword = filter.getText();
        clearTests();
        Ui.latest(this, bankLoad, lookup::banks, banks -> Ui.setOptions(bank, banks, false));
        Ui.latest(this, eventLoad, () -> service.list(keyword), rows -> Ui.fill(events, rows));
    }

    private void checkEligibility() {
        String id = donorId.getText().trim();
        Ui.latest(this, eligibilityLoad, () -> service.nextEligibleDate(id), next -> {
            if (!id.equals(donorId.getText().trim())) {
                return;
            }
            if (next == null) {
                Ui.info(this, "Donor " + id + " chưa từng hiến máu, đủ điều kiện hiến.");
            } else if (next.isAfter(Biz.today())) {
                Ui.info(this, "Donor " + id + " chỉ được hiến lại từ " + next + " (cách tối thiểu " + Biz.DONATION_GAP_DAYS + " ngày).");
            } else {
                Ui.info(this, "Donor " + id + " đủ điều kiện hiến (đủ " + Biz.DONATION_GAP_DAYS + " ngày kể từ lần hiến trước).");
            }
        });
    }

    private void record() {
        Ui.guard(this, () -> {
            String donor = donorId.getText().trim();
            String bankId = Ui.id(bank);
            LocalDate d = Ui.date(date, "Ngày hiến");
            int ml = Ui.integer(volume, "Thể tích");
            Ui.async(this, () -> service.record(donor, bankId, d, ml), id -> {
                Ui.info(this, "Đã ghi nhận đợt hiến " + id + " (trạng thái Pending).");
                filter.setText(donor);
                reload();
            });
        });
    }

    private void loadTests() {
        String eventId = Ui.selected(events, "event_id");
        clearTests();
        if (eventId == null) {
            return;
        }
        Ui.latest(this, testLoad, () -> service.tests(eventId), rows -> {
            if (!eventId.equals(Ui.selected(events, "event_id"))) {
                return;
            }
            Ui.fill(tests, rows);
            Set<String> done = new HashSet<>();
            for (int i = 0; i < rows.size(); i++) {
                done.add(rows.str(i, "test_type"));
            }
            for (Map.Entry<String, JComboBox<String>> entry : testBoxes.entrySet()) {
                boolean exists = done.contains(entry.getKey());
                entry.getValue().setEnabled(!exists);
                entry.getValue().setSelectedItem(NONE);
            }
        });
    }

    private void clearTests() {
        testLoad.invalidate();
        Ui.clear(tests);
        for (JComboBox<String> box : testBoxes.values()) {
            box.setEnabled(false);
            box.setSelectedItem(NONE);
        }
    }

    private void saveTests() {
        String eventId = Ui.selected(events, "event_id");
        if (eventId == null) {
            Ui.info(this, "Chọn một đợt hiến máu trước.");
            return;
        }
        Ui.guard(this, () -> {
            LocalDate d = Ui.date(testDate, "Ngày xét nghiệm");
            Map<String, String> results = new LinkedHashMap<>();
            for (Map.Entry<String, JComboBox<String>> entry : testBoxes.entrySet()) {
                String value = (String) entry.getValue().getSelectedItem();
                if (entry.getValue().isEnabled() && value != null && !NONE.equals(value)) {
                    results.put(entry.getKey(), value);
                }
            }
            Ui.async(this, () -> {
                service.saveTests(eventId, d, results);
                return eventId;
            }, id -> {
                reloadKeepingSelection(id);
            });
        });
    }

    private void deleteTest() {
        String eventId = Ui.selected(events, "event_id");
        String type = Ui.selected(tests, "test_type");
        if (eventId == null || type == null) {
            Ui.info(this, "Chọn đợt hiến và một xét nghiệm trong bảng dưới.");
            return;
        }
        if (!Ui.confirm(this, "Xóa xét nghiệm " + type + " của đợt " + eventId + "?")) {
            return;
        }
        Ui.async(this, () -> {
            service.deleteTest(eventId, type);
            return eventId;
        }, this::reloadKeepingSelection);
    }

    private void reloadKeepingSelection(String eventId) {
        String keyword = filter.getText();
        clearTests();
        Ui.latest(this, eventLoad, () -> service.list(keyword), rows -> {
            Ui.fill(events, rows);
            for (int i = 0; i < events.getRowCount(); i++) {
                if (eventId.equals(events.getValueAt(i, events.getColumn("event_id").getModelIndex()))) {
                    events.setRowSelectionInterval(i, i);
                    break;
                }
            }
        });
    }
}
