import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/postgresql_pool_async.dart';
import 'package:postgresql/postgresql_pool_async_impl.dart';
import 'postgresql_mock.dart';


main() {
  mockLogger = (msg) => print(msg);

  test('Test pool', () {
    testPool()
      .then(expectAsync((v) { print('done'); }));
  });
}


Future testPool() async {
    var mockConnection = new MockConnection()
      ..onQuery = (sql, values) {
        if (sql == 'select pg_backend_pid()') return queryResults([[42]]);
        if (sql == 'select true') return queryResults([[true]]);
        print('other query: $sql');
      };
    var mockConnect = (uri, settings) => new Future.value(mockConnection);
    int minConnections = 2;
    var settings = new PoolSettings(minConnections: minConnections);
    var pool = new PoolImpl('foo', settings, mockConnect);

    try {
      print('created');
      pool.getConnections().forEach(print);

      expect(pool.getConnections(), isEmpty);

      var v = await pool.start();

      expect(v, isNull);
      expect(pool.getConnections().length, equals(minConnections));
      expect(pool.getConnections().where((c) => c.state == available).length,
          equals(minConnections));

      print('started');
      pool.getConnections().forEach(print);

      var c = await pool.connect();

      print('connected');
      pool.getConnections().forEach(print);

      c.close();

      print('closed');
      pool.getConnections().forEach(print);

    } catch (ex, st) {
      print('failed');
      print(ex);
      print(st);
    }
}