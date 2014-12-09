library postgresql.impl2;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
//import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/protocol/protocol.dart';


//enum CState { starting, authenticated, idle, busy, streaming }

class CState {
  const CState();
  static const CState starting = const CState();
  static const CState authenticated = const CState();
  static const CState idle = const CState();
  static const CState busy = const CState();
  static const CState streaming = const CState();
}

typedef Object RowMapper(RowDescription desc, int cmd, DataRow row);

class Task {
  Task.query(this.sql, this.mapper) : isExecute = false;
  Task.execute(this.sql) : isExecute = true, mapper = ((a, b, c) {});
  final String sql;
  final bool isExecute;
  final RowMapper mapper;
  final StreamController controller = new StreamController();
}

String md5s(String s) {
  var hash = new MD5();
  hash.add(s.codeUnits.toList());
  return CryptoUtils.bytesToHex(hash.close());
}

String md5CredentialsHash(String user, String password, List<int> salt) {
  var hash = md5s(password + user);
  var saltStr = new String.fromCharCodes(salt);
  return 'md5' + md5s('$hash$saltStr');
}


class ConnectionImpl {

  ConnectionImpl(this._settings, this._client);
    
  final Settings _settings;
  final ProtocolClient _client;
  
  CState _state = CState.starting;
  int _backendPid;
  int _secretKey;
  final Map<String,String> _parameters = <String,String>{};
  final StreamController<Message> _messages = new StreamController<Message>();
  final List<Task> _queue = new List<Task>();
  
  static Future<ConnectionImpl> connect(
      Settings settings, Duration timeout) async {
     
      var client = await ProtocolClient.connect(
          settings.host, settings.port, timeout: timeout);
      
      var conn = new ConnectionImpl(settings, client);
      
      await conn._startup();
      
      assert(conn._state == CState.idle);
      
      conn._idle();
      
      return conn;
  }
  
  // Need to manually patch cps output: finally0(() => ....); should be finally0((_) => ....);
  // http://www.postgresql.org/docs/9.2/static/protocol-flow.html#AEN95219
  Future _startup() async {
    
    _client.send(new Startup(_settings.user, _settings.database, {}));
    
    //FIXME what to do with notices received during startup?
    // Can't add to messages stream, as there won't be any listeners yet,
    // and this stream doesn't buffer.
    var notices = [];
    
    await for (var msg in _client.messages) {
      
      if (msg is AuthenticationRequest) {
        if (msg.authType == 0) { // ok
          _state = CState.authenticated;
        
        } else if (msg.authType == 3) { // cleartext
          _client.send(new PasswordMessage(_settings.password));
          
        } else if (msg.authType == 5) { // md5
          var md5 = md5CredentialsHash(
              _settings.user, _settings.password, msg.salt);
          _client.send(new PasswordMessage(md5));
        }
      } else if (msg is ReadyForQuery) {
        assert(_state == CState.authenticated);
        assert(msg.transactionState == TransactionState.none);
        _state = CState.idle;
        return null;
      
      } else if (msg is ErrorResponse) {
        //FIXME throw new PostgresqlException('Error while establishing a connection.', null, serverMessage: msg);
        throw new Exception('${msg.code}: ${msg.message}');
      
      } else if (msg is NoticeResponse) {
        notices.add(msg);
      
      } else if (msg is BackendKeyData) {
        _backendPid = msg.backendPid;
        _secretKey = msg.secretKey;
      
      } else if (msg is ParameterStatus) {
        _parameters[msg.name] = msg.value;
      }
    }
    
    throw new Exception('Server disconnected during authentication.');
  }  
  
  //FIXME should be return void.
  // But async_await chokes.
  Future _idle() async {
    assert(_state == CState.idle);
    await for (var msg in _client.messages) {
      if (_state != CState.idle) {
        // State has changed stop listening.
        return null; //FIXME should just be return; but async await chokes. 
      }
      if (msg is ErrorResponse || msg is NoticeResponse) {
        _messages.add(new ServerMessage(msg is ErrorResponse, msg.fields));
      } else if (msg is ParameterStatus) {
        _parameters[msg.name] = msg.value;
      }
    }
    
    // Connection closed.
    // TODO do I need to do something here?
    // _state = closed; ??
  }
  

  Stream query(String sql) {
    //TODO proper mapper.
    var mapper = (RowDescription desc, int cmd, DataRow msg) =>
          msg.values.map((bytes) => UTF8.decode(bytes)).toList(growable: false);
    
    var task = new Task.query(sql, mapper);
    _enqueue(task);
    return task.controller.stream;
  }
  
  Future<int> execute(String sql) {
    var task = new Task.execute(sql);
    _enqueue(task);
    return task.controller.stream.last;
  }
  
  Stream _enqueue(Task task) {
    
    if (task.sql == null) {
      //TODO consider throwing ArgumentError instead. I am just wary of this
      // as it means that it will bring down an entire application.
      var err = new Exception('Sql is null.'); //FIXME
      return new Stream.fromFuture(new Future.error(err));
    }
    
    _queue.add(task);
    
    new Future(_processTasks);
    
    return task.controller.stream;
  }
  
  void _processTasks() {
    while (_queue.isNotEmpty) {
      var task = _queue.removeAt(0);
      _client.send(new Query(task.sql));
      _simpleQuery(task);
    }
  }

  // TODO Once async* is implemented might be able to make this pretty.
  // http://www.postgresql.org/docs/9.2/static/protocol-flow.html#AEN95294
  void _simpleQuery(Task task) {
    
    _state = CState.busy;
    
    var out = task.controller;
        
    int cmd = 0;
    RowDescription desc = null;
    
    var subs = _client.messages.listen(null);
    
    subs.onData((msg) {
      if (msg is DataRow) {
        if (!out.isClosed && !task.isExecute)
          out.add(task.mapper(desc, cmd, msg));

      } else if (msg is CommandComplete) {
        cmd++;
        if (!out.isClosed && task.isExecute)
          out.add(msg.rowsAffected);
        
      } else if (msg is CopyInResponse) {
        throw new UnimplementedError();
      
      } else if (msg is CopyOutResponse) {
        throw new UnimplementedError();
      
      } else if (msg is RowDescription) {
        desc = msg;
        _state = CState.streaming;
        
      } else if (msg is EmptyQueryResponse) {
        // No action required.
      
      } else if (msg is ReadyForQuery) {
        if (!out.isClosed) out.close();
        subs.cancel(); //TODO handle error returned by future?
      
      } else if (msg is ErrorResponse) {
        var error = new ServerMessage(true, msg.fields);
        if (!out.isClosed) {
          out.addError(error);
          out.close();
        } else {
          // This shouldn't be able to happen - but better not to swallow the
          // error message in case I'm wrong and it does happen.
          _messages.addError(error);
        }
      
      } else if (msg is NoticeResponse) {
        _messages.add(new ServerMessage(false, msg.fields));
      
      } else if (msg is ParameterStatus) {
        // TODO move the general async handlers into a shared method.
        _parameters[msg.name] = msg.value;
      }
    });
    
    subs.onError((err) {
      if (!out.isClosed) {
        out.addError(err);
        out.close();
      } else {
        var error = new ClientMessage(
            isError: true, message: err.toString(), exception: err);
        _messages.addError(error);
      }
      subs.cancel(); //TODO handle error returned by future?
    });
    
    subs.onDone(() {
      if (!out.isClosed) {
        var ex = new Exception('Connection with server was lost.'); //TODO exception type.
        out.addError(ex);
      }
      _state = CState.idle;
      _processTasks();
    });
  }
  
}