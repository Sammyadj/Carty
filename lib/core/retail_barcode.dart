/// Validation and comparison for the GTIN formats used on retail packaging.
abstract final class RetailBarcode {
  static final _digits = RegExp(r'^[0-9]+$');
  static const _lengths = {8, 12, 13, 14};

  /// Keeps the printed representation, including any leading zeroes.
  static String? normalize(String value) {
    final barcode = value.trim();
    if (!_lengths.contains(barcode.length) || !_digits.hasMatch(barcode)) {
      return null;
    }

    var sum = 0;
    var weight = 3;
    for (var i = barcode.length - 2; i >= 0; i--) {
      sum += (barcode.codeUnitAt(i) - 48) * weight;
      weight = weight == 3 ? 1 : 3;
    }
    final checkDigit = (10 - sum % 10) % 10;
    return checkDigit == barcode.codeUnitAt(barcode.length - 1) - 48
        ? barcode
        : null;
  }

  /// Makes equivalent UPC and zero-prefixed EAN representations compare equal.
  static String key(String value) {
    final barcode = normalize(value);
    if (barcode == null) {
      throw ArgumentError.value(value, 'value', 'A valid GTIN is required.');
    }
    return barcode.padLeft(14, '0');
  }
}
