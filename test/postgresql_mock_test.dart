import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/mock/mock.dart';
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart';
import 'package:postgresql/src/protocol.dart';
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
testStartup(MockServer server) async {
    
    Future connecting = server.connect();
    Future backendStarting = server.waitForConnect();
    
    var backend = await backendStarting;
    
    //TODO make mock socket server and mock server behave the same.
    if (server is MockSocketServerImpl)
      await backend.waitForClient();
    
    expect(backend.received, equals([makeStartup('testdb', 'testdb')]));
    
    backend.clear();
    backend.sendToClient(makeAuth(authOk));
    backend.sendToClient(makeReadyForQuery(txIdle));
    
    var conn = await connecting;
    
    var sql = "select 'foo'";
    Stream<Row> querying = conn.query(sql);
    
    await backend.waitForClient();
    
    expect(backend.received, equals([makeQuery(sql)]), verbose: true);
    backend.clear();

    backend.sendToClient(makeRowDescription([new Field('?', PG_TEXT)]));
    backend.sendToClient(makeDataRow(['foo']));
    
    var row = null;
    await for (var r in querying) {
      row = r;
      
      expect(row, new isInstanceOf<Row>());
      expect(row.toList().length, equals(1));
      expect(row[0], equals('foo'));
      
      backend.sendToClient(makeCommandComplete('SELECT 1'));    
      backend.sendToClient(makeReadyForQuery(txIdle));
    }
    
    expect(row, isNotNull);
    
    conn.close();
    
    // Async in server, but sync in mock.
    //TODO make getter on backend. isRealSocket
    if (server is MockSocketServerImpl)
      await backend.waitForClient();
    
    expect(backend.received, equals([makeTerminate()]));
    expect(backend.isDestroyed, isTrue);
    
    server.stop();
}

