part of postgresql;

final _escapeRegExp = new RegExp(r"['\r\n\\]");

String _encodeString(String s) {
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

class _DefaultTypeConverter implements TypeConverter {

   String encode(value, String type) {
     throw new UnimplementedError();
   }

   Object decode(String value, int pgType) {
     throw new UnimplementedError();
   }
}
