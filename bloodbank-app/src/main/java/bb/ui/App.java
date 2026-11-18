package bb.ui;

import bb.core.Db;
import java.io.File;
import java.sql.SQLException;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JTextField;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;

public final class App {
    private static final String DEFAULT_URL =
            "jdbc:mysql://localhost:3306/blood_bank_group2_d3?useSSL=false&allowPublicKeyRetrieval=true&characterEncoding=utf8";

    private App() {
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            try {
                UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
            } catch (Exception ignored) {
            }
            File file = new File(args.length > 0 ? args[0] : "db.properties");
            boolean ready = Db.loadFile(file) && ping();
            while (!ready) {
                if (!promptConnection()) {
                    System.exit(0);
                }
                ready = ping();
            }
            new MainFrame().setVisible(true);
        });
    }

    private static boolean ping() {
        try {
            Db.ping();
            return true;
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(null, "Cannot connect to the database: " + e.getMessage(), "Connection error", JOptionPane.ERROR_MESSAGE);
            return false;
        }
    }

    private static boolean promptConnection() {
        JTextField url = new JTextField(DEFAULT_URL, 48);
        JTextField user = new JTextField(20);
        JPasswordField password = new JPasswordField(20);
        JPanel form = Ui.form(1, "JDBC URL", url, "User", user, "Password", password);
        int choice = JOptionPane.showConfirmDialog(null, form, "Connect to MySQL", JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
        if (choice != JOptionPane.OK_OPTION) {
            return false;
        }
        Db.configure(url.getText().trim(), user.getText().trim(), new String(password.getPassword()));
        return true;
    }
}
