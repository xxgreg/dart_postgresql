part of postgresql.impl;


class ClientMessageImpl implements ClientMessage {

  ClientMessageImpl(
      {this.isError: false,
       this.severity,
       this.message,
       this.connectionName,
       this.exception,
       this.stackTrace}) {

    if (isError == null) throw new ArgumentError.notNull('isError');
    
    if (severity != 'ERROR' && severity != 'WARNING' && severity != 'DEBUG')
      throw new ArgumentError.notNull('severity');

    if (message == null) throw new ArgumentError.notNull('message');
  }

  final bool isError;
  final String severity;
  final String message;
  final String connectionName;
  final exception;
  final StackTrace stackTrace;
  
  String toString() => connectionName == null
        ? '$severity $message'
        : '$connectionName $severity $message';
}

class ServerMessageImpl implements ServerMessage {

  ServerMessageImpl(this.isError, Map<String,String> fields, [this.connectionName])
      : fields = new UnmodifiableMapView<String,String>(fields),
        severity = fields['S'],
        code = fields['C'],
        message = fields['m'];

  final bool isError;
  final String connectionName;
  final Map<String,String> fields;
  
  final String severity;
  final String code;
  final String message;

  String get detail => fields['D'];
  String get hint => fields['H'];
  String get position => fields['P'];
  String get internalPosition => fields['p'];
  String get internalQuery => fields['q'];
  String get where => fields['W'];
  String get schema => fields['s'];
  String get table => fields['t'];
  String get column => fields['c'];
  String get dataType => fields['d'];
  String get constraint => fields['n'];
  String get file => fields['F'];
  String get line => fields['L'];
  String get routine => fields['R'];
  
  String toString() => connectionName == null
      ? '$severity $code $message'
      : '$connectionName $severity $code $message';
}
