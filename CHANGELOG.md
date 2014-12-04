#### Version 0.3.0

  * A new connection pool with more configuration options.
  * Support for json and timestamptz types.
  * Utc time zone support.
  * User customisable type conversions.
  * Improved error handling.
  * Connection.onClosed has been removed.
  * Some api has been renamed, the original names are still functional but marked as deprecated.
      * Pool.destroy() => Pool.stop()
      * The constants were upper case and int type. Now typed and lower camel case to match the style guide.
      * Connection.unhandled => Connection.messages
      * Connection.transactionStatus => Connection.transactionState

  Thanks to Tom Yeh and Petar Sabev for their helpful feedback.
