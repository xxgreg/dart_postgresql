# PostgreSQL database driver for Dart

This is alpha level software, expect things to break, especially with the
number of breaking changes happening in Dart's libraries at the moment.

## Basic usage

### Obtaining a connection

```dart
connect('database', 'username', 'password', host: 'localhost', port: 5432).then((conn) {
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
psql -h localhost -U testdb3 -W
```

Enter "\q" to quit from the psql console.

## Links

http://www.postgresql.org/docs/9.2/static/index.html
http://www.dartlang.org/
