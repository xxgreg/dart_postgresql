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


  Future start() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
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
        new Future.value(Future.wait(futures).timeout(settings.startTimeout)).then((x0) {
          try {
            x0;
            break0() {
              _state = running;
              completer0.complete();
            }
            var trampoline0;
            continue0() {
              trampoline0 = null;
              if (_connections.length < settings.minConnections) {
                new Future.value(_establishConnection().timeout(settings.startTimeout - stopwatch.elapsed)).then((x1) {
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
      var pconn = new PooledConnection(this);
      pconn.state = connecting;
      new Future.value(_connectionFactory(databaseUri, null)).then((x0) {
        try {
          var conn = x0;
          pconn.connection = conn;
          pconn.established = new DateTime.now();
          pconn.adapter = new ConnectionAdapter(conn, onClose: (() {
            _releaseConnection(pconn);
          }));
          new Future.value(conn.query('select pg_backend_pid()').single).then((x1) {
            try {
              var row = x1;
              pconn.backendPid = row[0];
              _connections.add(pconn);
              pconn.state = available;
              completer0.complete();
            } catch (e0, s0) {
              completer0.completeError(e0, s0);
            }
          }, onError: completer0.completeError);
        } catch (e1, s1) {
          completer0.completeError(e1, s1);
        }
      }, onError: completer0.completeError);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}

  // Used to generate unique ids (well... unique for this isolate at least).
  static int _sequence = 1;

  Future<pg.Connection> connect({String debugId}) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _processWaitQueue();
      new Future.value(_connect(settings.connectionTimeout)).then((x0) {
        try {
          var pconn = x0;
          pconn
              ..state = inUse
              ..obtained = new DateTime.now()
              ..useId = _sequence++
              ..debugId = debugId;
          completer0.complete(pconn.adapter);
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

  Future<PooledConnection> _connect(Duration timeout) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      var stopwatch = new Stopwatch()
          ..start();
      var onTimeout = (() {
        return throw new TimeoutException('Connect timeout exceeded: ${settings.connectionTimeout}.', settings.connectionTimeout);
      });
      PooledConnection conn = _getFirstAvailable();
      join0() {
        new Future.value(_testConnection(conn).timeout(timeout - stopwatch.elapsed)).then((x0) {
          try {
            join1() {
              completer0.complete(conn);
            }
            if (!x0) {
              _destroyConnection(conn);
              completer0.complete(_connect(timeout - stopwatch.elapsed));
            } else {
              join1();
            }
          } catch (e0, s0) {
            completer0.completeError(e0, s0);
          }
        }, onError: completer0.completeError);
      }
      if (conn == null) {
        var c = new Completer();
        _waitQueue.add(c);
        new Future.value(c.future.timeout(timeout)).then((x1) {
          try {
            conn = x1;
            _waitQueue.remove(c);
            join0();
          } catch (e1, s1) {
            completer0.completeError(e1, s1);
          }
        }, onError: completer0.completeError);
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
  Future<bool> _testConnection(PooledConnection conn) {
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
            print('Connection test failed.');
            print(exception);
            join0();
          } else {
            throw ex;
          }
        } catch (ex, s0) {
          completer0.completeError(ex, s0);
        }
      }
      try {
        new Future.value(conn.connection.query('select true').single).then((x0) {
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

  Future stop() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      join0() {
        _state = stopping;
        var stopwatch = new Stopwatch()
            ..start();
        break0() {
          _state = stopped;
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
      if (state == stopped) {
        completer0.complete(null);
      } else {
        join0();
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}

  //FIXME just here for testing. Figure out a better way.
  List<PooledConnection> getConnections() => _connections;
}


