package bb.core;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public final class Sql {
    @FunctionalInterface
    public interface Work<T> {
        T run(Connection c) throws SQLException;
    }

    @FunctionalInterface
    public interface Job {
        void run(Connection c) throws SQLException;
    }

    private Sql() {
    }

    private static void bind(PreparedStatement ps, Object[] params) throws SQLException {
        for (int i = 0; i < params.length; i++) {
            ps.setObject(i + 1, params[i]);
        }
    }

    public static Rows select(Connection c, String sql, Object... params) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                ResultSetMetaData meta = rs.getMetaData();
                int n = meta.getColumnCount();
                List<String> columns = new ArrayList<>();
                for (int i = 1; i <= n; i++) {
                    columns.add(meta.getColumnLabel(i));
                }
                List<Object[]> data = new ArrayList<>();
                while (rs.next()) {
                    Object[] row = new Object[n];
                    for (int i = 0; i < n; i++) {
                        row[i] = rs.getObject(i + 1);
                    }
                    data.add(row);
                }
                return new Rows(columns, data);
            }
        }
    }

    public static int update(Connection c, String sql, Object... params) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            bind(ps, params);
            return ps.executeUpdate();
        }
    }

    public static Rows query(String sql, Object... params) {
        try (Connection c = Db.open()) {
            return select(c, sql, params);
        } catch (SQLException e) {
            throw Errors.of(e);
        }
    }

    public static <T> T tx(Work<T> work) {
        try (Connection c = Db.open()) {
            c.setAutoCommit(false);
            try {
                T result = work.run(c);
                c.commit();
                return result;
            } catch (SQLException e) {
                rollback(c);
                throw Errors.of(e);
            } catch (RuntimeException e) {
                rollback(c);
                throw e;
            }
        } catch (SQLException e) {
            throw Errors.of(e);
        }
    }

    public static void run(Job job) {
        tx(c -> {
            job.run(c);
            return null;
        });
    }

    private static void rollback(Connection c) {
        try {
            c.rollback();
        } catch (SQLException ignored) {
        }
    }
}
