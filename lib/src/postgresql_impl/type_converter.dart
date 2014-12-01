part of postgresql.impl;

const int _apos = 39;
const int _return = 13;
const int _newline = 10;
const int _backslash = 92;

final _escapeRegExp = new RegExp(r"['\r\n\\]");

class RawTypeConverter extends DefaultTypeConverter {
   String encode(value, String type, {getConnectionName()})
    => encodeValue(value, type);
   
   Object decode(String value, int pgType, {bool isUtcTimeZone: false,
     getConnectionName()}) => value;
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


class DefaultTypeConverter implements TypeConverter {
    
  String encode(value, String type, {getConnectionName()}) 
    => encodeValue(value, type, getConnectionName: getConnectionName);
   
  Object decode(String value, int pgType, {bool isUtcTimeZone: false,
    getConnectionName()}) => decodeValue(value, pgType, 
        isUtcTimeZone: isUtcTimeZone, getConnectionName: getConnectionName);

  PostgresqlException _error(String msg, getConnectionName()) {
    var name = getConnectionName == null ? null : getConnectionName();
    return new PostgresqlException(msg, name);
  }
  
  String encodeValue(value, String type, {getConnectionName()}) {
  
    if (type == null)
      return encodeValueDefault(value, getConnectionName: getConnectionName);
  
    throwError() => throw _error('Invalid runtime type and type modifier '
        'combination (${value.runtimeType} to $type).', getConnectionName);
  
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
  
    throw _error('Unknown type name: $type.', getConnectionName);
  }
  
  // Unspecified type name. Use default type mapping.
  String encodeValueDefault(value, {getConnectionName()}) {
  
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
  
    throw _error('Unsupported runtime type as query parameter '
        '(${value.runtimeType}).', getConnectionName);
  }
  
  //FIXME can probably simplify this, as in postgresql json type must take
  // map or array at top level, not string or number. (I think???)
  String encodeValueToJson(value, {getConnectionName()}) {
    if (value == null)
      return "'null'";
  
    if (value is Map || value is List)
      return encodeString(JSON.encode(value));
  
    if (value is String)
      return encodeString('"$value"');
  
    if (value is num) {
      // These are not valid JSON numbers, so encode them as strings.
      // TODO consider throwing an error instead.
      if (value.isNaN) return '"nan"';
      if (value == double.INFINITY) return '"infinity"';
      if (value == double.NEGATIVE_INFINITY) return '"-infinity"';
      return value.toString();
    }
  
    try {
      var map = value.toJson();
      return encodeString(JSON.encode(value));
    } catch (e) {
      throw _error('Could not convert object to JSON. '
          'No toJson() method was implemented on the object.', getConnectionName);
    }
  }
  
  String encodeNumber(num n) {
    if (n.isNaN) return "'nan'";
    if (n == double.INFINITY) return "'infinity'";
    if (n == double.NEGATIVE_INFINITY) return "'-infinity'";
    return "${n.toString()}";
  }
  
  String encodeArray(List value) {
    //TODO implement postgresql array types
    throw _error('Postgresql array types not implemented yet. '
        'Pull requests welcome ;)', null);
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
  
    String tz;
    if (datetime.isUtc) {
      tz = 'UTC';
    } else {
      // Construct localtime offset '+12:00:00';
      var offset = datetime.timeZoneOffset;
      var sign = offset.isNegative ? '-' : '+';
      var totalSeconds = offset.inSeconds;
      var hours = (totalSeconds ~/ 3600).toString().padLeft(2,'0');
      var minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2,'0');
      var seconds = (totalSeconds % 60).toString().padLeft(2,'0');
      tz = '$sign$hours:$minutes:$seconds';
    }
  
    if (isDateOnly)
      return "'$year-$month-$day$bc'";
    else
      return "'$year-$month-$day $hour:$minute:$second.$millisecond$bc $tz'";
  }
  
  // See http://www.postgresql.org/docs/9.0/static/sql-syntax-lexical.html#SQL-SYNTAX-STRINGS-ESCAPE
  String encodeBytea(List<int> value) {
  
    //var b64String = ...;
    //return " decode('$b64String', 'base64') ";
  
    throw _error('bytea encoding not implemented. Pull requests welcome ;)', null);
  }
  
  Object decodeValue(String value, int pgType,
                     {bool isUtcTimeZone, getConnectionName()}) {
  
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
        return decodeDateTime(value, isDateOnly: pgType == _PG_DATE,
                  isUtcTimeZone: isUtcTimeZone, getConnectionName: getConnectionName);
  
      case _PG_JSON:
      case _PG_JSONB:
        return JSON.decode(value);
  
      // Not implemented yet - return a string.
      case _PG_MONEY:
      case _PG_TIMETZ:
      case _PG_TIME:
      case _PG_INTERVAL:
      case _PG_NUMERIC:
  
      //TODO arrays
      //TODO binary bytea
  
      default:
        // Return a string for unknown types. The end user can parse this.
        return value;
    }
  }
  
  
  
  final _timestampRegexp = new RegExp(
      r'(\d{4,10})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)( BC)?');
  
  final _dateRegexp = new RegExp(r'^(\d{4,10})-(\d\d)-(\d\d)( BC)?$');
  
  DateTime decodeDateTime(String value, {bool isDateOnly, bool isUtcTimeZone, getConnectionName()}) {
      
    if (value == 'infinity' || value == '-infinity') {
      throw _error('Server returned a timestamp with value '
          '"$value", this cannot be represented as a dart date object, if '
          'infinity values are required, rewrite the sql query to cast the '
          'value to a string, i.e. col::text.', getConnectionName);
    }
  
    var m = isDateOnly
         ? _dateRegexp.firstMatch(value)
         : _timestampRegexp.firstMatch(value);
  
    if (m == null)
      throw _error('Unexpected ${isDateOnly ? 'date' : 'timestamp'} format '
                   'returned from server: "$value".', getConnectionName);
  
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
  
    // Built in Dart dates can either be local time or utc. Which means that the
    // the postgresql timezone parameter for the connection must be either set
    // to UTC, or the local time of the server on which the client is running.
    // This restriction could be relaxed by using a more advanced date library
    // capable of creating DateTimes for a non-local time zone.
    return isUtcTimeZone
       ? new DateTime.utc(year, month, day, hour, minute, second)
       : new DateTime(year, month, day, hour, minute, second);
  }
  
}