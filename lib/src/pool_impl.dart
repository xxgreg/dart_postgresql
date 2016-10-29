library postgresql.pool.impl;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart' as pgi;
import 'package:postgresql/pool.dart';


// I like my enums short and sweet, not long and typey.
const PooledConnectionState connecting = PooledConnectionState.connecting;
const PooledConnectionState available = PooledConnectionState.available;
const PooledConnectionState reserved = PooledConnectionState.reserved;
const PooledConnectionState testing = PooledConnectionState.testing;
const PooledConnectionState inUse = PooledConnectionState.inUse;
const PooledConnectionState connClosed = PooledConnectionState.closed;


typedef Future<pg.Connection> ConnectionFactory(
    String uri,
    {Duration connectionTimeout,
     String applicationName,
     String timeZone,
     pg.TypeConverter typeConverter,
     String getDebugName(),
     Future<Socket> mockSocketConnect(String host, int port)});

class ConnectionDecorator implements pg.Connection {

  ConnectionDecorator(this._pool, PooledConnectionImpl pconn, this._conn)
      : _pconn = pconn, _debugName = pconn.name;

  _error(fnName) => new pg.PostgresqlException(
      '$fnName() called on closed connection.', _debugName);

  bool _isReleased = false;
  final pg.Connection _conn;
  final PoolImpl _pool;
  final PooledConnectionImpl _pconn;
  final String _debugName;

  void close() {
    if (!_isReleased) _pool._releaseConnection(_pconn);
    _isReleased = true;
  }

  Stream<pg.Row> query(String sql, [values]) => _isReleased
      ? throw _error('query')
      : _conn.query(sql, values);

  Future<int> execute(String sql, [values]) => _isReleased
      ? throw _error('execute')
      : _conn.execute(sql, values);

  Future runInTransaction(Future operation(),
                          [pg.Isolation isolation = readCommitted])
    => _isReleased
        ? throw throw _error('runInTransaction')
        : _conn.runInTransaction(operation, isolation);

  pg.ConnectionState get state => _isReleased ? closed : _conn.state;

  pg.TransactionState get transactionState => _isReleased
      ? unknown
      : _conn.transactionState;

  @deprecated pg.TransactionState get transactionStatus
    => transactionState;

  Stream<pg.Message> get messages => _isReleased
    ? new Stream.fromIterable([])
    : _conn.messages;

  @deprecated Stream<pg.Message> get unhandled => messages;

  Map<String,String> get parameters => _isReleased ? {} : _conn.parameters;

  int get backendPid => _conn.backendPid;

  String get debugName => _debugName;

  @override
  String toString() => "$_pconn";
}


class PooledConnectionImpl implements PooledConnection {

  PooledConnectionImpl(this._pool);

  final PoolImpl _pool;
  pg.Connection _connection;
  PooledConnectionState _state;
  DateTime _established;
  DateTime _obtained;
  DateTime _released;
  String _debugName;
  int _useId;
  bool _isLeaked = false;
  StackTrace _stackTrace;
  
  final Duration _random = new Duration(seconds: new math.Random().nextInt(20));
  
  PooledConnectionState get state => _state;

  DateTime get established => _established;

  DateTime get obtained => _obtained;

  DateTime get released => _released;
  
  int get backendPid => _connection == null ? null : _connection.backendPid;

  String get debugName => _debugName;

  int get useId => _useId;
  
  bool get isLeaked => _isLeaked;

  StackTrace get stackTrace => _stackTrace;
  
  pg.ConnectionState get connectionState
    => _connection == null ? null : _connection.state;
  
  String get name => '${_pool.settings.poolName}:$backendPid'
      + (_useId == null ? '' : ':$_useId')
      + (_debugName == null ? '' : ':$_debugName');

  String toString() => '$name:$_state:$connectionState';
}

//_debug(msg) => print(msg);

_debug(msg) {}

class PoolImpl implements Pool {

  PoolImpl(PoolSettings settings,
        this._typeConverter,
       [this._connectionFactory = pgi.ConnectionImpl.connect])
      : settings = settings == null ? new PoolSettings() : settings;
      
  PoolState _state = initial;
  PoolState get state => _state;

  final PoolSettings settings;
  final pg.TypeConverter _typeConverter;
  final ConnectionFactory _connectionFactory;
  
  //TODO Consider using a list instead. removeAt(0); instead of removeFirst().
  // Since the list will be so small there is not performance benefit using a
  // queue.
  final Queue<Completer<PooledConnectionImpl>> _waitQueue =
      new Queue<Completer<PooledConnectionImpl>>();

  Timer _heartbeatTimer;
  Future _stopFuture;
  
  final StreamController<pg.Message> _messages =
      new StreamController<pg.Message>.broadcast();

  final List<PooledConnectionImpl> _connections = new List<PooledConnectionImpl>();
  
  List<PooledConnectionImpl> _connectionsView; 
  
  List<PooledConnectionImpl> get connections {
    if (_connectionsView == null)
      _connectionsView = new UnmodifiableListView(_connections);
    return _connectionsView;
  }

  int get waitQueueLength => _waitQueue.length;
  
  Stream<pg.Message> get messages => _messages.stream;

  Future start() async {
    _debug('start');
    //TODO consider allowing moving from state stopped to starting.
    //Need to carefully clear out all state.
    if (_state != initial)
      throw new pg.PostgresqlException(
          'Cannot start connection pool while in state: $_state.', null);

    var stopwatch = new Stopwatch()..start();

    var onTimeout = () {
      _state = startFailed;
      throw new pg.PostgresqlException(
        'Connection pool start timed out with: '
          '${settings.startTimeout}).', null);
    };

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
    
    // Do nothing if called while shutting down.
    if (!(_state == running || _state == PoolState.starting))
      return new Future.value();
    
    // This shouldn't be able to happen - but is here for robustness.
    if (_connections.length >= settings.maxConnections)
      return new Future.value();
    
    var pconn = new PooledConnectionImpl(this);
    pconn._state = connecting;
    _connections.add(pconn);

    var conn = await _connectionFactory(
      settings.databaseUri,
      connectionTimeout: settings.establishTimeout,
      applicationName: settings.applicationName,
      timeZone: settings.timeZone,
      typeConverter: _typeConverter,
      getDebugName: () => pconn.name);
    
    // Pass this connection's messages through to the pool messages stream.
    conn.messages.listen((msg) => _messages.add(msg),
        onError: (msg) => _messages.addError(msg));

    pconn._connection = conn;
    pconn._established = new DateTime.now(); 
    pconn._state = available;
    
    _debug('Established connection. ${pconn.name}');
  }
  
  void _heartbeat() {
    if (_state != running) return;
    
    for (var pconn in new List.from(_connections)) {
      _checkIfLeaked(pconn);
      _checkIdleTimeout(pconn);
      
      // This shouldn't be necessary, but should help fault tolerance. 
      _processWaitQueue();
    }
    
    _checkIfAllConnectionsLeaked();
  }

  _checkIdleTimeout(PooledConnectionImpl pconn) {
    if (_connections.length > settings.minConnections) {
      if (pconn._state == available
          && pconn._released != null
          && _isExpired(pconn._released, settings.idleTimeout)) {
        _debug('Idle connection ${pconn.name}.');
        _destroyConnection(pconn);
      }
    }
  }
  
  _checkIfLeaked(PooledConnectionImpl pconn) {
    if (settings.leakDetectionThreshold != null
        && !pconn._isLeaked
        && pconn._state != available
        && pconn._obtained != null
        && _isExpired(pconn._obtained, settings.leakDetectionThreshold)) {
      pconn._isLeaked = true;
      _messages.add(new pg.ClientMessage(
          severity: 'WARNING',
          connectionName: pconn.name,
          message: 'Leak detected. '
            'state: ${pconn._connection.state} '
            'transactionState: ${pconn._connection.transactionState} '
            'debugId: ${pconn.debugName}'
            'stacktrace: ${pconn._stackTrace}'));
    }
  }
  
  int get _leakedConnections =>
    _connections.where((c) => c._isLeaked).length;
  
  /// If all connections are in leaked state, then destroy them all, and
  /// restart the minimum required number of connections.
  _checkIfAllConnectionsLeaked() {
    if (settings.restartIfAllConnectionsLeaked
        && _leakedConnections >= settings.maxConnections) {

      _messages.add(new pg.ClientMessage(
          severity: 'WARNING',
          message: '${settings.poolName} is full of leaked connections. '
            'These will be closed and new connections started.'));
      
      // Forcefully close leaked connections.
      for (var pconn in new List.from(_connections)) {
        _destroyConnection(pconn);
      }
      
      // Start new connections in parallel.
      for (int i = 0; i < settings.minConnections; i++) {
        _establishConnection();
      }
    }
  }
  
  // Used to generate unique ids (well... unique for this isolate at least).
  static int _sequence = 1;

  Future<pg.Connection> connect({String debugName}) async {
    _debug('Connect.');
    
    if (_state != running)
      throw new pg.PostgresqlException(
        'Connect called while pool is not running.', null);
    
    StackTrace stackTrace = null;
    if (settings.leakDetectionThreshold != null) {
      // Store the current stack trace for connection leak debugging.
      try {
        throw "Generate stacktrace.";
      } catch (ex, st) {
        stackTrace = st;
      }
    }

    var pconn = await _connect(settings.connectionTimeout);

    assert((settings.testConnections && pconn._state == testing)
        || (!settings.testConnections && pconn._state == reserved));
    assert(pconn._connection.state == idle);
    assert(pconn._connection.transactionState == none);    
    
    pconn.._state = inUse
      .._obtained = new DateTime.now()
      .._useId = _sequence++
      .._debugName = debugName
      .._stackTrace = stackTrace;

    _debug('Connected. ${pconn.name} ${pconn._connection}');
    
    return new ConnectionDecorator(this, pconn, pconn._connection);
  }

  Future<PooledConnectionImpl> _connect(Duration timeout) async {

    if (state == stopping || state == stopped)
      throw new pg.PostgresqlException(
          'Connect failed as pool is stopping.', null);
    
    var stopwatch = new Stopwatch()..start();

    var pconn = _getFirstAvailable();
    
    timeoutException() => new pg.PostgresqlException(
      'Obtaining connection from pool exceeded timeout: '
        '${settings.connectionTimeout}', 
            pconn == null ? null : pconn.name);    
   
    // If there are currently no available connections then
    // add the current connection request at the end of the
    // wait queue.
    if (pconn == null) {
      var c = new Completer<PooledConnectionImpl>();
      _waitQueue.add(c);
      try {
        _processWaitQueue();
        pconn = await c.future.timeout(timeout, onTimeout: () => throw timeoutException());
      } finally {
        _waitQueue.remove(c);
      }
      assert(pconn.state == reserved);
    }
    
    if (!settings.testConnections) {
      pconn._state = reserved;
      return pconn;
    }
    
    pconn._state = testing;
        
    if (await _testConnection(pconn, timeout - stopwatch.elapsed, () => throw timeoutException()))
      return pconn;
    
    if (timeout > stopwatch.elapsed) {
      throw timeoutException();
    } else {
      _destroyConnection(pconn);
      // Get another connection out of the pool and test again.
      return _connect(timeout - stopwatch.elapsed);
    }
  }

  List<PooledConnectionImpl> _getAvailable()
    => _connections.where((c) => c._state == available).toList();

  PooledConnectionImpl _getFirstAvailable()
    => _connections.firstWhere((c) => c._state == available, orElse: () => null);

  /// If connections are available, return them to waiting clients.
  void _processWaitQueue() {
    
    if (_state != running) return;
    
    if (_waitQueue.isEmpty) return;

    //FIXME make sure this happens in the correct order so it is fair to the
    // order which connect was called, and that connections are reused, and
    // others left idle so that the pool can shrink.
    var pconns = _getAvailable();
    while(_waitQueue.isNotEmpty && pconns.isNotEmpty) {
      var completer = _waitQueue.removeFirst();
      var pconn = pconns.removeLast();
      pconn._state = reserved;
      completer.complete(pconn);
    }
        
    // If required start more connection.
    if (!_establishing) { //once at a time
      final int count = math.min(_waitQueue.length,
          settings.maxConnections - _connections.length);
      if (count > 0) {
        _establishing = true;
        new Future.sync(() {
          final List<Future> ops = new List(count);
          for (int i = 0; i < count; i++) {
            ops[i] = _establishConnection();
          }
          return Future.wait(ops);
        })
        .whenComplete(() {
          _establishing = false;

          _processWaitQueue(); //do again; there might be more requests
        });
      }
    }
  }
  bool _establishing = false;

  /// Perfom a query to check the state of the connection.
  Future<bool> _testConnection(
      PooledConnectionImpl pconn,
      Duration timeout, 
      Function onTimeout) async {
    bool ok;
    try {
      var row = await pconn._connection.query('select true')
                         .single.timeout(timeout);
      ok = row[0];
    } on Exception catch (ex) { //TODO Do I really want to log warnings when the connection timeout fails.
      ok = false;
      // Don't log connection test failures during shutdown.
      if (state != stopping && state != stopped) {
        var msg = ex is TimeoutException
              ? 'Connection test timed out.'
              : 'Connection test failed.';
        _messages.add(new pg.ClientMessage(
            severity: 'WARNING',
            connectionName: pconn.name,
            message: msg,
            exception: ex));
      }
    }
    return ok;
  }

  _releaseConnection(PooledConnectionImpl pconn) {
    _debug('Release ${pconn.name}');
    
    if (state == stopping || state == stopped) {
      _destroyConnection(pconn);
      return;
    }
    
    assert(pconn._pool == this);
    assert(_connections.contains(pconn));
    assert(pconn.state == inUse);
    
    pg.Connection conn = pconn._connection;
    
    // If connection still in transaction or busy with query then destroy.
    // Note this means connections which are returned with an un-committed 
    // transaction, the entire connection will be destroyed and re-established.
    // While it would be possible to write code which would send a rollback 
    // command, this is simpler and probably nearly as fast (not that this
    // is likely to become a bottleneck anyway).
    if (conn.state != idle || conn.transactionState != none) {
        _messages.add(new pg.ClientMessage(
            severity: 'WARNING',
            connectionName: pconn.name,
            message: 'Connection returned in bad state. Removing from pool. '
              'state: ${conn.state} '
              'transactionState: ${conn.transactionState}.'));

        _destroyConnection(pconn);
        _establishConnection();

    // If connection older than lifetime setting then destroy.
    // A random number of seconds 0-20 is added, so that all connections don't
    // expire at exactly the same moment.
    } else if (settings.maxLifetime != null
        && _isExpired(pconn._established, settings.maxLifetime + pconn._random)) {
      _destroyConnection(pconn);
      _establishConnection();

    } else {
      pconn._released = new DateTime.now();
      pconn._state = available;
      _processWaitQueue();
    }
  }
  
  bool _isExpired(DateTime time, Duration timeout) 
    => new DateTime.now().difference(time) > timeout;
  
  _destroyConnection(PooledConnectionImpl pconn) {
    _debug('Destroy connection. ${pconn.name}');
    if (pconn._connection != null) pconn._connection.close();
    pconn._state = connClosed;
    _connections.remove(pconn);
  }
  
  /// Depreciated. Use [stop]() instead.
  @deprecated void destroy() { stop(); }
  
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
  
    // Send error messages to connections in wait queue.
    _waitQueue.forEach((completer) =>
      completer.completeError(new pg.PostgresqlException(
          'Connection pool is stopping.', null)));
    _waitQueue.clear();
    
    
    // Close connections as they are returned to the pool.
    // If stop timeout is reached then close connections even if still in use.

    var stopwatch = new Stopwatch()..start();
    while (_connections.isNotEmpty) {
      _getAvailable().forEach(_destroyConnection);

      await new Future.delayed(new Duration(milliseconds: 100), () => null);

      if (stopwatch.elapsed > settings.stopTimeout ) {
        _messages.add(new pg.ClientMessage(
            severity: 'WARNING',
            message: 'Exceeded timeout while stopping pool, '
              'closing in use connections.'));        
        // _destroyConnection modifies this list, so need to make a copy.
        new List.from(_connections).forEach(_destroyConnection);
      }
    }
    _state = stopped;
    
    _debug('Stopped');
  }

}






