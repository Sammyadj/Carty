import 'package:flutter/foundation.dart';

import 'carty_backup.dart';

class BackupCodec {
  const BackupCodec();
  Future<CartyBackup> decode(Uint8List bytes) =>
      compute(CartyBackup.decode, bytes);
  Future<Uint8List> encode(String snapshot) => compute(_encode, snapshot);
  static Uint8List _encode(String snapshot) =>
      CartyBackup.fromSnapshot(snapshot).encode();
}
