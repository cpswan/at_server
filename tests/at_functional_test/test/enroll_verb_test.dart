import 'dart:convert';
import 'dart:io';

import 'package:at_functional_test/conf/config_util.dart';
import 'package:test/test.dart';

import 'at_demo_data.dart';
import 'functional_test_commons.dart';
import 'pkam_utils.dart';

Socket? socketConnection1;
Socket? socketConnection2;
var firstAtsignServer =
    ConfigUtil.getYaml()!['first_atsign_server']['first_atsign_url'];
var firstAtsignPort =
    ConfigUtil.getYaml()!['first_atsign_server']['first_atsign_port'];

Future<void> _connect() async {
  // socket connection for first atsign
  socketConnection1 =
      await secure_socket_connection(firstAtsignServer, firstAtsignPort);
  socket_listener(socketConnection1!);
}

void main() {
  var firstAtsign =
      ConfigUtil.getYaml()!['first_atsign_server']['first_atsign_name'];

  //Establish the client socket connection
  setUp(() async {
    await _connect();
  });

  group('A group of tests to verify apkam enroll requests', () {
    test('enroll request on authenticated connection', () async {
      await socket_writer(socketConnection1!, 'from:$firstAtsign');
      var fromResponse = await read();
      print('from verb response : $fromResponse');
      fromResponse = fromResponse.replaceAll('data:', '');
      var pkamDigest = generatePKAMDigest(firstAtsign, fromResponse);
      await socket_writer(socketConnection1!, 'pkam:$pkamDigest');
      var pkamResult = await read();
      expect(pkamResult, 'data:success\n');
      var enrollRequest =
          'enroll:request:appName:wavi:deviceName:pixel:namespaces:[wavi,rw]:apkamPublicKey:${pkamPublicKeyMap[firstAtsign]!}\n';
      await socket_writer(socketConnection1!, enrollRequest);
      var enrollResponse = await read();
      print(enrollResponse);
      enrollResponse = enrollResponse.replaceFirst('data:', '');
      var enrollJsonMap = jsonDecode(enrollResponse);
      expect(enrollJsonMap['enrollmentId'], isNotEmpty);
      expect(enrollJsonMap['status'], 'success');
    });

    test('enroll request on unauthenticated connection without totp', () async {
      var enrollRequest =
          'enroll:request:appName:wavi:deviceName:pixel:namespaces:[wavi,rw]:apkamPublicKey:${pkamPublicKeyMap[firstAtsign]!}\n';
      await socket_writer(socketConnection1!, enrollRequest);
      var enrollResponse = await read();
      print(enrollResponse);
      enrollResponse = enrollResponse.replaceFirst('data:', '');
      var enrollJsonMap = jsonDecode(enrollResponse);
      expect(enrollJsonMap['status'], 'exception');
      expect(enrollJsonMap['reason'],
          'Exception: invalid totp. Cannot process enroll request');
    });

    test('enroll request on unauthenticated connection invalid totp', () async {
      var enrollRequest =
          'enroll:request:appName:wavi:deviceName:pixel:namespaces:[wavi,rw]:totp:1234:apkamPublicKey:${pkamPublicKeyMap[firstAtsign]!}\n';
      await socket_writer(socketConnection1!, enrollRequest);
      var enrollResponse = await read();
      print(enrollResponse);
      enrollResponse = enrollResponse.replaceFirst('data:', '');
      var enrollJsonMap = jsonDecode(enrollResponse);
      expect(enrollJsonMap['status'], 'exception');
      expect(enrollJsonMap['reason'],
          'Exception: invalid totp. Cannot process enroll request');
    });

   // Purpose of the tests
    // 1. Do a pkam authentication
    // 2. Send an enroll request
    //  3 . Get an otp from the first client
    //  4. Send an enroll request with otp from the second client
    //  5. First client doesn't approve the enroll request
    //  6. Second client should get an exception as the enroll request is not approved
    test(
        'second enroll request using totp and client did not approved enrollment request',
        () async {
      await socket_writer(socketConnection1!, 'from:$firstAtsign');
      var fromResponse = await read();
      print('from verb response : $fromResponse');
      fromResponse = fromResponse.replaceAll('data:', '');
      var pkamDigest = generatePKAMDigest(firstAtsign, fromResponse);
      await socket_writer(socketConnection1!, 'pkam:$pkamDigest');
      var pkamResult = await read();
      expect(pkamResult, 'data:success\n');
      var enrollRequest =
          'enroll:request:appName:wavi:deviceName:pixel:namespaces:[wavi,rw]:apkamPublicKey:${pkamPublicKeyMap[firstAtsign]!}\n';
      await socket_writer(socketConnection1!, enrollRequest);
      var enrollResponse = await read();
      print(enrollResponse);
      enrollResponse = enrollResponse.replaceFirst('data:', '');
      var enrollJsonMap = jsonDecode(enrollResponse);
      expect(enrollJsonMap['enrollmentId'], isNotEmpty);
      expect(enrollJsonMap['status'], 'success');

      var totpRequest = 'totp:get\n';
      await socket_writer(socketConnection1!, totpRequest);
      var totpResponse = await read();
      totpResponse = totpResponse.replaceFirst('data:', '');
      print(totpResponse);
      totpResponse = totpResponse.trim();

      // connect to the second client
      socketConnection2 =
          await secure_socket_connection(firstAtsignServer, firstAtsignPort);
      socket_listener(socketConnection2!);

      //send second enroll request with totp
      var apkamPublicKey = pkamPublicKeyMap[firstAtsign];
      var secondEnrollRequest =
          'enroll:request:appName:buzz:deviceName:pixel:namespaces:[buzz,rw]:totp:$totpResponse:apkamPublicKey:$apkamPublicKey\n';
      print(secondEnrollRequest);
      await socket_writer(socketConnection2!, secondEnrollRequest);

      var secondEnrollResponse = await read();
      print(secondEnrollResponse);
      secondEnrollResponse = secondEnrollResponse.replaceFirst('data:', '');
      var enrollJson = jsonDecode(secondEnrollResponse);
      expect(enrollJson['enrollmentId'], isNotEmpty);
      expect(enrollJson['status'], 'pending');

      var secondEnrollId = enrollJson['enrollmentId'];

      // deny the enroll request from the first client
      var denyEnrollCommand = 'enroll:deny:enrollmentId:$secondEnrollId\n';
      await socket_writer(socketConnection1!, denyEnrollCommand);
      var denyEnrollResponse = await read();
      print(denyEnrollResponse);
      denyEnrollResponse = denyEnrollResponse.replaceFirst('data:', '');
      var approveJson = jsonDecode(denyEnrollResponse);
      expect(approveJson['status'], 'denied');
      expect(approveJson['enrollmentId'], secondEnrollId);

      // now do the apkam using the enrollment id
      await socket_writer(socketConnection2!, 'from:$firstAtsign');
      fromResponse = await read();
      fromResponse = fromResponse.replaceAll('data:', '');
      pkamDigest = generatePKAMDigest(firstAtsign, fromResponse);
      var apkamEnrollId = 'pkam:enrollApprovalId:$secondEnrollId:$pkamDigest\n';

      await socket_writer(socketConnection2!, apkamEnrollId);
      var apkamEnrollIdResponse = await read();
      print(apkamEnrollIdResponse);
      expect(apkamEnrollIdResponse,
          'error:AT0401-Exception: enrollment id: $secondEnrollId is not approved\n');
    });

    // Purpose of the tests
    // 1. Do a pkam authentication
    // 2. Send an enroll request
    //  3 . Get an otp from the first client
    //  4. Send an enroll request with otp from the second client
    //  5. First client approves the enroll request
    test(
        'second enroll request using totp and client approves enrollment request',
        () async {
      await socket_writer(socketConnection1!, 'from:$firstAtsign');
      var fromResponse = await read();
      print('from verb response : $fromResponse');
      fromResponse = fromResponse.replaceAll('data:', '');
      var pkamDigest = generatePKAMDigest(firstAtsign, fromResponse);
      await socket_writer(socketConnection1!, 'pkam:$pkamDigest');
      var pkamResult = await read();
      expect(pkamResult, 'data:success\n');
      var enrollRequest =
          'enroll:request:appName:wavi:deviceName:pixel:namespaces:[wavi,rw]:apkamPublicKey:${pkamPublicKeyMap[firstAtsign]!}\n';
      await socket_writer(socketConnection1!, enrollRequest);
      var enrollResponse = await read();
      print(enrollResponse);
      enrollResponse = enrollResponse.replaceFirst('data:', '');
      var enrollJsonMap = jsonDecode(enrollResponse);
      expect(enrollJsonMap['enrollmentId'], isNotEmpty);
      expect(enrollJsonMap['status'], 'success');

      var totpRequest = 'totp:get\n';
      await socket_writer(socketConnection1!, totpRequest);
      var totpResponse = await read();
      totpResponse = totpResponse.replaceFirst('data:', '');
      print(totpResponse);
      totpResponse = totpResponse.trim();

      // connect to the second client
      socketConnection2 =
          await secure_socket_connection(firstAtsignServer, firstAtsignPort);
      socket_listener(socketConnection2!);
      //send second enroll request with totp
      var apkamPublicKey = pkamPublicKeyMap[firstAtsign];
      var secondEnrollRequest =
          'enroll:request:appName:buzz:deviceName:pixel:namespaces:[buzz,rw]:totp:$totpResponse:apkamPublicKey:$apkamPublicKey\n';
      print(secondEnrollRequest);
      await socket_writer(socketConnection2!, secondEnrollRequest);

      var secondEnrollResponse = await read();
      print(secondEnrollResponse);
      secondEnrollResponse = secondEnrollResponse.replaceFirst('data:', '');
      var enrollJson = jsonDecode(secondEnrollResponse);
      expect(enrollJson['enrollmentId'], isNotEmpty);
      expect(enrollJson['status'], 'pending');
      var secondEnrollId = enrollJson['enrollmentId'];

      // connect to the first client to approve the enroll request
      await socket_writer(
          socketConnection1!, 'enroll:approve:enrollmentId:$secondEnrollId\n');
      var approveResponse = await read();
      print(approveResponse);
      approveResponse = approveResponse.replaceFirst('data:', '');
      var approveJson = jsonDecode(approveResponse);
      expect(approveJson['status'], 'approved');
      expect(approveJson['enrollmentId'], secondEnrollId);

      // connect to the second client to do an apkam
      await socket_writer(socketConnection2!, 'from:$firstAtsign');
      fromResponse = await read();
      fromResponse = fromResponse.replaceAll('data:', '');
      // now do the apkam using the enrollment id
      pkamDigest = generatePKAMDigest(firstAtsign, fromResponse);
      var apkamEnrollId = 'pkam:enrollApprovalId:$secondEnrollId:$pkamDigest\n';

      await socket_writer(socketConnection2!, apkamEnrollId);
      var apkamEnrollIdResponse = await read();
      print(apkamEnrollIdResponse);
      expect(apkamEnrollIdResponse, 'data:success\n');
    });
  });
}
