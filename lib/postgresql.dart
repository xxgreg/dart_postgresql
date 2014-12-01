library postgresql;

import 'dart:async';
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart' as impl;

/// Connect to a PostgreSQL database.
/// A uri has the following format:
/// 'postgres://testdb:password@localhost:5432/testdb'.
Future<Connection> connect(
    String uri, 
    { Duration connectionTimeout,
      String applicationName,
      String timeZone,
      TypeConverter typeConverter,
      String debugName}) 
    
      => impl.ConnectionImpl.connect(
            uri,
            connectionTimeout: connectionTimeout,
            applicationName: applicationName,
            timeZone: timeZone,
            typeConverter: typeConverter,
            getDebugName: () => debugName);


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

  /// Use messages.
  @deprecated Stream<Message> get unhandled;

  /// Server configuration parameters such as date format and timezone.
  Map<String,String> get parameters;
  
  /// The pid of the process the server started to handle this connection.
  int get backendPid;
  
  String get debugName;
  
  ConnectionState get state;

  TransactionState get transactionState;
  
  /// Use transactionState.
  @deprecated TransactionState get transactionStatus;
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
    
  /// Returns true if this is an error, otherwise it is a server-side notice,
  /// or logging.
  bool get isError;

  /// For a [ServerMessage] from an English localized database the field
  /// contents are ERROR, FATAL, or PANIC, for an error message. Otherwise in
  /// a notice message they are
  /// WARNING, NOTICE, DEBUG, INFO, or LOG.

  String get severity;

  /// A human readible error message, typically one line.
  String get message;

  /// An identifier for the connection. Useful for logging messages in a
  /// connection pool.
  String get connectionName;
}

abstract class ClientMessage implements Message {

  factory ClientMessage(
                {bool   isError,
                 String severity,
                 String message,
                 String connectionName,
                 exception,
                 StackTrace stackTrace}) = impl.ClientMessageImpl;

  final exception;
  final StackTrace stackTrace;
}

/// Represents an error or a notice sent from the postgresql server.
abstract class ServerMessage implements Message {

  /// Returns true if this is an error, otherwise it is a server-side notice.
  bool get isError;

  /// All of the information returned from the server.
  Map<String,String> get fields;
  
  /// An identifier for the connection. Useful for logging messages in a
  /// connection pool.
  String get connectionName;

  /// For a [ServerMessage] from an English localized database the field
  /// contents are ERROR, FATAL, or PANIC, for an error message. Otherwise in
  /// a notice message they are
  /// WARNING, NOTICE, DEBUG, INFO, or LOG.
  String get severity;
  
  /// A PostgreSQL error code.
  /// See http://www.postgresql.org/docs/9.2/static/errcodes-appendix.html
  String get code;
  
  /// A human readible error message, typically one line.
  String get message;

  /// More detailed information.
  String get detail;
  
  String get hint;

  /// The position as an index into the original query string where the syntax
  /// error was found. The first character has index 1, and positions are
  /// measured in characters not bytes. If the server does not supply a
  /// position this field is null.
  String get position;
  
  String get internalPosition;
  String get internalQuery;
  String get where;
  String get schema;
  String get table;
  String get column;
  String get dataType;
  String get constraint;
  String get file;
  String get line;
  String get routine;

}

//TODO Consider renaming. Parameter substitution and result set parsing aren't
// exactly symetric. So encode/decode may be a bit confusing.
abstract class TypeConverter {

  factory TypeConverter() = impl.DefaultTypeConverter;

  /// Returns all results in the raw postgresql string format without conversion.
  factory TypeConverter.raw() = impl.RawTypeConverter;
  
  /// Convert an object to a string representation to use in a sql query.
  /// Be very careful to escape your strings correctly. If you get this wrong
  /// you will introduce a sql injection vulnerability. Consider using the
  /// provided [encodeString] function.
  String encode(value, String type, {getConnectionName()});

  //TODO pgType is ... link to pg docs, and table where you can look these up. 
  // and also expose some constants for common types.
  
  /// Convert a string recieved from the database into a dart object.
  Object decode(String value, int pgType,
                {bool isUtcTimeZone, getConnectionName()});
}

/// Escape strings to a postgresql string format. i.e. E'str\'ing'
String encodeString(String s) => impl.encodeString(s);

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


@deprecated const Isolation READ_COMMITTED = Isolation.readCommitted;
@deprecated const Isolation REPEATABLE_READ = Isolation.repeatableRead;
@deprecated const Isolation SERIALIZABLE = Isolation.serializable;

@deprecated const TRANSACTION_BEGUN = TransactionState.begun;
@deprecated const TRANSACTION_ERROR = TransactionState.error;
@deprecated const TRANSACTION_NONE = TransactionState.none;
@deprecated const TRANSACTION_UNKNOWN = TransactionState.unknown;


class PostgresqlException implements Exception {
  
  PostgresqlException(this.message, this.connectionName, {this.serverMessage, this.exception});
  
  final String message;
  
  /// Note the connection name can be null in some cases when thrown by pool.
  final String connectionName;
  
  final ServerMessage serverMessage;
  
  /// Note may not always be an exception type.
  final exception;
  
  String toString() {
    if (serverMessage != null) return serverMessage.toString();
    return connectionName == null ? message : '$connectionName $message';
  }
}

/// Settings for PostgreSQL.
abstract class Settings {

  static const num defaultPort = 5432;
  
  factory Settings(String host, int port, String user, String password, String database,
      {bool requireSsl}) = impl.SettingsImpl;
  
  factory Settings.fromUri(String uri) = impl.SettingsImpl.fromUri;
  
  /// Parse a map, apply default rules etc. Throws [FormatException] when a
  /// setting (without default value) is present.
  factory Settings.fromMap(Map config) = impl.SettingsImpl.fromMap;
  String get host;
  int get port;
  String get user;
  String get password;
  String get database;
  bool get requireSsl;

  /// Return connection URI.
  String toUri();
  Map toMap();
  String toString();
}
