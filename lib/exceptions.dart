part of postgresql;

class _PgClientException implements PgClientException, PgException, Exception {
  final String _msg;
  _PgClientException(this._msg);
  String toString() => _msg;
}

class _PgServerException implements PgServerException, PgException, Exception {
  final PgServerInformation _info;
  _PgServerException(this._info);
  
  bool get isError => _info.isError;
  String get code => _info.code;
  String get severity => _info.severity;
  String get message => _info.message;
  String get detail => _info.detail;
  int get position => _info.position;
  String get allInformation => _info.allInformation;
  
  String toString() => 'PostgreSQL $severity $code $message';
}

class _PgServerInformation implements PgServerInformation {
  
  _PgServerInformation(this.isError, Map<String,String> map)
      : code = map['C'] == null ? '' : map['C'],    //FIXME use map.get(key, default), when implemented. See dart issue #2643.
        severity = map['S'] == null ? '' : map['S'],
        message = map['M'] == null ? '' : map['M'],
        detail = map['D'] == null ? '' : map['D'],
        position = map['P'] == null ? null : int.parse(map['P'], onError: (_) => null),
        allInformation = map.keys.reduce('', (val, item) {
          var fieldName = _fieldNames[item] == null ? item : _fieldNames[item]; 
          var fieldValue = map[item];
          return '$val\n$fieldName: $fieldValue';
        });
  
  final bool isError;
  final String code;
  final String severity;
  final String message;
  final String detail;
  final int position;
  final String allInformation;
}

final Map<String,String> _fieldNames = {
  'S': 'Severity',
  'C': 'Code',
  'M': 'Message',
  'D': 'Detail',
  'H': 'Hint',
  'P': 'Position',
  'p': 'Internal position',
  'q': 'Internal query',
  'W': 'Where',
  'F': 'File',
  'L': 'Line',
  'R': 'Routine'
};
