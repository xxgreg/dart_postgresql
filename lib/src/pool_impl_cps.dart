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


typedef Future<pgi.ConnectionImpl> ConnectionFactory(
    String uri,
    {Duration connectionTimeout,
     String applicationName,
     String timeZone,
     pg.TypeConverter typeConverter,
     String getDebugName(),
     Future<Socket> mockSocketConnect(String host, int port)});

class ConnectionDecorator implements pg.Connection {

  ConnectionDecorator(this._pool, this._pconn, this._conn);

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
  
  @deprecated pg.TransactionState get transactionStatus => _conn.transactionState;

  Stream<pg.Message> get messages => _conn.messages;
  
  @deprecated Stream<pg.Message> get unhandled => messages;

  Map<String,String> get parameters => _conn.parameters;
  
  int get backendPid => _conn.backendPid;
  
  String get debugName => _conn.debugName;
}


class PooledConnectionImpl implements PooledConnection {

  PooledConnectionImpl(this._pool);

  final PoolImpl _pool;
  pg.Connection _connection;
  ConnectionDecorator _decorator;
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

  Future start() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _debug('start');
      join0() {
        var stopwatch = new Stopwatch()
            ..start();
        var onTimeout = (() {
          _state = startFailed;
          throw new pg.PostgresqlException('Connection pool start timed out with: ' '${settings.startTimeout}).', null);
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
        throw new pg.PostgresqlException('Cannot start connection pool while in state: ${_state}.', null);
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
          new Future.value(_connectionFactory(settings.databaseUri, connectionTimeout: settings.establishTimeout, applicationName: settings.applicationName, timeZone: settings.timeZone, typeConverter: _typeConverter, getDebugName: (() {
            return pconn.name;
          }))).then((x0) {
            try {
              var conn = x0;
              conn.messages.listen(((msg) {
                return _messages.add(msg);
              }), onError: ((msg) {
                return _messages.addError(msg);
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

  Future<pg.Connection> connect({String debugName}) {
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
              assert((settings.testConnections && pconn._state == testing) || (!settings.testConnections && pconn._state == reserved));
              assert(pconn._connection.state == idle);
              assert(pconn._connection.transactionState == none);
              pconn
                  .._state = inUse
                  .._obtained = new DateTime.now()
                  .._useId = _sequence++
                  .._debugName = debugName
                  .._stackTrace = stackTrace;
              _debug('Connected. ${pconn.name} ${pconn._connection}');
              completer0.complete(new ConnectionDecorator(this, pconn, pconn._connection));
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
        throw new pg.PostgresqlException('Connect called while pool is not running.', null);
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
        var pconn = _getFirstAvailable();
        var onTimeout = (() {
          return throw new pg.PostgresqlException('Obtaining connection from pool exceeded timeout: ' '${settings.connectionTimeout}', pconn == null ? null : pconn.name);
        });
        join1() {
          join2() {
            pconn._state = testing;
            new Future.value(_testConnection(pconn, timeout - stopwatch.elapsed, onTimeout)).then((x0) {
              try {
                join3() {
                  join4() {
                    completer0.complete();
                  }
                  if (timeout > stopwatch.elapsed) {
                    onTimeout();
                    join4();
                  } else {
                    _destroyConnection(pconn);
                    completer0.complete(_connect(timeout - stopwatch.elapsed));
                  }
                }
                if (x0) {
                  completer0.complete(pconn);
                } else {
                  join3();
                }
              } catch (e0, s0) {
                completer0.completeError(e0, s0);
              }
            }, onError: completer0.completeError);
          }
          if (!settings.testConnections) {
            pconn._state = reserved;
            completer0.complete(pconn);
          } else {
            join2();
          }
        }
        if (pconn == null) {
          var c = new Completer<PooledConnectionImpl>();
          _waitQueue.add(c);
          join5() {
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
                finally0(join5);
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
        throw new pg.PostgresqlException('Connect failed as pool is stopping.', null);
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
        new Future.value(pconn._connection.query('select true').single.timeout(timeout)).then((x1) {
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
  
  Future _stop() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _state = stopping;
      join0() {
        _waitQueue.forEach(((completer) {
          return completer.completeError(new pg.PostgresqlException('Connection pool is stopping.', null));
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







