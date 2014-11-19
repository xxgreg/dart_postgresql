library postgresql;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:postgresql/constants.dart';
import 'package:postgresql/src/substitute.dart';
import 'package:postgresql/src/buffer.dart';

part 'src/postgresql/connection.dart';
part 'src/postgresql/constants.dart';
part 'src/postgresql/messages.dart';
part 'src/postgresql/query.dart';
part 'src/postgresql/settings.dart';
part 'src/postgresql/type_converter.dart';

/// Connect to a PostgreSQL database.
/// A uri has the following format:
/// 'postgres://testdb:password@localhost:5432/testdb'.
Future<Connection> connect(
    String uri, 
    { Duration connectionTimeout,
      TypeConverter typeConverter}) => 
        _Connection._connect(uri, connectionTimeout, typeConverter);

/// A connection to a PostgreSQL database.
abstract class Connection {

  /// Queue a sql query to be run, returning a [Stream] of rows.
  ///
  /// The data can be fetched from the rows by column name, or by index.
  ///
  /// Generally it is best to call [Stream.toList] on the stream and wait for
  /// all of the rows to be received.
  ///
  /// Example:
  ///
  ///     conn.query("select 'pear', 'apple' as a").toList().then((rows) {
  ///        print(row[0]);
  ///        print(row.a);
  ///     });
  ///
  Stream<Row> query(String sql, [values]);


  /// Queues a command for execution, and when done, returns the number of rows
  /// affected by the sql command.
  Future<int> execute(String sql, [values]);


  /// Allow multiple queries to be run in a transaction. The user must wait for
  /// runInTransaction() to complete before making any further queries.
  Future runInTransaction(Future operation(), [Isolation isolation]);


  /// Close the current [Connection]. It is safe to call this multiple times.
  /// This will never throw an exception.
  void close();

  /// The server can send notices or the network can cause errors while the
  /// connection is not being used to make a query. See [ClientMessage] and
  /// [ServerMessage] for more information.
  Stream<Message> get messages;


  /// Server configuration parameters such as date format and timezone.
  Map<String,String> get parameters;
  
  ConnectionState get state;


  TransactionState get transactionState;
}

/// Row allows field values to be retrieved as if they were getters.
///
///     c.query("select 'blah' as my_field")
///        .single
///        .then((row) => print(row.my_field));
///
/// Or by index.
///
///     c.query("select 'blah'")
///        .single
///        .then((row) => print(row[0]));
///
@proxy
abstract class Row {
  operator[] (int i);
  void forEach(void f(String columnName, columnValue));
  List toList();
  Map toMap();
}

abstract class Message {
  
  factory Message.from(Message m, {String connectionName}) 
    => _copy(m, connectionName: connectionName);
  
  /// Returns true if this is an error, otherwise it is a server-side notice,
  /// or logging.
  bool get isError;

  /// For a [ServerMessage] from an English localized database the field
  /// contents are ERROR, FATAL, or PANIC, for an error message. Otherwise in
  /// a notice message they are
  /// WARNING, NOTICE, DEBUG, INFO, or LOG.
  /// FIXME For [ClientMessage] ERROR, WARNING, DEBUG ??
  String get severity;

  /// A human readible error message, typically one line.
  String get message;

  /// An identifier for the connection. Useful for logging messages in a
  /// connection pool.
  String get connectionName;
}

abstract class ClientMessage implements Message {

  factory ClientMessage({String severity,
                 String message,
                 Object exception,
                 StackTrace stackTrace,
                 String connectionName}) = _ClientMessage;

  /// If an exception was thrown the body will be here.
  Object get exception;

  /// Stack trace may be null if the message does not represent an exception.
  StackTrace get stackTrace;

}

abstract class ServerMessage implements Message {

  /// A PostgreSQL error code.
  /// See http://www.postgresql.org/docs/9.2/static/errcodes-appendix.html
  String get code;

  /// More detailed information.
  String get detail;

  /// The position as an index into the original query string where the syntax
  /// error was found. The first character has index 1, and positions are
  /// measured in characters not bytes. If the server does not supply a
  /// position this field is null.
  int get position;

  /// All of the information returned from the server.
  String get allInformation;
}

abstract class TypeConverter {

  factory TypeConverter() = _DefaultTypeConverter;

  /// Returns all results in the raw postgresql string format without conversion.
  factory TypeConverter.raw() = _RawTypeConverter;

  /// Convert an object to a string representation to use in a sql query.
  /// Be very careful to escape your strings correctly. If you get this wrong
  /// you will introduce a sql injection vulnerability. Consider using the
  /// provided [encodeString] function.
  String encode(value, String type);

  /// Convert a string recieved from the database into a dart object.
  ///TODO pgType is ... link to pg docs, and table where you can look these up.
  /// Expose some constants.
  Object decode(String value, int pgType);
}

/// Escape strings to a postgresql string format. i.e. E'str\'ing'
String encodeString(String s) => _encodeString(s);

/// Default object to sql string encoding.
String encodeValue(value, String type) => _encodeValue(value, type);

//TODO docs do these correspond to libpq names?
//TODO change to enum once implemented.
class ConnectionState {
  final String _name;
  const ConnectionState(this._name);
  String toString() => _name;

  static const ConnectionState notConnected = const ConnectionState('notConnected');
  static const ConnectionState socketConnected = const ConnectionState('socketConnected');
  static const ConnectionState authenticating = const ConnectionState('authenticating');
  static const ConnectionState authenticated = const ConnectionState('authenticated');
  static const ConnectionState idle = const ConnectionState('idle');
  static const ConnectionState busy = const ConnectionState('busy');

  // state is called "ready" in libpq. Doesn't make sense in a non-blocking impl.
  static const ConnectionState streaming = const ConnectionState('streaming');
  static const ConnectionState closed = const ConnectionState('closed');
}

//TODO change to enum once implemented.
class TransactionState {
  final String _name;
  const TransactionState(this._name);
  String toString() => _name;

  static const TransactionState unknown = const TransactionState('unknown');
  static const TransactionState none = const TransactionState('none');
  static const TransactionState begun = const TransactionState('begun');
  static const TransactionState error = const TransactionState('error');
}

//TODO change to enum once implemented.
class Isolation {
  final String _name;
  const Isolation(this._name);
  String toString() => _name;

  static const Isolation readCommitted = const Isolation('readCommitted');
  static const Isolation repeatableRead = const Isolation('repeatableRead');
  static const Isolation serializable = const Isolation('serializable');
}

class PostgresqlException implements Exception {
  PostgresqlException(this._msg, [this.exception, this.stackTrace]);
  final String _msg;
  final dynamic exception;
  final StackTrace stackTrace;
  String toString() => exception == null ? _msg : '$_msg ($exception)';
}
