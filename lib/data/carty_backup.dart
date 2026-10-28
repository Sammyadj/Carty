import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../cloud/cloud_workspace.dart';
import '../state/cart_store.dart';

/// Portable shopping data only. Sessions, keys, email and sync revisions are
/// excluded. The checksum detects damage; it is not a signature or encryption.
class CartyBackup {
  CartyBackup._(this.snapshot, this.createdAt, this.hasChecksum)
    : _data = jsonDecode(snapshot) as Map<String, dynamic>;
  static const maxBytes = 20 * 1024 * 1024;
  final String snapshot;
  final DateTime? createdAt;
  final bool hasChecksum;
  final Map<String, dynamic> _data;
  int get itemCount => (_data['items'] as List).length;
  int get listCount => (_data['savedLists'] as List? ?? []).length;
  int get tripCount => (_data['history'] as List? ?? []).length;
  int get preferenceCount =>
      (_data['productPreferences'] as List? ?? []).length;
  bool get isPlanning => _data['isPlanning'] == true;
  int? get budgetPence => _data['budgetPence'] as int?;
  List<String> names(String field) => List.unmodifiable([
    for (final record in (_data[field] as List? ?? []).take(5))
      record['name'] as String,
  ]);

  factory CartyBackup.fromSnapshot(String snapshot, {DateTime? createdAt}) {
    if (!CartStore.isValidSnapshot(snapshot)) {
      throw const FormatException('Invalid shopping data');
    }
    return CartyBackup._(
      canonicalSnapshot(snapshot),
      createdAt ?? DateTime.now().toUtc(),
      true,
    );
  }

  factory CartyBackup.deviceSnapshot(String snapshot) {
    if (!CartStore.isValidSnapshot(snapshot)) {
      throw const FormatException('Invalid shopping data');
    }
    return CartyBackup._(canonicalSnapshot(snapshot), null, false);
  }
  Uint8List encode() {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'carty-shopping-backup',
          'formatVersion': 1,
          'currency': 'GBP',
          'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
          'snapshot': jsonDecode(snapshot),
          'checksum': sha256.convert(utf8.encode(snapshot)).toString(),
        }),
      ),
    );
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup exceeds 20 MB');
    }
    return bytes;
  }

  factory CartyBackup.decode(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup exceeds 20 MB');
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid Carty backup');
    }
    if (!value.containsKey('format') &&
        CartStore.isValidSnapshot(jsonEncode(value))) {
      return CartyBackup._(canonicalSnapshot(jsonEncode(value)), null, false);
    }
    final date = value['createdAt'];
    if (value['format'] != 'carty-shopping-backup' ||
        value['formatVersion'] != 1 ||
        value['currency'] != 'GBP' ||
        value['snapshot'] is! Map<String, dynamic> ||
        date is! String ||
        DateTime.tryParse(date) == null ||
        value['checksum'] is! String) {
      throw const FormatException('Unsupported Carty backup');
    }
    final snapshot = canonicalSnapshot(jsonEncode(value['snapshot']));
    if (sha256.convert(utf8.encode(snapshot)).toString() != value['checksum'] ||
        !CartStore.isValidSnapshot(snapshot)) {
      throw const FormatException('Damaged Carty backup');
    }
    return CartyBackup._(snapshot, DateTime.parse(date), true);
  }
}
