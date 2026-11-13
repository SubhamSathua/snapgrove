import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/services/settings_service.dart';
import 'package:snapgrove/services/storage_service.dart';

class MockStorageService implements StorageService {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<dynamic> read(String store, String key) async {
    return _data[store]?[key];
  }

  @override
  Future<void> write(String store, String key, dynamic value) async {
    _data.putIfAbsent(store, () => {})[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PC Bin Authentication & SettingsService', () {
    late MockStorageService mockStorage;
    late SettingsService settingsService;

    setUp(() async {
      mockStorage = MockStorageService();
      settingsService = SettingsService(mockStorage);
      await settingsService.init();
    });

    test('Bin password is not set by default', () {
      expect(settingsService.isBinPasswordSet, isFalse);
      expect(settingsService.binPasswordHint, isNull);
      expect(settingsService.binFirstMoveDone, isFalse);
    });

    test('Setting and verifying password works accurately', () async {
      await settingsService.setBinPassword('Secret123', hint: 'My secret');

      expect(settingsService.isBinPasswordSet, isTrue);
      expect(settingsService.binPasswordHint, equals('My secret'));
      expect(settingsService.verifyBinPassword('Secret123'), isTrue);
      expect(settingsService.verifyBinPassword('WrongPassword'), isFalse);
    });

    test('Clearing password resets isBinPasswordSet and hint', () async {
      await settingsService.setBinPassword('Pass456', hint: 'A hint');
      expect(settingsService.isBinPasswordSet, isTrue);

      await settingsService.setBinPassword(null);
      expect(settingsService.isBinPasswordSet, isFalse);
      expect(settingsService.binPasswordHint, isNull);
      expect(settingsService.verifyBinPassword('Pass456'), isFalse);
    });

    test('Marking first move done persists state', () async {
      expect(settingsService.binFirstMoveDone, isFalse);
      await settingsService.markBinFirstMoveDone();
      expect(settingsService.binFirstMoveDone, isTrue);

      // Verify persistence on new instance
      final newService = SettingsService(mockStorage);
      await newService.init();
      expect(newService.binFirstMoveDone, isTrue);
    });

    test('Bin auth toggle persists accurately', () async {
      await settingsService.setBinAuthEnabled(true);
      expect(settingsService.binAuthEnabled, isTrue);

      await settingsService.setBinAuthEnabled(false);
      expect(settingsService.binAuthEnabled, isFalse);
    });
  });
}
