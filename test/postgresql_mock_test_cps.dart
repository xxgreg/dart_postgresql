import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart';
import 'package:postgresql/src/mock/mock.dart';
import 'package:unittest/unittest.dart';


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
                makeStartup('testdb', 'testdb')
            ]));
            backend.clear();
            backend.sendToClient(makeAuth(authOk));
            backend.sendToClient(makeReadyForQuery(txIdle));
            new Future.value(connecting).then((x1) {
              try {
                var conn = x1;
                var sql = "select 'foo'";
                Stream<Row> querying = conn.query(sql);
                new Future.value(backend.waitForClient()).then((x2) {
                  try {
                    x2;
                    expect(backend.received, equals([
                        makeQuery(sql)
                    ]), verbose: true);
                    backend.clear();
                    backend.sendToClient(makeRowDescription([
                        new Field('?', PG_TEXT)
                    ]));
                    backend.sendToClient(makeDataRow([
                        'foo'
                    ]));
                    var row = null;
                    done0() {
                      expect(row, isNotNull);
                      conn.close();
                      join1() {
                        expect(backend.received, equals([
                            makeTerminate()
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
                      backend.sendToClient(makeCommandComplete('SELECT 1'));
                      backend.sendToClient(makeReadyForQuery(txIdle));
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


// Move all of these messages in to a protocol package.

// TODO make a set of Message classes with a parse/serialize method.
// http://www.postgresql.org/docs/9.2/static/protocol-message-formats.html

List<int> makeStartup(String user, String db) {
  var buf = new MessageBuffer()
    ..addInt32(0)
    ..addInt32(196608)
    ..addUtf8String('user')
    ..addUtf8String(user)
    ..addUtf8String('database')
    ..addUtf8String(db)
  //TODO write params list.
    ..addByte(0)
    ..setLength(startup: true);
  return buf.buffer;
}

List<int> makeSslRequest() => [0, 0, 0, 8, 4, 210, 22, 47];

List<int> makeTerminate() {
  var buf = new MessageBuffer()
  ..addByte('X'.codeUnitAt(0))
  ..addInt32(0)
  ..setLength();
  return buf.buffer;
}


const int authOk = 0;
const int authKerebosV5 = 2;
const int authScm = 6;
const int authGss = 7;
const int authClearText = 3;

List<int> makeAuth(int authType) {
  var buf = new MessageBuffer()
  ..addByte('R'.codeUnitAt(0))
  ..addInt32(0)
  ..addInt32(authType)
  ..setLength();
  return buf.buffer;
}

List<int> makeAuthMd5() {
  var buf = new MessageBuffer()
  ..addByte('R'.codeUnitAt(0))
  ..addInt32(0)
  ..addInt32(5)
  // Salt
  ..addByte(1)
  ..addByte(2)
  ..addByte(3)
  ..addByte(4)
  ..setLength();
  return buf.buffer;
}

List<int> makeBackendKeyData(int pid, int secretKey) {
  var buf = new MessageBuffer()
  ..addByte('K'.codeUnitAt(0))
  ..addInt32(0)
  ..addInt32(pid)
  ..addInt32(secretKey)
  ..setLength();
  return buf.buffer;
}

List<int> makeParameterStatus(String name, String value) {
  var buf = new MessageBuffer()
  ..addByte('S'.codeUnitAt(0))
  ..addInt32(0)
  ..addUtf8String(name)
  ..addUtf8String(value)
  ..setLength();
  return buf.buffer;
}

List<int> makeQuery(String query) {
  var buf = new MessageBuffer()
  ..addByte('Q'.codeUnitAt(0))
  ..addInt32(0)
  ..addUtf8String(query)
  ..setLength();
  return buf.buffer;
}

class Field {
  Field(this.name, this.fieldType);
  final String name;
  final int fieldId = 0;
  final int tableColNo = 0;
  final int fieldType;
  final int dataSize = -1;
  final int typeModifier = 0;
  final int formatCode = 0;
  bool get isBinary => formatCode == 1;
}

List<int> makeRowDescription(List<Field> fields) {
  var buf = new MessageBuffer()
  ..addByte('T'.codeUnitAt(0))
  ..addInt32(0)
  ..addInt16(fields.length);

  for (var f in fields) {
    buf..addUtf8String(f.name)
    ..addInt32(f.fieldId)
    ..addInt16(f.tableColNo)
    ..addInt32(f.fieldType)
    ..addInt16(f.dataSize)
    ..addInt32(f.typeModifier)
    ..addInt16(f.formatCode);
  }
  
  buf.setLength();
  return buf.buffer;
}


List<int> makeDataRow(List<String> row) {
  var buf = new MessageBuffer()
  ..addByte('D'.codeUnitAt(0))
  ..addInt32(0)
  ..addInt16(row.length);
  for (var value in row) {
    var bytes = UTF8.encode(value);
    buf..addInt32(bytes.length)
    ..addBytes(bytes);
  }
  buf.setLength();
  return buf.buffer;
}

List<int> makeCommandComplete(String command) {
  var buf = new MessageBuffer()
  ..addByte('C'.codeUnitAt(0))
  ..addInt32(0)
  ..addUtf8String(command)
  ..setLength();
  return buf.buffer;
}

// enum TxStatus { Idle, InTransaction, Error }

int txIdle = 1;
int txInTransaction = 2;
int txError = 3;

final int $I = 'I'.codeUnitAt(0);
final int $T = 'T'.codeUnitAt(0);
final int $E = 'E'.codeUnitAt(0);

List<int> makeReadyForQuery(int txState) {
  var buf = new MessageBuffer()
  ..addByte('Z'.codeUnitAt(0))
  ..addInt32(0)
  ..addByte({
      txIdle: $I,
      txInTransaction: $T,
      txError: $E}[txState])
  ..setLength();
  return buf.buffer;  
}

List<int> makeErrorResponse(Map<String,String> fields) {
  var buf = new MessageBuffer()
  ..addByte('E'.codeUnitAt(0))
  ..addInt32(0);
  for (var key in fields.keys) {
    buf..addByte(key.codeUnitAt(0))
      ..addUtf8String(fields[key]);
  }
  buf.setLength();
  return buf.buffer;
}

List<int> makeNoticeResponse(Map<String,String> fields) {
  var buf = new MessageBuffer()
  ..addByte('N'.codeUnitAt(0))
  ..addInt32(0);
  for (var key in fields.keys) {
    buf..addByte(key.codeUnitAt(0))
    ..addUtf8String(fields[key]);
  }
  buf.setLength();
  return buf.buffer;
}


List<int> makeEmptyQueryResponse() {
  var buf = new MessageBuffer()
  ..addByte('I'.codeUnitAt(0))
  ..addInt32(0)
  ..setLength();
  return buf.buffer;
}


class MessageBuffer {
  List<int> _buffer = new List<int>();
  List<int> get buffer => _buffer;

  void addByte(int byte) {
    assert(byte >= 0 && byte < 256);
    _buffer.add(byte);
  }

  void addInt16(int i) {
    assert(i >= -32768 && i <= 32767);

    if (i < 0)
      i = 0x10000 + i;

    int a = (i >> 8) & 0x00FF;
    int b = i & 0x00FF;

    _buffer.add(a);
    _buffer.add(b);
  }

  void addInt32(int i) {
    assert(i >= -2147483648 && i <= 2147483647);

    if (i < 0)
      i = 0x100000000 + i;

    int a = (i >> 24) & 0x000000FF;
    int b = (i >> 16) & 0x000000FF;
    int c = (i >> 8) & 0x000000FF;
    int d = i & 0x000000FF;

    _buffer.add(a);
    _buffer.add(b);
    _buffer.add(c);
    _buffer.add(d);
  }

  void addUtf8String(String s) {
    //Postgresql server must be configured to accept UTF8 - this is the default.
    _buffer.addAll(UTF8.encode(s));
    addByte(0);
  }
  
  void addBytes(List<int> bytes) {
    _buffer.addAll(bytes);
  }

  void setLength({bool startup: false}) {
    int offset = 0;
    int i = _buffer.length;

    if (!startup) {
      offset = 1;
      i -= 1;
    }

    _buffer[offset] = (i >> 24) & 0x000000FF;
    _buffer[offset + 1] = (i >> 16) & 0x000000FF;
    _buffer[offset + 2] = (i >> 8) & 0x000000FF;
    _buffer[offset + 3] = i & 0x000000FF;
  }
}



