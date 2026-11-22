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
        JButton search = new JButton("Filter");
        search.addActionListener(e -> search());
        add(Ui.flow(new JLabel("Status"), filterStatus, new JLabel("Urgency"), filterUrgency, search), BorderLayout.NORTH);

        JPanel lower = Ui.stack(new JLabel("Issue records of the selected request:"), Ui.browse(issues));
        JSplitPane split = new JSplitPane(JSplitPane.VERTICAL_SPLIT, Ui.browse(requests), lower);
        split.setResizeWeight(0.65);
        add(split, BorderLayout.CENTER);

        JButton create = new JButton("Create request");
        JButton update = new JButton("Update urgency/quantity");
        JButton delete = new JButton("Delete selected request");
        create.addActionListener(e -> create());
        update.addActionListener(e -> update());
        delete.addActionListener(e -> delete());
        JPanel south = Ui.stack(
                Ui.form(4, "Hospital", hospital, "Blood group", group, "Rh", rh, "Component", component,
                        "Quantity", quantity, "Urgency", urgency, "Request date", date, "", new JLabel()),
                Ui.flow(create, update, delete, new JLabel("New requests start as Pending; status updates automatically on issue.")));
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
        String level = Ui.selected(requests, "urgency_level");
        String qty = Ui.selected(requests, "quantity_needed");
        if (level != null) {
            urgency.setSelectedItem(level);
        }
        if (qty != null) {
            quantity.setText(qty);
        }
        Ui.latest(this, issueLoad, () -> service.issues(id), rows -> {
            if (id.equals(Ui.selected(requests, "request_id"))) {
                Ui.fill(issues, rows);
            }
        });
    }

    private void update() {
        String id = Ui.selected(requests, "request_id");
        if (id == null) {
            Ui.info(this, "Select a request in the table first.");
            return;
        }
        Ui.guard(this, () -> {
            String level = (String) urgency.getSelectedItem();
            int qty = Ui.integer(quantity, "Quantity");
            Ui.async(this, () -> {
                service.update(id, level, qty);
                return id;
            }, done -> {
                Ui.info(this, "Updated request " + done + ".");
                search();
            });
        });
    }

    private void delete() {
        String id = Ui.selected(requests, "request_id");
        if (id == null) {
            Ui.info(this, "Select a request in the table first.");
            return;
        }
        if (!Ui.confirm(this, "Delete request " + id + "?\nThis cannot be undone.")) {
            return;
        }
        Ui.async(this, () -> {
            service.delete(id);
            return id;
        }, done -> {
            Ui.info(this, "Deleted request " + done + ".");
            search();
        });
    }

    private void create() {
        Ui.guard(this, () -> {
            String hospitalId = Ui.id(hospital);
            String g = (String) group.getSelectedItem();
            String r = (String) rh.getSelectedItem();
            String c = (String) component.getSelectedItem();
            int qty = Ui.integer(quantity, "Quantity");
            String level = (String) urgency.getSelectedItem();
            LocalDate d = Ui.date(date, "Request date");
            Ui.async(this, () -> service.create(hospitalId, g, r, c, qty, level, d), id -> {
                Ui.info(this, "Created request " + id + ".");
                search();
            });
        });
    }
}
