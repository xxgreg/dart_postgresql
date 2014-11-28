/// Library used for testing the postgresql connection pool.
library postgresql.mock;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart';

part 'mock_server.dart';
part 'mock_socket_server.dart';

Function mockLogger;

void _log(msg) { if (mockLogger != null) mockLogger(msg); }


const toClient = 'to-client';
const toServer = 'to-server';
const clientClosed = 'client-closed';
const clientDestroyed = 'client-destroyed';
const serverClosed = 'server-closed';
const socketError = 'socket-error';

class Packet {
  Packet(this.direction, this.data);
  var direction;
  List<int> data;
}


abstract class MockServer {
  
  factory MockServer() = MockServerImpl;
  
  // Starts a mock server using a real socket.
  static Future<MockServer> startSocketServer([int port])
    => MockSocketServerImpl.start(port);
  
  Future<pg.Connection> connect();
  
  List<Backend> get backends;
  
  Future<Backend> waitForConnect();
  
  void stop();
}


// For each call to MockServer.connect(), one backend is created.
abstract class Backend {

  List<Packet> get log;
  List<List<int>> get received;
  bool get isClosed;
  bool get isDestroyed; //FIXME do I need both this and close? Is this client side specific?
  
  /// Send data over the socket from the mock server to the client listening
  /// on the socket.
  void sendToClient(List<int> data);
  
  /// Clear out received data.
  void clear();
  
  /// Server closes the connection.
  void close();
  
  // This is can only be used for a MockServer, not a MockSocketServer.
  //FIXME can other types of exception be received?
  /// Client receives socket error.
  void socketException(String msg);
  
  Future waitForClient();
}



Stream<pg.Row> queryResults(List rows) => new Stream.fromIterable(
    rows.map((row) {
      if (row is Map) return new MockRow.fromMap(row);
      if (row is List) return new MockRow.fromList(row);
      throw 'Expected list or map, got: ${row.runtimeType}.';
    }));

int _sequence = 1;

class MockConnection implements pg.Connection {

  pg.ConnectionState state = pg.ConnectionState.idle;
  pg.TransactionState transactionState = none;
  pg.TransactionState transactionStatus = none;

  Map<String,String> parameters = {};
  
  int backendPid = 42;
  
  Stream query(String sql, [values]) {
    _log('query("$sql")');
    if (sql == 'select pg_backend_pid()') return queryResults([[_sequence++]]);
    if (sql == 'select true') return queryResults([[true]]);
    // TODO allow adding json query results. i.e. [[42]]
    if (sql.startsWith('mock timeout')) {
      var re = new RegExp(r'mock timeout (\d+)');
      var match = re.firstMatch(sql);
      int delay = match == null ? 10 : int.parse(match[1]);
      return new Stream.fromFuture(
          new Future.delayed(new Duration(seconds: delay)));
    }
    return onQuery(sql, values);
  }

  Function onQuery = (sql, values) {};

  Future<int> execute(String sql, [values]) {
    _log('execute("$sql")');
    return onExecute(sql, values);
  }

  Function onExecute = (sql, values) {};


  void close() {
    _log('close');
    onClose();
  }

  Function onClose = () {};


  Stream<pg.Message> get messages => messagesController.stream;
  Stream<pg.Message> get unhandled => messages;
  StreamController<pg.Message> messagesController = new StreamController.broadcast();

  Future runInTransaction(Future operation(), [pg.Isolation isolation])
    => throw new UnimplementedError();

}


abstract class MockRow implements pg.Row {
  factory MockRow.fromList(List list) => new _ListMockRow(list);
  factory MockRow.fromMap(LinkedHashMap map) => new _MapMockRow(map);
}

@proxy
class _MapMockRow implements MockRow {

  _MapMockRow(this._values);

  final LinkedHashMap _values;

  operator [](int i) {
    return _values.values.elementAt(i);
  }

  @override
  void forEach(void f(String columnName, columnValue)) {
    _values.forEach(f);
  }

  noSuchMethod(Invocation invocation) {
    var name = invocation.memberName;
    if (invocation.isGetter) {
      return _values[name];
    }
    super.noSuchMethod(invocation);
  }

  String toString() => _values.values.toString();
}

class _ListMockRow implements MockRow {

  _ListMockRow(List values, [List<String> columnNames])
      : _values = values,
        _columnNames = columnNames == null
          ? new Iterable.generate(values.length, (i) => i.toString()).toList()
          : columnNames;

  final List _values;
  final List<String> _columnNames;

  operator [](int i) {
    return _values.elementAt(i);
  }

  @override
  void forEach(void f(String columnName, columnValue)) {
    toMap().forEach(f);
  }

  String toString() => _values.toString();
  
  List toList() => new UnmodifiableListView(_values);
  
  Map toMap() => new Map.fromIterables(_columnNames, _values);
}

