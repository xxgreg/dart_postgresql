part of postgresql;

final String DEFAULT_HOST = "localhost";
final num DEFAULT_PORT = 5432;

/**
 * Settings for PostgreSQL.
 */
class Settings {
  String _host;
  int _port;
  String _user;
  String _password;
  String _database;
  bool _requireSsl;
  
  /**
   * Settings map keys
   */
  static final String HOST = "host";
  static final String PORT = "port";
  static final String USER = "user";
  static final String PASSWORD = "password";
  static final String DATABASE = "database";

  Settings(this._host,
      this._port,
      this._user,
      this._password,
      this._database,
      {bool requireSsl: false})
    : _requireSsl = requireSsl;

  factory Settings.fromUri(String uri) {

    var u = Uri.parse(uri);
    if (u.scheme != 'postgres' && u.scheme != 'postgresql')
      throw new FormatException('Invalid uri.');

    if (u.userInfo == null || !u.userInfo.contains(':'))
      throw new FormatException('Invalid uri.');

    var userInfo = u.userInfo.split(':');

    if (u.path == null || !u.path.startsWith('/'))
      throw new FormatException('Invalid uri.');

    bool requireSsl = false;
    if (u.query != null)
      requireSsl = u.query.contains('sslmode=require');

    return new Settings(
        u.host,
        u.port == null ? DEFAULT_PORT : u.port,
        userInfo[0],
        userInfo[1],
        u.path.substring(1, u.path.length), // Remove preceding forward slash.
        requireSsl: requireSsl);
  }

  /**
   * Parse a map, apply default rules etc.
   * 
   * Throws [FormatException] when a setting (without default value)
   * is present.
   */
  Settings.fromMap(Map config){
    final String host = config.containsKey(HOST) ?
        config[HOST] : DEFAULT_HOST;
    final int port = config.containsKey(PORT) ?
        config[PORT] is int ? config[PORT]
          : throw new FormatException("Specified port is not a valid number")
        : DEFAULT_PORT;
    if (!config.containsKey(USER))
      throw new FormatException(USER);
    if (!config.containsKey(PASSWORD))
      throw new FormatException(PASSWORD);
    if (!config.containsKey(DATABASE))
      throw new FormatException(DATABASE);
    
    this._host = config[HOST];
    this._port = port;
    this._user = config[USER];
    this._password = config[PASSWORD];
    this._database = config[DATABASE];

    this._requireSsl = config.containsKey('sslmode') 
        && config['sslmode'] == 'require';
  }
  
  String get host => _host;
  int get port => _port;
  String get user => _user;
  String get password => _password;
  String get database => _database;
  bool get requireSsl => _requireSsl;

  /**
   * Return connection URI.
   * 
   * TODO
   * Support http://www.postgresql.org/docs/9.2/static/libpq-connect.html#AEN38149
   */
  String toUri()
    => "postgres://$_user:$_password@$_host:$_port/$_database${requireSsl ? '?sslmode=require' : ''}";
  
  String toString()
    => "Settings: [host: $_host, port: $_port, user: $_user, database: $_database]";

  Map toMap() {
    var map = new Map<String, dynamic>();
    map[HOST] = host;
    map[PORT] = port;
    map[USER] = user;
    map[PASSWORD] = password;
    map[DATABASE] = database;
    if (requireSsl)
      map['sslmode'] = 'require';
    return map;
  }
}