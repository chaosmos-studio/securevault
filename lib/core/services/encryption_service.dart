import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _saltKey = 'encryption_salt';

  static Future<String> _getOrCreateSalt() async {
    String? salt = await _storage.read(key: _saltKey);
    if (salt == null) {
      final saltBytes = encrypt.Key.fromSecureRandom(16);
      salt = saltBytes.base64;
      await _storage.write(key: _saltKey, value: salt);
    }
    return salt;
  }

  /// The salt every vault on this phone is keyed with, made on first use.
  static Future<String> deviceSalt() => _getOrCreateSalt();

  static Future<String> deriveKeyFromPassword(String password) async {
    return deriveKeyWithSalt(password, await _getOrCreateSalt());
  }

  /// The vault key for [password] under [salt], as made on the phone that
  /// owns that salt. Backups carry their phone's salt to open on another.
  static String deriveKeyWithSalt(String password, String salt) {
    final saltBytes = base64.decode(salt);
    final passwordBytes = utf8.encode(password);

    var key = Uint8List.fromList([...passwordBytes, ...saltBytes]);
    for (int i = 0; i < 10000; i++) {
      key = Uint8List.fromList(sha256.convert(key).bytes);
    }

    return base64.encode(key.sublist(0, 32));
  }

  static Future<String> hashPassword(String password) async {
    final salt = await _getOrCreateSalt();
    final combined = '$password$salt';
    final bytes = utf8.encode(combined);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  static Future<String> encryptData(String plainText, String keyBase64) async {
    final key = encrypt.Key.fromBase64(keyBase64);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<String> decryptData(String encryptedData, String keyBase64) async {
    final parts = encryptedData.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted data format');
    
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = encrypt.Key.fromBase64(keyBase64);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    
    return encrypter.decrypt(encrypted, iv: iv);
  }

  static Future<Uint8List> encryptBytes(Uint8List data, String keyBase64) async {
    final key = encrypt.Key.fromBase64(keyBase64);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    
    final paddedData = _padData(data);
    final encrypted = encrypter.encryptBytes(paddedData, iv: iv);
    
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  static Future<Uint8List> decryptBytes(Uint8List encryptedData, String keyBase64) async {
    final iv = encrypt.IV(encryptedData.sublist(0, 16));
    final encrypted = encrypt.Encrypted(encryptedData.sublist(16));
    final key = encrypt.Key.fromBase64(keyBase64);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return _unpadData(Uint8List.fromList(decrypted));
  }

  static Uint8List _padData(Uint8List data) {
    final blockSize = 16;
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength);
    padded.setRange(0, data.length, data);
    for (int i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }

  static Uint8List _unpadData(Uint8List data) {
    final padLength = data.last;
    if (padLength > 16 || padLength < 1) return data;
    return data.sublist(0, data.length - padLength);
  }
}
