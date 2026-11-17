package bb.core;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

public final class Db {
    private static volatile String url;
    private static volatile String user;
    private static volatile String password;

    private Db() {
    }

    public static void configure(String jdbcUrl, String dbUser, String dbPassword) {
        url = jdbcUrl;
        user = dbUser;
        password = dbPassword == null ? "" : dbPassword;
    }

    public static boolean loadFile(File file) {
        if (!file.isFile()) {
            return false;
        }
        Properties props = new Properties();
        try (InputStream in = new FileInputStream(file)) {
            props.load(in);
        } catch (IOException e) {
            return false;
        }
        String jdbcUrl = props.getProperty("url");
        String dbUser = props.getProperty("user");
        if (jdbcUrl == null || jdbcUrl.isBlank() || dbUser == null || dbUser.isBlank()) {
            return false;
        }
        configure(jdbcUrl.trim(), dbUser.trim(), props.getProperty("password", ""));
        return true;
    }

    public static Connection open() throws SQLException {
        if (url == null) {
            throw new SQLException("Chưa cấu hình kết nối database.");
        }
        return DriverManager.getConnection(url, user, password);
    }

    public static void ping() throws SQLException {
        try (Connection c = open()) {
            c.isValid(3);
        }
    }
}
