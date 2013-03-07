library postgresql_test;

import 'dart:async';
import 'package:unittest/unittest.dart';
import 'package:postgresql/postgresql.dart';

main() {
  var username = 'testdb';
  var database = 'testdb';
  var password = 'password';
  
  group('Connect', () {
    
    test('Connect', () {
      connect(username, database, password)
        .then(expectAsync1((c) {
          c.close();
        }));
    });
    
    test('Connect failure - incorrect password', () {
      connect(username, database, 'boom!')
        .then((c) => throw new Exception('Should not be reached.'),
            onError: expectAsync1((err) { /* boom! */ }));
    });
    
    // Should fail with a message like:
    // AsyncError: 'SocketIOException: OS Error: Connection refused, errno = 111'
    test('Connect failure - incorrect port', () {
      connect(username, database, password, port: 32423423)
        .then((c) => throw new Exception('Should not be reached.'),
            onError: expectAsync1((err) { /* boom! */ }));
    });
    
    test('Connect failure - connect to http server', () {
      connect(username, database, password, host: 'google.com', port: 80)
        .then((c) => throw new Exception('Should not be reached.'),
            onError: expectAsync1((err) { /* boom! */ }));
    });
    
  });
  
  group('Close', () {
    test('Close multiple times.', () {
      connect(username, database, password).then((conn) {
        conn.close();
        conn.close();
        new Future.delayed(new Duration(milliseconds: 20))
          .then((_) { conn.close(); });
      });
    });
    
    
    test('Query on closed connection.', () {
      connect(username, database, password).then((conn) {
        conn.close();
        conn.query("select 'blah'").toList()
          .then((_) => throw new Exception('Should not be reached.'))
          .catchError(expectAsync1((e) {}));
      });
    });
    
    test('Execute on closed connection.', () {
      connect(username, database, password).then((conn) {
        conn.close();
        conn.execute("select 'blah'")
          .then((_) => throw new Exception('Should not be reached.'))
          .catchError(expectAsync1((e) {}));
      });
    });
    
  });
  
  group('Query', () {
    
    Connection conn;
    
    setUp(() {
      return connect(username, database, password).then((c) => conn = c);
    });
    
    tearDown(() {
      if (conn != null) conn.close();
    });
  
    test('Invalid sql statement', () {
      conn.query('elect 1').toList().then(
          (rows) => throw new Exception('Should not be reached.'),
          onError: expectAsync1((err) { /* boom! */ }));
    });
    
    test('Null sql statement', () {
      conn.query(null).toList().then(
          (rows) => throw new Exception('Should not be reached.'),
          onError: expectAsync1((err) { /* boom! */ }));
    });
    
    test('Empty sql statement', () {
      conn.query('').toList().then(
          (rows) => throw new Exception('Should not be reached.'),
          onError: expectAsync1((err) { /* boom! */ }));
    });
    
    test('Whitespace only sql statement', () {
      conn.query('  ').toList().then(
          expectAsync1((rows) => expect(rows.length, 0)),
          onError: (err) { throw new Exception('Should not be reached.'); });
    });
    
    test('Empty multi-statement', () {
      conn.query('''
        select 'bob';
        ;
        select 'jim';
      ''').toList().then(
          expectAsync1((rows) => expect(rows.length, 2)),
          onError: (err) { throw new Exception('Should not be reached.'); });
    });
    
    test('Query queueing', () {

      conn.query('select 1').toList().then(
          expectAsync1((rows) {
            expect(rows[0][0], equals(1));
          })
      );
      
      conn.query('select 2').toList().then(
          expectAsync1((rows) {
            expect(rows[0][0], equals(2));
          })
      );
      
      conn.query('select 3').toList().then(
          expectAsync1((rows) {
            expect(rows[0][0], equals(3));
          })
      );
    });
    
    test('Query queueing with error', () {

      conn.query('elect 1').toList().then(
          (rows) => throw new Exception('Should not be reached.'),
          onError: expectAsync1((err) { /* boom! */ }));
      
      conn.query('select 2').toList().then(
          expectAsync1((rows) {
            expect(rows[0][0], equals(2));
          })
      );
      
      conn.query('select 3').toList().then(
          expectAsync1((rows) {
            expect(rows[0][0], equals(3));
          })
      );
    });
    
    test('Multiple queries in a single sql statement', () {
      conn.query('select 1; select 2; select 3;').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(1));
          expect(rows[1][0], equals(2));
          expect(rows[2][0], equals(3));
        })
      );
    });
  });
  
  group('Data types', () {
    
    Connection conn;
    
    setUp(() {
      return connect(username, database, password).then((c) => conn = c);
    });
    
    tearDown(() {
      if (conn != null) conn.close();
    });
    
    test('Select String', () {
      conn.query("select 'blah'").toList().then(
        expectAsync1((list) => expect(list[0][0], equals('blah')))
      );
    });
    
    test('Select int', () {
      conn.query('select 1, -1').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(1));
          expect(rows[0][1], equals(-1));
        })
      );
    });
    
    //FIXME Decimals not implemented yet.
    test('Select number', () {
      conn.query('select 1.1').toList().then(
        expectAsync1((rows) => expect(rows[0][0], equals('1.1')))
      );
    });
    
    test('Select boolean', () {
      conn.query('select true, false').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(true));
          expect(rows[0][1], equals(false));
        })
      );
    });
    
    test('Select null', () {
      conn.query('select null').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(null));
        })
      );
    });
    
    test('Select int 2', () {

      conn.execute('create temporary table dart_unit_test (a int2, b int4, c int8)');
      conn.execute('insert into dart_unit_test values (1, 2, 3)');
      conn.execute('insert into dart_unit_test values (-1, -2, -3)');
      conn.execute('insert into dart_unit_test values (null, null, null)');
      
      conn.query('select a, b, c from dart_unit_test').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(1));
          expect(rows[0][1], equals(2));
          expect(rows[0][2], equals(3));
          
          expect(rows[1][0], equals(-1));
          expect(rows[1][1], equals(-2));
          expect(rows[1][2], equals(-3));
          
          expect(rows[2][0], equals(null));
          expect(rows[2][1], equals(null));
          expect(rows[2][2], equals(null));
        })
      );
    });
    
    test('Select timestamp', () {

      conn.execute('create temporary table dart_unit_test (a timestamp)');
      conn.execute("insert into dart_unit_test values ('1979-12-20 09:00')");
      
      conn.query('select a from dart_unit_test').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(new DateTime(1979, 12, 20, 9)));
        })
      );
    });
    
    test('Select timestamp', () {

      conn.execute('create temporary table dart_unit_test (a timestamp)');
      conn.execute("insert into dart_unit_test values ('1979-12-20 09:00')");
      
      conn.query('select a from dart_unit_test').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(new DateTime(1979, 12, 20, 9)));
        })
      );
    });
    
    test('Select DateTime', () {

      conn.execute('create temporary table dart_unit_test (a date)');
      conn.execute("insert into dart_unit_test values ('1979-12-20')");
      
      conn.query('select a from dart_unit_test').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(new DateTime(1979, 12, 20)));
        })
      );
    });
    
    test('Select double', () {

      conn.execute('create temporary table dart_unit_test (a float4, b float8)');
      conn.execute("insert into dart_unit_test values (1.1, 2.2)");
      
      conn.query('select a, b from dart_unit_test').toList().then(
        expectAsync1((rows) {
          expect(rows[0][0], equals(1.1.toDouble()));
          expect(rows[0][1], equals(2.2.toDouble()));
        })
      );
    });
    
    //TODO
    // numeric (Need a BigDecimal type).
    // time
    // interval
    // timestamp and date with a timezone offset.
    
  });
  
  group('Execute', () {
    
    Connection conn;
    
    setUp(() {
      return connect(username, database, password).then((c) => conn = c);
    });
    
    tearDown(() {
      if (conn != null) conn.close();
    });
    
    test('Rows affected', () {
      conn.execute('create temporary table dart_unit_test (a int)');
      
      conn.execute('insert into dart_unit_test values (1), (2), (3)').then(
          expectAsync1((rowsAffected) {
            expect(rowsAffected, equals(3));
          })
      );
      
      conn.execute('update dart_unit_test set a = 5 where a = 1').then(
          expectAsync1((rowsAffected) {
            expect(rowsAffected, equals(1));
          })
      );
      
      conn.execute('delete from dart_unit_test where a > 2').then(
          expectAsync1((rowsAffected) {
            expect(rowsAffected, equals(2));
          })
      );
    });
    
  });
  
  group('PgException', () {
    
    Connection conn;
    
    setUp(() {
      return connect(username, database, password).then((c) => conn = c);
    });
    
    tearDown(() {
      if (conn != null) conn.close();
    });
  
    // This test depends on the locale settings of the postgresql server.
    test('Error information for invalid sql statement', () {
      conn.query('elect 1').toList().then(
          (rows) => throw new Exception('Should not be reached.'),
          onError: expectAsync1((err) { 
            expect(err.error.severity, equals('ERROR'));
            expect(err.error.code, equals('42601'));
            expect(err.error.position, equals(1));
          }));
    });
  });
}

