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
  int _rowsAffected;
  
  List<String> _columnNames;
  Map<Symbol, int> _columnIndex;
  
  _Query(this.sql);
  
  Stream<dynamic> get stream => _controller.stream;
  
  void addRowDescription() {
    if (_state == _QUEUED)
      _state = _STREAMING;
    
    _columnNames = _columns.map((c) => c.name).toList();
    
    var ident = new RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');
    _columnIndex = new Map<Symbol, int>();
    for (var i = 0; i < _columnNames.length; i++) {
      var name = _columnNames[i];
      if (ident.hasMatch(name))
        _columnIndex[new Symbol(name)] = i;
    }
  }
  
  void addRow() {
    var row = new _Row(_columnNames, _rowData, _columnIndex);
    _rowData = null;
    _controller.add(row);    
  }
  
  void addError(Object err) {
    _controller.addError(err);
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

class _Row implements Row {
  _Row(this._columnNames, this._columnValues, this._index) {
    assert(this._columnNames.length == this._columnValues.length);
  }
  
  // Map column name to column index
  final Map<Symbol, int> _index;
  final List<String> _columnNames;
  final List _columnValues;
  
  operator[] (int i) => _columnValues[i];
  
  void forEach(void f(String columnName, columnValue)) {
    assert(_columnValues.length == _columnNames.length);
    for (int i = 0; i < _columnValues.length; i++) {
      f(_columnNames[i], _columnValues[i]);
    }
  }
  
  noSuchMethod(Invocation invocation) {
    var name = invocation.memberName;
    if (invocation.isGetter) {
      var i = _index[name];
      if (i != null)
        return _columnValues[i];
    }
    super.noSuchMethod(invocation);
  }
  
  String toString() => _columnValues.toString();
}


