library postgresql;

import 'dart:async';
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart' as impl;

/// Connect to a PostgreSQL database.
/// 
/// A uri has the following format:
/// 
///     'postgres://username:password@hostname:5432/database'
///
/// The application name is displayed in the pg_stat_activity view. This
/// parameter is optional.
/// 
/// Care is required when setting the time zone, this is generally not required,
/// the default, if omitted, is to use the server provided default which will 
/// typically be localtime or sometimes UTC. Setting the time zone to UTC will
/// override the server provided default and all [DateTime] objects will be
/// returned in UTC. In the case where the application server is on a different 
/// host than the database, and the host's [DateTime]s should be in the hosts
/// localtime, then set this to the host's local time zone name. On linux 
/// systems this can be obtained using:
/// 
///     new File('/etc/timezone').readAsStringSync().trim()
/// 
/// The debug name is shown in error messages, this helps tracking down which
/// connection caused an error.
/// 
/// The type converter allows the end user to provide their own mapping to and
/// from Dart types to PostgreSQL types.

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

  /// Queue a sql query to be run, returning a [Stream] of [Row]s.
  ///
  /// If another query is already in progress, then the query will be queued
  /// and executed once the preceding query is complete.
  ///
  /// The results can be fetched from the [Row]s by column name, or by index.
  ///
  /// Generally it is best to call [Stream.toList] on the stream and wait for
  /// all of the rows to be received.
  ///
  /// For example:
  ///
  ///     conn.query("select 'pear', 'apple' as a").toList().then((rows) {
  ///        print(row[0]);
  ///        print(row.a);
  ///     });
  ///
  /// Values can be substitued into the sql query. If a string contains quotes
  /// or other special characters these will be escaped.
  ///
  /// For example:
  ///  
  ///     var a = 'bar';
  ///     var b = 42;
  ///     
  ///     conn.query("insert into foo_table values (@a, @b);", {'a': a, 'b': b})
  ///       .then(...);
  ///       
  ///  Or:
  ///  
  ///     conn.query("insert into foo_table values (@0, @1);", [a, b])
  ///        .then(...);
  ///        
  ///  If you need to use an '@' character in your query then you will need to
  ///  escape it as '@@'. If no values are provided, then there is no need to
  ///  escape '@' characters.
  Stream<Row> query(String sql, [values]);


  /// Queues a command for execution, and when done, returns the number of rows
  /// affected by the sql command. Indentical to [query] apart from the
  /// information returned.
  Future<int> execute(String sql, [values]);


  /// Allow multiple queries to be run in a transaction. The user must wait for
  /// runInTransaction() to complete before making any further queries.
  Future runInTransaction(Future operation(), [Isolation isolation]);


  /// Close the current [Connection]. It is safe to call this multiple times.
  /// This will never throw an exception.
  void close();

  /// The server can send errors and notices, or the network can cause errors
  /// while the connection is not being used to make a query. These can be 
  /// caught by listening to the messages stream. See [ClientMessage] and 
  /// [ServerMessage] for more information.
  Stream<Message> get messages;

  /// Deprecated. Use messages.
  @deprecated Stream<Message> get unhandled;

  /// Server configuration parameters such as date format and timezone.
  Map<String,String> get parameters;
  
  /// The pid of the process the server started to handle this connection.
  int get backendPid;
  
  /// The debug name passed into the connect function.
  String get debugName;
  
  /// The current state of the connection.
  ConnectionState get state;

  /// The state of the current transaction.
  TransactionState get transactionState;
  
  /// Deprecated. Use transactionState.
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
  
  /// Get a column value by column index (zero based).
  operator[] (int i);
  
  /// Iterate through column names and values.
  void forEach(void f(String columnName, columnValue));
  
  /// An unmodifiable list of column values.
  List toList();
  
  /// An unmodifiable map of column names and values. 
  Map toMap();
}


/// The server can send errors and notices, or the network can cause errors
/// while the connection is not being used to make a query. See 
/// [ClientMessage] and [ServerMessage] for more information.
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

/// An error or warning generated by the client.
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


/// By implementing this class and passing it to connect(), it is possible to
/// provide a customised handling of the Dart type encoding and PostgreSQL type 
/// decoding. 
abstract class TypeConverter {

  factory TypeConverter() = impl.DefaultTypeConverter;

  /// Returns all results in the raw postgresql string format without conversion.
  factory TypeConverter.raw() = impl.RawTypeConverter;
  
  /// Convert an object to a string representation to use in a sql query.
  /// Be very careful to escape your strings correctly. If you get this wrong
  /// you will introduce a sql injection vulnerability. Consider using the
  /// provided [encodeString] function.
  String encode(value, String type, {getConnectionName()});

  /// Convert a string recieved from the database into a dart object.
  Object decode(String value, int pgType,
                {bool isUtcTimeZone, getConnectionName()});
}

/// Escape strings to a postgresql string format. i.e. E'str\'ing'
String encodeString(String s) => impl.encodeString(s);


//TODO change to enum once implemented.

/// The current state of a connection.
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

/// Describes whether the a connection is participating in a transaction, and
/// if the transaction has failed.
class TransactionState {
  final String _name;
  
  const TransactionState(this._name);
  
  String toString() => _name;

  /// Directly after sending a query the transaction state is unknown, as the
  /// query may change the transaction state. Wait until the query is completed
  /// to query the transaction state.
  static const TransactionState unknown = const TransactionState('unknown');
  
  /// The current session has not opened a transaction.
  static const TransactionState none = const TransactionState('none');
  
  /// The current session has an open transaction.
  static const TransactionState begun = const TransactionState('begun');
  
  /// A transaction was opened on the current session, but an error occurred.
  /// In this state all futher commands will be ignored until a rollback is
  /// issued.
  static const TransactionState error = const TransactionState('error');
}

//TODO change to enum once implemented.

/// See http://www.postgresql.org/docs/9.3/static/transaction-iso.html
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
  
  /// Note may be null.
  final exception;
  
  String toString() {
    if (serverMessage != null) return serverMessage.toString();
    return connectionName == null ? message : '$connectionName $message';
  }
}

/// Settings can be used to create a postgresql uri for use in the [connect]
/// function.
/// 
/// An example of loading the connection settings from yaml using the
/// [yaml package](https://pub.dartlang.org/packages/yaml): 
/// 
///     var map = loadYaml(new File('db.yaml').readAsStringSync());
///     var settings = new Settings.fromMap(map);
///     var uri = settings.toUri();
///     connect(uri).then(...);
///     
abstract class Settings {

  /// The default port used by a PostgreSQL server.
  static const num defaultPort = 5432;
  
  factory Settings(String host, int port, String user, String password,
      String database, {bool requireSsl}) = impl.SettingsImpl;
  
  /// Parse a PostgreSQL URI string.
  factory Settings.fromUri(String uri) = impl.SettingsImpl.fromUri;
  
  /// Read settings from a map and set default values for unspecified values.
  /// Throws [PostgresqlException] when a required setting is not provided.
  factory Settings.fromMap(Map config) = impl.SettingsImpl.fromMap;
  String get host;
  int get port;
  String get user;
  String get password;
  String get database;
  bool get requireSsl;

  /// Return a connection URI.
  String toUri();
  Map toMap();
  String toString();
}
