import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:at_persistence_secondary_server/src/keystore/hive_base.dart';
import 'package:at_persistence_secondary_server/src/notification/at_notification.dart';
import 'package:at_persistence_secondary_server/src/notification/at_notification_callback.dart';
import 'package:at_utf7/at_utf7.dart';
import 'package:at_utils/at_utils.dart';
import 'package:cron/cron.dart';
import 'package:hive/hive.dart';

/// Class to initialize, put and get entries into [AtNotificationKeystore]
class AtNotificationKeystore
    with HiveBase<AtNotification?>
    implements SecondaryKeyStore {
  static final AtNotificationKeystore _singleton =
      AtNotificationKeystore._internal();

  AtNotificationKeystore._internal();
  late String currentAtSign;
  late String _boxName;
  factory AtNotificationKeystore.getInstance() {
    return _singleton;
  }

  final _logger = AtSignLogger('AtNotificationKeystore');

  bool _register = false;

  @override
  Future<void> initialize() async {
    _boxName = 'notifications_' + AtUtils.getShaForAtSign(currentAtSign);
    if (!_register) {
      Hive.registerAdapter(AtNotificationAdapter());
      Hive.registerAdapter(OperationTypeAdapter());
      Hive.registerAdapter(NotificationTypeAdapter());
      Hive.registerAdapter(NotificationStatusAdapter());
      Hive.registerAdapter(NotificationPriorityAdapter());
      Hive.registerAdapter(MessageTypeAdapter());
      if (!Hive.isAdapterRegistered(AtMetaDataAdapter().typeId)) {
        Hive.registerAdapter(AtMetaDataAdapter());
      }
      _register = true;
    }
    await super.openBox(_boxName);
  }

  bool isEmpty() {
    return _getBox().isEmpty;
  }

  /// Returns a list of atNotification sorted on notification date time.
  Future<List> getValues() async {
    var returnList = [];
    var notificationLogMap = await _toMap();
    returnList = notificationLogMap!.values.toList();
    returnList.sort(
        (k1, k2) => k1.notificationDateTime.compareTo(k2.notificationDateTime));
    return returnList;
  }

  @override
  Future<AtNotification?> get(key) async {
    return await getValue(key);
  }

  @override
  Future put(key, value,
      {int? time_to_live,
      int? time_to_born,
      int? time_to_refresh,
      bool? isCascade,
      bool? isBinary,
      bool? isEncrypted,
      String? dataSignature}) async {
    await _getBox().put(key, value);
    AtNotificationCallback.getInstance().invokeCallbacks(value);
  }

  @override
  Future create(key, value,
      {int? time_to_live,
      int? time_to_born,
      int? time_to_refresh,
      bool? isCascade,
      bool? isBinary,
      bool? isEncrypted,
      String? dataSignature}) async {
    // TODO: implement deleteExpiredKeys
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteExpiredKeys() async {
    var result = true;
    try {
      var expiredKeys = await getExpiredKeys();
      if (expiredKeys.isNotEmpty) {
        expiredKeys.forEach((element) {
          remove(element);
        });
        result = true;
      }
    } on Exception catch (e) {
      result = false;
      _logger.severe('Exception in deleteExpired keys: ${e.toString()}');
      throw DataStoreException(
          'exception in deleteExpiredKeys: ${e.toString()}');
    } on HiveError catch (error) {
      _logger.severe('HiveKeystore get error: $error');
      throw DataStoreException(error.message);
    }
    return result;
  }

  @override
  Future<List<dynamic>> getExpiredKeys() async {
    var expiredKeys = <String>[];
    try {
      var now = DateTime.now().toUtc();
      var keys = _getBox().keys;
      var expired = [];
      await Future.forEach(keys, (key) async {
        var value = await get(key);
        if (value != null &&
            value.expiresAt != null &&
            value.expiresAt!.isBefore(now)) {
          expired.add(key);
        }
      });
      expired.forEach((key) => expiredKeys.add(Utf7.encode(key)));
    } on Exception catch (e) {
      _logger.severe('exception in hive get expired keys:${e.toString()}');
      throw DataStoreException('exception in getExpiredKeys: ${e.toString()}');
    } on HiveError catch (error) {
      _logger.severe('HiveKeystore get error: $error');
      throw DataStoreException(error.message);
    }
    return expiredKeys;
  }

  @override
  List getKeys({String? regex}) {
    var keys = <String>[];
    var encodedKeys;

    if (_getBox().keys.isEmpty) {
      return [];
    }
    // If regular expression is not null or not empty, filter keys on regular expression.
    if (regex != null && regex.isNotEmpty) {
      encodedKeys = _getBox().keys.where(
          (element) => Utf7.decode(element).toString().contains(RegExp(regex)));
    } else {
      encodedKeys = _getBox().keys.toList();
    }
    encodedKeys?.forEach((key) => keys.add(Utf7.decode(key)));
    return encodedKeys;
  }

  @override
  Future getMeta(key) {
    // TODO: implement getMeta
    throw UnimplementedError();
  }

  @override
  Future putAll(key, value, metadata) {
    // TODO: implement putAll
    throw UnimplementedError();
  }

  @override
  Future putMeta(key, metadata) {
    // TODO: implement putMeta
    throw UnimplementedError();
  }

  @override
  Future remove(key) async {
    assert(key != null);
    await _getBox().delete(key);
  }

  void scheduleKeyExpireTask(int runFrequencyMins) {
    _logger.finest('scheduleKeyExpireTask starting cron job.');
    var cron = Cron();
    cron.schedule(Schedule.parse('*/$runFrequencyMins * * * *'), () async {
      var hiveKeyStore = SecondaryPersistenceStoreFactory.getInstance()
          .getSecondaryPersistenceStore(currentAtSign)!
          .getSecondaryKeyStore()!;
      await hiveKeyStore.deleteExpiredKeys();
    });
  }

  Future<Map>? _toMap() async {
    var notificationLogMap = {};
    var keys = _getBox().keys;
    var value;
    await Future.forEach(keys, (key) async {
      value = await getValue(key);
      notificationLogMap.putIfAbsent(key, () => value);
    });
    return notificationLogMap;
  }

  BoxBase _getBox() {
    return super.getBox();
  }
}
