part of postgresql;

const int _apos = 39;
const int _return = 13;
const int _newline = 10;
const int _backslash = 92;

//TODO handle int modifiers
dynamic _formatValue(value, String type) {

  err(rt, t) => new Exception('Invalid runtime type and type modifier combination ($rt to $t).');

  if (value == null)
    return 'null';

  if (value is bool)
    return value.toString();

  if (type != null)
    type = type.toLowerCase();

  if (value is num) {
    if (type == null || type == 'number')
      return value.toString(); //TODO test that corner cases of dart.toString() match postgresql number types.
    else if (type == 'string')
      return "'$value'";
    else
      throw err('num', type);
  }

  if (value is String) {
    if (type == null || type == 'string')
      return _formatString(value);
    else
      throw err('String', type);
  }

  if (value is DateTime) {
    //TODO check types.
    return _formatDateTime(value, type);
  }

  //if (value is List<int>)
  // return _formatBinary(value, type);

  throw new Exception('Unsupported runtime type as query parameter.');
}

final _escapeRegExp = new RegExp(r"['\r\n\\]");

//TODO test if this works without escaping unicode characters.
// Uses an string constant E''.
// See http://www.postgresql.org/docs/9.0/static/sql-syntax-lexical.html#SQL-SYNTAX-STRINGS-ESCAPE
_formatString(String s) {
  if (s == null)
    return ' null ';

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

_formatDateTime(DateTime datetime, String type) {

  if (datetime == null)
    return 'null';

  String escaped;
  var t = (type == null) ? 'timestamp' : type.toLowerCase();

  if (t != 'date' && t != 'timestamp' && t != 'timestamptz') {
    throw new Exception('Unexpected type: $type.'); //TODO exception type
  }

  pad(i) {
    var s = i.toString();
    return s.length == 1 ? '0$s' : s;
  }

  //2004-10-19 10:23:54.4455+02
  var sb = new StringBuffer()
    ..write(datetime.year)
    ..write('-')
    ..write(pad(datetime.month))
    ..write('-')
    ..write(pad(datetime.day));

  if (t == 'timestamp' || t == 'timestamptz') {
    sb..write(' ')
      ..write(pad(datetime.hour))
      ..write(':')
      ..write(pad(datetime.minute))
      ..write(':')
      ..write(pad(datetime.second));

    final int ms = datetime.millisecond;
    if (ms != 0) {
      sb.write('.');
      final s = ms.toString();
      if (s.length == 1) sb.write('00');
      else if (s.length == 2) sb.write('0');
      sb.write(s);
    }
  }

  if (t == 'timestamptz') {
    // Add timezone offset.
    throw new Exception('Not implemented'); //TODO
  }

  return "'${sb.toString()}'";
}

//TODO
// See http://www.postgresql.org/docs/9.0/static/sql-syntax-lexical.html#SQL-SYNTAX-STRINGS-ESCAPE
_formatBinary(List<int> buffer) {
  //var b64String = ...;
  //return " decode('$b64String', 'base64') ";
}
