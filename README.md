# PostgreSQL database driver for Dart

[![Build Status](https://drone.io/github.com/xxgreg/postgresql/status.png)](https://drone.io/github.com/xxgreg/postgresql/latest)

## Basic usage

### Obtaining a connection

```dart
var uri = 'postgres://username:password@localhost:5432/database';
connect(uri).then((conn) {
	// ...
});
```

### SSL connections

Set the sslmode to require by appending this to the connection uri. This driver only supports sslmode=require, if sslmode is ommitted the driver will always connect without using SSL.

```dart
var uri = 'postgres://username:password@localhost:5432/database?sslmode=require';
connect(uri).then((conn) {
	// ...
});
```

### Querying

```dart
conn.query('select color from crayons').toList().then((rows) {
	for (var row in rows) {
		print(row.color); // Refer to columns by name,
		print(row[0]);    // Or by column index.
	}
});
```

### Executing

```dart
conn.execute("update crayons set color = 'pink'").then((rowsAffected) {
	print(rowsAffected);
});
```

### Query Parameters

Query parameters can be provided using a map. Strings will be escaped to prevent SQL injection vulnerabilities.

```dart
conn.query('select color from crayons where id = @id', {'id': 5})
  .toList()
	.then((result) { print(result); });

conn.execute('insert into crayons values (@id, @color)',
             {'id': 1, 'color': 'pink'})
	.then((_) { print('done.'); });
```

### Closing the connection

You must remember to call Connection.close() when you're done. This wont be
done automatically for you.

### Conversion of Postgresql datatypes.

Below is the mapping from Postgresql types to Dart types. The type mapping is still a work in progress. All types which do not have an explicit mapping will be returned as a String in Postgresql's standard text format. This means that it is still possible to handle all types, as you can parse the string yourself.

```
  Postgresql type        Dart type
	boolean                bool
	int2, int4, int8       int
	float4, float8         double
	timestamp, date        Datetime
	All other types        String
```

### Mapping the results of a query to an object

```dart
class Crayon {
	String color;
	int length;
}

conn.query('select color, length from crayons')
  .toList()
	.map((row) => new Crayon()
	                     ..color = row.color,
	                     ..length = row.length)
	.then((List<Crayon> crayons) {
		for (var c in crayons) {
			print(c is Crayon);
			print(c.color);
			print(c.length);
		}
	});
```

Or for an immutable object:

```dart
class ImmutableCrayon {
	ImmutableCrayon(this.color, this.length);
	final String color;
	final int length;
}

conn.query('select color, length from crayons')
  .toList()
	.map((row) => new ImmutableCrayon(row.color, row.length))
	.then((List<ImmutableCrayon> crayons) {
		for (var c in crayons) {
			print(c is ImmutableCrayon);
			print(c.color);
			print(c.length);
		}
	});
```

### Query queueing

Queries are queued and executed in the order in which they were queued.

So if you're not concerned about handling errors, you can write code like this:

```dart
conn.execute("create table crayons (color text, length int)");
conn.execute("insert into crayons values ('pink', 5)");
conn.query("select color from crayons").single.then((crayon) {
	print(crayon.color); // prints 'pink'
});
```

### Query streaming

Connection.query() returns a Stream of results. You can use each row as soon as
it is received, or you can wait till they all arrive by calling Stream.toList().

### Connection pooling

In server applications, a connection pool can be used to avoid the overhead of obtaining a connection for each request.

```dart
// import 'postgres/postgres_pool.dart';
var uri = 'postgres://username:password@localhost:5432/database';
var pool = new Pool(uri, min: 2, max: 5);
pool.start().then((_) {
  print('Min connections established.');
  pool.connect().then((conn) { // Obtain connection from pool
    conn.query("select 'oi';")
      .toList()
      .then(print)
      .then((_) => conn.close()) // Return connection to pool
      .catchError((err) => print('Query error: $err'));
  });
});

```

### Example program

Add postgresql to your pubspec.yaml file, and run pub install.

```
name: postgresql_example
dependencies:
  postgresql: any
```

```dart
import 'package:postgresql/postgresql.dart';

void main() {
  var uri = 'postgres://testdb:password@localhost:5432/testdb';
  var sql = "select 'oi'"; 
  connect(uri).then((conn) {
    conn.query(sql).toList()
    	.then((result) {
    		print('result: $result');
    	})
    	.whenComplete(() {
    		conn.close();
    	});
  });
}
```

## Testing

To run the unit tests you will need to create a database, and edit
'test/config.yaml' accordingly.

### Creating a database for testing

Change to the postgres user and run the administration commands.
```bash
sudo su postgres
createuser --pwprompt testdb
  Enter password for new role: password
  Enter it again: password
  Shall the new role be a superuser? (y/n) n
  Shall the new role be allowed to create databases? (y/n) n
  Shall the new role be allowed to create more new roles? (y/n) n
createdb --owner testdb testdb
exit
```

Check that it worked by logging in.
```bash
psql -h localhost -U testdb -W
```

Enter "\q" to quit from the psql console.

## License

BSD

## Links

http://www.postgresql.org/docs/9.2/static/index.html
http://www.dartlang.org/
