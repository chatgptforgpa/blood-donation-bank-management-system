package bb.ui;

import bb.service.DonorService;
import java.awt.BorderLayout;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTable;
import javax.swing.JTextField;

final class DonorPanel extends JPanel implements Reloadable {
    private final DonorService service = new DonorService();
    private final JTextField search = new JTextField(20);
    private final JTextField name = new JTextField(18);
    private final JTextField dob = new JTextField(10);
    private final JTextField address = new JTextField(26);
    private final JTextField phones = new JTextField(20);
    private final JComboBox<String> group = Ui.combo("A", "B", "AB", "O");
    private final JComboBox<String> rh = Ui.combo("+", "-");
    private final JTable table = Ui.table();
    private final Ui.LoadGuard searchLoad = new Ui.LoadGuard();

    DonorPanel() {
        setLayout(new BorderLayout(6, 6));
        setBorder(Ui.pad());
        JButton find = new JButton("Search");
        find.addActionListener(e -> reload());
        search.addActionListener(e -> reload());
        add(Ui.flow(new JLabel("Donor ID or name:"), search, find), BorderLayout.NORTH);
        add(Ui.browse(table), BorderLayout.CENTER);

        JButton register = new JButton("Register donor");
        JButton update = new JButton("Update selected");
        JButton delete = new JButton("Delete selected donor");
        JButton reset = new JButton("Clear form");
        register.addActionListener(e -> register());
        update.addActionListener(e -> update());
        delete.addActionListener(e -> delete());
        reset.addActionListener(e -> resetForm());
        JPanel south = Ui.stack(
                Ui.form(3, "Full name", name, "Blood group", group, "Rh", rh,
                        "Date of birth (yyyy-MM-dd)", dob, "Address", address, "Phones (comma separated)", phones),
                Ui.flow(register, update, delete, reset, new JLabel("Blood group and Rh cannot be changed after registration.")));
        add(south, BorderLayout.SOUTH);
        table.getSelectionModel().addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting()) {
                loadSelection();
            }
        });
    }

    @Override
    public void reload() {
        String keyword = search.getText();
        Ui.latest(this, searchLoad, () -> service.search(keyword), rows -> Ui.fill(table, rows));
    }

    void resetForm() {
        table.clearSelection();
        name.setText("");
        dob.setText("");
        address.setText("");
        phones.setText("");
        group.setSelectedIndex(0);
        rh.setSelectedIndex(0);
        group.setEnabled(true);
        rh.setEnabled(true);
    }

    private void loadSelection() {
        String id = Ui.selected(table, "donor_id");
        group.setEnabled(id == null);
        rh.setEnabled(id == null);
        if (id == null) {
            return;
        }
        name.setText(Ui.selected(table, "full_name"));
        address.setText(Ui.selected(table, "address"));
        dob.setText(Ui.selected(table, "date_of_birth"));
        String phone = Ui.selected(table, "phones");
        phones.setText(phone == null ? "" : phone);
        group.setSelectedItem(Ui.selected(table, "blood_group"));
        rh.setSelectedItem(Ui.selected(table, "rh_factor"));
    }

    private List<String> phoneList() {
        return Arrays.asList(phones.getText().split("[,;]"));
    }

    private void register() {
        Ui.guard(this, () -> {
            String n = name.getText();
            String g = (String) group.getSelectedItem();
            String r = (String) rh.getSelectedItem();
            String a = address.getText();
            LocalDate d = Ui.date(dob, "Date of birth");
            List<String> p = phoneList();
            Ui.async(this, () -> service.register(n, g, r, a, d, p), id -> {
                Ui.info(this, "Registered donor " + id + ".");
                search.setText(id);
                reload();
            });
        });
    }

    private void delete() {
        String id = Ui.selected(table, "donor_id");
        if (id == null) {
            Ui.info(this, "Select a donor in the table first.");
            return;
        }
        String who = Ui.selected(table, "full_name");
        if (!Ui.confirm(this, "Delete donor " + id + " (" + who + ")?\nThe donor's phone numbers are deleted too. This cannot be undone.")) {
            return;
        }
        Ui.async(this, () -> {
            service.delete(id);
            return id;
        }, done -> {
            Ui.info(this, "Deleted donor " + done + ".");
            resetForm();
            reload();
        });
    }

    private void update() {
        String id = Ui.selected(table, "donor_id");
        if (id == null) {
            Ui.info(this, "Select a donor in the table first.");
            return;
        }
        Ui.guard(this, () -> {
            String n = name.getText();
            String a = address.getText();
            LocalDate d = Ui.date(dob, "Date of birth");
            List<String> p = phoneList();
            Ui.async(this, () -> {
                service.update(id, n, a, d, p);
                return id;
            }, done -> {
                Ui.info(this, "Updated donor " + done + ".");
                reload();
            });
        });
    }
}
