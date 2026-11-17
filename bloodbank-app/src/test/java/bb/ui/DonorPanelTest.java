package bb.ui;

import bb.core.Rows;
import java.lang.reflect.Field;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import javax.swing.JComboBox;
import javax.swing.JTable;
import javax.swing.JTextField;
import javax.swing.SwingUtilities;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class DonorPanelTest {
    private static <T> T field(Object target, String name, Class<T> type) {
        try {
            Field f = target.getClass().getDeclaredField(name);
            f.setAccessible(true);
            return type.cast(f.get(target));
        } catch (ReflectiveOperationException e) {
            throw new AssertionError(e);
        }
    }

    @Test
    void resetClearsSelectedDonorAndRestoresNewDonorInputs() throws Exception {
        AtomicReference<DonorPanel> panel = new AtomicReference<>();
        SwingUtilities.invokeAndWait(() -> {
            DonorPanel p = new DonorPanel();
            panel.set(p);
            JTable table = field(p, "table", JTable.class);
            Ui.fill(table, new Rows(List.of("donor_id", "full_name", "blood_group", "rh_factor",
                    "date_of_birth", "address", "phones"),
                    List.<Object[]>of(new Object[]{"D1", "Old donor", "AB", "-", "1990-01-01", "Old address", "0900000111"})));
            table.setRowSelectionInterval(0, 0);
            assertEquals("Old donor", field(p, "name", JTextField.class).getText());
            assertFalse(field(p, "group", JComboBox.class).isEnabled());
            p.resetForm();
            assertEquals(-1, table.getSelectedRow());
            for (String name : List.of("name", "dob", "address", "phones")) {
                assertEquals("", field(p, name, JTextField.class).getText(), name);
            }
            assertEquals("A", field(p, "group", JComboBox.class).getSelectedItem());
            assertEquals("+", field(p, "rh", JComboBox.class).getSelectedItem());
            assertTrue(field(p, "group", JComboBox.class).isEnabled());
            assertTrue(field(p, "rh", JComboBox.class).isEnabled());
        });
    }
}
