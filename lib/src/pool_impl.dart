library postgresql.pool.impl;

import 'dart:async';
import 'dart:collection';
import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/pool.dart';


const PooledConnectionState connecting = PooledConnectionState.connecting;
const PooledConnectionState testing = PooledConnectionState.testing;
const PooledConnectionState available = PooledConnectionState.available;
const PooledConnectionState inUse = PooledConnectionState.inUse;

//FIXME better name?
const PooledConnectionState closed2 = PooledConnectionState.closed;


// Allow for mocking the pg connection.
typedef Future<pg.Connection> ConnectionFactory(String uri, settings);

// TODO pass through required settings such as the type converter
_defaultConnectionFactory(uri, settings) => pg.connect(uri);

class PoolSettingsImpl implements PoolSettings {
  PoolSettingsImpl({String poolName,
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
      this.restartIfAllConnectionsLeaked: false,
      this.typeConverter})
        : poolName = poolName != null ? poolName : 'pgpool${_sequence++}';

  // Ids will be unique for this isolate.
  static int _sequence = 1;

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
  final pg.TypeConverter typeConverter;
}


class ConnectionAdapter implements pg.Connection {

  ConnectionAdapter(this._conn, {onClose})
    : _onClose = onClose;

  final pg.Connection _conn;
  final Function _onClose;
  void close() => _onClose();

  Stream query(String sql, [values]) => _conn.query(sql, values);

  Future<int> execute(String sql, [values]) => _conn.execute(sql, values);

  Future runInTransaction(Future operation(), [pg.Isolation isolation = readCommitted])
    => _conn.runInTransaction(operation, isolation);

  pg.ConnectionState get state => _conn.state;

  pg.TransactionState get transactionState => _conn.transactionState;

  //FIXME Test this to make sure it doesn't cause memory leaks.
  Stream<pg.Message> get messages => _conn.messages;

}

//TODO make setters private, and expose this information.
class PooledConnection {

  PooledConnection(this.pool);

  final PoolImpl pool;
  pg.Connection connection;
  ConnectionAdapter adapter;

  PooledConnectionState state;

  /// Time at which the physical connection to the database was established.
  DateTime established;

  /// Time at which the connection was last obtained by a client.
  DateTime obtained;

  /// Time at which the connection was last released by a client.
  DateTime released;
  
  /// The pid of the postgresql handler.
  int backendPid;

  /// The id passed to connect for debugging.
  String debugId;

  /// A unique id that upated whenever the connection is obtained.
  int useId;
  
  /// If a leak detection threshold is set, then this flag will be set on leaked
  /// connections.
  bool isLeaked;

  /// The stacktrace at the time pool.connect() was last called.
  StackTrace stackTrace;
  
  String get name => '${pool.settings.poolName}:$backendPid'
      + (useId == null ? '' : ':$useId')
      + (debugId == null ? '' : ':$debugId');

  String toString() => '$name $state est: $established obt: $obtained';
}

_debug(msg) => print(msg);

class PoolImpl implements Pool {

  PoolImpl(this.databaseUri,
      [PoolSettings settings,
       this._connectionFactory = _defaultConnectionFactory])
      : settings = settings == null ? new PoolSettings() : settings;

  PoolState _state = initial;
  PoolState get state => _state;

  final String databaseUri;
  final PoolSettings settings;
  final ConnectionFactory _connectionFactory;

  final List<PooledConnection> _connections = new List<PooledConnection>();
  
  final Queue<Completer<PooledConnection>> _waitQueue =
      new Queue<Completer<PooledConnection>>();

  Timer _heartbeatTimer;
  Future _stopFuture;
  
  final StreamController<pg.Message> _messages =
      new StreamController<pg.Message>.broadcast();

  Stream<pg.Message> get messages => _messages.stream;

  /// Note includes connections which are currently connecting/testing.
  int get totalConnections => _connections.length;

  int get availableConnections =>
    _connections.where((c) => c.state == available).length;

  int get inUseConnections =>
    _connections.where((c) => c.state == inUse).length;

  int get leakedConnections =>
    _connections.where((c) => c.isLeaked).length;

  Future start() async {
    _debug('start');
    //TODO consider allowing moving from state stopped to starting.
    //Need to carefully clear out all state.
    if (_state != initial)
      throw new StateError('Cannot start connection pool while in state: $_state.');

    var stopwatch = new Stopwatch()..start();

    var onTimeout = () => throw new TimeoutException(
      'Connection pool start timed out with: ${settings.startTimeout}).',
          settings.startTimeout);

    _state = starting;

    // Start connections in parallel.
    var futures = new Iterable.generate(settings.minConnections,
        (i) => _establishConnection());

    await Future.wait(futures)
      .timeout(settings.startTimeout, onTimeout: onTimeout);

    // If something bad happened and there are not enough connecitons.
    while (_connections.length < settings.minConnections) {
      await _establishConnection()
        .timeout(settings.startTimeout - stopwatch.elapsed, onTimeout: onTimeout);
    }

    _heartbeatTimer = 
        new Timer.periodic(new Duration(seconds: 1), (_) => _heartbeat());
    
    _state = running;
  }
  
  Future _establishConnection() async {
    _debug('Establish connection.');
    
    var stopwatch = new Stopwatch()..start();
    
    var pconn = new PooledConnection(this);
    pconn.state = connecting;

    var onTimeout = () => throw new TimeoutException(
      'Connection pool connection established timed out. '
        'establishTimeout: ${settings.establishTimeout}).',
          settings.establishTimeout);
    
    //FIXME timeout setting - implement in connection??, and pass through here.
    //TODO pass more settings
    var conn = await _connectionFactory(databaseUri, null)
      .timeout(settings.establishTimeout, onTimeout: onTimeout);
    
    // Pass this connection's messages through to the pool messages stream.
    conn.messages.listen((msg) => _messages.add(
          new pg.Message.from(msg, connectionName: pconn.name)),
        onError: (msg) => _messages.addError(
            new pg.Message.from(msg, connectionName: pconn.name)));

    pconn.connection = conn;
    pconn.established = new DateTime.now();
    pconn.adapter = new ConnectionAdapter(conn, onClose: () {
      _releaseConnection(pconn);
    });

    // Fetch postgresql backend pid to use as connection id.
    //TODO this may actually be passed to the connection during startup.
    // If that is the case then remove this.
    pg.Row row;
    try {
      row = await conn.query('select pg_backend_pid()').single
          .timeout(settings.establishTimeout - stopwatch.elapsed,
                   onTimeout: onTimeout);
    } on Exception {
      conn.close();
      rethrow;
    }
    
    pconn.backendPid = row[0];
    pconn.state = available;
    _connections.add(pconn);
    
    _debug('Established connection. ${pconn.name}');
  }
  
  void _heartbeat() {    
    for (var pconn in _connections) {
      _checkIfLeaked(pconn);
      _checkIdleTimeout(pconn);
      
      // This shouldn't be necessary, but should help fault tolerance. 
      _processWaitQueue();
    }
    
    _checkIfAllConnectionsLeaked();
  }

  _checkIdleTimeout(PooledConnection pconn) {
    if (totalConnections > settings.minConnections) {
      if (pconn.state == available
          && pconn.released != null
          && _isExpired(pconn.released, settings.idleTimeout)) {
        _debug('Idle connection ${pconn.name}.');
        _destroyConnection(pconn);
      }
    }
  }
  
  _checkIfLeaked(PooledConnection pconn) {
    if (settings.leakDetectionThreshold != null
        && !pconn.isLeaked
        && pconn.state != available
        && pconn.obtained != null
        && _isExpired(pconn.obtained, settings.leakDetectionThreshold)) {
      pconn.isLeaked = true;
      _messages.add(new pg.ClientMessage(
          severity: 'WARNING',
          connectionName: pconn.name,
          message: 'Leak detected. '
            'state: ${pconn.connection.state} '
            'transactionState: ${pconn.connection.transactionState}',
          stackTrace: pconn.stackTrace));
    }
  }
  
  /// If all connections are in leaked state, then destroy them all, and
  /// restart the minimum required number of connections.
  _checkIfAllConnectionsLeaked() {
    if (settings.restartIfAllConnectionsLeaked
        && leakedConnections >= settings.maxConnections) {

      _messages.add(new pg.ClientMessage(
          severity: 'WARNING',
          message: '${settings.poolName} is full of leaked connections. '
            'These will be closed and new connections started.'));
      
      // Forcefully close leaked connections.
      _connections.where((c) => c.isLeaked).forEach(_destroyConnection);
      
      // Start new connections in parallel.
      for (int i = 0; i < settings.minConnections; i++) {
        _establishConnection();
      }
    }
  }
  
  // Used to generate unique ids (well... unique for this isolate at least).
  static int _sequence = 1;

  Future<pg.Connection> connect({String debugId}) async {
    _debug('Connect.');
    
    StackTrace stackTrace = null;
    if (settings.leakDetectionThreshold != null) {
      // Store the current stack trace for connection leak debugging.
//      try {
//        throw "Generate stacktrace.";
//      } catch (ex, st) {
//        stackTrace = st;
//      }
    }
    
    var pconn = await _connect(settings.connectionTimeout);

    pconn..state = inUse
      ..obtained = new DateTime.now()
      ..useId = _sequence++
      ..debugId = debugId
      ..stackTrace = stackTrace;

    _debug('Connected. ${pconn.name}');
    
    return pconn.adapter;
  }

  Future<PooledConnection> _connect(Duration timeout) async {

    var stopwatch = new Stopwatch()..start();

    var onTimeout = () => throw new TimeoutException(
      'Connect timeout exceeded: ${settings.connectionTimeout}.',
          settings.connectionTimeout);

    PooledConnection pconn = _getFirstAvailable();

    // If there are currently no available connections then
    // add the current connection request at the end of the
    // wait queue.
    if (pconn == null) {
      var c = new Completer<PooledConnection>();
      _waitQueue.add(c);
      try {
        pconn = await c.future.timeout(timeout, onTimeout: onTimeout);
      } finally {
        _waitQueue.remove(c);
      }
    }
    
    if (!await _testConnection(pconn).timeout(timeout - stopwatch.elapsed, onTimeout: onTimeout)) {
      _destroyConnection(pconn);
      // Get another connection out of the pool and test again.
      return _connect(timeout - stopwatch.elapsed);
    } else {
      return pconn;
    }
  }

  List<PooledConnection> _getAvailable()
    => _connections.where((c) => c.state == available).toList();

  PooledConnection _getFirstAvailable()
    => _connections.firstWhere((c) => c.state == available, orElse: () => null);

  /// If connections are available, return them to waiting clients.
  _processWaitQueue() {
    if (_waitQueue.isEmpty) return;

    for (var pconn in _getAvailable()) {
      if (_waitQueue.isEmpty) return;
      var completer = _waitQueue.removeFirst();
      completer.complete(pconn);
    }
  }

  /// Perfom a query to check the state of the connection.
  Future<bool> _testConnection(PooledConnection pconn) async {
    bool ok;
    Exception exception;
    try {
      var row = await pconn.connection.query('select true').single;
      ok = row[0];
    } on Exception catch (ex) {
      ok = false;
      _messages.add(new pg.ClientMessage(
          severity: 'WARNING',
          connectionName: pconn.name,
          message: 'Connection test failed.',
          exception: ex,
          stackTrace: pconn.stackTrace));
    }
    return ok;
  }

  _releaseConnection(PooledConnection pconn) {
    _debug('release ${pconn.name}');
    
    pg.Connection conn = pconn.connection;
    
    // If connection still in transaction or busy with query then destroy.
    // Note this means connections which are returned with an un-committed 
    // transaction, the entire connection will be destroyed and re-established.
    // While it would be possible to write code which would send a rollback 
    // command, this is simpler and probably nearly as fast (not that this
    // is likely to become a bottleneck anyway).
    if (conn.state != idle && conn.transactionState != none) {
        _messages.add(new pg.ClientMessage(
            severity: 'WARNING',
            connectionName: pconn.name,
            message: 'Connection returned in bad state. Removing from pool. '
              'state: ${conn.state} '
              'transactionState: ${conn.transactionState}.'));

        _destroyConnection(pconn);
        _establishConnection();

    // If connection older than lifetime setting then destroy.
    } else if (_isExpired(pconn.established, settings.maxLifetime)) {

      _destroyConnection(pconn);
      _establishConnection();

    } else {
      pconn.released = new DateTime.now();
      pconn.state = available;
      _processWaitQueue();
    }
  }
  
  bool _isExpired(DateTime time, Duration timeout) 
    => new DateTime.now().difference(time) > timeout;
  
  _destroyConnection(PooledConnection pconn) {
    _debug('Destroy connection. ${pconn.name}');
    pconn.connection.close();
    pconn.state = closed2;
    _connections.remove(pconn);
  }
  
  Future stop() {
    _debug('Stop');
    
    if (state == stopped || state == initial) return null;
      
    if (_stopFuture == null)
      _stopFuture = _stop();
    else
      assert(state == stopping);
      
    return _stopFuture;
  }
  
  Future _stop() async {
   
    _state = stopping;

    if (_heartbeatTimer != null) _heartbeatTimer.cancel();
  
    // Close connections as they are returned to the pool.
    // If stop timeout is reached then close connections even if still in use.

    var stopwatch = new Stopwatch()..start();
    while (_connections.isNotEmpty) {
      _getAvailable().forEach(_destroyConnection);

      await new Future.delayed(new Duration(milliseconds: 100), () => null);

      if (stopwatch.elapsed > settings.stopTimeout ) {
        _messages.add(new pg.ClientMessage(
            severity: 'WARNING',
            message: 'Exceeded timeout while stopping, '
              'closing in use connections.'));        
        _connections.forEach(_destroyConnection);
      }
    }
    _state = stopped;
    
    _debug('Stopped');
  }

  //FIXME just exposed for testing. Expose in a safer way.
  List<PooledConnection> getConnections() => _connections;
}






