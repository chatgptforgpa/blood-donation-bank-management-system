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
        JButton find = new JButton("Tìm");
        find.addActionListener(e -> reload());
        search.addActionListener(e -> reload());
        add(Ui.flow(new JLabel("Mã hoặc tên donor:"), search, find), BorderLayout.NORTH);
        add(Ui.browse(table), BorderLayout.CENTER);

        JButton register = new JButton("Đăng ký donor mới");
        JButton update = new JButton("Cập nhật dòng đã chọn");
        JButton reset = new JButton("Làm mới form");
        register.addActionListener(e -> register());
        update.addActionListener(e -> update());
        reset.addActionListener(e -> resetForm());
        JPanel south = Ui.stack(
                Ui.form(3, "Họ tên", name, "Nhóm máu", group, "Rh", rh,
                        "Ngày sinh (yyyy-MM-dd)", dob, "Địa chỉ", address, "SĐT (cách nhau bởi dấu phẩy)", phones),
                Ui.flow(register, update, reset, new JLabel("Nhóm máu và Rh không thể sửa sau khi đăng ký (BR37).")));
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
            LocalDate d = Ui.date(dob, "Ngày sinh");
            List<String> p = phoneList();
            Ui.async(this, () -> service.register(n, g, r, a, d, p), id -> {
                Ui.info(this, "Đã đăng ký donor " + id + ".");
                search.setText(id);
                reload();
            });
        });
    }

    private void update() {
        String id = Ui.selected(table, "donor_id");
        if (id == null) {
            Ui.info(this, "Chọn một donor trong bảng trước.");
            return;
        }
        Ui.guard(this, () -> {
            String n = name.getText();
            String a = address.getText();
            LocalDate d = Ui.date(dob, "Ngày sinh");
            List<String> p = phoneList();
            Ui.async(this, () -> {
                service.update(id, n, a, d, p);
                return id;
            }, done -> {
                Ui.info(this, "Đã cập nhật donor " + done + ".");
                reload();
            });
        });
    }
}
