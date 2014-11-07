library postgresql;

import 'dart:async';
import 'dart:collection';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:convert';

part 'buffer.dart';
part 'connection.dart';
part 'constants.dart';
part 'messages.dart';
part 'format_value.dart';
part 'message_buffer.dart';
part 'query.dart';
part 'settings.dart';
part 'substitute.dart';
part 'type_converter.dart';

/// Connect to a PostgreSQL database.
/// A uri has the following format:
/// 'postgres://testdb:password@localhost:5432/testdb'.
Future<Connection> connect(String uri, {TypeConverter typeConverter})
  => _Connection._connect(uri, typeConverter);

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
  Future runInTransaction(Future operation(), [Isolation isolation = READ_COMMITTED]);


  /// Close the current [Connection]. It is safe to call this multiple times.
  /// This will never throw an exception.
  void close();

  /// The server can send notices or the network can cause errors while the
  /// connection is not being used to make a query. See [ClientMessage] and
  /// [ServerMessage] for more information.
  Stream<Message> get messages;

  //FIXME Use Transaction status const class.
  int get transactionStatus;

  Future get onClosed;

  /// Each connection is assigned a unique id (Within an isolate).
  int get connectionId;
}

/// Row allows field values to be retrieved as if they were getters.
///
///     c.query("select 'blah' as my_field")
///        .single
///        .then((row) => print(row.my_field));
///
@proxy
abstract class Row {
  operator[] (int i);
  void forEach(void f(String columnName, columnValue));
  //TODO toList()
  //TODO toMap()
}

/// FIXME use const ctor class instead.
/// Consider changing case.
const int TRANSACTION_UNKNOWN = 1;
const int TRANSACTION_NONE = 2;
const int TRANSACTION_BEGUN = 3;
const int TRANSACTION_ERROR = 4;

class Isolation {
  final String name;
  const Isolation(this.name);
  String toString() => name;
}

const Isolation READ_COMMITTED = const Isolation('Read committed');
const Isolation REPEATABLE_READ = const Isolation('Repeatable read');
const Isolation SERIALIZABLE = const Isolation('Serializable');

abstract class Message {
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
  int get connectionId;
}

abstract class ClientMessage extends Message {

  factory ClientMessage({String severity,
                 String message,
                 Object exception,
                 StackTrace stackTrace,
                 int connectionId}) = _ClientMessage;

  /// If an exception was thrown the body will be here.
  Object get exception;

  /// Stack trace may be null if the message does not represent an exception.
  StackTrace get stackTrace;

}

abstract class ServerMessage extends Message {

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

String encodeString(String s) => _encodeString(s);


//FIXME hide by using separate package for implementation.
/// Made public for testing.
String substitute(String source, values) => _substitute(source, values);
String formatValue(value, String type) => _formatValue(value, type);
