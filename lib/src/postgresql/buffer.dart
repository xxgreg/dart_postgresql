part of postgresql;

// Plenty of oportunity for optimisation here. This is just a quick and simple,
// but hopefully correct implementation.
class _Buffer {  
  
  int _position = 0;
  final Queue<List<int>> _queue = new Queue<List<int>>();
  
  int _bytesRead = 0;
  int get bytesRead => _bytesRead;
  
  int get bytesAvailable => _queue.fold(0, (len, buffer) => len + buffer.length) - _position;
  
  int readByte() {
    if (_queue.isEmpty)
      throw new Exception("Attempted to read from an empty buffer.");
    
    int byte = _queue.first[_position];
    
    _position++;
    if (_position >= _queue.first.length) {
      _queue.removeFirst();
      _position = 0;
    }
    
    _bytesRead++;
    
    return byte;
  }
  
  int readInt16() {
    int a = readByte();
    int b = readByte();
    
    assert(a < 256 && b < 256 && a >= 0 && b >= 0);
    int i = (a << 8) | b;
    
    if (i >= 0x8000)
      i = -0x10000 + i;
    
    return i;    
  }
  
  int readInt32() {
    int a = readByte();
    int b = readByte();
    int c = readByte();
    int d = readByte();
    
    assert(a < 256 && b < 256 && c < 256 && d < 256 && a >= 0 && b >= 0 && c >= 0 && d >= 0);
    int i = (a << 24) | (b << 16) | (c << 8) | d;
    
    if (i >= 0x80000000)
      i = -0x100000000 + i;
    
    return i;    
  }
  
  List<int> readBytes(int bytes) {
    var list = new List<int>(bytes);
    for (int i = 0; i < bytes; i++) {
      list[i] = readByte();
    }
    return list;
  }
  
  //FIXME handle unicode properly.
  String readString(int maxSize) {
    var sb = new StringBuffer();
    int c;
    while ((c = readByte()) != 0) {
      sb.writeCharCode(c);
    }
    return sb.toString();
  }
  
  void append(List<int> data) {
    if (data == null || data.isEmpty)
      throw new Exception("Attempted to append null or empty list.");
    
    _queue.addLast(data);
  }
}
