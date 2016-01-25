import 'dart:io';
import 'package:postgresql/pool.dart';
import 'package:postgresql/postgresql.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

Settings loadSettings(){
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
  return new Settings.fromMap(map);
}

main() {

	test('Test missing user setting', () {
    expect(() => new Settings.fromMap(
        {'host': 'host', 'password': 'password', 'database': 'database'}),
        throwsA(predicate((e) => e is PostgresqlException)));
  });

  test('Test missing password setting', () {
    expect(() => new Settings.fromMap(
        {'host': 'host', 'user': 'user', 'database': 'database'}),
        throwsA(predicate((e) => e is PostgresqlException)));
  });

	test('Test missing database setting', () {
    expect(() => new Settings.fromMap(
        {'host': 'host', 'password': 'password', 'user': 'user'}),
        throwsA(predicate((e) => e is PostgresqlException)));
  });

	test('Valid settings', () {
    expect(new Settings.fromMap(
        {'user': 'user', 'password': 'password', 'host': 'host',
        'database': 'database'}).toUri(),
        equals('postgres://user:password@host:5432/database'));
  });

  test('Valid settings - empty password', () {
    expect(new Settings.fromMap(
        {'user': 'user', 'password': '', 'host': 'host',
          'database': 'database'}).toUri(),
        equals('postgres://user@host:5432/database'));

    expect(new Settings.fromMap(
        {'user': 'user', 'password': null, 'host': 'host',
          'database': 'database'}).toUri(),
        equals('postgres://user@host:5432/database'));
  });

  test('Valid Uri', () {
    expect(new Settings.fromUri('postgres://user:password@host:5433/database').toMap(),
        equals({'host': 'host', 'user': 'user', 'password': 'password',
          'database': 'database', 'port': 5433}));

    expect(new Settings.fromUri('postgres://user:password@host/database').toMap(),
        equals({'host': 'host', 'user': 'user', 'password': 'password',
          'database': 'database', 'port': 5432}));

    expect(new Settings.fromUri('postgres://user@host/database').toMap(),
        equals({'host': 'host', 'user': 'user', 'password': '',
          'database': 'database', 'port': 5432}));
  });

	test('Valid settings different port', () {
    expect(new Settings.fromMap({'host': 'host', 'user': 'user',
      'password': 'password', 'database': 'database', 'port': 5433}).toUri(),
        equals('postgres://user:password@host:5433/database'));
  });

  test('Missing password ok - from uri', () {
    expect(new Settings.fromUri('postgres://user@host/foo').password,
        equals(''));
  });

  test('String encoding', () {
    var m = {'host': 'ho st',
      'port': 5433,
      'user': 'us er',
      'password': 'pass word',
      'database': 'data base'};
    var uri = new Settings.fromMap(m).toUri();
    expect(uri, equals('postgres://us%20er:pass%20word@ho%20st:5433/data%20base'));

    var settings = new Settings.fromUri(uri);
    expect(settings.toMap(), equals(m));

    expect(new Settings.fromUri('postgres://us er:pass word@ho st:5433/data base').toUri().toString(),
        'postgres://us%20er:pass%20word@ho%20st:5433/data%20base');
  });

	test('Load settings from yaml file', () {
	  Settings s = loadSettings();
    expect(s.database, isNotNull);
	});
	
	test('Pool settings', () {
	  var uri = 'postgres://user:password@host:5432/database';
	  var s = new PoolSettings(databaseUri: uri);
	  expect(s.databaseUri, equals(uri));
	  var m = s.toMap();
	  expect(m['databaseUri'], equals(uri));
	  var s2 = new PoolSettings.fromMap(m);
	  expect(s2.databaseUri, equals(uri));
	});
	
	test('Pool settings', () {
	  var uri = 'postgres://user:password@host:5432/database';
	  var d = new Duration(seconds: 42);
	  var s = new PoolSettings(
	      databaseUri: uri,
	      minConnections: 20,
	      maxConnections: 20,
	      connectionTimeout: d,
	      establishTimeout: d,
	      idleTimeout: d,
	      leakDetectionThreshold: d,
	      maxLifetime: d,
	      poolName: "foo",
	      restartIfAllConnectionsLeaked: false,
	      startTimeout: d,
	      stopTimeout: d,
	      testConnections: false);
	  
	  _testPoolSetting(value, flatValue, getter, mapKey) {
       expect(getter(), equals(value));
       var m = s.toMap();
       expect(m[mapKey], equals(flatValue));
       expect(getter(), equals(value));    
     }
	  
	  _testPoolSetting(
	      'postgres://user:password@host:5432/database',
	      'postgres://user:password@host:5432/database',
	      () => s.databaseUri,
	      'databaseUri');
	  
    _testPoolSetting(
        20,
        20,
        () => s.minConnections,
        'minConnections');
    
    _testPoolSetting(
        d,
        '42s',
        () => s.connectionTimeout,
        'connectionTimeout');

    _testPoolSetting(
        d,
        '42s',
        () => s.establishTimeout,
        'establishTimeout');
 
    _testPoolSetting(
         d,
         '42s',
         () => s.idleTimeout,
         'idleTimeout');

    _testPoolSetting(
         d,
         '42s',
         () => s.leakDetectionThreshold,
         'leakDetectionThreshold');
    
    _testPoolSetting(
             d,
             '42s',
             () => s.maxLifetime,
             'maxLifetime');
        

    _testPoolSetting(
             d,
             '42s',
             () => s.startTimeout,
             'startTimeout');
    
    _testPoolSetting(
                 d,
                 '42s',
                 () => s.stopTimeout,
                 'stopTimeout');
    
    _testPoolSetting(
        'foo',
        'foo',
        () => s.poolName,
        'poolName');
    
    _testPoolSetting(
        false,
        false,
        () => s.restartIfAllConnectionsLeaked,
        'restartIfAllConnectionsLeaked');

    _testPoolSetting(
        false,
        false,
        () => s.testConnections,
        'testConnections');
	});
	
}

