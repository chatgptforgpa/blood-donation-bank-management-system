package bb.service;

import bb.core.AppException;
import bb.core.Biz;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InventoryServiceTest {
    @Test
    void collectionDateIsRequired() {
        AppException error = assertThrows(AppException.class,
                () -> InventoryService.validateDates(null, Biz.today().plusDays(2)));
        assertTrue(error.getMessage().contains("Ngày thu thập"));
    }

    @Test
    void collectionDateCannotBeInTheFuture() {
        LocalDate tomorrow = Biz.today().plusDays(1);
        AppException error = assertThrows(AppException.class,
                () -> InventoryService.validateDates(tomorrow, tomorrow.plusDays(2)));
        assertTrue(error.getMessage().contains("không được sau ngày hiện tại"));
    }

    @Test
    void expiryDateIsRequired() {
        AppException error = assertThrows(AppException.class,
                () -> InventoryService.validateDates(Biz.today(), null));
        assertTrue(error.getMessage().contains("Ngày hết hạn"));
    }

    @Test
    void expiryCannotEqualCollectionDate() {
        LocalDate date = Biz.today();
        AppException error = assertThrows(AppException.class,
                () -> InventoryService.validateDates(date, date));
        assertTrue(error.getMessage().contains("phải sau ngày thu thập"));
    }

    @Test
    void expiryCannotPrecedeCollectionDate() {
        LocalDate date = Biz.today();
        AppException error = assertThrows(AppException.class,
                () -> InventoryService.validateDates(date, date.minusDays(1)));
        assertTrue(error.getMessage().contains("phải sau ngày thu thập"));
    }

    @Test
    void expiryInTheFutureIsAllowedWithoutAFixedShelfLife() {
        LocalDate date = Biz.today();
        assertDoesNotThrow(() -> InventoryService.validateDates(date, date.plusDays(2)));
        assertDoesNotThrow(() -> InventoryService.validateDates(date, date.plusDays(400)));
    }

    @Test
    void historicalDatesOnlyRequireExpiryAfterCollection() {
        LocalDate date = Biz.today().minusDays(10);
        assertDoesNotThrow(() -> InventoryService.validateDates(date, date.plusDays(2)));
    }
}
