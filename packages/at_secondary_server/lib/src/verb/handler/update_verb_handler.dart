import 'dart:collection';
import 'dart:convert';

import 'package:at_commons/at_commons.dart';
import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:at_secondary/src/notification/notification_manager_impl.dart';
import 'package:at_secondary/src/server/at_secondary_config.dart';
import 'package:at_secondary/src/server/at_secondary_impl.dart';
import 'package:at_secondary/src/utils/handler_util.dart';
import 'package:at_secondary/src/utils/secondary_util.dart';
import 'package:at_secondary/src/verb/handler/change_verb_handler.dart';
import 'package:at_server_spec/at_server_spec.dart';
import 'package:at_server_spec/at_verb_spec.dart';
import 'package:at_utils/at_utils.dart';

// UpdateVerbHandler is used to process update verb
// update can be used to update the public/private keys
// Ex: update:public:email@alice alice@atsign.com \n
class UpdateVerbHandler extends ChangeVerbHandler {
  static bool? _autoNotify = AtSecondaryConfig.autoNotify;
  static Update update = Update();

  UpdateVerbHandler(SecondaryKeyStore keyStore) : super(keyStore);

  //setter to set autoNotify value from dynamic server config "config:set".
  //only works when testingMode is set to true
  static setAutoNotify(bool newState) {
    if (AtSecondaryConfig.testingMode) {
      _autoNotify = newState;
    }
  }

  // Method to verify whether command is accepted or not
  // Input: command
  @override
  bool accept(String command) =>
      command.startsWith('update:') && !command.startsWith('update:meta');

  // Method to return Instance of verb belongs to this VerbHandler
  @override
  Verb getVerb() {
    return update;
  }

  @override
  HashMap<String, String?> parse(String command) {
    var verbParams = super.parse(command);
    if (command.contains('public:')) {
      verbParams.putIfAbsent('isPublic', () => 'true');
    }
    return verbParams;
  }

  // Method which will process update Verb
  // This will process given verb and write response to response object
  // Input : Response, verbParams, AtConnection
  @override
  Future<void> processVerb(
      Response response,
      HashMap<String, String?> verbParams,
      InboundConnection atConnection) async {
    // Sets Response bean to the response bean in ChangeVerbHandler
    await super.processVerb(response, verbParams, atConnection);
    var updateParams = _getUpdateParams(verbParams);
    if (updateParams.sharedBy != null &&
        updateParams.sharedBy!.isNotEmpty &&
        AtUtils.formatAtSign(updateParams.sharedBy) !=
            AtSecondaryServerImpl.getInstance().currentAtSign) {
      logger.warning(
          'Invalid update command sharedBy atsign ${AtUtils.formatAtSign(updateParams.sharedBy)} should be same as current atsign ${AtSecondaryServerImpl.getInstance().currentAtSign}');
      throw InvalidAtKeyException(
          'Invalid update command sharedBy atsign ${AtUtils.formatAtSign(updateParams.sharedBy)} should be same as current atsign ${AtSecondaryServerImpl.getInstance().currentAtSign}');
    }
    try {
      // Get the key and update the value
      var sharedWith = updateParams.sharedWith;
      var sharedBy = updateParams.sharedBy;
      var key = updateParams.atKey;
      var value = updateParams.value;
      var atData = AtData();
      atData.data = value;
      atData.metaData = AtMetaData();

      // Get the key using verbParams (forAtSign, key, atSign)
      if (sharedWith != null) {
        sharedWith = AtUtils.formatAtSign(sharedWith);
        key = '$sharedWith:$key';
      }
      if (sharedBy != null) {
        sharedBy = AtUtils.formatAtSign(sharedBy);
        key = '$key$sharedBy';
      }
      // Append public: as prefix if key is public
      if (updateParams.metadata!.isPublic != null &&
          updateParams.metadata!.isPublic!) {
        key = 'public:$key';
      }

      var ttrSeconds = updateParams.metadata!.ttr;
      var ccd = updateParams.metadata!.ccd;
      var metadata = await keyStore.getMeta(key);
      var cacheRefreshMetaMap = validateCacheMetadata(metadata, ttrSeconds, ccd);
      ttrSeconds = cacheRefreshMetaMap[AT_TTR];
      ccd = cacheRefreshMetaMap[CCD];

      //If ttr is set and atsign is not equal to currentAtSign, the key is
      //cached key.
      if (ttrSeconds != null &&
          ttrSeconds > 0 &&
          sharedBy != null &&
          sharedBy != AtSecondaryServerImpl.getInstance().currentAtSign) {
        key = 'cached:$key';
      }

      var atMetadata = AtMetaData()
        ..ttl = updateParams.metadata!.ttl
        ..ttb = updateParams.metadata!.ttb
        ..ttr = ttrSeconds
        ..isCascade = ccd
        ..isBinary = updateParams.metadata!.isBinary
        ..isEncrypted = updateParams.metadata!.isEncrypted
        ..dataSignature = updateParams.metadata!.dataSignature
        ..sharedKeyEnc = updateParams.metadata!.sharedKeyEnc
        ..pubKeyCS = updateParams.metadata!.pubKeyCS
        ..encoding = updateParams.metadata!.encoding
        ..encKeyName = updateParams.metadata!.encKeyName
        ..encAlgo = updateParams.metadata!.encAlgo
        ..ivNonce = updateParams.metadata!.ivNonce
        ..skeEncKeyName = updateParams.metadata!.skeEncKeyName
        ..skeEncAlgo = updateParams.metadata!.skeEncAlgo;

      if (_autoNotify!) {
        _notify(
            sharedBy,
            sharedWith,
            verbParams[AT_KEY],
            value,
            SecondaryUtil.getNotificationPriority(verbParams[PRIORITY]),
            atMetadata);
      }

      // update the key in data store
      var result = await keyStore.put(key, atData,
          time_to_live: updateParams.metadata!.ttl,
          time_to_born: updateParams.metadata!.ttb,
          time_to_refresh: ttrSeconds,
          isCascade: ccd,
          isBinary: updateParams.metadata!.isBinary,
          isEncrypted: updateParams.metadata!.isEncrypted,
          dataSignature: updateParams.metadata!.dataSignature,
          sharedKeyEncrypted: updateParams.metadata!.sharedKeyEnc,
          publicKeyChecksum: updateParams.metadata!.pubKeyCS,
          encoding: updateParams.metadata!.encoding,
          encKeyName: updateParams.metadata!.encKeyName,
          encAlgo: updateParams.metadata!.encAlgo,
          ivNonce: updateParams.metadata!.ivNonce,
          skeEncKeyName: updateParams.metadata!.skeEncKeyName,
          skeEncAlgo: updateParams.metadata!.skeEncAlgo
      );
      response.data = result?.toString();
    } on InvalidSyntaxException {
      rethrow;
    } on InvalidAtKeyException {
      rethrow;
    } catch (exception) {
      response.isError = true;
      response.errorMessage = exception.toString();
      return;
    }
  }

  void _notify(String? atSign, String? forAtSign, String? key, String? value,
      NotificationPriority priority, AtMetaData atMetaData) {
    if (forAtSign == null) {
      return;
    }
    key = '$forAtSign:$key$atSign';
    DateTime? expiresAt;
    if (atMetaData.ttl != null) {
      expiresAt = DateTime.now().add(Duration(seconds: atMetaData.ttl!));
    }

    var atNotification = (AtNotificationBuilder()
          ..fromAtSign = atSign
          ..toAtSign = forAtSign
          ..notification = key
          ..type = NotificationType.sent
          ..priority = priority
          ..opType = OperationType.update
          ..expiresAt = expiresAt
          ..atValue = value
          ..atMetaData = atMetaData)
        .build();

    NotificationManager.getInstance().notify(atNotification);
  }

  UpdateParams _getUpdateParams(HashMap<String, String?> verbParams) {
    if (verbParams['json'] != null) {
      var jsonString = verbParams['json']!;
      Map jsonMap = jsonDecode(jsonString);
      return UpdateParams.fromJson(jsonMap);
    }
    var updateParams = UpdateParams();
    updateParams.sharedBy = verbParams[AT_SIGN];
    updateParams.sharedWith = verbParams[FOR_AT_SIGN];
    updateParams.atKey = verbParams[AT_KEY];
    updateParams.value = verbParams[AT_VALUE];
    var metadata = Metadata();
    metadata.ttl = AtMetadataUtil.validateTTL(verbParams[AT_TTL]);
    metadata.ttb = AtMetadataUtil.validateTTB(verbParams[AT_TTB]);
    if (verbParams[AT_TTR] != null) {
      metadata.ttr = AtMetadataUtil.validateTTR(int.parse(verbParams[AT_TTR]!));
    }
    metadata.ccd = AtMetadataUtil.getBoolVerbParams(verbParams[CCD]);
    metadata.dataSignature = verbParams[PUBLIC_DATA_SIGNATURE];
    metadata.isBinary = AtMetadataUtil.getBoolVerbParams(verbParams[IS_BINARY]);
    metadata.isEncrypted =
        AtMetadataUtil.getBoolVerbParams(verbParams[IS_ENCRYPTED]);
    metadata.isPublic = AtMetadataUtil.getBoolVerbParams(verbParams[IS_PUBLIC]);
    metadata.sharedKeyEnc = verbParams[SHARED_KEY_ENCRYPTED];
    metadata.pubKeyCS = verbParams[SHARED_WITH_PUBLIC_KEY_CHECK_SUM];
    metadata.encoding = verbParams[ENCODING];
    updateParams.metadata = metadata;
    return updateParams;
  }
}
