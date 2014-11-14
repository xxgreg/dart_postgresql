library postgresql.mock;

//FIXME shift this file into lib.

import 'dart:async';
import 'dart:collection';
import 'package:postgresql/postgresql.dart' as pg;

void _log(msg) => mockLogger(msg);
Function mockLogger;

Stream<pg.Row> queryResults(List rows) => new Stream.fromIterable(
    rows.map((row) {
      if (row is Map) return new MockRow.fromMap(row);
      if (row is List) return new MockRow.fromList(row);
      throw 'Expected list or map, got: ${row.runtimeType}.';
    }));

int _sequence = 1;

class MockConnection implements pg.Connection {

  int state = pg.IDLE;
  int transactionStatus = pg.TRANSACTION_NONE;

  Stream query(String sql, [values]) {
    _log('query("$sql")');
    if (sql == 'select pg_backend_pid()') return queryResults([[_sequence++]]);
    if (sql == 'select true') return queryResults([[true]]);
    if (sql.startsWith('mock timeout')) {
      var re = new RegExp(r'mock timeout (\d+)');
      var match = re.firstMatch(sql);
      int delay = match == null ? 10 : int.parse(match[1]);
      return new Stream.fromFuture(
          new Future.delayed(new Duration(seconds: delay)));
    }
    return onQuery(sql, values);
  }

  Function onQuery;

  Future<int> execute(String sql, [values]) {
    _log('execute("$sql")');
    return onExecute(sql, values);
  }

  Function onExecute;


  void close() {
    _log('close');
    onClose();
  }

  Function onClose;


  Stream<pg.Message> get messages => messagesController.stream;
  StreamController<pg.Message> messagesController = new StreamController.broadcast();

  Future runInTransaction(Future operation(), [pg.Isolation isolation])
    => throw new UnimplementedError();

  //TODO remove these.
  @override
  Future get onClosed => null;

  @override
  int get connectionId => null;
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

  _ListMockRow(this._values);

  List _values;

  operator [](int i) {
    return _values.elementAt(i);
  }

  @override
  void forEach(void f(String columnName, columnValue)) {
    _values.forEach((v) => f('?', v));
  }

  String toString() => _values.toString();
}

