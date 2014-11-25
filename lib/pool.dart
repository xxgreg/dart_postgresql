library postgresql.pool;

import 'dart:async';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/src/pool_impl_cps.dart';


//TODO docs
abstract class Pool {
  factory Pool(String databaseUri, [PoolSettings settings])
    => new PoolImpl(databaseUri, settings);
  Future start();
  Future stop();
  Future<pg.Connection> connect({String debugId});
  Stream<pg.Message> get messages;
  List<PooledConnection> get connections;
  int get waitQueueLength;
}

abstract class PooledConnection {
  
  /// The state of connection in the pool, available, closed
  PooledConnectionState get state;

  /// Time at which the physical connection to the database was established.
  DateTime get established;

  /// Time at which the connection was last obtained by a client.
  DateTime get obtained;

  /// Time at which the connection was last released by a client.
  DateTime get released;
  
  /// The pid of the postgresql handler.
  int get backendPid;

  /// The id passed to connect for debugging.
  String get debugId;

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


abstract class PoolSettings {

  factory PoolSettings({String poolName,
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
      pg.TypeConverter typeConverter}) = PoolSettingsImpl;

  String get poolName;
  int get minConnections;
  int get maxConnections;
  Duration get startTimeout;
  Duration get stopTimeout;
  Duration get establishTimeout; //TODO better name
  Duration get connectionTimeout; //TODO better name
  Duration get idleTimeout;
  Duration get maxLifetime;
  Duration get leakDetectionThreshold;
  bool get testConnections;
  bool get restartIfAllConnectionsLeaked;
  pg.TypeConverter get typeConverter;
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

//TODO change to enum once implemented.
class PooledConnectionState {
  const PooledConnectionState(this.name);
  final String name;
  toString() => name;

  static const PooledConnectionState connecting = const PooledConnectionState('connecting');
  static const PooledConnectionState testing = const PooledConnectionState('testing');
  static const PooledConnectionState available = const PooledConnectionState('available');
  static const PooledConnectionState inUse = const PooledConnectionState('inUse');
  static const PooledConnectionState closed = const PooledConnectionState('closed');
}
