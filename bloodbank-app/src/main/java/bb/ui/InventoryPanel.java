package bb.ui;

import bb.core.Biz;
import bb.core.Option;
import bb.service.InventoryService;
import bb.service.LookupService;
import java.awt.BorderLayout;
import java.time.LocalDate;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTable;
import javax.swing.JTextField;

final class InventoryPanel extends JPanel implements Reloadable {
    private final InventoryService service = new InventoryService();
    private final LookupService lookup = new LookupService();
    private final JComboBox<Option> filterBank = new JComboBox<>();
    private final JComboBox<String> filterStatus = Ui.comboAll(InventoryService.STATUSES);
    private final JComboBox<String> filterGroup = Ui.comboAll("A", "B", "AB", "O");
    private final JComboBox<String> filterRh = Ui.comboAll("+", "-");
    private final JComboBox<String> filterComponent = Ui.comboAll(InventoryService.COMPONENTS);
    private final JComboBox<Option> eventBox = new JComboBox<>();
    private final JComboBox<Option> storeBank = new JComboBox<>();
    private final JComboBox<String> component = Ui.combo(InventoryService.COMPONENTS);
    private final JTextField collection = new JTextField(Biz.today().toString(), 10);
    private final JTextField expiry = new JTextField(10);
    private final JComboBox<Option> staff = new JComboBox<>();
    private final JTable table = Ui.table();
    private final Ui.LoadGuard bankLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard eventLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard staffLoad = new Ui.LoadGuard();
    private final Ui.LoadGuard unitLoad = new Ui.LoadGuard();

    InventoryPanel() {
        setLayout(new BorderLayout(6, 6));
        setBorder(Ui.pad());
        JButton search = new JButton("Search");
        search.addActionListener(e -> search());
        add(Ui.flow(new JLabel("Bank"), filterBank, new JLabel("Status"), filterStatus, new JLabel("Group"), filterGroup,
                new JLabel("Rh"), filterRh, new JLabel("Component"), filterComponent, search), BorderLayout.NORTH);
        add(Ui.browse(table), BorderLayout.CENTER);

        JButton register = new JButton("Register unit");
        JButton discard = new JButton("Discard selected unit");
        JButton expire = new JButton("Mark expired units");
        register.addActionListener(e -> register());
        discard.addActionListener(e -> discard());
        expire.addActionListener(e -> expire());
        JPanel south = Ui.stack(
                Ui.form(2, "Passed donation event", eventBox, "Storage bank", storeBank, "Component", component,
                        "Collection date (yyyy-MM-dd)", collection, "Expiry date (yyyy-MM-dd)", expiry),
                Ui.stack(Ui.flow(register, new JLabel("Expiry date must be after the collection date.")),
                        Ui.flow(new JLabel("Discarding staff"), staff, discard, expire)));
        add(south, BorderLayout.SOUTH);
    }

    @Override
    public void reload() {
        Ui.latest(this, bankLoad, lookup::banks, banks -> {
            Ui.setOptions(filterBank, banks, true);
            Ui.setOptions(storeBank, banks, false);
        });
        Ui.latest(this, eventLoad, lookup::passedEvents, events -> Ui.setOptions(eventBox, events, false));
        Ui.latest(this, staffLoad, lookup::staff, list -> Ui.setOptions(staff, list, false));
        search();
    }

    private void search() {
        String bank = Ui.id(filterBank);
        String status = Ui.value(filterStatus);
        String group = Ui.value(filterGroup);
        String rh = Ui.value(filterRh);
        String comp = Ui.value(filterComponent);
        Ui.latest(this, unitLoad, () -> service.units(bank, status, group, rh, comp), rows -> Ui.fill(table, rows));
    }

    private void register() {
        Ui.guard(this, () -> {
            String bank = Ui.id(storeBank);
            String event = Ui.id(eventBox);
            String comp = (String) component.getSelectedItem();
            LocalDate date = Ui.date(collection, "Collection date");
            LocalDate expiryDate = Ui.date(expiry, "Expiry date");
            Ui.async(this, () -> service.register(bank, event, comp, date, expiryDate), id -> {
                Ui.info(this, "Registered unit " + id + " (Available).");
                search();
            });
        });
    }

    private void discard() {
        String bank = Ui.selected(table, "bank_id");
        String unit = Ui.selected(table, "unit_id");
        String staffId = Ui.id(staff);
        if (bank == null || unit == null) {
            Ui.info(this, "Select a blood unit in the table.");
            return;
        }
        if (!Ui.confirm(this, "Discard unit " + unit + " at " + bank + "? This cannot be undone.")) {
            return;
        }
        Ui.async(this, () -> {
            service.discard(bank, unit, staffId);
            return unit;
        }, done -> {
            Ui.info(this, "Discarded unit " + done + ".");
            search();
        });
    }

    private void expire() {
        Ui.async(this, service::expireNow, count -> {
            Ui.info(this, "Marked " + count + " overdue unit(s) as Expired.");
            search();
        });
    }
}
