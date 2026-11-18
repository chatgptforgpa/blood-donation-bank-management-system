package bb.ui;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.util.ArrayList;
import java.util.List;
import javax.swing.JFrame;
import javax.swing.JTabbedPane;

final class MainFrame extends JFrame {
    MainFrame() {
        super("Blood Bank - Group 02");
        setDefaultCloseOperation(EXIT_ON_CLOSE);
        JTabbedPane tabs = new JTabbedPane();
        List<Reloadable> panels = new ArrayList<>();
        add(tabs, "Donor", new DonorPanel(), panels);
        add(tabs, "Donations & Screening", new DonationPanel(), panels);
        add(tabs, "Inventory", new InventoryPanel(), panels);
        add(tabs, "Requests", new RequestPanel(), panels);
        add(tabs, "Issuance", new IssuancePanel(), panels);
        add(tabs, "Reports", new ReportPanel(), panels);
        tabs.addChangeListener(e -> panels.get(tabs.getSelectedIndex()).reload());
        getContentPane().add(tabs, BorderLayout.CENTER);
        setMinimumSize(new Dimension(1000, 640));
        setSize(1200, 760);
        setLocationRelativeTo(null);
        panels.get(0).reload();
    }

    private static void add(JTabbedPane tabs, String title, javax.swing.JComponent panel, List<Reloadable> panels) {
        tabs.addTab(title, panel);
        panels.add((Reloadable) panel);
    }
}
