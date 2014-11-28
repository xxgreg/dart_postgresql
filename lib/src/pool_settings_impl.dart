library postgresql.pool.pool_settings_impl;

import 'package:postgresql/pool.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/src/duration_format.dart';

final PoolSettingsImpl _default = new PoolSettingsImpl();

class PoolSettingsImpl implements PoolSettings {
  
  PoolSettingsImpl({
      this.databaseUri,
      String poolName,
      this.minConnections: 2,
      this.maxConnections: 10,
      this.startTimeout: const Duration(seconds: 30),
      this.stopTimeout: const Duration(seconds: 30),
      this.establishTimeout: const Duration(seconds: 30),
      this.connectionTimeout: const Duration(seconds: 30),
      this.idleTimeout: const Duration(minutes: 10), //FIXME not sure what this default should be
      this.maxLifetime: const Duration(hours: 1),
      this.leakDetectionThreshold: null, // Disabled by default.
      this.testConnections: true,
      this.restartIfAllConnectionsLeaked: false})
        : poolName = poolName != null ? poolName : 'pgpool${_sequence++}';


 // Ugly work around for passing defaults from Pool constructor.
 factory PoolSettingsImpl.withDefaults({
        String databaseUri,
        String poolName,
        int minConnections,
        int maxConnections,
        Duration startTimeout,
        Duration stopTimeout,
        Duration establishTimeout,
        Duration connectionTimeout,
        Duration idleTimeout,
        Duration maxLifetime,
        Duration leakDetectionThreshold,
        bool testConnections,
        bool restartIfAllConnectionsLeaked}) {
  
   return new PoolSettingsImpl(
     databaseUri: databaseUri,
     poolName: poolName,
     minConnections: minConnections == null ? _default.minConnections : minConnections,
     maxConnections: maxConnections == null ? _default.maxConnections : maxConnections,
     startTimeout: startTimeout == null ? _default.startTimeout : startTimeout,
     stopTimeout: stopTimeout == null ? _default.stopTimeout : stopTimeout,
     establishTimeout: establishTimeout == null ? _default.establishTimeout : establishTimeout,
     connectionTimeout: connectionTimeout == null ? _default.connectionTimeout : connectionTimeout,
     idleTimeout: idleTimeout == null ? _default.idleTimeout : idleTimeout,
     maxLifetime: maxLifetime == null ? _default.maxLifetime : maxLifetime,
     leakDetectionThreshold: leakDetectionThreshold == null ? _default.leakDetectionThreshold : leakDetectionThreshold,
     testConnections: testConnections == null ? _default.testConnections : testConnections,
     restartIfAllConnectionsLeaked: restartIfAllConnectionsLeaked == null ? _default.restartIfAllConnectionsLeaked : restartIfAllConnectionsLeaked); 
 }

  // Ids will be unique for this isolate.
  static int _sequence = 1;

  
  final String databaseUri;
  final String poolName;
  final int minConnections;
  final int maxConnections;
  final Duration startTimeout;
  final Duration stopTimeout;
  final Duration establishTimeout;
  final Duration connectionTimeout;
  final Duration idleTimeout;
  final Duration maxLifetime;
  final Duration leakDetectionThreshold;
  final bool testConnections;
  final bool restartIfAllConnectionsLeaked;
  
  static final DurationFormat _durationFmt = new DurationFormat();
  
  factory PoolSettingsImpl.fromMap(Map map) {
    
    var uri = map['databaseUri'];
    
    if (uri == null) {
      try {
        uri = new pg.Settings.fromMap(map).toUri();
      } on FormatException catch (ex) { //TODO change to use a different exception type.
      }
    }
    
    fail(String msg) => throw new FormatException('Pool setting $msg');
    
    bool getBool(String field) {
      var value = map[field];
      if (value == null) return null;
      if (value is! bool)
        fail('$field requires boolean value was: ${value.runtimeType}.'); 
      return value;
    }

    int getInt(String field) {
      var value = map[field];
      if (value == null) return null;
      if (value is! int)
        fail('$field requires int value was: ${value.runtimeType}.'); 
      return value;
    }

    String getString(String field) {
      var value = map[field];
      if (value == null) return null;
      if (value is! String)
        fail('$field requires string value was: ${value.runtimeType}.'); 
      return value;
    }
    
    Duration getDuration(String field) {
      var value = map[field];
      if (value == null) return null;
      fail2([_]) => fail('$field is not a duration string: "$value". Use this format: "120s".');
      if (value is! String) fail2(); 
      return _durationFmt.parse(value, onError: fail2);
    }
    
    var settings = new PoolSettingsImpl(
        databaseUri: uri,
        poolName: getString('poolName'),
        minConnections: getInt('minConnections'),
        maxConnections: getInt('maxConnections'),
        startTimeout: getDuration('startTimeout'),
        stopTimeout: getDuration('stopTimeout'),
        establishTimeout: getDuration('establishTimeout'),
        connectionTimeout: getDuration('connectionTimeout'),
        idleTimeout: getDuration('idleTimeout'),
        maxLifetime: getDuration('maxLifetime'),
        leakDetectionThreshold: getDuration('leakDetectionThreshold'),
        testConnections: getBool('testConnections'),
        restartIfAllConnectionsLeaked: getBool('restartIfAllConnectionsLeaked'));
    
    return settings;
  }
  
  Map toMap() {
    String fmt(Duration d) => d == null ? null : _durationFmt.format(d);    
    Map m = {'databaseUri': databaseUri};
    if (poolName != null) m['poolName'] = poolName;
    if (minConnections != null) m['minConnections'] = minConnections;
    if (maxConnections != null) m['maxConnections'] = maxConnections;
    if (startTimeout != null) m['startTimeout'] = fmt(startTimeout);
    if (stopTimeout != null) m['stopTimeout'] = fmt(stopTimeout);
    if (establishTimeout != null) m['establishTimeout'] = fmt(establishTimeout);
    if (connectionTimeout != null)
      m['connectionTimeout'] = fmt(connectionTimeout);
    if (idleTimeout != null) m['idleTimeout'] = fmt(idleTimeout);
    if (maxLifetime != null) m['maxLifetime'] = fmt(maxLifetime);
    if (leakDetectionThreshold != null)
      m['leakDetectionThreshold'] = fmt(leakDetectionThreshold);
    if (testConnections != null) m['testConnections'] = testConnections;
    if (restartIfAllConnectionsLeaked != null)
      m['restartIfAllConnectionsLeaked'] = restartIfAllConnectionsLeaked;
    return m;
  }
  
  Map toJson() => toMap();

}
