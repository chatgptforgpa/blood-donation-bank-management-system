package bb.core;

public record Option(String id, String label) {
    @Override
    public String toString() {
        return label;
    }
}
