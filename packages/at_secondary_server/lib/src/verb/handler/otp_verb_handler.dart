import 'dart:collection';
import 'dart:math';
import 'package:at_commons/at_commons.dart';
import 'package:at_server_spec/at_server_spec.dart';
import 'package:uuid/uuid.dart';
import 'abstract_verb_handler.dart';
import 'package:at_server_spec/at_verb_spec.dart';
import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:expire_cache/expire_cache.dart';

class OtpVerbHandler extends AbstractVerbHandler {
  static Otp otpVerb = Otp();
  static final expireDuration = Duration(seconds: 90);
  static ExpireCache<String, String> cache =
      ExpireCache<String, String>(expireDuration: expireDuration);

  OtpVerbHandler(SecondaryKeyStore keyStore) : super(keyStore);

  @override
  bool accept(String command) =>
      command == 'otp:get' || command.startsWith('otp:validate');

  @override
  Verb getVerb() => otpVerb;

  @override
  Future<void> processVerb(
      Response response,
      HashMap<String, String?> verbParams,
      InboundConnection atConnection) async {
    final operation = verbParams['operation'];
    switch (operation) {
      case 'get':
        if (!atConnection.getMetaData().isAuthenticated) {
          throw UnAuthenticatedException(
              'otp:get requires authenticated connection');
        }
        do {
          response.data = _generateOTP();
        }
        // If OTP generated do not have digits, generate again.
        while (RegExp(r'\d').hasMatch(response.data!) == false);
        await cache.set(response.data!, response.data!);
        break;
      case 'validate':
        String? otp = verbParams['otp'];
        if (otp != null && (await cache.get(otp)) == otp) {
          response.data = 'valid';
        } else {
          response.data = 'invalid';
        }
        break;
    }
  }

  /// This function generates a UUID and converts it into a 6-character alpha-numeric string.
  ///
  /// The process involves converting the UUID to a hashcode, then transforming the hashcode
  /// into its Hexatridecimal representation to obtain the desired alpha-numeric characters.
  ///
  /// Additionally, if the resulting OTP contains "0" or "O", they are replaced with different
  /// number or alphabet, respectively. If the length of the OTP is less than 6, "padRight"
  /// is utilized to extend and match the length.
  String _generateOTP() {
    var uuid = Uuid().v4();
    Random random = Random();
    var otp = uuid.hashCode.toRadixString(36).toUpperCase();
    // If otp contains "0"(Zero) or "O" (alphabet) replace with a different number
    // or alphabet respectively.
    if (otp.contains('0') || otp.contains('O')) {
      for (int i = 0; i < otp.length; i++) {
        if (otp[i] == '0') {
          otp = otp.replaceFirst('0', (random.nextInt(8) + 1).toString());
        } else if (otp[i] == 'O') {
          otp = otp.replaceFirst('O', _generateRandomAlphabet());
        }
      }
    }
    if (otp.length < 6) {
      otp = otp.padRight(6, _generateRandomAlphabet());
    }
    return otp;
  }

  String _generateRandomAlphabet() {
    int minAscii = 'A'.codeUnitAt(0); // ASCII value of 'A'
    int maxAscii = 'Z'.codeUnitAt(0); // ASCII value of 'Z'
    int randomAscii;
    do {
      randomAscii = minAscii + Random().nextInt((maxAscii - minAscii) + 1);
      // 79 is the ASCII value of "O". If randamAscii is 79, generate again.
    } while (randomAscii == 79);
    return String.fromCharCode(randomAscii);
  }

  int bytesToInt(List<int> bytes) {
    int result = 0;
    for (final b in bytes) {
      result = result * 256 + b;
    }
    return result;
  }
}
