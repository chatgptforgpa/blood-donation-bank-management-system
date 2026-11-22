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
        JButton refresh = new JButton("Reload");
        refresh.addActionListener(e -> reload());
        add(Ui.flow(new JLabel("Issuing staff:"), staff, refresh,
                new JLabel("Units come only from the staff member's own bank.")), BorderLayout.NORTH);

        JPanel left = Ui.stack(new JLabel("Open requests (most urgent first):"), Ui.browse(requests));
        JPanel right = Ui.stack(new JLabel("Matching usable units, earliest expiry first (multi-select):"), Ui.browse(units));
        JSplitPane split = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, left, right);
        split.setResizeWeight(0.5);
        add(split, BorderLayout.CENTER);

        JButton issue = new JButton("Issue selected units");
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
        info.setText("Request " + requestId + " still needs " + remaining + " unit(s).");
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
            Ui.info(this, "Select a request, a staff member and at least one unit.");
            return;
        }
        if (!Ui.confirm(this, "Issue " + unitIds.size() + " unit(s) to request " + requestId + "? If one unit fails, the whole issue is rolled back.")) {
            return;
        }
        Ui.async(this, () -> service.issue(requestId, option.id(), unitIds), ids -> {
            Ui.info(this, "Issued: " + String.join(", ", ids));
            reload();
            Ui.clear(units);
        });
    }
}
