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
typedef Future<pg.Connection> ConnectionFactory(
    String uri, 
    { Duration timeout,
      pg.TypeConverter typeConverter});

_defaultConnectionFactory(
    String uri,
    { Duration timeout,
      pg.TypeConverter typeConverter}) => pg.connect(uri);

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

//FIXME Rename this, as it is not an adapter.
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

  Stream<pg.Message> get messages => _conn.messages;

  Map<String,String> get parameters => _conn.parameters;
  
  int get backendPid => _conn.backendPid;
}


class PooledConnection {

  PooledConnection(this._pool);

  final PoolImpl _pool;
  pg.Connection _connection;
  ConnectionAdapter _adapter;
  PooledConnectionState _state;
  DateTime _established;
  DateTime _obtained;
  DateTime _released;
  String _debugId;
  int _useId;
  bool _isLeaked;
  StackTrace _stackTrace;
  
  /// The state of connection in the pool, available, closed
  PooledConnectionState get state => _state;

  /// Time at which the physical connection to the database was established.
  DateTime get established => _established;

  /// Time at which the connection was last obtained by a client.
  DateTime get obtained => _obtained;

  /// Time at which the connection was last released by a client.
  DateTime get released => _released;
  
  /// The pid of the postgresql handler.
  int get backendPid => _connection == null ? null : _connection.backendPid;

  /// The id passed to connect for debugging.
  String get debugId => _debugId;

  /// A unique id that updated whenever the connection is obtained.
  int get useId => _useId;
  
  /// If a leak detection threshold is set, then this flag will be set on leaked
  /// connections.
  bool get isLeaked => _isLeaked;

  /// The stacktrace at the time pool.connect() was last called.
  StackTrace get stackTrace => _stackTrace;
  
  String get name => '${_pool.settings.poolName}:$backendPid'
      + (_useId == null ? '' : ':$_useId')
      + (_debugId == null ? '' : ':$_debugId');

  String toString() => '$name $_state est: $_established obt: $_obtained';
}

//_debug(msg) => print(msg);

_debug(msg) {}

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
  
  final Queue<Completer<PooledConnection>> _waitQueue =
      new Queue<Completer<PooledConnection>>();

  Timer _heartbeatTimer;
  Future _stopFuture;
  
  final StreamController<pg.Message> _messages =
      new StreamController<pg.Message>.broadcast();

  final List<PooledConnection> _connections = new List<PooledConnection>();
  
  List<PooledConnection> _connectionsView; 
  
  List<PooledConnection> get connections {
    if (_connectionsView == null)
      _connectionsView = new UnmodifiableListView(_connections);
    return _connectionsView;
  }
  
  Stream<pg.Message> get messages => _messages.stream;

  /// Note includes connections which are currently connecting/testing.
  int get totalConnections => _connections.length;

  int get availableConnections =>
    _connections.where((c) => c._state == available).length;

  int get inUseConnections =>
    _connections.where((c) => c._state == inUse).length;

  int get leakedConnections =>
    _connections.where((c) => c._isLeaked).length;

  Future start() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _debug('start');
      join0() {
        var stopwatch = new Stopwatch()
            ..start();
        var onTimeout = (() {
          return throw new TimeoutException('Connection pool start timed out with: ${settings.startTimeout}).', settings.startTimeout);
        });
        _state = starting;
        var futures = new Iterable.generate(settings.minConnections, ((i) {
          return _establishConnection();
        }));
        new Future.value(Future.wait(futures).timeout(settings.startTimeout, onTimeout: onTimeout)).then((x0) {
          try {
            x0;
            break0() {
              _heartbeatTimer = new Timer.periodic(new Duration(seconds: 1), ((_) {
                return _heartbeat();
              }));
              _state = running;
              completer0.complete();
            }
            var trampoline0;
            continue0() {
              trampoline0 = null;
              if (_connections.length < settings.minConnections) {
                new Future.value(_establishConnection().timeout(settings.startTimeout - stopwatch.elapsed, onTimeout: onTimeout)).then((x1) {
                  trampoline0 = () {
                    trampoline0 = null;
                    try {
                      x1;
                      trampoline0 = continue0;
                    } catch (e0, s0) {
                      completer0.completeError(e0, s0);
                    }
                  };
                  do trampoline0(); while (trampoline0 != null);
                }, onError: completer0.completeError);
              } else {
                break0();
              }
            }
            trampoline0 = continue0;
            do trampoline0(); while (trampoline0 != null);
          } catch (e1, s1) {
            completer0.completeError(e1, s1);
          }
        }, onError: completer0.completeError);
      }
      if (_state != initial) {
        throw new StateError('Cannot start connection pool while in state: ${_state}.');
        join0();
      } else {
        join0();
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}
  
  Future _establishConnection() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _debug('Establish connection.');
      var stopwatch = new Stopwatch()
          ..start();
      var pconn = new PooledConnection(this);
      pconn._state = connecting;
      new Future.value(_connectionFactory(databaseUri, timeout: settings.establishTimeout, typeConverter: settings.typeConverter)).then((x0) {
        try {
          var conn = x0;
          conn.messages.listen(((msg) {
            return _messages.add(new pg.Message.from(msg, connectionName: pconn.name));
          }), onError: ((msg) {
            return _messages.addError(new pg.Message.from(msg, connectionName: pconn.name));
          }));
          pconn._connection = conn;
          pconn._established = new DateTime.now();
          pconn._adapter = new ConnectionAdapter(conn, onClose: (() {
            _releaseConnection(pconn);
          }));
          pconn._state = available;
          _connections.add(pconn);
          _debug('Established connection. ${pconn.name}');
          completer0.complete();
        } catch (e0, s0) {
          completer0.completeError(e0, s0);
        }
      }, onError: completer0.completeError);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
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
      if (pconn._state == available
          && pconn._released != null
          && _isExpired(pconn._released, settings.idleTimeout)) {
        _debug('Idle connection ${pconn.name}.');
        _destroyConnection(pconn);
      }
    }
  }
  
  _checkIfLeaked(PooledConnection pconn) {
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
            'transactionState: ${pconn._connection.transactionState}',
          stackTrace: pconn._stackTrace));
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
      _connections.where((c) => c._isLeaked).forEach(_destroyConnection);
      
      // Start new connections in parallel.
      for (int i = 0; i < settings.minConnections; i++) {
        _establishConnection();
      }
    }
  }
  
  // Used to generate unique ids (well... unique for this isolate at least).
  static int _sequence = 1;

  Future<pg.Connection> connect({String debugId}) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _debug('Connect.');
      StackTrace stackTrace = null;
      join0() {
        new Future.value(_connect(settings.connectionTimeout)).then((x0) {
          try {
            var pconn = x0;
            pconn
                .._state = inUse
                .._obtained = new DateTime.now()
                .._useId = _sequence++
                .._debugId = debugId
                .._stackTrace = stackTrace;
            _debug('Connected. ${pconn.name}');
            completer0.complete(pconn._adapter);
          } catch (e0, s0) {
            completer0.completeError(e0, s0);
          }
        }, onError: completer0.completeError);
      }
      if (settings.leakDetectionThreshold != null) {
        join1() {
          join0();
        }
        catch0(ex, st) {
          try {
            stackTrace = st;
            join1();
          } catch (ex, st) {
            completer0.completeError(ex, st);
          }
        }
        try {
          throw "Generate stacktrace.";
          join1();
        } catch (e1, s1) {
          catch0(e1, s1);
        }
      } else {
        join0();
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}

  Future<PooledConnection> _connect(Duration timeout) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      var stopwatch = new Stopwatch()
          ..start();
      var onTimeout = (() {
        return throw new TimeoutException('Connect timeout exceeded: ${settings.connectionTimeout}.', settings.connectionTimeout);
      });
      PooledConnection pconn = _getFirstAvailable();
      join0() {
        new Future.value(_testConnection(pconn).timeout(timeout - stopwatch.elapsed, onTimeout: onTimeout)).then((x0) {
          try {
            join1() {
              completer0.complete();
            }
            if (!x0) {
              _destroyConnection(pconn);
              completer0.complete(_connect(timeout - stopwatch.elapsed));
            } else {
              completer0.complete(pconn);
            }
          } catch (e0, s0) {
            completer0.completeError(e0, s0);
          }
        }, onError: completer0.completeError);
      }
      if (pconn == null) {
        var c = new Completer<PooledConnection>();
        _waitQueue.add(c);
        join2() {
          join0();
        }
        finally0(cont0) {
          _waitQueue.remove(c);
          cont0();
        }
        catch0(e2, s2) {
          finally0(() => completer0.completeError(e2, s2));
        }
        try {
          new Future.value(c.future.timeout(timeout, onTimeout: onTimeout)).then((x1) {
            try {
              pconn = x1;
              finally0(join2);
            } catch (e3, s3) {
              catch0(e3, s3);
            }
          }, onError: catch0);
        } catch (e4, s4) {
          catch0(e4, s4);
        }
      } else {
        join0();
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}

  List<PooledConnection> _getAvailable()
    => _connections.where((c) => c._state == available).toList();

  PooledConnection _getFirstAvailable()
    => _connections.firstWhere((c) => c._state == available, orElse: () => null);

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
  Future<bool> _testConnection(PooledConnection pconn) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      bool ok;
      Exception exception;
      join0() {
        completer0.complete(ok);
      }
      catch0(ex, s0) {
        try {
          if (ex is Exception) {
            ok = false;
            _messages.add(new pg.ClientMessage(severity: 'WARNING', connectionName: pconn.name, message: 'Connection test failed.', exception: ex, stackTrace: pconn._stackTrace));
            join0();
          } else {
            throw ex;
          }
        } catch (ex, s0) {
          completer0.completeError(ex, s0);
        }
      }
      try {
        new Future.value(pconn._connection.query('select true').single).then((x0) {
          try {
            var row = x0;
            ok = row[0];
            join0();
          } catch (e0, s1) {
            catch0(e0, s1);
          }
        }, onError: catch0);
      } catch (e1, s2) {
        catch0(e1, s2);
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}

  _releaseConnection(PooledConnection pconn) {
    _debug('release ${pconn.name}');
    
    pg.Connection conn = pconn._connection;
    
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
    } else if (_isExpired(pconn._established, settings.maxLifetime)) {

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
  
  _destroyConnection(PooledConnection pconn) {
    _debug('Destroy connection. ${pconn.name}');
    pconn._connection.close();
    pconn._state = closed2;
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
  
  Future _stop() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _state = stopping;
      join0() {
        var stopwatch = new Stopwatch()
            ..start();
        break0() {
          _state = stopped;
          _debug('Stopped');
          completer0.complete();
        }
        var trampoline0;
        continue0() {
          trampoline0 = null;
          if (_connections.isNotEmpty) {
            _getAvailable().forEach(_destroyConnection);
            new Future.value(new Future.delayed(new Duration(milliseconds: 100), (() {
              return null;
            }))).then((x0) {
              trampoline0 = () {
                trampoline0 = null;
                try {
                  x0;
                  join1() {
                    trampoline0 = continue0;
                  }
                  if (stopwatch.elapsed > settings.stopTimeout) {
                    _messages.add(new pg.ClientMessage(severity: 'WARNING', message: 'Exceeded timeout while stopping, '
                        'closing in use connections.'));
                    _connections.forEach(_destroyConnection);
                    join1();
                  } else {
                    join1();
                  }
                } catch (e0, s0) {
                  completer0.completeError(e0, s0);
                }
              };
              do trampoline0(); while (trampoline0 != null);
            }, onError: completer0.completeError);
          } else {
            break0();
          }
        }
        trampoline0 = continue0;
        do trampoline0(); while (trampoline0 != null);
      }
      if (_heartbeatTimer != null) {
        _heartbeatTimer.cancel();
        join0();
      } else {
        join0();
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}

}







