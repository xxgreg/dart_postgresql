library postgresql.pool.impl;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/pool.dart';


// I like my enums short and sweet, not long and typey.
const PooledConnectionState connecting = PooledConnectionState.connecting;
const PooledConnectionState available = PooledConnectionState.available;
const PooledConnectionState reserved = PooledConnectionState.reserved;
const PooledConnectionState testing = PooledConnectionState.testing;
const PooledConnectionState inUse = PooledConnectionState.inUse;
const PooledConnectionState connClosed = PooledConnectionState.closed;



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

  ConnectionAdapter(this._pool, this._pconn, this._conn);

  bool _isReleased = false;
  final pg.Connection _conn;
  final PoolImpl _pool;
  final PooledConnectionImpl _pconn;
  
  void close() {
    if (!_isReleased) _pool._releaseConnection(_pconn);
    _isReleased = true;    
  }

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


class PooledConnectionImpl implements PooledConnection {

  PooledConnectionImpl(this._pool);

  final PoolImpl _pool;
  pg.Connection _connection;
  ConnectionAdapter _adapter;
  PooledConnectionState _state;
  DateTime _established;
  DateTime _obtained;
  DateTime _released;
  String _debugId;
  int _useId;
  bool _isLeaked = false;
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
  
  /// Returns null if not connected yet.
  pg.ConnectionState get connectionState
    => _connection == null ? null : _connection.state;
  
  String get name => '${_pool.settings.poolName}:$backendPid'
      + (_useId == null ? '' : ':$_useId')
      + (_debugId == null ? '' : ':$_debugId');

  String toString() => '$name $_state $connectionState est: $_established obt: $_obtained';
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
      join0() {
        join1() {
          var stopwatch = new Stopwatch()
              ..start();
          var pconn = new PooledConnectionImpl(this);
          pconn._state = connecting;
          _connections.add(pconn);
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
              pconn._state = available;
              _debug('Established connection. ${pconn.name}');
              completer0.complete();
            } catch (e0, s0) {
              completer0.completeError(e0, s0);
            }
          }, onError: completer0.completeError);
        }
        if (_connections.length >= settings.maxConnections) {
          completer0.complete(new Future.value());
        } else {
          join1();
        }
      }
      if (!(_state == running || _state == PoolState.starting)) {
        completer0.complete(new Future.value());
      } else {
        join0();
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}
  
  void _heartbeat() {
    if (_state != running) return;
    
    for (var pconn in _connections) {
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
            'transactionState: ${pconn._connection.transactionState}',
          stackTrace: pconn._stackTrace));
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
      join0() {
        StackTrace stackTrace = null;
        join1() {
          new Future.value(_connect(settings.connectionTimeout)).then((x0) {
            try {
              var pconn = x0;
              assert(pconn._state == testing);
              assert(pconn._connection.state == idle);
              assert(pconn._connection.transactionState == none);
              pconn
                  .._state = inUse
                  .._obtained = new DateTime.now()
                  .._useId = _sequence++
                  .._debugId = debugId
                  .._stackTrace = stackTrace;
              _debug('Connected. ${pconn.name} ${pconn._connection}');
              completer0.complete(new ConnectionAdapter(this, pconn, pconn._connection));
            } catch (e0, s0) {
              completer0.completeError(e0, s0);
            }
          }, onError: completer0.completeError);
        }
        if (settings.leakDetectionThreshold != null) {
          join2() {
            join1();
          }
          catch0(ex, st) {
            try {
              stackTrace = st;
              join2();
            } catch (ex, st) {
              completer0.completeError(ex, st);
            }
          }
          try {
            throw "Generate stacktrace.";
            join2();
          } catch (e1, s1) {
            catch0(e1, s1);
          }
        } else {
          join1();
        }
      }
      if (_state != running) {
        throw new pg.PostgresqlException('Connect called while pool is not running.');
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

  Future<PooledConnectionImpl> _connect(Duration timeout) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      join0() {
        var stopwatch = new Stopwatch()
            ..start();
        var onTimeout = (() {
          return throw new TimeoutException('Connect timeout exceeded.', settings.connectionTimeout);
        });
        var pconn = _getFirstAvailable();
        join1() {
          pconn._state = testing;
          new Future.value(_testConnection(pconn, timeout - stopwatch.elapsed, onTimeout)).then((x0) {
            try {
              join2() {
                join3() {
                  completer0.complete();
                }
                if (timeout > stopwatch.elapsed) {
                  onTimeout();
                  join3();
                } else {
                  _destroyConnection(pconn);
                  completer0.complete(_connect(timeout - stopwatch.elapsed));
                }
              }
              if (x0) {
                completer0.complete(pconn);
              } else {
                join2();
              }
            } catch (e0, s0) {
              completer0.completeError(e0, s0);
            }
          }, onError: completer0.completeError);
        }
        if (pconn == null) {
          var c = new Completer<PooledConnectionImpl>();
          _waitQueue.add(c);
          join4() {
            assert(pconn.state == reserved);
            join1();
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
                finally0(join4);
              } catch (e3, s3) {
                catch0(e3, s3);
              }
            }, onError: catch0);
          } catch (e4, s4) {
            catch0(e4, s4);
          }
        } else {
          join1();
        }
      }
      if (state == stopping || state == stopped) {
        throw new pg.PostgresqlException('Connect failed as pool is stopping.');
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

  List<PooledConnectionImpl> _getAvailable()
    => _connections.where((c) => c._state == available).toList();

  PooledConnectionImpl _getFirstAvailable()
    => _connections.firstWhere((c) => c._state == available, orElse: () => null);

  /// If connections are available, return them to waiting clients.
  _processWaitQueue() {
    
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
    if (_waitQueue.isNotEmpty
        && _connections.length < settings.maxConnections) {
      int count = math.min(_waitQueue.length,
          settings.maxConnections - _connections.length);
      for (int i = 0; i < count; i++) {
        _establishConnection();
      }
    }
  }

  /// Perfom a query to check the state of the connection.
  Future<bool> _testConnection(
      PooledConnectionImpl pconn,
      Duration timeout, 
      Function onTimeout) {
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
            join1() {
              join0();
            }
            if (state != stopping && state != stopped) {
              join2(x0) {
                var msg = x0;
                _messages.add(new pg.ClientMessage(severity: 'WARNING', connectionName: pconn.name, message: msg, exception: ex));
                join1();
              }
              if (ex is TimeoutException) {
                join2('Connection test timed out.');
              } else {
                join2('Connection test failed.');
              }
            } else {
              join1();
            }
          } else {
            throw ex;
          }
        } catch (ex, s0) {
          completer0.completeError(ex, s0);
        }
      }
      try {
        new Future.value(pconn._connection.query('select true').single.timeout(timeout, onTimeout: onTimeout)).then((x1) {
          try {
            var row = x1;
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
  
  _destroyConnection(PooledConnectionImpl pconn) {
    _debug('Destroy connection. ${pconn.name}');
    if (pconn._connection != null) pconn._connection.close();
    pconn._state = connClosed;
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
        _waitQueue.forEach(((completer) {
          return completer.completeError(new pg.PostgresqlException('Connection pool is shutting down.'));
        }));
        _waitQueue.clear();
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
                    _messages.add(new pg.ClientMessage(severity: 'WARNING', message: 'Exceeded timeout while stopping pool, '
                        'closing in use connections.'));
                    new List.from(_connections).forEach(_destroyConnection);
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







