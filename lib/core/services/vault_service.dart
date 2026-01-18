import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'encryption_service.dart';

class VaultItem {
  final String id;
  final VaultItemType type;
  final String name;
  final DateTime createdAt;
  final String? thumbnailPath;

  VaultItem({
    required this.id,
    required this.type,
    required this.name,
    required this.createdAt,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'thumbnailPath': thumbnailPath,
  };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
    id: json['id'],
    type: VaultItemType.values[json['type']],
    name: json['name'],
    createdAt: DateTime.parse(json['createdAt']),
    thumbnailPath: json['thumbnailPath'],
  );
}

class Vault {
  final String id;
  final String passwordHash;
  List<VaultItem> items;

  Vault({
    required this.id,
    required this.passwordHash,
    List<VaultItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'passwordHash': passwordHash,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory Vault.fromJson(Map<String, dynamic> json) => Vault(
    id: json['id'],
    passwordHash: json['passwordHash'],
    items: (json['items'] as List).map((i) => VaultItem.fromJson(i)).toList(),
  );
}

class VaultService {
  static const _storage = FlutterSecureStorage();
  static const _vaultIndexKey = 'vault_index';
  static const _uuid = Uuid();

  static Future<Directory> _getVaultsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultsDir = Directory('${appDir.path}/vaults');
    if (!await vaultsDir.exists()) {
      await vaultsDir.create(recursive: true);
    }
    return vaultsDir;
  }

  static Future<Map<String, String>> _getVaultIndex() async {
    final indexData = await _storage.read(key: _vaultIndexKey);
    if (indexData == null) return {};
    return Map<String, String>.from(json.decode(indexData));
  }

  static Future<void> _saveVaultIndex(Map<String, String> index) async {
    await _storage.write(key: _vaultIndexKey, value: json.encode(index));
  }

  static Future<bool> hasAnyVault() async {
    final index = await _getVaultIndex();
    return index.isNotEmpty;
  }

  static Future<String> createVault(String password) async {
    final vaultId = _uuid.v4();
    final passwordHash = await EncryptionService.hashPassword(password);
    
    final index = await _getVaultIndex();
    index[passwordHash] = vaultId;
    await _saveVaultIndex(index);
    
    final vault = Vault(id: vaultId, passwordHash: passwordHash);
    await _saveVault(vault, password);
    
    final vaultsDir = await _getVaultsDirectory();
    final vaultAssetsDir = Directory('${vaultsDir.path}/$vaultId/assets');
    await vaultAssetsDir.create(recursive: true);
    
    return vaultId;
  }

  static Future<Vault?> unlockVault(String password) async {
    final passwordHash = await EncryptionService.hashPassword(password);
    final index = await _getVaultIndex();
    
    final vaultId = index[passwordHash];
    if (vaultId == null) return null;
    
    return await _loadVault(vaultId, password);
  }

  static Future<void> _saveVault(Vault vault, String password) async {
    final vaultsDir = await _getVaultsDirectory();
    final vaultFile = File('${vaultsDir.path}/${vault.id}/metadata.enc');
    
    await vaultFile.parent.create(recursive: true);
    
    final key = await EncryptionService.deriveKeyFromPassword(password);
    final encrypted = await EncryptionService.encryptData(
      json.encode(vault.toJson()),
      key,
    );
    
    await vaultFile.writeAsString(encrypted);
  }

  static Future<Vault?> _loadVault(String vaultId, String password) async {
    final vaultsDir = await _getVaultsDirectory();
    final vaultFile = File('${vaultsDir.path}/$vaultId/metadata.enc');
    
    if (!await vaultFile.exists()) return null;
    
    try {
      final encrypted = await vaultFile.readAsString();
      final key = await EncryptionService.deriveKeyFromPassword(password);
      final decrypted = await EncryptionService.decryptData(encrypted, key);
      return Vault.fromJson(json.decode(decrypted));
    } catch (e) {
      return null;
    }
  }

  static Future<String> addItem({
    required Vault vault,
    required String password,
    required VaultItemType type,
    required String name,
    required Uint8List data,
    Uint8List? thumbnail,
  }) async {
    final itemId = _uuid.v4();
    final vaultsDir = await _getVaultsDirectory();
    final key = await EncryptionService.deriveKeyFromPassword(password);
    
    final assetPath = '${vaultsDir.path}/${vault.id}/assets/$itemId.enc';
    final encryptedData = await EncryptionService.encryptBytes(data, key);
    await File(assetPath).writeAsBytes(encryptedData);
    
    String? thumbnailPath;
    if (thumbnail != null) {
      thumbnailPath = '${vaultsDir.path}/${vault.id}/assets/${itemId}_thumb.enc';
      final encryptedThumb = await EncryptionService.encryptBytes(thumbnail, key);
      await File(thumbnailPath).writeAsBytes(encryptedThumb);
    }
    
    final item = VaultItem(
      id: itemId,
      type: type,
      name: name,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
    
    vault.items.add(item);
    await _saveVault(vault, password);
    
    return itemId;
  }

  static Future<Uint8List?> getItemData(Vault vault, String password, String itemId) async {
    final vaultsDir = await _getVaultsDirectory();
    final assetPath = '${vaultsDir.path}/${vault.id}/assets/$itemId.enc';
    final file = File(assetPath);
    
    if (!await file.exists()) return null;
    
    try {
      final key = await EncryptionService.deriveKeyFromPassword(password);
      final encryptedData = await file.readAsBytes();
      return await EncryptionService.decryptBytes(encryptedData, key);
    } catch (e) {
      return null;
    }
  }

  static Future<Uint8List?> getThumbnail(Vault vault, String password, VaultItem item) async {
    if (item.thumbnailPath == null) return null;
    
    final file = File(item.thumbnailPath!);
    if (!await file.exists()) return null;
    
    try {
      final key = await EncryptionService.deriveKeyFromPassword(password);
      final encryptedData = await file.readAsBytes();
      return await EncryptionService.decryptBytes(encryptedData, key);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteItem(Vault vault, String password, String itemId) async {
    final vaultsDir = await _getVaultsDirectory();
    
    final assetFile = File('${vaultsDir.path}/${vault.id}/assets/$itemId.enc');
    if (await assetFile.exists()) await assetFile.delete();
    
    final thumbFile = File('${vaultsDir.path}/${vault.id}/assets/${itemId}_thumb.enc');
    if (await thumbFile.exists()) await thumbFile.delete();
    
    vault.items.removeWhere((item) => item.id == itemId);
    await _saveVault(vault, password);
  }
}
