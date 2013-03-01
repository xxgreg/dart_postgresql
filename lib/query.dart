part of postgresql;

class _Query {
  int __state = _QUEUED;
  
  int get _state => __state;
  set _state(int s) {
    var was = __state;
    __state = s;
    //print('Query state change: ${_queryStateToString(was)} => ${_queryStateToString(s)}.');
  }
  
  final String sql;
  final StreamController<_Row> _controller = new StreamController<_Row>();
  int _commandIndex = 0;
  int _rowIndex = -1;
  int _columnCount;
  List<_Column> _columns;
  List<dynamic> _rowData;
  ExecuteResult _executeResult;
  
  _Query(this.sql);
  
  Stream<dynamic> get stream => _controller.stream;
  
  void streamRow() {
    if (_state == _QUEUED)
      _state = _STREAMING;
    
    var names = _columns.map((c) => c.name).toList();
    var row = new _Row(names, _rowData);
    _rowData = null;
    _controller.add(row);    
  }
  
  void streamError(Exception err) {
    _controller.signalError(err);
    // stream will be closed once the ready for query message is received.
  }
  
  void close() {
    _controller.close();
    _state = _DONE;
  }
}

class _Column {
  final int index;
  final String name;
    
  //TODO figure out what to name these.
  // Perhaps just use libpq names as they will be documented in existing code 
  // examples. It may not be neccesary to store all of this info.
  final int fieldId;
  final int tableColNo;
  final int fieldType;
  final int dataSize;
  final int typeModifier;
  final int formatCode;
  
  bool get isBinary => formatCode == 1;
  
  _Column(this.index, this.name, this.fieldId, this.tableColNo, this.fieldType, this.dataSize, this.typeModifier, this.formatCode);
  
  String toString() => 'Column: index: $index, name: $name, fieldId: $fieldId, tableColNo: $tableColNo, fieldType: $fieldType, dataSize: $dataSize, typeModifier: $typeModifier, formatCode: $formatCode.';
}

class _Row {
  _Row(this._columnNames, this._values) {
    assert(this._columnNames.length == this._values.length);
  }
  
  final List<String> _columnNames;
  final List<dynamic> _values;
  
  operator[] (int i) => _values[i];
  
  noSuchMethod(InvocationMirror invocationMirror) {
    var name = invocationMirror.memberName;
    if (invocationMirror.isGetter) {
      var i = _columnNames.indexOf(name);
      if (i != -1)
        return _values[i];
      else
        //FIXME throw NoSuchMethodError
        throw new Exception('Unknown column name: $name.');
    } else {
      //FIXME throw NoSuchMethodError
      throw new Exception();
    }
  }
  
  String toString() => _values.toString();
  List<dynamic> toList() => _values;
}

class _ExecuteResult implements ExecuteResult {
  _ExecuteResult(this.lastInsertId, this.rowsAffected);
  final int lastInsertId;
  final int rowsAffected;
  String toString() => 'lastInsertId: $lastInsertId, rowsAffected: $rowsAffected';
}


