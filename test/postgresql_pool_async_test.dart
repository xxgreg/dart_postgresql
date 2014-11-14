import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/postgresql_pool_async.dart';
import 'package:postgresql/postgresql_pool_async_impl.dart';

import 'postgresql_mock.dart';


_log(msg) => print(msg);
//_log(msg) { }


main() {
  mockLogger = _log;

  test('Test pool', () {
    testPool()
      .then(expectAsync((v) { _log('done'); }));
  });

  test('Test start timeout', () {
    testStartTimeout()
      .then(expectAsync((v) { _log('done'); }));
  });

  test('Test connect timeout', () {
      testConnectTimeout().then(expectAsync((v) { _log('done'); }));
  });

  test('Test wait queue', () {
    testWaitQueue()
      .then(expectAsync((v) { _log('done'); }));
  });
}

Future testPool() async {
    var mockConnect = (uri, settings) => new Future.value(new MockConnection());
    int minConnections = 2;
    var settings = new PoolSettings(minConnections: minConnections);
    var pool = new PoolImpl('postgresql://fakeuri', settings, mockConnect);

    _log('created');
    pool.getConnections().forEach(_log);

    expect(pool.getConnections(), isEmpty);

    var v = await pool.start();

    expect(v, isNull);
    expect(pool.getConnections().length, equals(minConnections));
    expect(pool.getConnections().where((c) => c.state == available).length,
        equals(minConnections));

    _log('started');
    pool.getConnections().forEach(_log);

    var c = await pool.connect();

    _log('connected');
    pool.getConnections().forEach(_log);

    c.close();

    _log('closed');
    pool.getConnections().forEach(_log);
}


Future testStartTimeout() async {
    var mockConnect = (uri, settings) => new Future.delayed(new Duration(seconds: 10));
    int minConnections = 2;
    var settings = new PoolSettings(
        startTimeout: new Duration(seconds: 2),
        minConnections: minConnections);
    var pool = new PoolImpl('postgresql://fakeuri', settings, mockConnect);

    try {
      _log('created');
      pool.getConnections().forEach(_log);

      expect(pool.getConnections(), isEmpty);

      var v = await pool.start();

      fail('Pool started, but should have timed out.');

    } on TimeoutException catch (ex, st) {
      _log(ex);
      _log(st);
    }
}



Future testConnectTimeout() async {
    var mockConnect = (uri, settings) => new Future.value(new MockConnection());
    int minConnections = 2;
    var settings = new PoolSettings(
        minConnections: minConnections,
        maxConnections: minConnections,
        connectionTimeout: new Duration(seconds: 2));
    var pool = new PoolImpl('postgresql://fakeuri', settings, mockConnect);

    _log('created');
    pool.getConnections().forEach(_log);

    expect(pool.getConnections(), isEmpty);

    var v = await pool.start();

    expect(v, isNull);
    expect(pool.getConnections().length, equals(minConnections));
    expect(pool.getConnections().where((c) => c.state == available).length,
        equals(minConnections));

    _log('started');
    pool.getConnections().forEach(_log);

    // Obtain all of the connections from the pool.
    var c1 = await pool.connect();
    var c2 = await pool.connect();

    try {
      // All connections are in use, this should timeout.
      var c = await pool.connect();
      fail('connect() should have timed out.');
    } on TimeoutException catch (ex, st) {
      _log(ex);
      _log(st);
      pool.getConnections().forEach(_log);
    }
}


Future testWaitQueue() async {
    var mockConnect = (uri, settings) => new Future.value(new MockConnection());
    int minConnections = 2;
    var settings = new PoolSettings(
        minConnections: minConnections,
        maxConnections: minConnections);
    var pool = new PoolImpl('postgresql://fakeuri', settings, mockConnect);

    _log('created');
    pool.getConnections().forEach(_log);

    expect(pool.getConnections(), isEmpty);

    var v = await pool.start();

    expect(v, isNull);
    expect(pool.getConnections().length, equals(minConnections));
    expect(pool.getConnections().where((c) => c.state == available).length,
        equals(minConnections));

    _log('started');
    pool.getConnections().forEach(_log);

    var c1 = await pool.connect();
    var c2 = await pool.connect();

    c1.query('mock timeout 5').toList().then((r) => c1.close());
    c2.query('mock timeout 10').toList().then((r) => c2.close());

    _log('busy');
    pool.getConnections().forEach(_log);

    var conns = pool.getConnections();
    expect(conns.length, equals(2));
    expect(conns.where((c) => c.state == available).length, equals(0));
    expect(conns.where((c) => c.state == inUse).length, equals(2));

    var c3 = await pool.connect();

    _log('obtained after wait');
    expect(c3.state, equals(pg.IDLE));

    c3.close();

    _log('closed');
    pool.getConnections().forEach(_log);

}
