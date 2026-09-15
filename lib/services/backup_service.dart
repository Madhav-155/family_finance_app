import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';

class BackupService {
  BackupService(this.database);

  final AppDatabase database;
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'backup_encryption_key';
  final _cipher = AesGcm.with256bits();

  Future<File> createBackup() async {
    final clearText = utf8.encode(jsonEncode(await database.exportData()));
    final secretBox = await _cipher.encrypt(
      clearText,
      secretKey: await _secretKey(),
      nonce: _randomBytes(_cipher.nonceLength),
    );
    final directory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(path.join(directory.path, 'backups'));
    await backupDirectory.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File(
      path.join(backupDirectory.path, 'finance-$stamp.ffbackup'),
    );
    return file.writeAsBytes(secretBox.concatenation(), flush: true);
  }

  Future<void> createAndShareBackup() async {
    final file = await createBackup();
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Encrypted Family Finance backup',
        text: 'Keep this encrypted backup in a safe location.',
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
      ),
    );
  }

  Future<File?> latestBackup() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(path.join(directory.path, 'backups'));
    if (!await backupDirectory.exists()) return null;
    final files = await backupDirectory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.ffbackup'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.firstOrNull;
  }

  Future<void> restoreLatestBackup() async {
    final file = await latestBackup();
    if (file == null) throw StateError('No local backup was found.');
    final bytes = await file.readAsBytes();
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clearText = await _cipher.decrypt(box, secretKey: await _secretKey());
    final data = jsonDecode(utf8.decode(clearText)) as Map<String, dynamic>;
    await database.restoreData(data);
  }

  Future<SecretKey> _secretKey() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      encoded = base64UrlEncode(_randomBytes(32));
      await _storage.write(key: _keyName, value: encoded);
    }
    return SecretKey(base64Url.decode(encoded));
  }

  List<int> _randomBytes(int length) =>
      List.generate(length, (_) => Random.secure().nextInt(256));
}
