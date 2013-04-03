# Roadmap

## Write some transaction handling tests.

## Consider exposing the transaction state of the connection.
   - Connection.transactionState = 
        BUSY, Query is in progress, might be in a transaction, might not.
        | In Transaction
        | Not in Transaction (Idle?)
        | Error state. In a failed transaction. Commands will be aborted until next rollback.

## If no unhandled error/notice listener is registered then log to standard
   error.


## Write some reflection mappers

  A way to map to immutable classes.

  query('select a, b from blah', map: constructorMapper(Bob));

  class Bob {
    Bob(this.a, this.b);
    final int a;
    final int b;
  }


  A way to map to mutable classes.

  query('select a, b from blah', map: memberMapper(Jim));

  class Jim {
    int a;
    int b;
  }

  Note: this will be slow, as it uses reflection. But it's convienient.



## Add support for new types

  - Timestamp with timezone => class OffsetDateTime { final Duration offset; final DateTime dateTime; }.    
    First only implement parsing for now, don't implement DateTime interface.
    Later implement DateTime interface - see florians email.

  - Date with timezone => OffsetDateTime()

  - numeric => class Numeric { final int value; final int scale; final int precision; // Is precision needed? }
  - First only implement parsing for now, don't implement num interface.
  - Implment num interface. (Can you implement num interface or is it magic?)

  - bytea => List<int>
  - In text mode this is returned as a base64 encoded string - I think.

  - text Any decoding required. Any odd UTF stuff?

  - xml, json Automatically decode?

  - hstore => Map<String,String>

  - Figure out other types which should be supported:
    i.e. oid, serial, bigserial.


## Write new tests, that use a mock socket, rather than a live database
  - Add a public mockSocketProperty to the Settings object, so this can be tested
    in the public version.
  - Write some code to dump all conversation between database and client. This
    can be implemented as: class RecordingSocket implements Socket. and passed
    into the settings object specified above.
  - The mock socket can then use this data to replay the conversation.


## Write performance tests


## Implement streaming data decoding
   - Check performance against non streaming version for small data.


## Have a look at Dapper, and PicoPoco
   - See if there are any feature ideas.
   - Add support for serialising lists to sql:
    query('select a, b from blah where id in @id', {'id': [1, 2, 3, 4]});


## Implement large object support. Copy command, for streaming data in and out of the database.


## Consider implementing prepared queries.
    - The protocol looks pretty complicated and slow. May not be worth it.
    - Do some benchmarking with libpq, to figure out if this performs much better, and is worth
      adding.

