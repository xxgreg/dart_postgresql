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
      this.maxLifetime: const Duration(hours: 1),
      this.leakDetectionThreshold,
      this.testConnections: true,
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
  final Duration maxLifetime;
  final Duration leakDetectionThreshold;
  final bool testConnections;
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

  //FIXME Could pass through messages until connection is released.
  // Need to unsubscribe listeners on close.
  Stream<dynamic> get messages { throw new UnimplementedError(); }

}

//FIXME option to store stacktrace for leak detection.
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

  /// The pid of the postgresql handler.
  int backendPid;

  /// The id passed to connect for debugging.
  String debugId;

  /// A unique id that upated whenever the connection is obtained.
  int useId;

  String get name => '${pool.settings.poolName}:$backendPid'
      + (useId == null ? '' : ':$useId')
      + (debugId == null ? '' : ':$debugId');

  String toString() => '$name $state est: $established obt: $obtained';
}


//FIXME consistent use of pconn and conn.
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
  final Queue<Completer<PooledConnection>> _waitQueue = new Queue<Completer<PooledConnection>>();
  final StreamController<pg.Message> _messages = new StreamController<pg.Message>.broadcast();

  //TODO pass connection messages through to pool.
  Stream<pg.Message> get messages => _messages.stream;

  /// Note includes connections which are currently connecting/testing.
  int get totalConnections => _connections.length;

  int get availableConnections =>
    _connections.where((c) => c.state == available).length;

  int get inUseConnections =>
    _connections.where((c) => c.state == inUse).length;


  Future start() async {
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
      .timeout(settings.startTimeout); //FIXME, onTimeout: onTimeout);

    // If something bad happened and there are not enough connecitons.
    while (_connections.length < settings.minConnections) {
      await _establishConnection()
        .timeout(settings.startTimeout - stopwatch.elapsed); //FIXME,onTimeout: onTimeout);
    }

    _state = running;
  }

  Future _establishConnection() async {

    var pconn = new PooledConnection(this);
    pconn.state = connecting;

    //FIXME timeout setting - implement in connection, and pass through here.
    var conn = await _connectionFactory(databaseUri, null); //TODO pass more settings

    pconn.connection = conn;
    pconn.established = new DateTime.now();
    pconn.adapter = new ConnectionAdapter(conn, onClose: () {
      _releaseConnection(pconn);
    });

    //FIXME timeout setting
    var row = await conn.query('select pg_backend_pid()').single;
    pconn.backendPid = row[0];

    _connections.add(pconn);
    pconn.state = available;
  }

  // Used to generate unique ids (well... unique for this isolate at least).
  static int _sequence = 1;

  Future<pg.Connection> connect({String debugId}) async {
    _processWaitQueue();
    var pconn = await _connect(settings.connectionTimeout);

    pconn..state = inUse
      ..obtained = new DateTime.now()
      ..useId = _sequence++
      ..debugId = debugId;

    return pconn.adapter;
  }

  Future<PooledConnection> _connect(Duration timeout) async {

    var stopwatch = new Stopwatch()..start();

    var onTimeout = () => throw new TimeoutException(
      'Connect timeout exceeded: ${settings.connectionTimeout}.',
          settings.connectionTimeout);

    PooledConnection conn = _getFirstAvailable();

    // If there are currently no available connections then
    // add the current connection request at the end of the
    // wait queue.
    if (conn == null) {
      var c = new Completer();
      _waitQueue.add(c);
      conn = await c.future.timeout(timeout); //FIXME, onTimeout: onTimeout);
      _waitQueue.remove(c);
    }

    if (!await _testConnection(conn).timeout(timeout - stopwatch.elapsed)) { //FIXME, onTimeout: onTimeout)) {
      _destroyConnection(conn);
      // Get another connection out of the pool and test again.
      return _connect(timeout - stopwatch.elapsed);
    }

    return conn;
  }

  List<PooledConnection> _getAvailable()
    => _connections.where((c) => c.state == available).toList();

  PooledConnection _getFirstAvailable()
    => _connections.firstWhere((c) => c.state == available, orElse: () => null);

  /// If connections are available, return them to waiting clients.
  _processWaitQueue() {
    if (_waitQueue.isEmpty) return;

    for (var conn in _getAvailable()) {
      if (_waitQueue.isEmpty) return;
      var completer = _waitQueue.removeFirst();
      completer.complete(conn);
    }
  }

  /// Perfom a query to check the state of the connection.
  Future<bool> _testConnection(PooledConnection conn) async {
    bool ok;
    Exception exception;
    try {
      var row = await conn.connection.query('select true').single;
      ok = row[0];
    } on Exception catch (ex) {
      ok = false;
      //FIXME
      print('Connection test failed.');
      print(exception);
    }
    return ok;
  }

  _releaseConnection(PooledConnection pconn) {

    pg.Connection conn = pconn.connection;

    //TODO Maybe rollback transactions. But probably more robust and nearly as fast
    // to close and reconnect.
    //if (conn.transactionStatus == pg.TRANSACTION_ERROR) {
    //  await conn.execute('rollback').timeout(?);
    //}

    // If connection still in transaction or busy with query then destroy.
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
    } else if (new DateTime.now().difference(pconn.established) >
                 settings.maxLifetime) {

      _destroyConnection(pconn);
      _establishConnection();

    } else {
      pconn.state = available;
      _processWaitQueue();
    }
  }

  _destroyConnection(PooledConnection pconn) {
    pconn.connection.close();
    pconn.state = closed2;
    _connections.remove(pconn);

    //FIXME unsubscribe.
    //pconn.connection.messages
  }

  Future stop() async {
    if (state == stopped) return null;

    //TODO if (state == stopping)
    // wait for stopping process to finish.

    _state = stopping;

    // Close connections as they are returned to the pool.
    // If stop timeout is reached then close connections even if still in use.

    var stopwatch = new Stopwatch()..start();
    while (_connections.isNotEmpty) {
      _getAvailable().forEach(_destroyConnection);

      await new Future.delayed(new Duration(milliseconds: 100), () => null);

      //TODO log stopTimeout exceeded. Closing connections.
      if (stopwatch.elapsed > settings.stopTimeout ) {
        _connections.forEach(_destroyConnection);
      }
    }
    _state = stopped;
  }

  //FIXME just here for testing. Figure out a better way.
  List<PooledConnection> getConnections() => _connections;
}

