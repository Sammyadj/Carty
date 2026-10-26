import 'package:carty_app/core/retail_barcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts GTIN 8, 12, 13 and 14 with valid check digits', () {
    for (final code in [
      '96385074',
      '036000291452',
      '4006381333931',
      '10012345000017',
    ]) {
      expect(RetailBarcode.normalize('  $code\n'), code);
    }
  });

  test('rejects incomplete, non-numeric and invalid-checksum barcodes', () {
    for (final code in [
      '',
      '1234567',
      '123456789',
      '123456789012345',
      '4006381333932',
      '96385075',
      '036000291453',
      '10012345000018',
      '4006381 33931',
      '+4006381333931',
      '４００６３８１３３３９３１',
      'ABCDEF12',
    ]) {
      expect(RetailBarcode.normalize(code), isNull, reason: code);
    }
  });

  test('retains leading zeroes while keys match equivalent UPC and EAN', () {
    expect(RetailBarcode.normalize('036000291452'), '036000291452');
    expect(RetailBarcode.normalize('0036000291452'), '0036000291452');
    expect(RetailBarcode.key('036000291452'), '00036000291452');
    expect(
      RetailBarcode.key('036000291452'),
      RetailBarcode.key('0036000291452'),
    );
    expect(RetailBarcode.key('96385074'), '00000096385074');
    expect(() => RetailBarcode.key('not a barcode'), throwsArgumentError);
  });
}
