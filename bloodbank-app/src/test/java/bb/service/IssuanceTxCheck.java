package bb.service;

import bb.core.AppException;
import bb.core.Db;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Proxy;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Driver;
import java.sql.DriverManager;
import java.sql.DriverPropertyInfo;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.SQLFeatureNotSupportedException;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.logging.Logger;
import java.util.function.Function;

public final class IssuanceTxCheck {
    record Table(List<String> cols, List<Object[]> rows) {
    }

    static final List<String> LOG = new ArrayList<>();
    static int failOnCall = -1;
    static long needed = 3;
    static long issued = 0;
    static int calls = 0;

    @SuppressWarnings("unchecked")
    static <T> T proxy(Class<T> type, InvocationHandler handler) {
        return (T) Proxy.newProxyInstance(IssuanceTxCheck.class.getClassLoader(), new Class<?>[] {type}, handler);
    }

    static Object defaults(java.lang.reflect.Method m) {
        Class<?> r = m.getReturnType();
        if (r == boolean.class) {
            return false;
        }
        if (r == int.class) {
            return 0;
        }
        if (r == long.class) {
            return 0L;
        }
        return null;
    }

    static Table answer(String sql) {
        if (sql.contains("FROM REQUEST WHERE request_id")) {
            return new Table(List.of("quantity_needed"), List.<Object[]>of(new Object[] {needed}));
        }
        if (sql.contains("FROM ISSUE_RECORD WHERE request_id")) {
            return new Table(List.of("n"), List.<Object[]>of(new Object[] {issued}));
        }
        if (sql.contains("FROM STAFF WHERE staff_id")) {
            return new Table(List.of("bank_id"), List.<Object[]>of(new Object[] {"B1"}));
        }
        return new Table(List.of(), List.of());
    }

    static ResultSet resultSet(Table t) {
        int[] pos = {-1};
        ResultSetMetaData meta = proxy(ResultSetMetaData.class, (p, m, a) -> switch (m.getName()) {
            case "getColumnCount" -> t.cols().size();
            case "getColumnLabel" -> t.cols().get((Integer) a[0] - 1);
            default -> defaults(m);
        });
        return proxy(ResultSet.class, (p, m, a) -> switch (m.getName()) {
            case "next" -> ++pos[0] < t.rows().size();
            case "getMetaData" -> meta;
            case "getObject" -> t.rows().get(pos[0])[(Integer) a[0] - 1];
            default -> defaults(m);
        });
    }

    static Connection connection() {
        return proxy(Connection.class, (p, m, a) -> switch (m.getName()) {
            case "setAutoCommit" -> {
                LOG.add("autocommit=" + a[0]);
                yield null;
            }
            case "commit" -> {
                LOG.add("commit");
                yield null;
            }
            case "rollback" -> {
                LOG.add("rollback");
                yield null;
            }
            case "prepareStatement" -> {
                String sql = (String) a[0];
                yield proxy(PreparedStatement.class, (pp, mm, aa) -> switch (mm.getName()) {
                    case "executeQuery" -> resultSet(answer(sql));
                    case "executeUpdate" -> 1;
                    default -> defaults(mm);
                });
            }
            case "prepareCall" -> {
                String sql = (String) a[0];
                List<Object> args = new ArrayList<>();
                yield proxy(CallableStatement.class, (pp, mm, aa) -> {
                    if (mm.getName().equals("setString")) {
                        args.add(aa[1]);
                    }
                    if (mm.getName().equals("execute")) {
                        calls++;
                        LOG.add("call " + sql + " " + args.subList(1, args.size()));
                        if (calls == failOnCall) {
                            throw new SQLException("The blood unit must exist and be Available.", "45000", 1644);
                        }
                        args.clear();
                    }
                    return defaults(mm);
                });
            }
            default -> defaults(m);
        });
    }

    static void expect(boolean ok, String label) {
        System.out.println((ok ? "PASS " : "FAIL ") + label);
        if (!ok) {
            throw new AssertionError(label);
        }
    }

    static void reset(long need, long done, int fail) {
        LOG.clear();
        needed = need;
        issued = done;
        failOnCall = fail;
        calls = 0;
    }

    public static void main(String[] args) throws Exception {
        DriverManager.registerDriver(new Driver() {
            public Connection connect(String url, Properties info) {
                return url.startsWith("jdbc:fake:") ? connection() : null;
            }

            public boolean acceptsURL(String url) {
                return url.startsWith("jdbc:fake:");
            }

            public DriverPropertyInfo[] getPropertyInfo(String url, Properties info) {
                return new DriverPropertyInfo[0];
            }

            public int getMajorVersion() {
                return 1;
            }

            public int getMinorVersion() {
                return 0;
            }

            public boolean jdbcCompliant() {
                return false;
            }

            public Logger getParentLogger() throws SQLFeatureNotSupportedException {
                throw new SQLFeatureNotSupportedException();
            }
        });
        Db.configure("jdbc:fake:db", "u", "p");
        IssuanceService service = new IssuanceService();

        reset(3, 0, -1);
        List<String> ids = service.issue("R1", "S1", List.of("U1", "U2"));
        expect(ids.size() == 2 && LOG.contains("commit") && !LOG.contains("rollback"), "two units issued in one committed transaction");
        expect(LOG.stream().filter(s -> s.startsWith("call")).count() == 2, "procedure called once per unit");
        expect(LOG.get(0).equals("autocommit=false"), "transaction opened with autocommit off");

        reset(3, 0, 2);
        try {
            service.issue("R1", "S1", List.of("U1", "U2"));
            expect(false, "second failure must throw");
        } catch (AppException e) {
            expect(e.getMessage().equals("The blood unit must exist and be Available."), "business message surfaced to UI");
        }
        expect(LOG.contains("rollback") && !LOG.contains("commit"), "failure after first issue rolls back everything");

        reset(3, 2, -1);
        try {
            service.issue("R1", "S1", List.of("U1", "U2"));
            expect(false, "over-issue must throw");
        } catch (AppException e) {
            expect(e.getMessage().contains("còn thiếu 1"), "over-issuance rejected with remaining count");
        }
        expect(calls == 0 && LOG.contains("rollback"), "no procedure call when quantity exceeds remaining");

        reset(3, 3, -1);
        try {
            service.issue("R1", "S1", List.of("U1"));
            expect(false, "fulfilled must throw");
        } catch (AppException e) {
            expect(e.getMessage().contains("cấp đủ"), "fulfilled request rejected");
        }

        try {
            service.issue("R1", "S1", List.of("U1", "U1"));
            expect(false, "duplicate must throw");
        } catch (AppException e) {
            expect(e.getMessage().contains("trùng"), "duplicate unit ids rejected before opening a transaction");
        }
        System.out.println("ALL PASS");
    }
}
