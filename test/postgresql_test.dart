import 'dart:async';
import 'dart:io';
import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/**
 * Loads configuration from yaml file into [Settings].
 */
Settings loadSettings() {
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
  return new Settings.fromMap(map);
}

main() {
  String validUri = loadSettings().toUri();

  group('Connect', () {
    test('Connect', () async {
      var c = await connect(validUri);
      c.close();
    });

    // Make travis happy by cheating.
    // test('Connect failure - incorrect password', () {
    //   var map = loadSettings().toMap();
    //   map['password'] = 'WRONG';
    //   var uri = new Settings.fromMap(map).toUri();

    //   connect(uri).then((c) => throw new Exception('Should not be reached.'),
    //     onError: expectAsync((err) { /* boom! */ }));
    // });

    //Should fail with a message like:settings.toUri()
    //AsyncError: 'SocketIOException: OS Error: Connection refused, errno = 111'
    test('Connect failure - incorrect port', () {
      var map = loadSettings().toMap();
      map['port'] = 9037;
      var uri = new Settings.fromMap(map).toUri();

      connect(uri).then((c) => throw new Exception('Should not be reached.'),
          onError: expectAsync((err) {/* boom! */}));
    });

    test('Connect failure - connect to http server', () {
      var uri = 'postgresql://user:pwd@google.com:80/database';
      connect(uri).then((c) => throw new Exception('Should not be reached.'),
          onError: expectAsync((err) {/* boom! */}));
    });
  });

  group('Close', () {
    test('Close multiple times.', () {
      connect(validUri).then((conn) {
        conn.close();
        conn.close();
        new Future.delayed(new Duration(milliseconds: 20)).then((_) {
          conn.close();
        });
      });
    });

    test('Query on closed connection.', () {
      var cb = expectAsync((e) {});
      connect(validUri).then((conn) {
        conn.close();
        conn
            .query("select 'blah'")
            .toList()
            .then((_) => throw new Exception('Should not be reached.'))
            .catchError(cb);
      });
    });

    test('Execute on closed connection.', () {
      var cb = expectAsync((e) {});
      connect(validUri).then((conn) {
        conn.close();
        conn
            .execute("select 'blah'")
            .then((_) => throw new Exception('Should not be reached.'))
            .catchError(cb);
      });
    });
  });

  group('Query', () {
    Connection conn;

    setUp(() {
      return connect(validUri).then((c) => conn = c);
    });

    tearDown(() {
      if (conn != null) conn.close();
    });

    test('Invalid sql statement', () {
      conn
          .query('elect 1')
          .toList()
          .then((rows) => throw new Exception('Should not be reached.'),
              onError: expectAsync((err) {/* boom! */}));
    });

    test('Null sql statement', () {
      conn
          .query(null)
          .toList()
          .then((rows) => throw new Exception('Should not be reached.'),
              onError: expectAsync((err) {/* boom! */}));
    });

    test('Empty sql statement', () {
      conn
          .query('')
          .toList()
          .then((rows) => throw new Exception('Should not be reached.'),
              onError: expectAsync((err) {/* boom! */}));
    });

    test('Whitespace only sql statement', () async {
      var rows = await conn.query('  ').toList();
      expect(rows.length, 0);
    });

    test('Empty multi-statement', () async {
      var rows = await conn.query('''
        select 'bob';
        ;
        select 'jim';
      ''').toList();
      expect(rows.length, 2);
    });

    test('Query queueing', () async {
      var rows = await conn.query('select 1').toList();
      expect(rows[0][0], equals(1));

      rows = await conn.query('select 2').toList();
      expect(rows[0][0], equals(2));

      rows = await conn.query('select 3').toList();
      expect(rows[0][0], equals(3));
    });

    test('Query queueing with error', () async {
      try {
        await conn.query('elect 1').toList();
        fail('Should not be reached');
      } catch (err) {}

      var rows = await conn.query('select 2').toList();
      expect(rows[0][0], equals(2));

      rows = await conn.query('select 3').toList();
      expect(rows[0][0], equals(3));
    });

    test('Multiple queries in a single sql statement', () async {
      var rows = await conn.query('select 1; select 2; select 3;').toList();
      expect(rows[0][0], equals(1));
      expect(rows[1][0], equals(2));
      expect(rows[2][0], equals(3));
    });

    test('Substitution', () async {
      var rows = await conn.query(
          'select @num, @num:text, @num:real, '
          '@int, @int:text, @int:int, '
          '@string, '
          '@datetime, @datetime:date, @datetime:timestamp, '
          '@boolean, @boolean_false, @boolean_null',
          {
            'num': 1.2,
            'int': 3,
            'string': 'bob\njim',
            'datetime': new DateTime(2013, 1, 1),
            'boolean': true,
            'boolean_false': false,
            'boolean_null': null,
          }).toList();
      expect(rows.length, 1);
    });
  });

  group('Data types', () {
    Connection conn;

    setUp(() {
      return connect(validUri, timeZone: 'UTC').then((c) => conn = c);
    });

    tearDown(() {
      if (conn != null) conn.close();
    });

    test('Select String', () async {
      var rows = await conn.query("select 'blah'").toList();
      expect(rows[0][0], equals('blah'));
    });

    // Postgresql database doesn't allow null bytes in strings.
    test('Select String with null character.', () {
      conn
          .query("select '(\u0000)'")
          .toList()
          .then((r) => fail('Expected query failure.'))
          .catchError(expectAsync((e) => expect(e, isException)));
    });

    test('Select UTF8 String', () async {
      var list = await conn.query("select '☺'").toList();
      expect(list[0][0], equals('☺'));
    });

    test('Select int', () async {
      var rows = await conn.query('select 1, -1').toList();
      expect(rows[0][0], equals(1));
      expect(rows[0][1], equals(-1));
    });

    //FIXME Decimals not implemented yet.
    test('Select number', () async {
      var rows = await conn.query('select 1.1').toList();
      expect(rows[0][0], equals('1.1'));
    });

    test('Select boolean', () async {
      var rows = await conn.query('select true, false').toList();
      expect(rows[0][0], equals(true));
      expect(rows[0][1], equals(false));
    });

    test('Select null', () async {
      var rows = await conn.query('select null').toList();
      expect(rows[0][0], equals(null));
    });

    test('Select int 2', () async {
      conn.execute(
          'create temporary table dart_unit_test (a int2, b int4, c int8)');
      conn.execute('insert into dart_unit_test values (1, 2, 3)');
      conn.execute('insert into dart_unit_test values (-1, -2, -3)');
      conn.execute('insert into dart_unit_test values (null, null, null)');

      var rows =
          await conn.query('select a, b, c from dart_unit_test').toList();
      expect(rows[0][0], equals(1));
      expect(rows[0][1], equals(2));
      expect(rows[0][2], equals(3));

      expect(rows[1][0], equals(-1));
      expect(rows[1][1], equals(-2));
      expect(rows[1][2], equals(-3));

      expect(rows[2][0], equals(null));
      expect(rows[2][1], equals(null));
      expect(rows[2][2], equals(null));
    });

    test('Select timestamp with milliseconds', () async {
      var t0 = new DateTime.utc(1979, 12, 20, 9, 0, 0, 0);
      var t1 = new DateTime.utc(1979, 12, 20, 9, 0, 0, 9);
      var t2 = new DateTime.utc(1979, 12, 20, 9, 0, 0, 10);
      var t3 = new DateTime.utc(1979, 12, 20, 9, 0, 0, 99);
      var t4 = new DateTime.utc(1979, 12, 20, 9, 0, 0, 100);
      var t5 = new DateTime.utc(1979, 12, 20, 9, 0, 0, 999);

      conn.execute('create temporary table dart_unit_test (a timestamp)');

      var insert = 'insert into dart_unit_test values (@time)';
      conn.execute(insert, {"time": t0});
      conn.execute(insert, {"time": t1});
      conn.execute(insert, {"time": t2});
      conn.execute(insert, {"time": t3});
      conn.execute(insert, {"time": t4});
      conn.execute(insert, {"time": t5});

      var rows = await conn
          .query('select a from dart_unit_test order by a asc')
          .toList();
      expect((rows[0][0] as DateTime).difference(t0), Duration.ZERO);
      expect((rows[1][0] as DateTime).difference(t1), Duration.ZERO);
      expect((rows[2][0] as DateTime).difference(t2), Duration.ZERO);
      expect((rows[3][0] as DateTime).difference(t3), Duration.ZERO);
      expect((rows[4][0] as DateTime).difference(t4), Duration.ZERO);
      expect((rows[5][0] as DateTime).difference(t5), Duration.ZERO);
    });

    test("Insert timestamp with milliseconds and timezone", () async {
      var t0 = new DateTime.now();

      conn.execute('create temporary table dart_unit_test (a timestamptz)');

      conn.execute("insert into dart_unit_test values (@time)", {"time": t0});

      var rows = await conn.query("select a from dart_unit_test").toList();
      expect((rows[0][0] as DateTime).difference(t0), Duration.ZERO);
    });

    test(
        "Insert and select timestamp and timestamptz from using UTC and local DateTime",
        () async {
      var localNow = new DateTime.now();
      var utcNow = new DateTime.now().toUtc();

      conn.execute(
          'create temporary table dart_unit_test (a timestamp, b timestamptz)');
      conn.execute(
          "insert into dart_unit_test values (@timestamp, @timestamptz)",
          {"timestamp": utcNow, "timestamptz": localNow});

      var rows = await conn.query("select a, b from dart_unit_test").toList();
      expect((rows[0][0] as DateTime).difference(utcNow), Duration.ZERO,
          reason: "UTC -> Timestamp not the same");
      expect((rows[0][1] as DateTime).difference(localNow), Duration.ZERO,
          reason: "Local -> Timestamptz not the same");
    });

    test("Multiple Timezone encoding/decoding", () async {
      var bdayGMT = DateTime.parse("1983-11-06T06:01:00.123+00:00");
      var bdayPositiveTZ = DateTime.parse("1983-11-06T06:01:00.123+04:00");
      var bdayNegativeTZ = DateTime.parse("1983-11-06T06:01:00.123-04:00");
      var bdayPositiveMinuteTZ =
          DateTime.parse("1983-11-06T06:01:00.123+01:30");
      var bdayNegativeMinuteTZ =
          DateTime.parse("1983-11-06T06:01:00.123-01:15");

      conn.execute('create temporary table dart_unit_test (a timestamptz)');
      conn.execute("insert into dart_unit_test values (@a)", {"a": bdayGMT});
      conn.execute(
          "insert into dart_unit_test values (@a)", {"a": bdayPositiveTZ});
      conn.execute(
          "insert into dart_unit_test values (@a)", {"a": bdayNegativeTZ});
      conn.execute("insert into dart_unit_test values (@a)",
          {"a": bdayPositiveMinuteTZ});
      conn.execute("insert into dart_unit_test values (@a)",
          {"a": bdayNegativeMinuteTZ});

      var rows = await conn.query("select a from dart_unit_test").toList();
      expect((rows[0][0] as DateTime).difference(bdayGMT), Duration.ZERO,
          reason: "GMT");
      expect((rows[1][0] as DateTime).difference(bdayPositiveTZ), Duration.ZERO,
          reason: "Positive Hour TZ");
      expect((rows[2][0] as DateTime).difference(bdayNegativeTZ), Duration.ZERO,
          reason: "Negative Hour TZ");
      expect((rows[3][0] as DateTime).difference(bdayPositiveMinuteTZ),
          Duration.ZERO,
          reason: "Positive Minute TZ");
      expect((rows[4][0] as DateTime).difference(bdayNegativeMinuteTZ),
          Duration.ZERO,
          reason: "Negative Minute TZ");
    });

    test("Selected null timestamp DateTime", () async {
      var dt = null;

      conn.execute('create temporary table dart_unit_test (a timestamp)');
      conn.execute("insert into dart_unit_test values (@time)", {"time": dt});

      var rows = await conn.query('select a from dart_unit_test').toList();
      expect(rows[0], isNotNull);
      expect(rows[0][0], isNull);
    });

    test('Select DateTime', () async {
      conn.execute('create temporary table dart_unit_test (a date)');
      conn.execute("insert into dart_unit_test values ('1979-12-20')");

      var rows = await conn.query('select a from dart_unit_test').toList();
      expect(rows[0][0], equals(new DateTime.utc(1979, 12, 20)));
    });

    // These tests will handle timestamps outside of the explicitly supported ISO8601 range.

    test("DateTime Edge Cases", () async {
      conn.execute('create temporary table dart_unit_test (a timestamp)');
      conn.execute("insert into dart_unit_test (a) values (@t)",
          {"t": new DateTime(10000).toUtc()});
      conn.execute("insert into dart_unit_test (a) values (@t)",
          {"t": new DateTime(-10).toUtc()});

      var rows = await conn.query("select a from dart_unit_test").toList();
      expect((rows[0][0] as DateTime).difference(new DateTime(10000).toUtc()),
          Duration.ZERO);
      expect((rows[1][0] as DateTime).difference(new DateTime(-10).toUtc()),
          Duration.ZERO);
    });

    test('Select double', () async {
      conn.execute(
          'create temporary table dart_unit_test (a float4, b float8)');
      conn.execute("insert into dart_unit_test values (1.1, 2.2)");
      conn.execute("insert into dart_unit_test values "
          "(-0.0, -0.0), ('NaN', 'NaN'), ('Infinity', 'Infinity'), "
          "('-Infinity', '-Infinity');");
      conn.execute(
          "insert into dart_unit_test values "
          "(@0, @0), (@1, @1), (@2, @2), (@3, @3), (@4, @4), (@5, @5);",
          [
            -0.0,
            double.NAN,
            double.INFINITY,
            double.NEGATIVE_INFINITY,
            1e30,
            1e-30
          ]);

      var rows = await conn.query('select a, b from dart_unit_test').toList();
      expect(rows[0][0], equals(1.1.toDouble()));
      expect(rows[0][1], equals(2.2.toDouble()));

      expect(rows[1][0], equals(-0.0));
      expect(rows[1][1], equals(-0.0));

      expect(rows[2][0], isNaN);
      expect(rows[2][1], isNaN);

      expect(rows[3][0], equals(double.INFINITY));
      expect(rows[3][1], equals(double.INFINITY));

      expect(rows[4][0], equals(double.NEGATIVE_INFINITY));
      expect(rows[4][1], equals(double.NEGATIVE_INFINITY));

      expect(rows[5][0], equals(-0.0));
      expect(rows[5][1], equals(-0.0));

      expect(rows[6][0], isNaN);
      expect(rows[6][1], isNaN);

      expect(rows[7][0], equals(double.INFINITY));
      expect(rows[7][1], equals(double.INFINITY));

      expect(rows[8][0], equals(double.NEGATIVE_INFINITY));
      expect(rows[8][1], equals(double.NEGATIVE_INFINITY));

      expect(rows[9][0], equals(1e30));
      expect(rows[9][1], equals(1e30));

      expect(rows[10][0], equals(1e-30));
      expect(rows[10][1], equals(1e-30));
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
      return connect(validUri).then((c) => conn = c);
    });

    tearDown(() {
      if (conn != null) conn.close();
    });

    test('Rows affected', () async {
      conn.execute('create temporary table dart_unit_test (a int)');

      int rowsAffected =
          await conn.execute('insert into dart_unit_test values (1), (2), (3)');
      expect(rowsAffected, equals(3));

      rowsAffected =
          await conn.execute('update dart_unit_test set a = 5 where a = 1');
      expect(rowsAffected, equals(1));
      rowsAffected =
          await conn.execute('delete from dart_unit_test where a > 2');
      expect(rowsAffected, equals(2));
      rowsAffected = await conn.execute('create temporary table bob (a int)');
      expect(rowsAffected, equals(null));
      rowsAffected = await conn.execute('''
        select 'one';
        create temporary table jim (a int);
        create temporary table sally (a int);
      ''');
      expect(rowsAffected, equals(null));
    });
  });

  group('PgException', () {
    Connection conn;

    setUp(() {
      return connect(validUri).then((c) => conn = c);
    });

    tearDown(() {
      if (conn != null) conn.close();
    });

    // This test depends on the locale settings of the postgresql server.
    test('Error information for invalid sql statement', () {
      conn
          .query('elect 1')
          .toList()
          .then((rows) => throw new Exception('Should not be reached.'),
              onError: expectAsync((err) {
        expect(err, new isInstanceOf<PostgresqlException>());
        expect(err.serverMessage, isNotNull);
        expect(err.serverMessage.severity, equals('ERROR'));
        expect(err.serverMessage.code, equals('42601'));
        expect(err.serverMessage.position, equals("1"));
      }));
    });
  });

  group('Object mapping', () {
    Connection conn;

    setUp(() {
      return connect(validUri).then((c) => conn = c);
    });

    tearDown(() {
      if (conn != null) conn.close();
    });

    test('Map person.', () async {
      var result = await conn
          .query('''
        select 'Greg' as firstname, 'Lowe' as lastname;
        select 'Bob' as firstname, 'Jones' as lastname;
      ''')
          .map((row) => new Person()
            ..firstname = row.firstname
            ..lastname = row.lastname)
          .toList();
      expect(result.last.lastname, 'Jones');
    });

    test('Map person immutable.', () async {
      var result = await conn
          .query('''
          select 'Greg' as firstname, 'Lowe' as lastname;
          select 'Bob' as firstname, 'Jones' as lastname;
      ''')
          .map((row) => new ImmutablePerson(row.firstname, row.lastname))
          .toList();
      expect(result.last.lastname, 'Jones');
    });
  });

  group('Transactions', () {
    Connection conn1;
    Connection conn2;

    setUp(() {
      return connect(validUri)
          .then((c) => conn1 = c)
          .then((_) => connect(validUri))
          .then((c) => conn2 = c)
          .then((_) => conn1.execute(
              'create table if not exists tx (val int); delete from tx;')); // if not exists requires pg9.1
    });

    tearDown(() {
      if (conn1 != null) conn1.close();
      if (conn2 != null) conn2.close();
    });

    test('simple query', () {
      var cb = expectAsync((_) {});
      conn1.runInTransaction(() {
        return conn1.query("select 'oi'").toList().then((result) {
          expect(result[0][0], equals('oi'));
        });
      }).then(cb);
    });

    test('simple query read committed', () {
      var cb = expectAsync((_) {});
      conn1.runInTransaction(() {
        return conn1.query("select 'oi'").toList().then((result) {
          expect(result[0][0], equals('oi'));
        });
      }, readCommitted).then(cb);
    });

    test('simple query repeatable read', () {
      var cb = expectAsync((_) {});
      conn1.runInTransaction(() {
        return conn1.query("select 'oi'").toList().then((result) {
          expect(result[0][0], equals('oi'));
        });
      }, readCommitted).then(cb);
    });

    test('simple query serializable', () {
      var cb = expectAsync((_) {});
      conn1.runInTransaction(() {
        return conn1.query("select 'oi'").toList().then((result) {
          expect(result[0][0], equals('oi'));
        });
      }, serializable).then(cb);
    });

    test('rollback', () {
      var cb = expectAsync((_) {});

      conn1
          .runInTransaction(() {
            return conn1
                .execute('insert into tx values (42)')
                .then((_) => conn1.query('select val from tx').toList())
                .then((result) {
              expect(result[0][0], equals(42));
            }).then((_) => throw new Exception('Boom!'));
          })
          .catchError((e) => print('Ignore: $e'))
          .then((_) => conn1.query('select val from tx').toList())
          .then((result) {
            expect(result, equals([]));
          })
          .then(cb);
    });

    test('type converter', () {
      connect(validUri, typeConverter: new TypeConverter.raw()).then((c) {
        c.query('select true, 42').toList().then((result) {
          expect(result[0][0], equals('t'));
          expect(result[0][1], equals('42'));
          c.close();
        });
      });
    });

    //TODO test Row.toList() and Row.toMap()

    test('getColumns', () {
      conn1.query('select 42 as val').toList().then(expectAsync((rows) {
        rows.forEach((row) {
          expect(row.getColumns()[0].name, 'val');
        });
      }));
    });

    test('isolation', () {
      var cb = expectAsync((_) {});
      conn1.runInTransaction(() async {
        int count = await conn1.execute('insert into tx values (42)');
        expect(count, 1, reason: "single value should be added");
        List result = await (await conn1.query('select val from tx')).toList();
        expect(result[0][0], equals(42));
        await conn2.runInTransaction(() async {
          await conn2.execute('insert into tx values (43)');

          ///Read committed conn2 should not see 42 added by conn1
          List result2 =
              await (await conn2.query('select min(val) from tx')).toList();
          expect(result2[0][0], equals(43));
        });
      }).then(cb);
    });
  });
}

class Person {
  String firstname;
  String lastname;
  String toString() => '$firstname $lastname';
}

class ImmutablePerson {
  ImmutablePerson(this.firstname, this.lastname);
  final String firstname;
  final String lastname;
  String toString() => '$firstname $lastname';
}
