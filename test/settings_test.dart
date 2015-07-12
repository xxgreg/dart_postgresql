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
    var map = new Map();
    map['host'] = "dummy1";
    map['password'] = "dummy2";
    map['database'] = "dummy3";
    expect(() => new Settings.fromMap(map),
        throwsA(predicate((e) => e is PostgresqlException)));
  });

	test('Test missing password setting', () {
    var map = new Map();
    map['host'] = "dummy1";
    map['user'] = "dummy2";
    map['database'] = "dummy3";
    expect(() => new Settings.fromMap(map),
        throwsA(predicate((e) => e is PostgresqlException)));
  });

	test('Test missing database setting', () {
    var map = new Map();
    map['host'] = "dummy1";
    map['user'] = "dummy2";
    map['password'] = "dummy3";
    expect(() => new Settings.fromMap(map),
        throwsA(predicate((e) => e is PostgresqlException)));
  });

	test('Valid settings', () {
    var map = new Map();
    map['host'] = "host";
    map['user'] = "user";
    map['password'] = "password";
    map['database'] = "database";
    expect(new Settings.fromMap(map).toUri(), 'postgres://user:password@host:5432/database');
  });

	test('Valid settings different port', () {
    var map = new Map();
    map['host'] = "host";
    map['port'] = 5433;
    map['user'] = "user";
    map['password'] = "password";
    map['database'] = "database";
    expect(new Settings.fromMap(map).toUri(), 'postgres://user:password@host:5433/database');
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

