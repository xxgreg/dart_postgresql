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
        || type == 'num'
        || type == 'number') {
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

    var timezoneString = (datetime.isUtc ? "" : datetime.timeZoneName);

    return "'${datetime.toIso8601String()}${timezoneString}'";
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
        return int.parse(value);
  
      case _PG_FLOAT4: // real
      case _PG_FLOAT8: // double precision
        return double.parse(value);
  
      case _PG_TIMESTAMP:
      case _PG_TIMESTAMPZ:
      case _PG_DATE:
        return decodeDateTime(value, pgType,
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

  DateTime decodeDateTime(String value, int pgType, {bool isUtcTimeZone, getConnectionName()}) {

    if (value == 'infinity' || value == '-infinity') {
      throw _error('Server returned a timestamp with value '
          '"$value", this cannot be represented as a dart date object, if '
          'infinity values are required, rewrite the sql query to cast the '
          'value to a string, i.e. col::text.', getConnectionName);
    }

    var formattedValue = value;
    if(pgType == _PG_TIMESTAMP) {
      formattedValue = formattedValue + "Z";
    } else if(pgType == _PG_TIMESTAMPZ) {

    } else if(pgType == _PG_DATE) {
      formattedValue = formattedValue + "T00:00:00Z";
    }

    return DateTime.parse(formattedValue);
  }
  
}