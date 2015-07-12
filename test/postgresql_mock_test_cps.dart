import 'dart:async';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/mock/mock.dart';
import 'package:postgresql/src/protocol.dart';
import 'package:test/test.dart';


main() {
  
  mockLogger = print;
  
    test('testStartup with socket', 
        () => MockServer.startSocketServer().then(testStartup));

    test('testStartup with mock socket', () => testStartup(new MockServer()));
}

int PG_TEXT = 25;


//TODO test which parses/generates a recorded db stream to test protocol matches spec.
// Might mean that testing can be done at the message object level.
// But is good test test things like socket errors.
testStartup(MockServer server) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      Future connecting = server.connect();
      Future backendStarting = server.waitForConnect();
      new Future.value(backendStarting).then((x0) {
        try {
          var backend = x0;
          join0() {
            expect(backend.received, equals([
                new Startup('testdb', 'testdb').encode()
            ]));
            backend.clear();
            backend.sendToClient(new AuthenticationRequest.ok().encode());
            backend.sendToClient(new ReadyForQuery(TransactionStatus.none).encode());
            new Future.value(connecting).then((x1) {
              try {
                var conn = x1;
                var sql = "select 'foo'";
                Stream<Row> querying = conn.query(sql);
                new Future.value(backend.waitForClient()).then((x2) {
                  try {
                    x2;
                    expect(backend.received, equals([
                        new Query(sql).encode()
                    ]), verbose: true);
                    backend.clear();
                    backend.sendToClient(new RowDescription([
                        new Field('?', PG_TEXT)
                    ]).encode());
                    backend.sendToClient(new DataRow.fromStrings([
                        'foo'
                    ]).encode());
                    var row = null;
                    done0() {
                      expect(row, isNotNull);
                      conn.close();
                      join1() {
                        expect(backend.received, equals([
                            new Terminate().encode()
                        ]));
                        expect(backend.isDestroyed, isTrue);
                        server.stop();
                        completer0.complete();
                      }
                      if (server is MockSocketServerImpl) {
                        new Future.value(backend.waitForClient()).then((x3) {
                          try {
                            x3;
                            join1();
                          } catch (e0, s0) {
                            completer0.completeError(e0, s0);
                          }
                        }, onError: completer0.completeError);
                      } else {
                        join1();
                      }
                    }
                    var stream0;
                    finally0(cont0) {
                      try {
                        new Future.value(stream0.cancel()).then(cont0);
                      } catch (e1, s1) {
                        completer0.completeError(e1, s1);
                      }
                    }
                    catch0(e1, s1) {
                      finally0(() => completer0.completeError(e1, s1));
                    }
                    stream0 = querying.listen((x4) {
                      var r = x4;
                      row = r;
                      expect(row, new isInstanceOf<Row>());
                      expect(row.toList().length, equals(1));
                      expect(row[0], equals('foo'));
                      backend.sendToClient(new CommandComplete('SELECT 1').encode());
                      backend.sendToClient(new ReadyForQuery(TransactionStatus.none).encode());
                    }, onError: catch0, onDone: done0);
                  } catch (e2, s2) {
                    completer0.completeError(e2, s2);
                  }
                }, onError: completer0.completeError);
              } catch (e3, s3) {
                completer0.completeError(e3, s3);
              }
            }, onError: completer0.completeError);
          }
          if (server is MockSocketServerImpl) {
            new Future.value(backend.waitForClient()).then((x5) {
              try {
                x5;
                join0();
              } catch (e4, s4) {
                completer0.completeError(e4, s4);
              }
            }, onError: completer0.completeError);
          } else {
            join0();
          }
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


