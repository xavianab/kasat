/// Timestamp helpers. Everything the operator sees is UTC and 24-hour; local
/// time would narrow down a survivor's timezone.
abstract final class TimeFormat {
  static String stamp(DateTime dt) {
    final u = dt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)}Z';
  }

  static String clock(DateTime dt) {
    final u = dt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  static String elapsed(DateTime from, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(from);
    if (d.inMinutes < 1) return 'JUST NOW';
    if (d.inMinutes < 60) return '${d.inMinutes}M AGO';
    if (d.inHours < 48) return '${d.inHours}H AGO';
    return '${d.inDays}D AGO';
  }
}
