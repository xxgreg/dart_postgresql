### Version 0.3.4
 
 * Update broken crypto dependency.

#### Version 0.3.3

 * Fix #73 Properly encode/decode connection uris. Thanks to Martin Manev.
 * Permit connection without a password. Thanks to Jirka Daněk.

#### Version 0.3.2

 * Improve handing of datetimes. Thanks to Joe Conway.
 * Remove manually cps transformed async code.
 * Fix #58: Establish connections concurrently. Thanks to Tom Yeh.
 * Fix #67: URI encode db name so spaces can be used in db name. Thanks to Chad Schwendiman.
 * Fix #69: Empty connection pool not establishing connections.

#### Version 0.3.1+1

 * Expose column information via row.getColumns(). Credit to Jesper Håkansson for this change.

#### Version 0.3.0

  * A new connection pool with more configuration options.
  * Support for json and timestamptz types.
  * Utc time zone support.
  * User customisable type conversions.
  * Improved error handling.
  * Connection.onClosed has been removed.
  * Some api has been renamed, the original names are still functional but marked as deprecated.
      * import 'package:postgresql/postgresql_pool.dart'  =>  import 'package:postgresql/pool.dart'
      * Pool.destroy() => Pool.stop()
      * The constants were upper case and int type. Now typed and lower camel case to match the style guide.
      * Connection.unhandled => Connection.messages
      * Connection.transactionStatus => Connection.transactionState

  Thanks to Tom Yeh and Petar Sabev for their helpful feedback.
