# PostgreSQL database driver for Dart

## Basic usage

### Obtaining a connection

```dart
connect('database', 'username', 'password').then((conn) {
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
conn.execute("update crayons set color = 'pink'").then((result) {
	print(result.rowsAffected);
});
```

### Closing the connection

You must remember to call Connection.close() when you're done. This wont be
done automatically for you.

### Query queueing

Queries are queued and executed in the order in which they were queued.

So you can write code like this:

```dart
conn.execute("update crayons set color = 'pink'");
conn.query("select color from crayons").toList().then((rows) {
	rows.forEach((row) => print(row.color); 
});
```

### Query streaming

Connection.query() returns a Stream of results. You can use each row as soon as
it is received, or you can wait till they all arrive by calling String.toList().


## Testing

To run the unit tests you will need to create a database, and add the database
name, username and password to 'postgresql_test.dart'.

## Links

http://www.postgresql.org/docs/9.2/static/index.html
http://www.dartlang.org/
