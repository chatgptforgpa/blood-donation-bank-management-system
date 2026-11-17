package bb.ui;

import bb.service.ReportService;
import java.awt.BorderLayout;
import java.awt.Dimension;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTable;

final class ReportPanel extends JPanel implements Reloadable {
    private final ReportService service = new ReportService();
    private final JComboBox<String> reports = new JComboBox<>(service.names().toArray(new String[0]));
    private final JTable table = Ui.table();
    private final JLabel count = new JLabel(" ");
    private final Ui.LoadGuard reportLoad = new Ui.LoadGuard();

    ReportPanel() {
        setLayout(new BorderLayout(6, 6));
        setBorder(Ui.pad());
        reports.setPreferredSize(new Dimension(520, reports.getPreferredSize().height));
        JButton run = new JButton("Chạy báo cáo");
        run.addActionListener(e -> reload());
        reports.addActionListener(e -> reload());
        add(Ui.flow(new JLabel("Báo cáo:"), reports, run, count), BorderLayout.NORTH);
        add(Ui.scroll(table), BorderLayout.CENTER);
    }

    @Override
    public void reload() {
        String name = (String) reports.getSelectedItem();
        if (name == null) {
            reportLoad.invalidate();
            Ui.clear(table);
            count.setText("0 dòng");
            return;
        }
        Ui.clear(table);
        count.setText("Đang tải...");
        Ui.latest(this, reportLoad, () -> service.run(name), rows -> {
            Ui.fill(table, rows);
            count.setText(rows.size() + " dòng");
        });
    }
}
