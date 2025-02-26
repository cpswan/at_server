import 'dart:async';
import 'dart:io';

import 'package:at_commons/at_commons.dart';
import 'package:at_secondary/src/conf/config_util.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

class AtSecondaryConfig {
  // Config
  @visibleForTesting
  static YamlMap? configYamlMap = ConfigUtil.getYaml();
  static final Map<ModifiableConfigs, ModifiableConfigurationEntry>
      _streamListeners = {};

  //Certs
  static const bool _useTLS = true;
  static const bool _clientCertificateRequired = true;
  static const bool _testingMode = false;

  //Certificate Paths
  static const String _certificateChainLocation = 'certs/fullchain.pem';
  static const String _privateKeyLocation = 'certs/privkey.pem';
  static const String _trustedCertificateLocation = '/etc/cacert/cacert.pem';

  //Secondary Storage
  static const String _storagePath = 'storage/hive';
  static const String _commitLogPath = 'storage/commitLog';
  static const String _accessLogPath = 'storage/accessLog';
  static const String _notificationStoragePath = 'storage/notificationLog.v1';
  static const int _expiringRunFreqMins = 10;

  //Commit Log
  static const int _commitLogCompactionFrequencyMins = 18;
  static const int _commitLogCompactionPercentage = 20;
  static const int _commitLogExpiryInDays = 15;
  static const int _commitLogSizeInKB = 2;

  //Access Log
  static const int _accessLogCompactionFrequencyMins = 15;
  static const int _accessLogCompactionPercentage = 30;
  static const int _accessLogExpiryInDays = 15;
  static const int _accessLogSizeInKB = 2;

  //Notification
  static const bool _autoNotify = true;

  // The maximum number of retries for a notification.
  static const int _maxNotificationRetries = 30;

  // The quarantine duration of an atsign. Notifications will be retried max_retries times, every quarantineDuration seconds approximately.
  static const int _notificationQuarantineDuration = 10;

  // The notifications queue will be processed every jobFrequency seconds. However, the notifications queue will always be processed
  // *immediately* when a new notification is queued. When that happens, the queue processing will not run again until jobFrequency
  // seconds have passed since the last queue-processing run completed.
  static const int _notificationJobFrequency = 11;

  // The time interval(in seconds) to notify latest commitID to monitor connections
  // To disable to the feature, set to -1.
  static const int _statsNotificationJobTimeInterval = 15;

  // defines the time after which a notification expires in units of minutes. Notifications expire after 1440 minutes or 24 hours by default.
  static const int _notificationExpiresAfterMins = 1440;

  static const int _notificationKeyStoreCompactionFrequencyMins = 5;
  static const int _notificationKeyStoreCompactionPercentage = 30;
  static const int _notificationKeyStoreExpiryInDays = 1;
  static const int _notificationKeyStoreSizeInKB = -1;

  //Refresh Job
  static const int _runRefreshJobHour = 3;

  //Connection
  static const int _inboundMaxLimit = 200;
  static const int _outboundMaxLimit = 200;
  static const int _unauthenticatedInboundIdleTimeMillis =
      10 * 60 * 1000; // 10 minutes
  static const int _authenticatedInboundIdleTimeMillis =
      30 * 24 * 60 * 60 * 1000; // 30 days
  static const int _outboundIdleTimeMillis = 600000;

  //Lookup
  static const int _lookupDepthOfResolution = 3;

  //Stats
  static const int _statsTopKeys = 5;
  static const int _statsTopVisits = 5;

  //log level configuration. Value should match the name of one of dart logging package's Level.LEVELS
  static const String _defaultLogLevel = 'INFO';

  //root server configurations
  static const String _rootServerUrl = 'root.atsign.org';
  static const int _rootServerPort = 64;

  //force restart
  static const bool _isForceRestart = false;

  //Sync Configurations
  static const int _syncBufferSize = 5242880;
  static const int _syncPageLimit = 100;

  // Malformed Keys
  static final List<String> _malformedKeys = [];
  static const bool _shouldRemoveMalformedKeys = true;

  // Protected Keys
  // <@atsign> is a placeholder. To be replaced with actual atsign during runtime
  static final Set<String> _protectedKeys = {
    'signing_publickey<@atsign>',
    'signing_privatekey<@atsign>',
    'publickey<@atsign>',
    'at_pkam_publickey'
  };

  //version
  static final String? _secondaryServerVersion =
      (ConfigUtil.getPubspecConfig() != null &&
              ConfigUtil.getPubspecConfig()!['version'] != null)
          ? ConfigUtil.getPubspecConfig()!['version']
          : null;

  static final Map<String, String> _envVars = Platform.environment;

  static String? get secondaryServerVersion => _secondaryServerVersion;

  // Enrollment Configurations
  static const int _enrollmentExpiryInHours = 48;
  static int _maxEnrollRequestsAllowed = 5;

  static final int _timeFrameInHours = 1;

  // For easy of testing, duration in hours is long. Hence introduced "timeFrameInMills"
  // to have a shorter time frame. This is defaulted to "_timeFrameInHours", can be modified
  // via the config verb
  static int _timeFrameInMills =
      Duration(hours: _timeFrameInHours).inMilliseconds;

  static int get enrollmentExpiryInHours => _enrollmentExpiryInHours;

  // TODO: Medium priority: Most (all?) getters in this class return a default value but the signatures currently
  //  allow for nulls. Should fix this as has been done for logLevel
  // TODO: Low priority: Lots of very similar boilerplate code here. Not necessarily bad in this particular case, but
  //  could be terser as per the logLevel getter
  static String get logLevel {
    return _getStringEnvVar('logLevel') ??
        getStringValueFromYaml(['log', 'level']) ??
        _defaultLogLevel;
  }

  /// Used to be called "useSSL" and check env and config for "useSSL"
  /// Now we are checking env and config for "useTLS", and for backwards
  /// compatibility reasons we will fallback check env and config for "useSSL"
  static bool? get useTLS {
    var result = _getBoolEnvVar('useTLS');
    if (result != null) {
      return result;
    }

    result = _getBoolEnvVar('useSSL');
    if (result != null) {
      return result;
    }

    try {
      return getConfigFromYaml(['security', 'useTLS']);
    } on ElementNotFoundException {
      try {
        return getConfigFromYaml(['security', 'useSSL']);
      } on ElementNotFoundException {
        return _useTLS;
      }
    }
  }

  static bool get testingMode {
    var result = _getBoolEnvVar('testingMode');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['testing', 'testingMode']);
    } on ElementNotFoundException {
      return _testingMode;
    }
  }

  static bool? get clientCertificateRequired {
    var result = _getBoolEnvVar('clientCertificateRequired');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['security', 'clientCertificateRequired']);
    } on ElementNotFoundException {
      return _clientCertificateRequired;
    }
  }

  static int? get runRefreshJobHour {
    var result = _getIntEnvVar('runRefreshJobHour');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['refreshJob', 'runJobHour']);
    } on ElementNotFoundException {
      return _runRefreshJobHour;
    }
  }

  static int? get accessLogSizeInKB {
    var result = _getIntEnvVar('accessLogSizeInKB');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['access_log_compaction', 'sizeInKB']);
    } on ElementNotFoundException {
      return _accessLogSizeInKB;
    }
  }

  static int? get accessLogExpiryInDays {
    var result = _getIntEnvVar('accessLogExpiryInDays');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['access_log_compaction', 'expiryInDays']);
    } on ElementNotFoundException {
      return _accessLogExpiryInDays;
    }
  }

  static int? get accessLogCompactionPercentage {
    var result = _getIntEnvVar('accessLogCompactionPercentage');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['access_log_compaction', 'compactionPercentage']);
    } on ElementNotFoundException {
      return _accessLogCompactionPercentage;
    }
  }

  static int? get accessLogCompactionFrequencyMins {
    var result = _getIntEnvVar('accessLogCompactionFrequencyMins');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['access_log_compaction', 'compactionFrequencyMins']);
    } on ElementNotFoundException {
      return _accessLogCompactionFrequencyMins;
    }
  }

  static int? get commitLogSizeInKB {
    var result = _getIntEnvVar('commitLogSizeInKB');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['commit_log_compaction', 'sizeInKB']);
    } on ElementNotFoundException {
      return _commitLogSizeInKB;
    }
  }

  static int? get commitLogExpiryInDays {
    var result = _getIntEnvVar('commitLogExpiryInDays');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['commit_log_compaction', 'expiryInDays']);
    } on ElementNotFoundException {
      return _commitLogExpiryInDays;
    }
  }

  static int? get commitLogCompactionPercentage {
    var result = _getIntEnvVar('commitLogCompactionPercentage');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['commit_log_compaction', 'compactionPercentage']);
    } on ElementNotFoundException {
      return _commitLogCompactionPercentage;
    }
  }

  static int? get commitLogCompactionFrequencyMins {
    var result = _getIntEnvVar('commitLogCompactionFrequencyMins');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['commit_log_compaction', 'compactionFrequencyMins']);
    } on ElementNotFoundException {
      return _commitLogCompactionFrequencyMins;
    }
  }

  static int? get expiringRunFreqMins {
    var result = _getIntEnvVar('expiringRunFreqMins');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['hive', 'expiringRunFrequencyMins']);
    } on ElementNotFoundException {
      return _expiringRunFreqMins;
    }
  }

  static int? get notificationKeyStoreExpiryInDays {
    var result = _getIntEnvVar('notificationKeyStoreExpiryInDays');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['notification_keystore_compaction', 'expiryInDays']);
    } on ElementNotFoundException {
      return _notificationKeyStoreExpiryInDays;
    }
  }

  static int? get notificationKeyStoreCompactionPercentage {
    var result = _getIntEnvVar('notificationKeyStoreCompactionPercentage');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['notification_keystore_compaction', 'compactionPercentage']);
    } on ElementNotFoundException {
      return _notificationKeyStoreCompactionPercentage;
    }
  }

  static int? get notificationKeyStoreSizeInKB {
    var result = _getIntEnvVar('notificationKeyStoreInKB');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['notification_keystore_compaction', 'sizeInKB']);
    } on ElementNotFoundException {
      return _notificationKeyStoreSizeInKB;
    }
  }

  static int? get notificationKeyStoreCompactionFrequencyMins {
    var result = _getIntEnvVar('notificationKeyStoreCompactionFrequencyMins');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['notification_keystore_compaction', 'compactionFrequencyMins']);
    } on ElementNotFoundException {
      return _notificationKeyStoreCompactionFrequencyMins;
    }
  }

  static String? get notificationStoragePath {
    if (_envVars.containsKey('notificationStoragePath')) {
      return _envVars['notificationStoragePath'];
    }
    try {
      return getConfigFromYaml(['hive', 'notificationStoragePath']);
    } on ElementNotFoundException {
      return _notificationStoragePath;
    }
  }

  static String? get accessLogPath {
    if (_envVars.containsKey('accessLogPath')) {
      return _envVars['accessLogPath'];
    }
    try {
      return getConfigFromYaml(['hive', 'accessLogPath']);
    } on ElementNotFoundException {
      return _accessLogPath;
    }
  }

  static String? get commitLogPath {
    if (_envVars.containsKey('commitLogPath')) {
      return _envVars['commitLogPath'];
    }
    try {
      return getConfigFromYaml(['hive', 'commitLogPath']);
    } on ElementNotFoundException {
      return _commitLogPath;
    }
  }

  static String? get storagePath {
    if (_envVars.containsKey('secondaryStoragePath')) {
      return _envVars['secondaryStoragePath'];
    }
    try {
      return getConfigFromYaml(['hive', 'storagePath']);
    } on ElementNotFoundException {
      return _storagePath;
    }
  }

  // ignore: non_constant_identifier_names
  static int get outbound_idletime_millis {
    var result = _getIntEnvVar('outbound_idletime_millis');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['connection', 'outbound_idle_time_millis']);
    } on ElementNotFoundException {
      return _outboundIdleTimeMillis;
    }
  }

  // ignore: non_constant_identifier_names
  static int get inbound_idletime_millis {
    var result = _getIntEnvVar('inbound_idletime_millis');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['connection', 'inbound_idle_time_millis']);
    } on ElementNotFoundException {
      return _unauthenticatedInboundIdleTimeMillis;
    }
  }

  // ignore: non_constant_identifier_names
  static int get authenticated_inbound_idletime_millis {
    var result = _getIntEnvVar('authenticated_inbound_idletime_millis');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['connection', 'authenticated_inbound_idle_time_millis']);
    } on ElementNotFoundException {
      return _authenticatedInboundIdleTimeMillis;
    }
  }

  // ignore: non_constant_identifier_names
  static int get outbound_max_limit {
    var result = _getIntEnvVar('outbound_max_limit');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['connection', 'outbound_max_limit']);
    } on ElementNotFoundException {
      return _outboundMaxLimit;
    }
  }

  // ignore: non_constant_identifier_names
  static int get inbound_max_limit {
    var result = _getIntEnvVar('inbound_max_limit');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['connection', 'inbound_max_limit']);
    } on ElementNotFoundException {
      return _inboundMaxLimit;
    }
  }

  // ignore: non_constant_identifier_names
  static int? get lookup_depth_of_resolution {
    var result = _getIntEnvVar('lookup_depth_of_resolution');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['lookup', 'depth_of_resolution']);
    } on ElementNotFoundException {
      return _lookupDepthOfResolution;
    }
  }

  // ignore: non_constant_identifier_names
  static int? get stats_top_visits {
    var result = _getIntEnvVar('statsTopVisits');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['stats', 'top_visits']);
    } on ElementNotFoundException {
      return _statsTopVisits;
    }
  }

  // ignore: non_constant_identifier_names
  static int? get stats_top_keys {
    var result = _getIntEnvVar('statsTopKeys');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['stats', 'top_keys']);
    } on ElementNotFoundException {
      return _statsTopKeys;
    }
  }

  static bool get autoNotify {
    var result = _getBoolEnvVar('autoNotify');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['notification', 'autoNotify']);
    } on ElementNotFoundException {
      return _autoNotify;
    }
  }

  static String? get trustedCertificateLocation {
    if (_envVars.containsKey('securityTrustedCertificateLocation')) {
      return _envVars['securityTrustedCertificateLocation'];
    }
    try {
      return getConfigFromYaml(['security', 'trustedCertificateLocation']);
    } on ElementNotFoundException {
      return _trustedCertificateLocation;
    }
  }

  static String? get privateKeyLocation {
    if (_envVars.containsKey('securityPrivateKeyLocation')) {
      return _envVars['securityPrivateKeyLocation'];
    }
    try {
      return getConfigFromYaml(['security', 'privateKeyLocation']);
    } on ElementNotFoundException {
      return _privateKeyLocation;
    }
  }

  static String? get certificateChainLocation {
    if (_envVars.containsKey('securityCertificateChainLocation')) {
      return _envVars['securityCertificateChainLocation'];
    }
    try {
      return getConfigFromYaml(['security', 'certificateChainLocation']);
    } on ElementNotFoundException {
      return _certificateChainLocation;
    }
  }

  static int get rootServerPort {
    var result = _getIntEnvVar('rootServerPort');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['root_server', 'port']);
    } on ElementNotFoundException {
      return _rootServerPort;
    }
  }

  static String get rootServerUrl {
    if (_envVars.containsKey('rootServerUrl')) {
      return _envVars['rootServerUrl']!;
    }
    try {
      return getConfigFromYaml(['root_server', 'url']);
    } on ElementNotFoundException {
      return _rootServerUrl;
    }
  }

  static bool? get isForceRestart {
    var result = _getBoolEnvVar('forceRestart');
    if (result != null) {
      return _getBoolEnvVar('forceRestart');
    }
    try {
      return getConfigFromYaml(['certificate_expiry', 'force_restart']);
    } on ElementNotFoundException {
      return _isForceRestart;
    }
  }

  static int? get maxNotificationRetries {
    var result = _getIntEnvVar('maxNotificationRetries');
    if (result != null) {
      return _getIntEnvVar('maxNotificationRetries');
    }
    try {
      return getConfigFromYaml(['notification', 'max_retries']);
    } on ElementNotFoundException {
      return _maxNotificationRetries;
    }
  }

  static int? get notificationQuarantineDuration {
    var result = _getIntEnvVar('notificationQuarantineDuration');
    if (result != null) {
      return _getIntEnvVar('notificationQuarantineDuration');
    }
    try {
      return getConfigFromYaml(['notification', 'quarantineDuration']);
    } on ElementNotFoundException {
      return _notificationQuarantineDuration;
    }
  }

  static int get notificationJobFrequency {
    var result = _getIntEnvVar('notificationJobFrequency');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['notification', 'jobFrequency']);
    } on ElementNotFoundException {
      return _notificationJobFrequency;
    }
  }

  static int get statsNotificationJobTimeInterval {
    var result = _getIntEnvVar('statsNotificationJobTimeInterval');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(
          ['notification', 'statsNotificationJobTimeInterval']);
    } on ElementNotFoundException {
      return _statsNotificationJobTimeInterval;
    }
  }

  static int get notificationExpiryInMins {
    var result = _getIntEnvVar('notificationExpiryInMins');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['notification', 'expiryInMins']);
    } on ElementNotFoundException {
      return _notificationExpiresAfterMins;
    }
  }

  static int get syncBufferSize {
    var result = _getIntEnvVar('syncBufferSize');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['sync', 'bufferSize']);
    } on ElementNotFoundException {
      return _syncBufferSize;
    }
  }

  static int get syncPageLimit {
    var result = _getIntEnvVar('syncPageLimit');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['sync', 'pageLimit']);
    } on ElementNotFoundException {
      return _syncPageLimit;
    }
  }

  static List<String> get malformedKeysList {
    var result = _getStringEnvVar('hiveMalformedKeys');
    if (result != null) {
      return result.split(',');
    }
    try {
      return getConfigFromYaml(['hive', 'malformedKeys']).split(',');
    } on ElementNotFoundException {
      return _malformedKeys;
    }
  }

  static bool get shouldRemoveMalformedKeys {
    var result = _getBoolEnvVar('shouldRemoveMalformedKeys');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['hive', 'shouldRemoveMalformedKeys']);
    } on ElementNotFoundException {
      return _shouldRemoveMalformedKeys;
    }
  }

  static Set<String> get protectedKeys {
    try {
      YamlList keys = getConfigFromYaml(['hive', 'protectedKeys']);
      Set<String> protectedKeysFromConfig = {};
      for (var key in keys) {
        protectedKeysFromConfig.add(key);
      }
      protectedKeysFromConfig.addAll(_protectedKeys);
      return protectedKeysFromConfig;
    } on Exception {
      return _protectedKeys;
    }
  }

  static int get maxEnrollRequestsAllowed {
    // For easy of testing purpose, we need to reduce the number of requests.
    // So, in testing mode, enable to modify the "maxEnrollRequestsAllowed"
    // can be set via the config verb
    // Defaults to value in config.yaml
    if (testingMode) {
      return _maxEnrollRequestsAllowed;
    }
    var result = _getIntEnvVar('maxEnrollRequestsAllowed');
    if (result != null) {
      return result;
    }
    try {
      return getConfigFromYaml(['enrollment', 'maxRequestsPerTimeFrame']);
    } on ElementNotFoundException {
      return _maxEnrollRequestsAllowed;
    }
  }

  static set maxEnrollRequestsAllowed(int value) {
    _maxEnrollRequestsAllowed = value;
  }

  static int get timeFrameInMills {
    // For easy of testing purpose, we need to reduce the time frame.
    // So, in testing mode, enable to modify the "timeFrameInMills"
    // can be set via the config verb
    // Defaults to value in config.yaml
    if (testingMode) {
      return _timeFrameInMills;
    }
    var result = _getIntEnvVar('enrollTimeFrameInHours');
    if (result != null) {
      return Duration(hours: result).inMilliseconds;
    }
    try {
      return Duration(
              hours: getConfigFromYaml(['enrollment', 'timeFrameInHours']))
          .inMilliseconds;
    } on ElementNotFoundException {
      return Duration(hours: _timeFrameInHours).inMilliseconds;
    }
  }

  static set timeFrameInMills(int timeWindowInMills) {
    _timeFrameInMills = timeWindowInMills;
  }

  //implementation for config:set. This method returns a data stream which subscribers listen to for updates
  static Stream<dynamic>? subscribe(ModifiableConfigs configName) {
    if (testingMode) {
      if (!_streamListeners.containsKey(configName)) {
        _streamListeners[configName] = ModifiableConfigurationEntry()
          ..streamController = StreamController<dynamic>.broadcast()
          ..defaultValue = AtSecondaryConfig.getDefaultValue(configName)!;
      }
      return _streamListeners[configName]!.streamController.stream;
    }
    return null;
  }

  //implementation for config:set. Broadcasts new config value to all the listeners/subscribers
  static void broadcastConfigChange(
      ModifiableConfigs configName, var newConfigValue,
      {bool isReset = false}) {
    if (testingMode) {
      //if an entry for the config does not exist new entry is created
      if (!_streamListeners.containsKey(configName)) {
        _streamListeners[configName] = ModifiableConfigurationEntry()
          ..streamController = StreamController<dynamic>.broadcast()
          ..defaultValue = AtSecondaryConfig.getDefaultValue(configName)!;
      }
      //in case of reset, the default value of that config is broadcast
      if (isReset) {
        _streamListeners[configName]
            ?.streamController
            .add(_streamListeners[configName]!.defaultValue);
        _streamListeners[configName]?.currentValue =
            _streamListeners[configName]!.defaultValue;
        // this else case broadcast new config value
      } else {
        _streamListeners[configName]?.streamController.add(newConfigValue!);
        _streamListeners[configName]?.currentValue = newConfigValue;
      }
    }
  }

  //implementation for config:Set. Returns current value of modifiable configs
  static dynamic getLatestConfigValue(ModifiableConfigs configName) {
    if (_streamListeners.containsKey(configName)) {
      return _streamListeners[configName]?.currentValue ??
          _streamListeners[configName]?.defaultValue;
    }
    return null;
  }

  //implementation for config:set
  //switch case that returns default value of modifiable configs
  static dynamic getDefaultValue(ModifiableConfigs configName) {
    switch (configName) {
      case ModifiableConfigs.accessLogCompactionFrequencyMins:
        return accessLogCompactionFrequencyMins;
      case ModifiableConfigs.commitLogCompactionFrequencyMins:
        return commitLogCompactionFrequencyMins;
      case ModifiableConfigs.notificationKeyStoreCompactionFrequencyMins:
        return notificationKeyStoreCompactionFrequencyMins;
      case ModifiableConfigs.inboundMaxLimit:
        return inbound_max_limit;
      case ModifiableConfigs.autoNotify:
        return autoNotify;
      case ModifiableConfigs.maxNotificationRetries:
        return maxNotificationRetries;
      case ModifiableConfigs.checkCertificateReload:
        return false;
      case ModifiableConfigs.shouldReloadCertificates:
        return false;
      case ModifiableConfigs.doCacheRefreshNow:
        return false;
      case ModifiableConfigs.maxRequestsPerTimeFrame:
        return maxEnrollRequestsAllowed;
      case ModifiableConfigs.timeFrameInMills:
        return Duration(hours: _timeFrameInHours).inMilliseconds;
    }
  }

  static int? _getIntEnvVar(String envVar) {
    if (_envVars.containsKey(envVar)) {
      return int.parse(_envVars[envVar]!);
    }
    return null;
  }

  static bool? _getBoolEnvVar(String envVar) {
    if (_envVars.containsKey(envVar)) {
      return (_envVars[envVar]!.toLowerCase() == 'true') ? true : false;
    }
    return null;
  }

  static String? _getStringEnvVar(String envVar) {
    if (_envVars.containsKey(envVar)) {
      return _envVars[envVar];
    }
    return null;
  }
}

dynamic getConfigFromYaml(List<String> args) {
  var yamlMap = AtSecondaryConfig.configYamlMap;
  // ignore: prefer_typing_uninitialized_variables
  var value;
  if (yamlMap != null) {
    for (int i = 0; i < args.length; i++) {
      if (i == 0) {
        value = yamlMap[args[i]];
      } else {
        if (value != null) {
          value = value[args[i]];
        }
      }
    }
  }
  // If value not found throw exception
  if (value == Null || value == null) {
    throw ElementNotFoundException(
        'Element ${args.toString()} Not Found in yaml');
  }
  return value;
}

String? getStringValueFromYaml(List<String> keyParts) {
  var yamlMap = AtSecondaryConfig.configYamlMap;
  // ignore: prefer_typing_uninitialized_variables
  var value;
  if (yamlMap != null) {
    for (int i = 0; i < keyParts.length; i++) {
      if (i == 0) {
        value = yamlMap[keyParts[i]];
      } else {
        if (value != null) {
          value = value[keyParts[i]];
        }
      }
    }
  }
  // If value not found throw exception
  if (value == Null || value == null) {
    return null;
  } else {
    return value.toString();
  }
}

enum ModifiableConfigs {
  inboundMaxLimit,
  commitLogCompactionFrequencyMins,
  accessLogCompactionFrequencyMins,
  notificationKeyStoreCompactionFrequencyMins,
  autoNotify,
  maxNotificationRetries,
  checkCertificateReload,
  shouldReloadCertificates,
  doCacheRefreshNow,
  maxRequestsPerTimeFrame,
  timeFrameInMills
}

class ModifiableConfigurationEntry {
  late StreamController<dynamic> streamController;
  late dynamic defaultValue;
  dynamic currentValue;
}

class ElementNotFoundException extends AtException {
  ElementNotFoundException(message) : super(message);
}
