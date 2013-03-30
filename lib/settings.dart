library postgresql;

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
  
  /**
   * Settings map keys
   */
  static final String HOST = "host";
  static final String PORT = "port";
  static final String USER = "user";
  static final String PASSWORD = "password";
  static final String DATABASE = "database";

  Settings(this._host, this._port, this._user, this._password, this._database);

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
  }
  
  /**
   * Return connection URI.
   * 
   * TODO
   * Support http://www.postgresql.org/docs/9.2/static/libpq-connect.html#AEN38149
   */
  String toUri()
    => "postgres://$_user:$_password@$_host:$_port/$_database";
  
  String toString()
    => "Settings: [host: $_host, port: $_port, user: $_user, database: $_database]";
}