part of postgresql;

class _Settings {
  _Settings(String username,
      this._database,
      String password,
      {host : 'localhost',
       port: 5432})
    : _username = username,
      _passwordHash = _md5s(password.concat(username)),
      _host = host,
      _port = port;      
  
  final String _host;
  final int _port;
  final String _username;
  final String _database;
  final String _passwordHash;
}

String _md5s(String s) {
  var hash = new MD5();
  hash.add(s.codeUnits.toList());
  return CryptoUtils.bytesToHex(hash.close());
}