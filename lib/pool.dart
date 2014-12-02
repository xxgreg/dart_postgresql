library postgresql.pool;

import 'dart:async';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/src/pool_impl_cps.dart';
import 'package:postgresql/src/pool_settings_impl.dart';

/// A connection pool for PostgreSQL database connections.
abstract class Pool {
  
  /// See [PoolSettings] for a description of settings.
  factory Pool(String databaseUri,
   {String poolName,
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
    bool restartIfAllConnectionsLeaked,
    String applicationName,
    String timeZone,
    pg.TypeConverter typeConverter})
      
      => new PoolImpl(new PoolSettingsImpl.withDefaults(
              databaseUri: databaseUri,
              poolName: poolName,
              minConnections: minConnections,
              maxConnections: maxConnections,
              startTimeout: startTimeout,
              stopTimeout: stopTimeout,
              establishTimeout: establishTimeout,
              connectionTimeout: connectionTimeout,
              idleTimeout: idleTimeout,
              maxLifetime: maxLifetime,
              leakDetectionThreshold: leakDetectionThreshold,
              testConnections: testConnections,
              restartIfAllConnectionsLeaked: restartIfAllConnectionsLeaked,
              applicationName: applicationName,
              timeZone: timeZone),
            typeConverter);
  
  factory Pool.fromSettings(PoolSettings settings, {pg.TypeConverter typeConverter})
    => new PoolImpl(settings, typeConverter);
  
  Future start();
  Future stop();
  Future<pg.Connection> connect({String debugName});
  PoolState get state;
  Stream<pg.Message> get messages;
  List<PooledConnection> get connections;
  int get waitQueueLength;
  
  /// Depreciated. Use [stop]() instead.
  @deprecated void destroy();
}


/// Store settings for a PostgreSQL connection pool.
/// 
/// An example of loading the connection pool settings from yaml using the
/// [yaml package](https://pub.dartlang.org/packages/yaml): 
/// 
///     var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
///     var settings = new PoolSettings.fromMap(map);
///     var pool = new Pool.fromSettings(settings);

abstract class PoolSettings {
 
  factory PoolSettings({
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
      bool restartIfAllConnectionsLeaked,
      String applicationName,
      String timeZone}) = PoolSettingsImpl;
  
  factory PoolSettings.fromMap(Map map) = PoolSettingsImpl.fromMap;

  String get databaseUri;
  
  /// Pool name is used in log messages. It is helpful if there are multiple
  /// connection pools. Defaults to pgpoolX.
  String get poolName;

  /// Minimum number of connections. When the pool is started
  /// this is the number of connections that will initially be started. The pool
  /// will ensure that this number of connections is always running. In typical
  /// production settings, this should be set to be the same size as 
  /// maxConnections. Defaults to 5.
  int get minConnections;
  
  /// Maximum number of connections. The pool will not exceed
  /// this number of database connections. Defaults to 10. 
  int get maxConnections;
  
  /// If the pool cannot start within this time then return an
  /// error. Defaults to 30 seconds.
  Duration get startTimeout;
  
  /// If when stopping connections are not returned to the pool
  /// within this time, then they will be forefully closed. Defaults to 30
  /// seconds.
  Duration get stopTimeout;
  
  /// When the pool wants to establish a new database
  /// connection and it is not possible to complete within this time then a
  /// warning will be logged. Defaults to 30 seconds.
  Duration get establishTimeout;
  
  /// When client code calls Pool.connect(), and a 
  /// connection does not become available within this time, an error is
  /// returned. Defaults to 30 seconds.  
  Duration get connectionTimeout;
  
  /// If a connection has not been used for this ammount of time
  /// and there are more than the minimum number of connections in the pool,
  /// then this connection will be closed. Defaults to 10 minutes.  
  Duration get idleTimeout;

  /// At the time that a connection is released, if it is older
  /// than this time it will be closed. Defaults to 30 minutes.
  Duration get maxLifetime;
  
  /// If a connection is not returned to the pool 
  /// within this time after being obtained by pool.connect(), the a warning
  /// message will be logged. Defaults to null, off by default. This setting is
  /// useful for tracking down code which leaks connections by forgetting to
  /// call Connection.close() on them.
  Duration get leakDetectionThreshold;
  
  /// Perform a simple query to check if a connection is
  /// still valid before returning a connection from pool.connect(). Default is
  /// false.  
  bool get testConnections;
  
  /// Once the entire pool is full of leaked
  /// connections, close them all and restart the minimum number of connections.
  /// Defaults to false. This must be used in combination with the leak 
  /// detection threshold setting.  
  bool get restartIfAllConnectionsLeaked;
  
  /// The application name is displayed in the pg_stat_activity view.
  String get applicationName;
  
  /// Care is required when setting the time zone, this is generally not required,
  /// the default, if omitted, is to use the server provided default which will 
  /// typically be localtime or sometimes UTC. Setting the time zone to UTC will
  /// override the server provided default and all [DateTime] objects will be
  /// returned in UTC. In the case where the application server is on a different 
  /// host than the database, and the host's [DateTime]s should be in the host's
  /// localtime, then set this to the host's local time zone name. On linux 
  /// systems this can be obtained using:
  /// 
  ///     new File('/etc/timezone').readAsStringSync().trim()
  ///   
  String get timeZone;
  
  Map toMap();
  Map toJson();
}

//TODO change to enum once implemented.
class PoolState {
  const PoolState(this.name);
  final String name;
  toString() => name;

  static const PoolState initial = const PoolState('inital');
  static const PoolState starting = const PoolState('starting');
  static const PoolState running = const PoolState('running');
  static const PoolState stopping = const PoolState('stopping');
  static const PoolState stopped = const PoolState('stopped');
}

abstract class PooledConnection {
  
  /// The state of connection in the pool: available, closed, etc.
  PooledConnectionState get state;

  /// Time at which the physical connection to the database was established.
  DateTime get established;

  /// Time at which the connection was last obtained by a client.
  DateTime get obtained;

  /// Time at which the connection was last released by a client.
  DateTime get released;
  
  /// The pid of the postgresql handler.
  int get backendPid;

  /// The name passed to connect which is printed in error messages to help
  /// with debugging.
  String get debugName;

  /// A unique id that updated whenever the connection is obtained.
  int get useId;
  
  /// If a leak detection threshold is set, then this flag will be set on leaked
  /// connections.
  bool get isLeaked;

  /// The stacktrace at the time pool.connect() was last called.
  StackTrace get stackTrace;
  
  pg.ConnectionState get connectionState;
  
  String get name;
}


//TODO change to enum once implemented.
class PooledConnectionState {
  const PooledConnectionState(this.name);
  final String name;
  toString() => name;

  static const PooledConnectionState connecting = const PooledConnectionState('connecting');  
  static const PooledConnectionState available = const PooledConnectionState('available');
  static const PooledConnectionState reserved = const PooledConnectionState('reserved');
  static const PooledConnectionState testing = const PooledConnectionState('testing');
  static const PooledConnectionState inUse = const PooledConnectionState('inUse');
  static const PooledConnectionState closed = const PooledConnectionState('closed');
}
