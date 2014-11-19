part of postgresql;


class _ClientMessage implements ClientMessage {

  _ClientMessage({severity,
                  this.message,
                  this.exception,
                  this.stackTrace,
                  this.connectionName})
      : isError = severity == 'ERROR',
        severity = severity {

    if (severity != 'ERROR' && severity != 'WARNING' && severity != 'DEBUG')
      throw new ArgumentError();

    if (message == null) throw new ArgumentError();
  }

  final bool isError;
  final String severity;
  final String message;
  final String connectionName;
  final Object exception; // May not be an exception type.
  final StackTrace stackTrace;

  String toString() {
    var msg = connectionName == null
        ? '$severity $message'
        : '$connectionName $severity $message';
    if (exception != null)
      msg = '$msg\n$exception';
    if (stackTrace != null)
      msg = '$msg\n$stackTrace';
    return msg;
  }
}

class _ServerMessage implements ServerMessage {

  _ServerMessage(this.isError, Map<String,String> map, [this.connectionName])
      : code = map['C'] == null ? '' : map['C'],    //FIXME use map.get(key, default), when implemented. See dart issue #2643.
        severity = map['S'] == null ? '' : map['S'],
        message = map['M'] == null ? '' : map['M'],
        detail = map['D'] == null ? '' : map['D'],
        position = map['P'] == null ? null : int.parse(map['P'], onError: (_) => null),
        allInformation = map.keys.fold('', (val, item) {
          var fieldName = _fieldNames[item] == null ? item : _fieldNames[item];
          var fieldValue = map[item];
          return '$val\n$fieldName: $fieldValue';
        });
  
  _ServerMessage._private(this.isError, this.code, this.severity, this.message,
    this.detail, this.position, this.allInformation, this.connectionName);

  final bool isError;
  final String code;
  final String severity;
  final String message;
  final String detail;
  final int position;
  final String allInformation;
  final String connectionName;

  String toString() => connectionName == null
      ? '$severity $code $message'
      : '$connectionName $severity $code $message';
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

Message _copy(Message msg, {String connectionName}) {
  if (msg is _ClientMessage) {
    return new _ClientMessage(
        severity: msg.severity,
        message: msg.message,
        exception: msg.exception,
        stackTrace: msg.stackTrace,
        connectionName: connectionName == null
          ? msg.connectionName : connectionName);
  } else if (msg is _ServerMessage) {
    return new _ServerMessage._private(
        msg.isError,
        msg.code,
        msg.severity,
        msg.message,
        msg.detail,
        msg.position,
        msg.allInformation,
        connectionName == null ? msg.connectionName : connectionName);    
  } else {
    return msg;
  }
}
