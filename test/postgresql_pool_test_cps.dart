import 'dart:async';
import 'package:postgresql/constants.dart';
import 'package:postgresql/pool.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/mock/mock.dart';
import 'package:postgresql/src/pool_impl_cps.dart';
import 'package:unittest/unittest.dart';


//_log(msg) => print(msg);
_log(msg) { }

main() {
  mockLogger = _log;

  test('Test pool', testPool);
  test('Test start timeout', testStartTimeout);
  test('Test connect timeout', testConnectTimeout);
  test('Test wait queue', testWaitQueue);
}

PoolImpl createPool(PoolSettings settings) {
  int minConnections = 2;
  return new PoolImpl(settings, null, mockConnectionFactory());
}

expectState(PoolImpl pool, {int total, int available, int inUse}) {
  int ctotal = pool.connections.length;
  int cavailable = pool.connections
        .where((c) => c.state == PooledConnectionState.available).length;
  int cinUse = pool.connections
        .where((c) => c.state == PooledConnectionState.inUse).length;
  
  if (total != null) expect(ctotal, equals(total));
  if (available != null) expect(cavailable, equals(available));
  if (inUse != null) expect(cinUse, equals(inUse));
}

Future testPool() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      var pool = createPool(new PoolSettings(databaseUri: 'postgresql://fakeuri', minConnections: 2));
      new Future.value(pool.start()).then((x0) {
        try {
          var v = x0;
          expect(v, isNull);
          expectState(pool, total: 2, available: 2, inUse: 0);
          new Future.value(pool.connect()).then((x1) {
            try {
              var c = x1;
              expectState(pool, total: 2, available: 1, inUse: 1);
              c.close();
              new Future.value(new Future((() {
              }))).then((x2) {
                try {
                  x2;
                  expectState(pool, total: 2, available: 2, inUse: 0);
                  var stopFuture = pool.stop();
                  new Future.value(new Future((() {
                  }))).then((x3) {
                    try {
                      x3;
                      expect(pool.state, equals(stopping));
                      new Future.value(stopFuture).then((x4) {
                        try {
                          var v2 = x4;
                          expect(v2, isNull);
                          expect(pool.state, equals(stopped));
                          expectState(pool, total: 0, available: 0, inUse: 0);
                          completer0.complete();
                        } catch (e0, s0) {
                          completer0.completeError(e0, s0);
                        }
                      }, onError: completer0.completeError);
                    } catch (e1, s1) {
                      completer0.completeError(e1, s1);
                    }
                  }, onError: completer0.completeError);
                } catch (e2, s2) {
                  completer0.completeError(e2, s2);
                }
              }, onError: completer0.completeError);
            } catch (e3, s3) {
              completer0.completeError(e3, s3);
            }
          }, onError: completer0.completeError);
        } catch (e4, s4) {
          completer0.completeError(e4, s4);
        }
      }, onError: completer0.completeError);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}


Future testStartTimeout() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      var mockConnect = mockConnectionFactory((() {
        return new Future.delayed(new Duration(seconds: 10));
      }));
      var settings = new PoolSettings(databaseUri: 'postgresql://fakeuri', startTimeout: new Duration(seconds: 2), minConnections: 2);
      var pool = new PoolImpl(settings, null, mockConnect);
      join0() {
        completer0.complete();
      }
      catch0(ex, st) {
        try {
          expect(ex, new isInstanceOf<PostgresqlException>());
          expect(ex.message, contains('timed out'));
          expect(pool.state, equals(startFailed));
          join0();
        } catch (ex, st) {
          completer0.completeError(ex, st);
        }
      }
      try {
        expect(pool.connections, isEmpty);
        new Future.value(pool.start()).then((x0) {
          try {
            var v = x0;
            fail('Pool started, but should have timed out.');
            join0();
          } catch (e0, s0) {
            catch0(e0, s0);
          }
        }, onError: catch0);
      } catch (e1, s1) {
        catch0(e1, s1);
      }
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}


Future testConnectTimeout() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      var settings = new PoolSettings(databaseUri: 'postgresql://fakeuri', minConnections: 2, maxConnections: 2, connectionTimeout: new Duration(seconds: 2));
      var pool = createPool(settings);
      expect(pool.connections, isEmpty);
      var f = pool.start();
      expect(pool.state, equals(initial));
      new Future.value(f).then((x0) {
        try {
          var v = x0;
          expect(v, isNull);
          expect(pool.state, equals(running));
          expect(pool.connections.length, equals(settings.minConnections));
          expect(pool.connections.where(((c) {
            return c.state == available;
          })).length, equals(settings.minConnections));
          new Future.value(pool.connect()).then((x1) {
            try {
              var c1 = x1;
              new Future.value(pool.connect()).then((x2) {
                try {
                  var c2 = x2;
                  expect(pool.connections.where(((c) {
                    return c.state == available;
                  })).length, 0);
                  join0() {
                    c1.close();
                    expect(c1.state, equals(closed));
                    new Future.value(pool.connect()).then((x3) {
                      try {
                        var c3 = x3;
                        expect(c3.state, equals(idle));
                        c2.close();
                        c3.close();
                        expect(c1.state, equals(closed));
                        expect(c3.state, equals(closed));
                        expect(pool.connections.where(((c) {
                          return c.state == available;
                        })).length, equals(settings.minConnections));
                        completer0.complete();
                      } catch (e0, s0) {
                        completer0.completeError(e0, s0);
                      }
                    }, onError: completer0.completeError);
                  }
                  catch0(ex, st) {
                    try {
                      if (ex is PostgresqlException) {
                        expect(ex, new isInstanceOf<PostgresqlException>());
                        expect(ex.message, contains('timeout'));
                        expect(pool.state, equals(running));
                        join0();
                      } else {
                        throw ex;
                      }
                    } catch (ex, st) {
                      completer0.completeError(ex, st);
                    }
                  }
                  try {
                    new Future.value(pool.connect()).then((x4) {
                      try {
                        var c = x4;
                        fail('connect() should have timed out.');
                        join0();
                      } catch (e1, s1) {
                        catch0(e1, s1);
                      }
                    }, onError: catch0);
                  } catch (e2, s2) {
                    catch0(e2, s2);
                  }
                } catch (e3, s3) {
                  completer0.completeError(e3, s3);
                }
              }, onError: completer0.completeError);
            } catch (e4, s4) {
              completer0.completeError(e4, s4);
            }
          }, onError: completer0.completeError);
        } catch (e5, s5) {
          completer0.completeError(e5, s5);
        }
      }, onError: completer0.completeError);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}


Future testWaitQueue() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      var settings = new PoolSettings(databaseUri: 'postgresql://fakeuri', minConnections: 2, maxConnections: 2);
      var pool = createPool(settings);
      expect(pool.connections, isEmpty);
      new Future.value(pool.start()).then((x0) {
        try {
          var v = x0;
          expect(v, isNull);
          expect(pool.connections.length, equals(2));
          expect(pool.connections.where(((c) {
            return c.state == available;
          })).length, equals(2));
          new Future.value(pool.connect()).then((x1) {
            try {
              var c1 = x1;
              new Future.value(pool.connect()).then((x2) {
                try {
                  var c2 = x2;
                  c1.query('mock timeout 5').toList().then(((r) {
                    return c1.close();
                  }));
                  c2.query('mock timeout 10').toList().then(((r) {
                    return c2.close();
                  }));
                  var conns = pool.connections;
                  expect(conns.length, equals(2));
                  expect(conns.where(((c) {
                    return c.state == available;
                  })).length, equals(0));
                  expect(conns.where(((c) {
                    return c.state == inUse;
                  })).length, equals(2));
                  new Future.value(pool.connect()).then((x3) {
                    try {
                      var c3 = x3;
                      expect(c3.state, equals(idle));
                      c3.close();
                      completer0.complete();
                    } catch (e0, s0) {
                      completer0.completeError(e0, s0);
                    }
                  }, onError: completer0.completeError);
                } catch (e1, s1) {
                  completer0.completeError(e1, s1);
                }
              }, onError: completer0.completeError);
            } catch (e2, s2) {
              completer0.completeError(e2, s2);
            }
          }, onError: completer0.completeError);
        } catch (e3, s3) {
          completer0.completeError(e3, s3);
        }
      }, onError: completer0.completeError);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}

