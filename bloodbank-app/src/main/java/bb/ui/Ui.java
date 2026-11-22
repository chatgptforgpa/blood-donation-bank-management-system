package bb.ui;

import bb.core.AppException;
import bb.core.Option;
import bb.core.Rows;
import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.FlowLayout;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import javax.swing.BorderFactory;
import javax.swing.JComboBox;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.JTextField;
import javax.swing.SwingWorker;
import javax.swing.SwingUtilities;
import javax.swing.border.Border;
import javax.swing.table.DefaultTableModel;

final class Ui {
    static final Option ALL = new Option(null, "All");

    private Ui() {
    }

    static Border pad() {
        return BorderFactory.createEmptyBorder(8, 8, 8, 8);
    }

    static JTable table() {
        JTable t = new JTable(new DefaultTableModel() {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        });
        t.setAutoCreateRowSorter(true);
        t.setFillsViewportHeight(true);
        t.setRowHeight(22);
        return t;
    }

    static JScrollPane scroll(JTable t) {
        return new JScrollPane(t);
    }

    static JPanel browse(JTable table) {
        JLabel count = new JLabel();
        Runnable update = () -> count.setText(table.getRowCount() + " rows");
        table.getModel().addTableModelListener(e -> SwingUtilities.invokeLater(update));
        table.addPropertyChangeListener("rowSorter", e -> {
            if (table.getRowSorter() != null) {
                table.getRowSorter().addRowSorterListener(event -> update.run());
            }
            update.run();
        });
        if (table.getRowSorter() != null) {
            table.getRowSorter().addRowSorterListener(e -> update.run());
        }
        update.run();
        JPanel panel = new JPanel(new BorderLayout(0, 3));
        panel.add(scroll(table), BorderLayout.CENTER);
        panel.add(count, BorderLayout.SOUTH);
        return panel;
    }

    static void fill(JTable t, Rows rows) {
        DefaultTableModel model = (DefaultTableModel) t.getModel();
        model.setDataVector(rows.data().toArray(new Object[0][]), rows.columns().toArray());
    }

    static void clear(JTable t) {
        ((DefaultTableModel) t.getModel()).setDataVector(new Object[0][], new Object[0]);
    }

    static String selected(JTable t, String column) {
        int view = t.getSelectedRow();
        if (view < 0) {
            return null;
        }
        DefaultTableModel model = (DefaultTableModel) t.getModel();
        int col = model.findColumn(column);
        if (col < 0) {
            return null;
        }
        Object value = model.getValueAt(t.convertRowIndexToModel(view), col);
        return value == null ? null : value.toString();
    }

    static List<String> selectedAll(JTable t, String column) {
        List<String> values = new ArrayList<>();
        DefaultTableModel model = (DefaultTableModel) t.getModel();
        int col = model.findColumn(column);
        if (col < 0) {
            return values;
        }
        for (int view : t.getSelectedRows()) {
            Object value = model.getValueAt(t.convertRowIndexToModel(view), col);
            if (value != null) {
                values.add(value.toString());
            }
        }
        return values;
    }

    static JComboBox<String> combo(String... items) {
        return new JComboBox<>(items);
    }

    static JComboBox<String> comboAll(String... items) {
        String[] all = new String[items.length + 1];
        all[0] = "All";
        System.arraycopy(items, 0, all, 1, items.length);
        return new JComboBox<>(all);
    }

    static String value(JComboBox<String> box) {
        String v = (String) box.getSelectedItem();
        return v == null || "All".equals(v) ? null : v;
    }

    static void setOptions(JComboBox<Option> box, List<Option> options, boolean withAll) {
        Object previous = box.getSelectedItem();
        box.removeAllItems();
        if (withAll) {
            box.addItem(ALL);
        }
        for (Option o : options) {
            box.addItem(o);
        }
        if (previous instanceof Option p) {
            for (int i = 0; i < box.getItemCount(); i++) {
                if (java.util.Objects.equals(box.getItemAt(i).id(), p.id())) {
                    box.setSelectedIndex(i);
                    break;
                }
            }
        }
    }

    static String id(JComboBox<Option> box) {
        Option o = (Option) box.getSelectedItem();
        return o == null ? null : o.id();
    }

    static LocalDate date(JTextField field, String name) {
        try {
            return LocalDate.parse(field.getText().trim());
        } catch (DateTimeParseException e) {
            throw new AppException(name + " must be in the form yyyy-MM-dd.");
        }
    }

    static int integer(JTextField field, String name) {
        try {
            return Integer.parseInt(field.getText().trim());
        } catch (NumberFormatException e) {
            throw new AppException(name + " must be a whole number.");
        }
    }

    static JPanel flow(Component... parts) {
        JPanel p = new JPanel(new FlowLayout(FlowLayout.LEFT, 6, 4));
        for (Component c : parts) {
            p.add(c);
        }
        return p;
    }

    static JPanel form(int pairsPerRow, Object... labelAndField) {
        JPanel p = new JPanel(new GridBagLayout());
        GridBagConstraints g = new GridBagConstraints();
        g.insets = new Insets(3, 4, 3, 4);
        g.anchor = GridBagConstraints.WEST;
        g.fill = GridBagConstraints.HORIZONTAL;
        int pairs = labelAndField.length / 2;
        for (int i = 0; i < pairs; i++) {
            int col = (i % pairsPerRow) * 2;
            int row = i / pairsPerRow;
            g.gridx = col;
            g.gridy = row;
            g.weightx = 0;
            p.add(new JLabel((String) labelAndField[2 * i]), g);
            g.gridx = col + 1;
            g.weightx = 1;
            p.add((Component) labelAndField[2 * i + 1], g);
        }
        return p;
    }

    static JPanel stack(Component top, Component bottom) {
        JPanel p = new JPanel(new BorderLayout(0, 4));
        p.add(top, BorderLayout.NORTH);
        p.add(bottom, BorderLayout.CENTER);
        return p;
    }

    static final class LoadGuard {
        private final AtomicLong version = new AtomicLong();

        long next() {
            return version.incrementAndGet();
        }

        void invalidate() {
            version.incrementAndGet();
        }

        boolean isCurrent(long ticket) {
            return version.get() == ticket;
        }
    }

    static <T> void async(Component owner, Callable<T> job, Consumer<T> ok) {
        submit(owner, job, ok, () -> true);
    }

    static <T> SwingWorker<T, Void> latest(Component owner, LoadGuard guard,
            Callable<T> job, Consumer<T> ok) {
        long ticket = guard.next();
        return submit(owner, job, ok, () -> guard.isCurrent(ticket));
    }

    private static <T> SwingWorker<T, Void> submit(Component owner, Callable<T> job,
            Consumer<T> ok, BooleanSupplier current) {
        SwingWorker<T, Void> worker = new SwingWorker<T, Void>() {
            @Override
            protected T doInBackground() throws Exception {
                return job.call();
            }

            @Override
            protected void done() {
                if (!current.getAsBoolean()) {
                    return;
                }
                try {
                    ok.accept(get());
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } catch (ExecutionException e) {
                    error(owner, e.getCause());
                }
            }
        };
        worker.execute();
        return worker;
    }

    static void error(Component owner, Throwable t) {
        String message = t instanceof AppException ? t.getMessage() : "Unexpected error: " + t;
        JOptionPane.showMessageDialog(owner, message, "Error", JOptionPane.ERROR_MESSAGE);
    }

    static void info(Component owner, String message) {
        JOptionPane.showMessageDialog(owner, message, "Information", JOptionPane.INFORMATION_MESSAGE);
    }

    static boolean confirm(Component owner, String message) {
        return JOptionPane.showConfirmDialog(owner, message, "Confirm", JOptionPane.YES_NO_OPTION) == JOptionPane.YES_OPTION;
    }

    static void guard(Component owner, Runnable action) {
        try {
            action.run();
        } catch (AppException e) {
            error(owner, e);
        }
    }
}
