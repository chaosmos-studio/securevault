import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/providers/app_state.dart';
import 'package:securevault/core/services/vault_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.securevault/disguise');
  final calls = <MethodCall>[];

  setUp(() async {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'getCurrentDisguise' ? 'calculator' : true;
    });
    await useFreshDevice();
    await VaultService.createVault('482915', name: 'Mine', isMaster: true);
  });

  Future<AppState> unlocked({int autoLock = 0}) async {
    await setPrefs({...setUpOn(DisguiseType.calculator), 'auto_lock_seconds': autoLock});
    final state = AppState();
    await state.initialize();
    expect(await state.unlock('482915'), isTrue);
    return state;
  }

  test('locks the moment the app is left when set to lock right away', () async {
    final state = await unlocked();
    await state.onLeft();
    expect(state.isUnlocked, isFalse);
  });

  test('stays open for a short trip away when set to a minute', () async {
    final state = await unlocked(autoLock: 60);
    await state.onLeft();
    state.onReturned();
    expect(state.isUnlocked, isTrue);
  });

  test('stays open while a picker or share sheet is in front', () async {
    final state = await unlocked();
    await state.whileOutside(() async {
      await state.onLeft();
      state.onReturned();
    });
    expect(state.isUnlocked, isTrue);
  });

  test('changes the launcher icon only once the vault is locked and left', () async {
    final state = await unlocked(autoLock: 60);
    await state.changeDisguise(DisguiseType.notes);

    await state.onLeft();
    expect(calls.where((c) => c.method == 'setDisguise'), isEmpty);

    state.lock();
    await state.onLeft();
    final set = calls.where((c) => c.method == 'setDisguise').toList();
    expect(set, hasLength(1));
    expect(set.single.arguments, {'disguiseId': 'notes'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_icon'), isNull);
  });
}
