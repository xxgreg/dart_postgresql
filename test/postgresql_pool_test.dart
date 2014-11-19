import 'dart:async';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/constants.dart';
import 'package:postgresql/src/mock.dart';
import 'package:postgresql/pool.dart';
import 'package:postgresql/src/pool_impl_cps.dart';
import 'package:unittest/unittest.dart';


//_log(msg) => print(msg);
_log(msg) { }

main() {
  mockLogger = _log;

  test('Test pool', testPool);
  test('Test start timeout', testStartTimeout);
  test('Test connect timeout', testConnectTimeout);
  test('Test wait queue', testWaitQueue);
}

PoolImpl createPool(PoolSettings settings) {
  var mockConnect = (uri, {timeout, typeConverter}) => new Future.value(new MockConnection());
  int minConnections = 2;
  return new PoolImpl('postgresql://fakeuri', settings, mockConnect);
}

expectState(PoolImpl pool, {int total, int available, int inUse}) {
  if (total != null) expect(pool.totalConnections, equals(total));
  if (available != null) expect(pool.availableConnections, equals(available));
  if (inUse != null) expect(pool.inUseConnections, equals(inUse));
}

Future testPool() async {
  var pool = createPool(new PoolSettings(minConnections: 2));

  var v = await pool.start();
  expect(v, isNull);
  expectState(pool, total: 2, available: 2, inUse: 0);

  var c = await pool.connect();
  expectState(pool, total: 2, available: 1, inUse: 1);

  c.close();

  // Wait for next event loop.
  await new Future(() {});
  expectState(pool, total: 2, available: 2, inUse: 0);

  var stopFuture = pool.stop();
  await new Future(() {});
  expect(pool.state, equals(stopping));

  var v2 = await stopFuture;
  expect(v2, isNull);
  expect(pool.state, equals(stopped));
  expectState(pool, total: 0, available: 0, inUse: 0);
}


Future testStartTimeout() async {
  var mockConnect = (uri, {timeout, typeConverter}) => new Future.delayed(new Duration(seconds: 10));
  var settings = new PoolSettings(
      startTimeout: new Duration(seconds: 2),
      minConnections: 2);
  var pool = new PoolImpl('postgresql://fakeuri', settings, mockConnect);

  try {
    expect(pool.getConnections(), isEmpty);
    var v = await pool.start();
    fail('Pool started, but should have timed out.');
  } catch (ex, st) {
    expect(ex, new isInstanceOf<TimeoutException>());

    //TODO check the state of pool. What state should it be in now? "start-failed"?
  }
}


Future testConnectTimeout() async {
  var settings = new PoolSettings(
      minConnections: 2,
      maxConnections: 2,
      connectionTimeout: new Duration(seconds: 2));
  var pool = createPool(settings);

  expect(pool.getConnections(), isEmpty);

  var v = await pool.start();

  expect(v, isNull);
  //TODO totalConnections getter;
  expect(pool.getConnections().length, equals(settings.minConnections));
  expect(pool.getConnections().where((c) => c.state == available).length,
      equals(settings.minConnections));

  // Obtain all of the connections from the pool.
  //TODO for i..minConnections
  var c1 = await pool.connect();
  var c2 = await pool.connect();

  try {
    // All connections are in use, this should timeout.
    var c = await pool.connect();
    fail('connect() should have timed out.');
  } on TimeoutException catch (ex, st) {
    expect(ex, new isInstanceOf<TimeoutException>());
    //TODO check the state of the pool.
  }
}


Future testWaitQueue() async {
  var settings = new PoolSettings(
      minConnections: 2,
      maxConnections: 2);
  var pool = createPool(settings);

  expect(pool.getConnections(), isEmpty);

  var v = await pool.start();

  expect(v, isNull);
  //TODO getter totalConnections;
  expect(pool.getConnections().length, equals(2));

  //TODO expose getter availableConnections
  expect(pool.getConnections().where((c) => c.state == available).length,
      equals(2));

  var c1 = await pool.connect();
  var c2 = await pool.connect();

  c1.query('mock timeout 5').toList().then((r) => c1.close());
  c2.query('mock timeout 10').toList().then((r) => c2.close());

  var conns = pool.getConnections();
  expect(conns.length, equals(2));
  expect(conns.where((c) => c.state == available).length, equals(0));
  expect(conns.where((c) => c.state == inUse).length, equals(2));

  var c3 = await pool.connect();

  expect(c3.state, equals(idle));

  c3.close();

  //TODO check state of pool.
}
