# Roadmap

## Connection Settings
   - Export connection Settings class.
   - Change connect to take Settings class as parameter.
   - Write Settings ctors:
      - fromPostgresUri()
      - fromPsqlEnv()
      - fromHerokuEnv()

## If no unhandled error/notice listener is registered then log to standard
   error.

## Query value subsitution and escaping
  - Goal: Prevent sql injection attacks.
  - Change query(), and exec() methods to:
     
     Stream query(String sql, dynamic values);
     // Where values should be either a OrderedMap<String,Object> aka LinkedHashMap<String,Object>,
        or a List<Object>.

     query('select a, b from blah where id = @id', {'id': 5});
     query('select a, b from blah where id = @0', [5]);

     Strings will have quotes added, and will have quotes escaped. (TODO Check if any other escaping is required).

  -  Support for standard types:
     Map
     List<int> binary (bytea, blob etc).
     DateTime
     JSON
     XML 

  - Allow types to be specified in query.

    query('select a, b from blah where id = @id:int', {'id': 5});
    query('select a, b from blah where id = @0:int', [5]);


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

  - numeric => class Real { final int value; final int scale; final int precision; // Is precision needed? }
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


## Read about binary transfer mode
  - figure out how important this is to support.


## Write performance tests


## Implement streaming data decoding
   - Check performance against non streaming version for small data.


## Have a look at Dapper, and PicoPoco
   - See if there are any feature ideas.
   - Add support for serialising lists to sql:
    query('select a, b from blah where id in @id', {'id': [1, 2, 3, 4]});

