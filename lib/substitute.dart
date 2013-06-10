part of postgresql;

const int _TOKEN_TEXT = 1;
const int _TOKEN_AT = 2;
const int _TOKEN_IDENT = 3;

const int _a = 97;
const int _A = 65;
const int _z = 122;
const int _Z = 90;
const int _0 = 48;
const int _9 = 57;
const int _at = 64;
const int _colon = 58;
const int _underscore = 95;

class _Token {
  _Token(this.type, this.value, [this.typeName]);
  final int type;
  final String value;
  final String typeName;
  String toString() => '${['?', 'Text', 'At', 'Ident'][type]} "$value" "$typeName"';
}

bool isIdentifier(int charCode) => (charCode >= _a && charCode <= _z)
                                    || (charCode >= _A && charCode <= _Z)
                                  || (charCode >= _0 && charCode <= _9)
                                  || (charCode == _underscore);

bool isDigit(int charCode) => (charCode >= _0 && charCode <= _9);

class ParseException {
  ParseException(this.message, [this.source, this.index]);
  final String message;
  final String source;
  final int index;
  String toString() => (source == null || index == null) 
      ? message
      : '$message At character: $index, in source "$source"';
}

String _substitute(String source, values) {
  
  var valueWriter;
  
  if (values is List)
    valueWriter = _createListValueWriter(values);

  else if (values is Map)
    valueWriter = _createMapValueWriter(values);

  else if (values == null)
    valueWriter = (_, _1, _2)
        => throw new ParseException('Template contains a parameter, but no values were passed.');
  
  else
    throw new ArgumentError('Unexpected type.');
  
  var buf = new StringBuffer();
  var s = new _Scanner(source);
  
  while (s.hasMore()) {
    var t = s.read();
    if (t.type == _TOKEN_IDENT) {
      valueWriter(buf, t.value, t.typeName);
    } else {
      buf.write(t.value);
    }
  } 
 
  return buf.toString();  
}

_createListValueWriter(List list) => (StringSink buf, String identifier, String type) {

  int i = int.parse(identifier, onError: 
    (_) => throw new ParseException('Expected integer parameter.'));

  if (i < 0 || i >= list.length)
    throw new ParseException('Substitution token out of range.');
  
  var s = _formatValue(list[i], type);
  buf.write(s);
};

_createMapValueWriter(Map map) => (StringSink buf, String identifier, String type) {
  
  var val;

  if (isDigit(identifier.codeUnits.first)) {
    int i = int.parse(identifier, onError: 
      (_) => throw new ParseException('Expected integer parameter.'));

    if (i < 0 || i >= map.values.length)
      throw new ParseException("Substitution token out of range.");

    val = map.values.elementAt(i);
  
  } else {

    if (!map.keys.contains(identifier))
      throw new ParseException("Substitution token not passed: $identifier.");

    val = map[identifier];
  }

  var s = _formatValue(val, type);
  buf.write(s);
};

class _Scanner {
  _Scanner(String source)
      : _source = source,
        _r = new _CharReader(source) {
        
    if (_r.hasMore())
      _t = _read();
  }
  
  final String _source;
  final _CharReader _r;
  _Token _t;
  
  bool hasMore() => _t != null;
  
  _Token peek() => _t;
  
  _Token read() {
    var t = _t;
    _t = _r.hasMore() ? _read() : null;
    return t;
  }
  
  _Token _read() {
    
    assert(_r.hasMore());
    
    // '@@', '@ident', or '@ident:type'
    if (_r.peek() == _at) {
      _r.read();
      
      if (!_r.hasMore())
        throw new ParseException('Unexpected end of input.');
      
      // Escaped '@' character.
      if (_r.peek() == _at) {
        _r.read();
        return new _Token(_TOKEN_AT, '@');
      }
      
      if (!isIdentifier(_r.peek()))
        throw new ParseException('Expected alphanumeric identifier character after "@".');

      // Identifier
      var ident = _r.readWhile(isIdentifier);      
      
      // Optional type modifier
      var type;
      if (_r.peek() == _colon) {
        _r.read();
        type = _r.readWhile(isIdentifier);        
      }
      return new _Token(_TOKEN_IDENT, ident, type);
    }
    
    // Read plain text
    var text = _r.readWhile((c) => c != _at);
    return new _Token(_TOKEN_TEXT, text);
  }
}

class _CharReader {
  _CharReader(String source)
      : _source = source,
        _itr = source.codeUnits.iterator {
        
    if (source == null)
      throw new ArgumentError('Source is null.');
    
    _i = 0;
    
    if (source != '') {
      _itr.moveNext();
      _c = _itr.current;
    }
  }
  
  String _source;
  Iterator<int> _itr;
  int _i, _c;
  
  bool hasMore() => _i < _source.length;
  
  int read() {
    var c = _c;
    _itr.moveNext();
    _i++;
    _c = _itr.current;
    return c;
  }
  
  int peek() => _c;
  
  String readWhile([bool test(int charCode)]) {
    
    if (!hasMore())
      throw new ParseException('Unexpected end of input.', _source, _i);
    
    int start = _i;
    
    while (hasMore() && test(peek())) {
      read();
    }
    
    int end = hasMore() ? _i : _source.length;    
    return _source.substring(start, end);
  }
}
