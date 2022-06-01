import 'dart:async';
import 'dart:io';

import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:test/test.dart';

void main() async {
  var storageDir = Directory.current.path + '/test/hive';

  group('A group of commit log test', () {
    setUp(() async => await setUpFunc(storageDir));
    test('test single insert', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var hiveKey =
          await commitLogInstance!.commit('location@alice', CommitOp.UPDATE);
      var committedEntry = await (commitLogInstance.getEntry(hiveKey));
      expect(committedEntry?.key, hiveKey);
      expect(committedEntry?.atKey, 'location@alice');
      expect(committedEntry?.operation, CommitOp.UPDATE);
      commitLogInstance = null;
    });
    test('test multiple insert', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      var key_2 =
          await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);

      await commitLogInstance?.commit('location@alice', CommitOp.DELETE);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 2);
      var committedEntry = await (commitLogInstance?.getEntry(key_2));
      expect(committedEntry?.atKey, 'location@alice');
      expect(committedEntry?.operation, CommitOp.UPDATE);
    });

    test('test get entry ', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var key_1 =
          await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      var committedEntry = await (commitLogInstance?.getEntry(key_1));
      expect(committedEntry?.atKey, 'location@alice');
      expect(committedEntry?.operation, CommitOp.UPDATE);
      expect(committedEntry?.opTime, isNotNull);
      expect(committedEntry?.commitId, isNotNull);
    });

    test('test entries since commit Id', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      var key_2 =
          await commitLogInstance!.commit('location@alice', CommitOp.UPDATE);
      var key_3 =
          await commitLogInstance.commit('location@alice', CommitOp.DELETE);
      var key_4 = await commitLogInstance.commit('phone@bob', CommitOp.UPDATE);
      var key_5 =
          await commitLogInstance.commit('email@charlie', CommitOp.UPDATE);
      expect(commitLogInstance.lastCommittedSequenceNumber(), 4);
      var changes = await commitLogInstance.getChanges(key_2, '');
      expect(changes.length, 3);
      expect(changes[0].atKey, 'location@alice');
      expect(changes[1].atKey, 'phone@bob');
      expect(changes[2].atKey, 'email@charlie');
    });

    test('test last sequence number called once', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 1);
    });

    test('test last sequence number called multiple times', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);

      await commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 1);
      expect(commitLogInstance?.lastCommittedSequenceNumber(), 1);
    });
    tearDown(() async => await tearDownFunc());
  });

  group('A group of commit log compaction tests', () {
    setUp(() async => await setUpFunc(storageDir));
    test('Test to verify compaction when single is modified ten times',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var compactionService =
          CommitLogCompactionService(commitLogInstance!.commitLogKeyStore);
      commitLogInstance.addEventListener(compactionService);
      for (int i = 0; i <= 50; i++) {
        await commitLogInstance.commit('location@alice', CommitOp.UPDATE);
      }

      var list = compactionService.getEntries('location@alice');
      expect(list?.getSize(), 1);
    });

    test('Test to verify compaction when two are modified ten times', () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      var compactionService =
          CommitLogCompactionService(commitLogInstance!.commitLogKeyStore);
      commitLogInstance.addEventListener(compactionService);
      for (int i = 0; i <= 50; i++) {
        await commitLogInstance.commit('location@alice', CommitOp.UPDATE);
        await commitLogInstance.commit('country@alice', CommitOp.UPDATE);
      }
      var locationList = compactionService.getEntries('location@alice');
      var countryList = compactionService.getEntries('country@alice');
      expect(locationList!.getSize(), 1);
      expect(countryList!.getSize(), 1);
    });
    tearDown(() async => await tearDownFunc());
  });

  group('A group of tests to verify repair commit log', () {
    setUp(() async => await setUpFunc(storageDir, enableCommitId: false));
    test('A test to verify null commit id gets replaced with hive internal key',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      commitLogInstance?.commit('location@alice', CommitOp.UPDATE);
      var commitLogMap = await commitLogInstance?.commitLogKeyStore.toMap();
      expect(commitLogMap?.values.first.commitId, null);
      await commitLogInstance?.commitLogKeyStore.repairCommitLog(commitLogMap!);
      commitLogMap = await commitLogInstance?.commitLogKeyStore.toMap();
      expect(commitLogMap?.values.first.commitId, 0);
    });

    test(
        'A test to verify multiple null commit id gets replaced with hive internal key',
        () async {
      var commitLogInstance =
          await (AtCommitLogManagerImpl.getInstance().getCommitLog('@alice'));
      // Inserting commitEntry with commitId 0
      await commitLogInstance!.commitLogKeyStore.getBox().add(
          CommitEntry('location@alice', CommitOp.UPDATE, DateTime.now())
            ..commitId = 0);
      // Inserting commitEntry with null commitId
      await commitLogInstance.commitLogKeyStore
          .getBox()
          .add(CommitEntry('location@alice', CommitOp.UPDATE, DateTime.now()));
      // Inserting commitEntry with commitId 2
      await commitLogInstance.commitLogKeyStore.getBox().add(
          CommitEntry('phone@alice', CommitOp.UPDATE, DateTime.now())
            ..commitId = 2);
      // Inserting commitEntry with null commitId
      await commitLogInstance.commitLogKeyStore
          .getBox()
          .add(CommitEntry('mobile@alice', CommitOp.UPDATE, DateTime.now()));

      var commitLogMap = await commitLogInstance.commitLogKeyStore.toMap();
      await commitLogInstance.commitLogKeyStore.repairCommitLog(commitLogMap);
      commitLogMap = await commitLogInstance.commitLogKeyStore.toMap();
      commitLogMap.forEach((key, value) {
        assert(value.commitId != null);
        expect(value.commitId, key);
      });

      // verify the commit id's return correct key's
      expect((await commitLogInstance.commitLogKeyStore.get(1))?.atKey,
          'location@alice');
      expect((await commitLogInstance.commitLogKeyStore.get(3))?.atKey,
          'mobile@alice');
    });
    tearDown(() async => await tearDownFunc());
  });
}

Future<SecondaryKeyStoreManager> setUpFunc(storageDir,
    {bool enableCommitId = true}) async {
  var commitLogInstance = await AtCommitLogManagerImpl.getInstance()
      .getCommitLog('@alice',
          commitLogPath: storageDir, enableCommitId: enableCommitId);
  var secondaryPersistenceStore = SecondaryPersistenceStoreFactory.getInstance()
      .getSecondaryPersistenceStore('@alice')!;
  var persistenceManager =
      secondaryPersistenceStore.getHivePersistenceManager()!;
  await persistenceManager.init(storageDir);
//  persistenceManager.scheduleKeyExpireTask(1); //commented this line for coverage test
  var hiveKeyStore = secondaryPersistenceStore.getSecondaryKeyStore()!;
  hiveKeyStore.commitLog = commitLogInstance;
  var keyStoreManager =
      secondaryPersistenceStore.getSecondaryKeyStoreManager()!;
  keyStoreManager.keyStore = hiveKeyStore;
  return keyStoreManager;
}

Future<void> tearDownFunc() async {
  await AtCommitLogManagerImpl.getInstance().close();
  var isExists = await Directory('test/hive/').exists();
  if (isExists) {
    Directory('test/hive').deleteSync(recursive: true);
  }
}
