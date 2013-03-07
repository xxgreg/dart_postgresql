# PostgreSQL database driver for Dart

This is alpha level software, expect things to break, especially with the
number of breaking changes happening in Dart's libraries at the moment.

## Basic usage

### Obtaining a connection

```dart
connect('username', 'database', 'password', host: 'localhost', port: 5432).then((conn) {
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

### Closing the connection

You must remember to call Connection.close() when you're done. This wont be
done automatically for you.

### Mapping the results of a query to an object

```dart
class Crayon {
	String color;
	int length;
}

conn.query('select color, length from crayons')
	.map((row) => new Crayon()
	                     ..color = row.color,
	                     ..length = row.length)
	.toList()
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
	.map((row) => new ImmutableCrayon(row.color, row.length))
	.toList()
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


## Testing

To run the unit tests you will need to create a database, and add the database
name, username and password to 'postgresql_test.dart'.

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
