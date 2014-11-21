part of postgresql.impl;

const int _apos = 39;
const int _return = 13;
const int _newline = 10;
const int _backslash = 92;

final _escapeRegExp = new RegExp(r"['\r\n\\]");

class DefaultTypeConverter implements TypeConverter {
   String encode(value, String type) => encodeValue(value, type);
   Object decode(String value, int pgType) => decodeValue(value, pgType);
}

class RawTypeConverter implements TypeConverter {
   String encode(value, String type) => encodeValue(value, type);
   Object decode(String value, int pgType) => value;
}

String encodeString(String s) {
  if (s == null) return ' null ';

  var escaped = s.replaceAllMapped(_escapeRegExp, (m) {
   switch (s.codeUnitAt(m.start)) {
     case _apos: return r"\'";
     case _return: return r'\r';
     case _newline: return r'\n';
     case _backslash: return r'\\';
     default: assert(false);
   }
 });

  return " E'$escaped' ";
}


String encodeValue(value, String type) {

  if (type == null)
    return encodeValueDefault(value);

  //TODO exception type. PgException
  throwError() => throw new Exception('Invalid runtime type and type modifier combination '
      '(${value.runtimeType} to $type).');

  if (value == null)
    return 'null';

  if (type != null)
    type = type.toLowerCase();

  if (type == 'text' || type == 'string')
    return encodeString(value.toString());

  if (type == 'integer'
      || type == 'smallint'
      || type == 'bigint'
      || type == 'serial'
      || type == 'bigserial'
      || type == 'int') {
    if (value is! int) throwError();
    return encodeNumber(value);
  }

  if (type == 'real'
      || type == 'double'
      || type == 'num') {
    if (value is! num) throwError();
    return encodeNumber(value);
  }

  // TODO numeric, decimal

  if (type == 'boolean' || type == 'bool') {
    if (value is! bool) throwError();
    return value.toString();
  }

  if (type == 'timestamp' || type == 'timestamptz' || type == 'datetime') {
    if (value is! DateTime) throwError();
    return encodeDateTime(value, isDateOnly: false);
  }

  if (type == 'date') {
    if (value is! DateTime) throwError();
    return encodeDateTime(value, isDateOnly: true);
  }

  if (type == 'json' || type == 'jsonb')
    return encodeValueToJson(value);

//  if (type == 'bytea') {
//    if (value is! List<int>) throwError();
//    return encodeBytea(value);
//  }
//
//  if (type == 'array') {
//    if (value is! List) throwError();
//    return encodeArray(value);
//  }

  throw new Exception('Unknown type name: $type.');
}

// Unspecified type name. Use default type mapping.
String encodeValueDefault(value) {

  if (value == null)
    return 'null';

  if (value is num)
    return encodeNumber(value);

  if (value is String)
    return encodeString(value);

  if (value is DateTime)
    return encodeDateTime(value, isDateOnly: false);

  if (value is bool)
    return value.toString();

  if (value is Map)
    return encodeString(JSON.encode(value));

  if (value is List)
    return encodeArray(value);

  throw new Exception('Unsupported runtime type as query parameter (${value.runtimeType}).');
}

//FIXME can probably simplify this, as in postgresql json type must take
// map or array at top level, not string or number. (I think???)
String encodeValueToJson(value) {
  if (value == null)
    return "'null'";

  if (value is Map || value is List)
    return encodeString(JSON.encode(value));

  if (value is String)
    return encodeString('"$value"');

  if (value is num) {
    // These are not valid JSON numbers, so encode them as strings.
    //TODO test this
    if (value.isNaN) return '"nan"';
    if (value == double.INFINITY) return '"infinity"';
    if (value == double.NEGATIVE_INFINITY) return '"-infinity"';
    return value.toString();
  }

  try {
    var map = value.toJson();
    return encodeString(JSON.encode(value));
  } catch (e) {
    // Error actually swallowed
    throw new FormatException('Could not convert object to JSON. '
        'No toJson() method was implemented on the object.');
  }
}

String encodeNumber(num n) {
  if (n.isNaN) return "'nan'";
  if (n == double.INFINITY) return "'infinity'";
  if (n == double.NEGATIVE_INFINITY) return "'-infinity'";
  return "${n.toString()}";
}

String encodeArray(List value) {
  //TODO
  throw new UnimplementedError('Postgresql array types not implemented yet.');
}

String encodeDateTime(DateTime datetime, {bool isDateOnly}) {

  if (datetime == null)
    return 'null';

  // 2004-10-19 10:23:54.445 BC PST
  var year = datetime.year.abs().toString().padLeft(4, '0');
  var month = datetime.month.toString().padLeft(2,'0');
  var day = datetime.day.toString().padLeft(2,'0');

  var hour = datetime.hour.toString().padLeft(2,'0');
  var minute = datetime.minute.toString().padLeft(2,'0');
  var second = datetime.second.toString().padLeft(2,'0');
  var millisecond = datetime.millisecond.toString().padLeft(3,'0');

  var bc = datetime.year < 0 ? ' BC' : '';

  var tz = datetime.timeZoneName;

  if (isDateOnly)
    return "'$year-$month-$day$bc'";
  else
    return "'$year-$month-$day $hour:$minute:$second.$millisecond$bc $tz'";

  // TODO Consider providing an option to pass the timezone offset instead of
  // timezone name. This means that we are relying on the Dart application's
  // host computer's timezone data. If we pass the timezone name, then the
  // Postgresql database's host's timezone data is used to make the conversion.
  //  String tz;
  //  if (datetime.isUtc) {
  //    tz = 'UTC';
  //  } else {
  //    // Construct localtime offset '+12:00:00';
  //    var offset = datetime.timeZoneOffset;
  //    var sign = offset.isNegative ? '-' : '+';
  //    var totalSeconds = offset.inSeconds;
  //    var hours = (totalSeconds ~/ 3600).toString().padLeft(2,'0');
  //    var minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2,'0');
  //    var seconds = (totalSeconds % 60).toString().padLeft(2,'0');
  //    // Note milliseconds are truncated. Could round them when calculating seconds.
  //    tz = '$sign$hours:$minutes:$seconds';
  //  }

}

// See http://www.postgresql.org/docs/9.0/static/sql-syntax-lexical.html#SQL-SYNTAX-STRINGS-ESCAPE
String encodeBytea(List<int> value) {

  //var b64String = ...;
  //return " decode('$b64String', 'base64') ";

  //TODO
  throw new UnimplementedError('bytea encoding not implemented.');
}

Object decodeValue(String value, int pgType) {

  switch (pgType) {

    case _PG_BOOL:
      return value == 't';

    case _PG_INT2: // smallint
    case _PG_INT4: // integer
    case _PG_INT8: // bigint
    //TODO serial
    //TODO bigserial
      return int.parse(value);

    case _PG_FLOAT4: // real
    case _PG_FLOAT8: // double precision
      //TODO Test that dart will parse postgresql's number format.
      // Consider infinity, -infinity, NaN, 0, -0, exponential notation.
      return double.parse(value);

    case _PG_TIMESTAMP:
    case _PG_TIMESTAMPZ:
    case _PG_DATE:
      return decodeDateTime(value, isDateOnly: pgType == _PG_DATE);

    case _PG_JSON:
    case _PG_JSONB:
      //TODO make the JSON reviver plugable.
      return JSON.decode(value);

    // Not implemented yet - return a string.
    case _PG_MONEY:
    case _PG_TIMETZ:
    case _PG_TIME:
    case _PG_INTERVAL: //TODO return a dart core.Duration type.
    case _PG_NUMERIC:

    //TODO arrays
    //TODO binary bytea

    default:
      // Return a string for unknown types. The end user can parse this.
      return value;
  }
}



final _timestampRegexp = new RegExp(r'(\d{4,10})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)( BC)?');

final _dateRegexp = new RegExp(r'^(\d{4,10})-(\d\d)-(\d\d)( BC)?$');

DateTime decodeDateTime(String value, {bool isDateOnly}) {

  //TODO Figure out how to represent postgresql's quirky 'infinity' and
  // '-infinity' date values. Could use sentinals, null, or throw an exception.
  //return DateTime.parse(value);

  // Notes

  // When Postgresql stores a timestamptz field it converts the timestamp to utc
  // time using the servers current timezone setting. When the server returns a
  // timestamptz it converts it from utc into the local timezone set in the
  // server configuration. (Timezone information is not stored in a timestamptz
  // field)

  // Dart [DateTime] objects are in the host's local timezone by default. (They
  // can also be constructed in the utc timezone).

  // There is currently not a Dart library to create [DateTime]s in an arbitrary
  // non-local timezone. (As of 2014/11. But keep an eye on the intl package.)

  // So... for timestamptz fields to work correctly the host on which the client
  // is running must be set to the same local timezone as the postgresql server.

  //TODO write code to check the server timezone on start up. If it differs
  // from the local timezone then issue a warning.

  // TODO Some people run their servers set to the UTC timezone. It is possible
  // to detect this at start up and then return UTC [DateTime]s here.

  var m = isDateOnly
       ? _dateRegexp.firstMatch(value)
       : _timestampRegexp.firstMatch(value);

  if (m == null)
    throw new FormatException(
      'Unexpected ${isDateOnly ? 'date' : 'timestamp'} '
      'format returned from server: "$value".');

  int year = int.parse(m[1]);
  int month = int.parse(m[2]);
  int day = int.parse(m[3]);

  int hour = 0, minute = 0, second = 0;

  if (!isDateOnly) {
    hour = int.parse(m[4]);
    minute = int.parse(m[5]);
    second = int.parse(m[6]);
  }

  if ((isDateOnly && m[4] != null)
      || (!isDateOnly && m[7] != null))
    year = -year;

  return new DateTime(year, month, day, hour, minute, second);
}

