/// Small, dependency-free currency helpers for the GBP-only MVP.
///
/// Amounts are stored as pence throughout the app so calculations never rely
/// on floating-point values.
class Money {
  const Money._();

  static const maxPence = 999999999;

  static int? tryParsePence(String input) {
    var value = input.trim();
    if (value.startsWith('£')) value = value.substring(1).trim();
    if (value.length > 24) return null;
    final match = RegExp(
      r'^(?:(\d+)(?:[.,](\d{1,2}))?|[.,](\d{1,2}))$',
    ).firstMatch(value);
    if (match == null) return null;

    final pounds = int.tryParse(match.group(1) ?? '0');
    if (pounds == null || pounds > maxPence ~/ 100) return null;

    final decimal = match.group(2) ?? match.group(3) ?? '';
    final pence = decimal.isEmpty ? 0 : int.parse(decimal.padRight(2, '0'));
    final amount = pounds * 100 + pence;
    return amount <= maxPence ? amount : null;
  }

  static String format(int pence) {
    final sign = pence < 0 ? '-' : '';
    final absolute = pence.abs();
    final pounds = absolute ~/ 100;
    final remainder = (absolute % 100).toString().padLeft(2, '0');
    return '$sign£$pounds.$remainder';
  }
}
