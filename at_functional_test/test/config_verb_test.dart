import 'dart:io';

import 'package:test/test.dart';

import 'commons.dart';
import 'package:at_functional_test/conf/config_util.dart';


void main() {

  var first_atsign = '@high8289';
  var second_atsign = '@92official22';

  Socket _socket_first_atsign;

  //Establish the client socket connection
  setUp(() async {
    var high8289_server =  ConfigUtil.getYaml()['high8289_server']['high8289_url'];
    var high8289_port =  ConfigUtil.getYaml()['high8289_server']['high8289_port'];

    _socket_first_atsign =
        await secure_socket_connection(high8289_server, high8289_port);
    socket_listener(_socket_first_atsign);
    await prepare(_socket_first_atsign, first_atsign);
  });

  test('config verb for adding a atsign to blocklist', () async {
    /// CONFIG VERB
    await socket_writer(
        _socket_first_atsign, 'config:block:add:$second_atsign');
    var response = await read();
    print('config verb response : $response');
    expect(response, contains('data:success'));

    ///CONFIG VERB -SHOW BLOCK LIST
    await socket_writer(_socket_first_atsign, 'config:block:show');
    response = await read();
    print('config verb response $response');
    expect(response, contains('data:["$second_atsign"]'));
  });

  test('config verb for deleting a atsign from blocklist', () async {
    /// CONFIG VERB
    await socket_writer(
        _socket_first_atsign, 'config:block:add:$second_atsign');
    var response = await read();
    print('config verb response : $response');
    expect(response, contains('data:success'));

    /// CONFIG VERB - REMOVE FROM BLOCKLIST
    await socket_writer(
          _socket_first_atsign, 'config:block:remove:$second_atsign');
    response = await read();
    print('config verb response : $response');
    expect(response, contains('data:success'));

    ///CONFIG VERB -SHOW BLOCK LIST
    await socket_writer(_socket_first_atsign, 'config:block:show');
    response = await read();
    print('config verb response $response');
    expect(response, contains('data:null'));
  });

  test('config verb for adding a atsign to blocklist without giving a atsign (Negative case)', () async {
    /// CONFIG VERB
    await socket_writer(
        _socket_first_atsign, 'config:block:add:');
    var response = await read();
    print('config verb response : $response');
    assert(response.contains('error:AT0003-Invalid syntax'));
  });

  test('config verb for adding a atsign to blocklist by giving 2 @ in the atsign (Negative case)', () async {
    /// CONFIG VERB
    await socket_writer(
        _socket_first_atsign, 'config:block:add:@@kevin');
    var response = await read();
    print('config verb response : $response');
    assert(response.contains('error:AT0003-Invalid syntax'));
  });


  test('config verb by giving list instead of show (Negative case)', () async {
    /// CONFIG VERB
    await socket_writer(
        _socket_first_atsign, 'config:block:list');
    var response = await read();
    print('config verb response : $response');
    assert(response.contains('error:AT0003-Invalid syntax'));

  });
  
  tearDown(() {
    //Closing the client socket connection
    clear();
    _socket_first_atsign.destroy();
  });
}
