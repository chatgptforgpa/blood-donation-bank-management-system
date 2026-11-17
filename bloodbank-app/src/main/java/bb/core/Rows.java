package bb.core;

import java.util.List;

public record Rows(List<String> columns, List<Object[]> data) {
    public int size() {
        return data.size();
    }

    public Object get(int row, String column) {
        int index = columns.indexOf(column);
        if (index < 0) {
            throw new IllegalArgumentException("Unknown column " + column);
        }
        return data.get(row)[index];
    }

    public String str(int row, String column) {
        Object value = get(row, column);
        return value == null ? null : value.toString();
    }

    public long num(int row, String column) {
        Object value = get(row, column);
        return value == null ? 0 : ((Number) value).longValue();
    }
}
