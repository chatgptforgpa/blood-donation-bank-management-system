package bb.ui;

import bb.core.AppException;
import bb.core.Rows;
import java.awt.Component;
import java.awt.Container;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTable;
import javax.swing.SwingUtilities;
import javax.swing.SwingWorker;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import static org.junit.jupiter.api.Assertions.*;

@Timeout(10)
class UiTest {
    private static void edt(Runnable action) throws Exception {
        SwingUtilities.invokeAndWait(action);
    }

    private static CountDownLatch done(SwingWorker<?, ?> worker) {
        CountDownLatch latch = new CountDownLatch(1);
        worker.addPropertyChangeListener(e -> {
            if ("state".equals(e.getPropertyName())
                    && e.getNewValue() == SwingWorker.StateValue.DONE) {
                latch.countDown();
            }
        });
        if (worker.getState() == SwingWorker.StateValue.DONE) {
            latch.countDown();
        }
        return latch;
    }

    @Test
    void newerReadCannotBeOverwrittenByAnOlderRead() throws Exception {
        Ui.LoadGuard guard = new Ui.LoadGuard();
        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch applied = new CountDownLatch(1);
        AtomicReference<String> visible = new AtomicReference<>("empty");
        AtomicReference<SwingWorker<String, Void>> older = new AtomicReference<>();
        edt(() -> older.set(Ui.latest(new JPanel(), guard, () -> {
            started.countDown();
            assertTrue(release.await(5, TimeUnit.SECONDS));
            return "A";
        }, visible::set)));
        assertTrue(started.await(5, TimeUnit.SECONDS));
        CountDownLatch oldDone = done(older.get());
        edt(() -> Ui.latest(new JPanel(), guard, () -> "B", value -> {
            assertTrue(SwingUtilities.isEventDispatchThread());
            visible.set(value);
            applied.countDown();
        }));
        assertTrue(applied.await(5, TimeUnit.SECONDS));
        release.countDown();
        assertTrue(oldDone.await(5, TimeUnit.SECONDS));
        assertEquals("B", visible.get());
    }

    @Test
    void clearingTheSelectionInvalidatesItsPendingRead() throws Exception {
        Ui.LoadGuard guard = new Ui.LoadGuard();
        CountDownLatch release = new CountDownLatch(1);
        AtomicReference<String> visible = new AtomicReference<>("empty");
        AtomicReference<SwingWorker<String, Void>> worker = new AtomicReference<>();
        edt(() -> worker.set(Ui.latest(new JPanel(), guard, () -> {
            assertTrue(release.await(5, TimeUnit.SECONDS));
            return "old detail";
        }, visible::set)));
        CountDownLatch finished = done(worker.get());
        edt(guard::invalidate);
        release.countDown();
        assertTrue(finished.await(5, TimeUnit.SECONDS));
        assertEquals("empty", visible.get());
    }

    @Test
    void errorFromAnObsoleteReadIsNotShown() throws Exception {
        Ui.LoadGuard guard = new Ui.LoadGuard();
        CountDownLatch release = new CountDownLatch(1);
        AtomicReference<SwingWorker<String, Void>> worker = new AtomicReference<>();
        edt(() -> worker.set(Ui.<String>latest(new JPanel(), guard, () -> {
            assertTrue(release.await(5, TimeUnit.SECONDS));
            throw new AppException("Obsolete selection");
        }, value -> fail("A failed obsolete read must not update the UI"))));
        CountDownLatch finished = done(worker.get());
        edt(guard::invalidate);
        release.countDown();
        assertTrue(finished.await(5, TimeUnit.SECONDS));
    }

    @Test
    void browseCountTracksLoadedAndEmptyResults() throws Exception {
        AtomicReference<JTable> table = new AtomicReference<>();
        AtomicReference<JPanel> panel = new AtomicReference<>();
        edt(() -> {
            table.set(Ui.table());
            panel.set(Ui.browse(table.get()));
        });
        assertEquals("0 rows", countLabel(panel.get()).getText());
        edt(() -> Ui.fill(table.get(), new Rows(List.of("id"),
                List.of(new Object[]{"A"}, new Object[]{"B"}))));
        edt(() -> { });
        assertEquals("2 rows", countLabel(panel.get()).getText());
        edt(() -> Ui.fill(table.get(), new Rows(List.of("id"), List.of())));
        edt(() -> { });
        assertEquals("0 rows", countLabel(panel.get()).getText());
    }

    private static JLabel countLabel(Container parent) {
        for (Component c : parent.getComponents()) {
            if (c instanceof JLabel label && label.getText().endsWith(" rows")) {
                return label;
            }
            if (c instanceof Container child) {
                JLabel found = countLabel(child);
                if (found != null) return found;
            }
        }
        return null;
    }
}
