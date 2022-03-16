import 'package:test/test.dart';
import 'notify_verb_test.dart' as notification;
import 'e2e_test_utils.dart' as e2e;

void main() {
  late String atSign_1;
  late e2e.SimpleOutboundSocketHandler sh1;

  late String atSign_2;
  late e2e.SimpleOutboundSocketHandler sh2;

  setUpAll(() async {
    List<String> atSigns = e2e.knownAtSigns();
    atSign_1 = atSigns[0];
    sh1 = await e2e.getSocketHandler(atSign_1);
    atSign_2 = atSigns[1];
    sh2 = await e2e.getSocketHandler(atSign_2);
  });

  tearDownAll(() {
    sh1.close();
    sh2.close();
  });

  setUp(() async {
    print("Clearing socket response queues");
    sh1.clear();
    sh2.clear();
  });

  test('update-llookup verb with ttr:-1', () async {
    /// UPDATE VERB
    await sh1.writeCommand('notify:update:ttr:-1:$atSign_2:key-1$atSign_1:value1');
    String response = await sh1.read();
    print('notify verb response : $response');
    assert((!response.contains('Invalid syntax')) && (!response.contains('null')));
    String notificationId = response.replaceAll('data:', '');
    await notification.getNotifyStatus(sh1, notificationId, returnWhenStatusIn: ['delivered'], timeOutMillis: 15000);

    ///LLOOKUP VERB in the receiving atsign 
    await sh2.writeCommand('llookup:cached:$atSign_2:key-1$atSign_1');
    response = await sh2.read();
    print('llookup verb response of a cached key : $response');
    expect(response, contains('data:value1'));
  });

  test('update-llookup verb with ttr and ccd true', () async {
    /// UPDATE VERB
    await sh1.writeCommand('notify:update:ttr:2000:ccd:true:$atSign_2:key-2$atSign_1:value2');
    var response = await sh1.read(timeoutMillis: 1000);
    print('notify verb response : $response');
    assert((!response.contains('Invalid syntax')) && (!response.contains('null')));
    String notificationId = response.replaceAll('data:', '');
    await notification.getNotifyStatus(sh1, notificationId, returnWhenStatusIn: ['delivered'], timeOutMillis: 15000);
    
    ///LLOOKUP VERB in the receiving atsign before delete
    await sh2.writeCommand('llookup:cached:$atSign_2:key-2$atSign_1');
    response = await sh2.read();
    print('llookup verb response of a cached key before delete : $response');
    expect(response, contains('data:value2'));

    /// Deleting key which has ccd:true
    await sh1.writeCommand('notify:delete:$atSign_2:key-2$atSign_1');
    response = await sh1.read();
    print('notify delete verb response : $response');
    assert((!response.contains('Invalid syntax')) && (!response.contains('null')));
    notificationId = response.replaceAll('data:', '');
    await notification.getNotifyStatus(sh1, notificationId, returnWhenStatusIn: ['delivered'], timeOutMillis: 15000);

    ///LLOOKUP VERB in the receiving atsign after deleting the key from the sender
    await sh2.writeCommand('llookup:cached:$atSign_2:key-2$atSign_1');
    response = await sh2.read();
    print('llookup verb response of a cached key : $response');
    expect(response, contains('cached:$atSign_2:key-2$atSign_1 does not exist in keystore'));

  });

   test('update-llookup verb with ttr and ccd false', () async {
    /// UPDATE VERB
    await sh1.writeCommand('notify:update:ttr:2000:ccd:false:$atSign_2:key-3$atSign_1:value3');
    var response = await sh1.read(timeoutMillis: 1000);
    print('update verb response : $response');
    assert((!response.contains('Invalid syntax')) && (!response.contains('null')));
    String notificationId = response.replaceAll('data:', '');
    await notification.getNotifyStatus(sh1, notificationId, returnWhenStatusIn: ['delivered'], timeOutMillis: 15000);

    ///LLOOKUP VERB in the receiving atsign before delete
    await sh2.writeCommand('llookup:cached:$atSign_2:key-3$atSign_1');
    response = await sh2.read();
    print('llookup verb response of a cached key before delete : $response');
    expect(response, contains('data:value3'));

    /// Deleting key which has ccd:true
    await sh1.writeCommand('notify:delete:$atSign_2:key-3$atSign_1');
    response = await sh1.read();
    print('delete verb response : $response');
    assert((!response.contains('Invalid syntax')) && (!response.contains('null')));
    notificationId = response.replaceAll('data:', '');
    await notification.getNotifyStatus(sh1, notificationId, returnWhenStatusIn: ['delivered'], timeOutMillis: 15000);

    ///LLOOKUP VERB in the receiving atsign after deleting the key from the sender
    await sh2.writeCommand('llookup:cached:$atSign_2:key-3$atSign_1');
    response = await sh2.read();
    print('llookup verb response of a cached key : $response');
    expect(response, contains('data:value3'));

  });

  // Will uncomment after validations are in place
  // test('update-llookup verb without ttr and with ccd', () async {
  //   /// UPDATE VERB
  //   await sh1.writeCommand('update:ccd:true:$atSign_2:sample$atSign_1 sams');
  //   var response = await sh1.read();
  //   print('update verb response : $response');
  //   assert((response.contains('Invalid syntax')));
  // });




}