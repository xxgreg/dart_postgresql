library postgresql.pool;

import 'dart:async';
import 'dart:collection';
import 'package:postgresql/postgresql.dart' as pg;

//TODO implement lifetime. When connection is release if been open for more than lifetime millis, then close the connection, and open another. But need some way to stagger, initial creation, so they don't all expire at the same time.

abstract class Pool {	
	factory Pool(String uri, {int timeout, int min: 2, int max: 10})
		=> new _Pool(uri, timeout: timeout, min: min, max: max);

	/// Returns once the specified minimum number of connections have connected successfully.
	Future start();

	/// Get an existing [Connection] from the connection pool, or establish a new one.
	/// The [Connection] will be automatically closed after [timeout] milliseconds.
	/// Timeout overrides the pool set timeout.
	Future<pg.Connection> connect([int timeout]);

	// Close all of the connections.
	void destroy();
}

class _Pool implements Pool {
	final String _uri;
	final int _timeout;
	final int _min;
	final int _max;	
	final _connections = new List<_PoolConnection>();
	final _available = new List<_PoolConnection>();
	bool _destroyed = false;
	int get _count => _connections.length + _connecting;
	int _connecting = 0;

	_Pool(this._uri, {int timeout, int min: 2, int max: 10})
		: _timeout = timeout,
		  _min = min,
		  _max = max;
	
	Future start() {
		var futures = new List<Future>(_min);
		for (int i = 0; i < _min; i++) {
			futures[i] = _incConnections();
		}
		return Future.wait(futures).then((_) { return true; });
	}

	Future<_PoolConnection> connect([int timeout]) {
		if (_destroyed)
			return new Future.error('Connect() called on destroyed pool.');

		if (!_available.isEmpty)
			return new Future.value(_available.removeAt(0));

		if (_count >= _max)
			return new Future.error('Maximum number of connections for the connection pool was exhausted.');

		return _incConnections().then((_) {

			if (_available.isEmpty)
				throw new Exception('No connections available.'); //FIXME exception type.

			var c = _available.removeAt(0);

			if (_destroyed) {
				_destroy(c);
				throw new Exception('Connect() called on destroyed pool (Pool was destroyed during connection establishment).');
			}

			if (!c._isReleased) {
				throw new Exception('Connection not released.'); //FIXME
			}

			_setObtainedState(c, timeout == null ? _timeout : timeout);

			return c;
		});
	}

	// Close all connections and cleanup.
	void destroy({waitForConnectionRelease: false}) {
		_destroyed = true;

		if (!waitForConnectionRelease) {
			// Immediately close all connections
			for (var c in _connections)
				c.close();

			_available.clear();
			_connections.clear();
		
		} else {
			// Close available connections.
			for (var c in _available)
				c.close();
			_available.clear();

			// Wait for other connections to be released
			// ??
			throw new UnimplementedError();
		}
	}

	// Establish another connection, add to the list of available connections.
	Future _incConnections() {
		_connecting++;
		return pg.connect(_uri)
		 .then((c) {
		 	var conn = new _PoolConnection(this, c);
		 	c.onClosed.then((_) => _handleUnexpectedClose(conn));
		 	_connections.add(conn);
		 	_available.add(conn);
		 	_connecting--;
		 })
		 .catchError((err) {
		 	_connecting--;
		 	//FIXME logging.
		 	print('Pool connect error: $err');
		 });
	}

	void _release(_PoolConnection conn) {

		if (_available.contains(conn))
			return;

		if (conn.isClosed || conn.transactionStatus != pg.TRANSACTION_NONE) {

			//TODO lifetime expiry.
			//|| conn._obtained.millis > lifetime

			//TODO logging.
			print('Connection returned in bad transaction state: $conn.transactionStatus');
			_destroy(conn);
			_incConnections();
		
		} else {
			_setReleasedState(conn);
			_available.add(conn);
		}
	}

	void _destroy(_PoolConnection conn) {
		conn._conn.close();           // OK if already closed.
		_connections.remove(conn);
		_available.remove(conn);
	}

	void _setObtainedState(_PoolConnection conn, int timeout) {
		conn._isReleased = false;
		conn._obtained = new DateTime.now();
		conn._timeout = timeout;
		conn._reaper = null;

		if (timeout != null) {
			conn._reaper = new Timer(new Duration(milliseconds: _timeout), () {
				print('Connection not released within timeout: ${conn._timeout}ms.'); //TODO logging.
				_destroy(conn);
			});
		}
	}

	void _setReleasedState(_PoolConnection conn) {
		conn._isReleased = true;
		conn._timeout = null;
		if (conn._reaper != null) {
			conn._reaper.cancel();
			conn._reaper = null;
		}
	}

	void _handleUnexpectedClose(_PoolConnection conn) {
		print('Connection closed unexpectedly. Removed from pool.'); //TODO logging.
		_destroy(conn);

		// TODO consider automatically restarting lost connections.
	}

	toString() => 'Pool connecting: $_connecting available: ${_available.length} total: ${_connections.length}';
}

class _PoolConnection implements pg.Connection {
	final _Pool _pool;
	final pg.Connection _conn;
	final DateTime _connected;
	DateTime _obtained;
	bool _isReleased;
	int _timeout;
	Timer _reaper; // Kills connections after a timeout expires.

	_PoolConnection(this._pool, this._conn)
		: _connected = new DateTime.now(),
		  _isReleased = true;

	void close() => _pool._release(this);
	Stream query(String sql, [values]) => _conn.query(sql, values);
	Future<int> execute(String sql, [values]) => _conn.execute(sql, values);

	bool get isClosed => false; //TODO.
	int get transactionStatus => _conn.transactionStatus;

	Stream<dynamic> get unhandled { throw new UnimplementedError(); }

	Future get onClosed { throw new UnimplementedError(); }
}
