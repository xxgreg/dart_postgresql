library postgresql;

import 'dart:async';
import 'dart:collection';
import 'dart:crypto';
import 'dart:io';
import 'dart:utf' show encodeUtf8, decodeUtf8;

part 'buffer.dart';
part 'connection.dart';
part 'constants.dart';
part 'exceptions.dart';
part 'message_buffer.dart';
part 'query.dart';

/// Connect to a PostgreSQL database.
///
Future<Connection> connect(String uri) => _Connection._connect(uri);

/// A connection to a PostgreSQL database.
abstract class Connection {
  
  /// Queue a sql query to be run, returning a [Stream] of rows. 
  ///
  /// The data can be fetched from the rows by column name, or by index.
  ///
  /// Generally it is best to call [toList] on the stream and wait for all of
  /// the rows to be received.
  ///
  /// Example:
  ///
  ///     conn.query("select 'pear', 'apple' as a").toList().then((rows) {
  ///        print(row[0]);
  ///        print(row.a);
  ///     });
  ///
  Stream<dynamic> query(String sql);
  
  
  /// Queues a command for execution, and when done, returns the number of rows
  /// affected by the sql command.
  Future<int> execute(String sql);
  
  
  /// Close the current [Connection]. It is safe to call this multiple times.
  /// This will never throw an exception.
  void close();
  
  //FIXME test this properly - I'm not sure if it works.
  /// Listen for a [PgServerException], [PgServerInformation], or 
  /// [PgClientException], that occur while the connection is idle, or are not
  /// related to a specific query.
  Stream get unhandled;
}

/// A marker interface implemented by all postgresql library exceptions.
abstract class PgException implements Exception {
}

/// A exception caused by a problem within the postgresql library. 
abstract class PgClientException implements PgException, Exception {
}

/// A exception representing an error reported by the postgresql server. 
abstract class PgServerException implements 
  PgException, PgServerInformation, Exception {
}

/// Information returned from the server about an error or a notice.
abstract class PgServerInformation {
  
  /// Returns true if this is a server error, otherwise it is a notice.
  bool get isError;
  
  /// A PostgreSQL error code.
  /// See http://www.postgresql.org/docs/9.2/static/errcodes-appendix.html
  String get code;
  
  /// For a english localized database the field contents are ERROR, FATAL, or
  /// PANIC, for an error message. Otherwise in a notice message they are 
  /// WARNING, NOTICE, DEBUG, INFO, or LOG.
  String get severity;
  
  /// A human readible error message, typically one line.
  String get message;
  
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
