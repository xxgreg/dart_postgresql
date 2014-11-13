import 'dart:async';
import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/postgresql_pool_async_impl.dart';


class MockConnection implements pg.Connection {
  void close() {}
  Future<int> execute(String sql, [values]) { print('execute("$sql")'); }
  Stream<pg.Message> get messages => null;
  Future get onClosed => null;
  Stream query(String sql, [values]) {
    print('query("$sql")');
    return new Stream.fromIterable([[42]]);
  }
  Future runInTransaction(Future operation(), [pg.Isolation isolation]) {}
  int get state => null;
  int get transactionStatus => null;

  @override
  int get connectionId => null;
}

main() {
  test();
}

test() async {
  //test('Start', () {
    var mockConnection = new MockConnection();
    var mockConnect = (uri, settings) => new Future.value(mockConnection);
    var settings = new PoolSettingsImpl();
    var pool = new PoolImpl('foo', settings, mockConnect);

    try {
      var v = await pool.start();
      // expect v == null
      print('started');

      var c = await pool.connect();

      print('connected');


    } catch (ex, st) {
      print('failed');
      print(ex);
      print(st);
    }
  //});
}