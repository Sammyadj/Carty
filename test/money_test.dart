import 'package:carty_app/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses whole and decimal GBP values into exact pence', () {
    expect(Money.tryParsePence('2'), 200);
    expect(Money.tryParsePence('2.5'), 250);
    expect(Money.tryParsePence(' £2.05 '), 205);
    expect(Money.tryParsePence('0,10'), 10);
    expect(Money.tryParsePence('.50'), 50);
    expect(Money.tryParsePence('0'), 0);
    expect(Money.tryParsePence('9999999.99'), Money.maxPence);
  });

  test('rejects malformed, non-finite, signed and over-precision prices', () {
    for (final input in [
      '',
      ' ',
      '-1',
      '+1',
      'NaN',
      'Infinity',
      '1e3',
      '2.001',
      '1,234.00',
      '2£',
      '££2',
      '2.',
      '2..5',
      '10000000',
      '999999999999999999999999999999999',
    ]) {
      expect(Money.tryParsePence(input), isNull, reason: input);
    }
  });

  test('formats positive, zero and negative integer amounts', () {
    expect(Money.format(10), '£0.10');
    expect(Money.format(0), '£0.00');
    expect(Money.format(1205), '£12.05');
    expect(Money.format(-1205), '-£12.05');
  });
}
