library postgresql.impl2;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
//import 'package:postgresql/constants.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/protocol/protocol.dart';


//enum CState { starting, authenticated, idle, busy, streaming }

class CState {
  const CState(this.name);
  final String name;
  
  static const CState starting = const CState('starting');
  static const CState authenticated = const CState('authenticated');
  static const CState idle = const CState('idle');
  static const CState busy = const CState('busy');
  static const CState streaming = const CState('streaming');
  
  static const CState copyIn = const CState('copyIn');
  static const CState copyOut = const CState('copyOut');
  
  static const CState closed = const CState('closed');
  
  String toString() => name;
}

typedef Object RowMapper(RowDescription desc, int cmd, DataRow row);

typedef CopyInCallback(StreamSink<List<int>> sink);
typedef CopyOutCallback(Stream<List<int>> stream);

class Task {
  
  Task.query(this.sql, this.values, this.mapper, {this.copyIn, this.copyOut})
    : isExecute = false;
  
//  Task.execute(this.sql, {this.copyIn, this.copyOut})
//    : isExecute = true, mapper = ((a, b, c) {});
  
  final String sql;
  final bool isExecute;
  final RowMapper mapper;
  final StreamController controller = new StreamController(); // Rename results or something.
  final CopyInCallback copyIn;
  final CopyOutCallback copyOut;
  final List<Object> values;
  
  StreamController<List<int>> copyOutController;
  int cmd = 0;
  RowDescription desc = null;
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
  Task _task;
  int _backendPid;
  int _secretKey;
  final Map<String,String> _parameters = <String,String>{};
  final StreamController<Message> _messages = new StreamController<Message>();
  final List<Task> _queue = new List<Task>();  
  
  static Future<ConnectionImpl> connect(
      Settings settings, Duration timeout) {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      new Future.value(ProtocolClient.connect(settings.host, settings.port, timeout: timeout)).then((x0) {
        try {
          var client = x0;
          var conn = new ConnectionImpl(settings, client);
          new Future.value(conn._startup()).then((x1) {
            try {
              x1;
              assert(conn._state == CState.idle);
              completer0.complete(conn);
            } catch (e0, s0) {
              completer0.completeError(e0, s0);
            }
          }, onError: completer0.completeError);
        } catch (e1, s1) {
          completer0.completeError(e1, s1);
        }
      }, onError: completer0.completeError);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}
    
  // Need to manually patch cps output: finally0((_) => ....); should be finally0((_) => ....);
  // http://www.postgresql.org/docs/9.2/static/protocol-flow.html#AEN95219
  Future _startup() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      _client.send(new Startup(_settings.user, _settings.database, {}));
      var notices = [];
      done0() {
        throw new Exception('Server disconnected during authentication.');
        completer0.complete();
      }
      var stream0;
      finally0(cont0) {
        try {
          new Future.value(stream0.cancel()).then(cont0);
        } catch (e0, s0) {
          completer0.completeError(e0, s0);
        }
      }
      catch0(e0, s0) {
        finally0((_) => completer0.completeError(e0, s0));
      }
      stream0 = _client.messages.listen((x0) {
        var msg = x0;
        join0() {
        }
        if (msg is AuthenticationRequest) {
          join1() {
            join0();
          }
          if (msg.authType == 0) {
            _state = CState.authenticated;
            join1();
          } else {
            join2() {
              join1();
            }
            if (msg.authType == 3) {
              _client.send(new PasswordMessage(_settings.password));
              join2();
            } else {
              join3() {
                join2();
              }
              if (msg.authType == 5) {
                var md5 = md5CredentialsHash(_settings.user, _settings.password, msg.salt);
                _client.send(new PasswordMessage(md5));
                join3();
              } else {
                join3();
              }
            }
          }
        } else {
          join4() {
            join0();
          }
          if (msg is ReadyForQuery) {
            assert(_state == CState.authenticated);
            assert(msg.transactionState == TransactionState.none);
            _state = CState.idle;
            _client.messages.listen(_handleMessage)
                ..onError(_handleError)
                ..onDone(_handleDisconnect);
            finally0((_) {
              completer0.complete(null);
            });
          } else {
            join5() {
              join4();
            }
            if (msg is ErrorResponse) {
              throw new Exception('${msg.code}: ${msg.message}');
              join5();
            } else {
              join6() {
                join5();
              }
              if (msg is NoticeResponse) {
                notices.add(msg);
                join6();
              } else {
                join7() {
                  join6();
                }
                if (msg is BackendKeyData) {
                  _backendPid = msg.backendPid;
                  _secretKey = msg.secretKey;
                  join7();
                } else {
                  join8() {
                    join7();
                  }
                  if (msg is ParameterStatus) {
                    _parameters[msg.name] = msg.value;
                    join8();
                  } else {
                    join8();
                  }
                }
              }
            }
          }
        }
      }, onError: catch0, onDone: done0);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
}  
  
  void _handleMessage(ProtocolMessage msg) {
    switch (_state) {
      case CState.starting:
      case CState.authenticated:
        throw new Exception('boom!'); //TODO
        break;
      case CState.idle:
        _idle(msg);
        break;
      case CState.busy:
      case CState.streaming:
        _busy(msg);
        break;
      case CState.copyOut:
        _copyOut(msg);
        break;
      default:
        assert(false);
    }
  }
  
  void _handleError(error) {
    
    if (_state == CState.busy ||
        _state == CState.streaming ||
        _state == CState.copyIn ||
        _state == CState.copyOut) {

      var c = _task.controller;
      if (!c.isClosed) {
        c.addError(error);
        c.close();
      }
      
    } else {
      throw error; // FIXME
      
      if (!_messages.isClosed)
        _messages.addError(error);
    }
  }
  
  void _handleDisconnect() {
    //FIXME
    
    if (_state == CState.busy ||
        _state == CState.streaming ||
        _state == CState.copyIn ||
        _state == CState.copyOut) {
      
      var c = _task.controller;
      if (!c.isClosed) {
        var err = new Exception('Connection closed.'); // FIXME
        c.addError(err);
        c.close();
      }
    }
    
    _state = CState.closed;
  }

  
  //FIXME should be return void.
  // But async_await chokes.
  void _idle(ProtocolMessage msg) {
    assert(_state == CState.idle);
    if (msg is BaseResponse) {
      _messages.add(new ServerMessage(msg is ErrorResponse, msg.fields));
    } else if (msg is ParameterStatus) {
      _parameters[msg.name] = msg.value;
    }
  }
  

  //FIXME
  final _tc = new TypeConverter();
  
  Stream query(String sql, [List<Object> values]) {
    //TODO proper mapper.
    var mapper = (RowDescription desc, int cmd, DataRow msg) {
      var result = new List(msg.values.length);
      for (int i = 0; i < msg.values.length; i++) {
        var s = UTF8.decode(msg.values[i]);
        result[i] = _tc.decode(s, desc.fields[i].fieldType);
      }
      return result;
    };
    
    var task = new Task.query(sql, values, mapper);
    _enqueue(task);
    return task.controller.stream;
  }
  
//  Future<int> execute(String sql) {
//    var task = new Task.execute(sql);
//    _enqueue(task);
//    return task.controller.stream.last;
//  }
  
  Stream _enqueue(Task task) {
    
    if (task.sql == null) {
      //TODO consider throwing ArgumentError instead. I am just wary of this
      // as it means that it will bring down an entire application.
      var err = new Exception('Sql is null.'); //FIXME
      return new Stream.fromFuture(new Future.error(err));
    }
    
    _queue.add(task);
    
    new Future.microtask(_processTask);
    
    return task.controller.stream;
  }
  
  void _processTask() {
    if (_state != CState.idle || _queue.isEmpty) return;
    _state = CState.busy;
    _task = _queue.removeAt(0);
    
    // TODO have separate tasks for prepare and execute.
    // So these can be performed separately.
    
    // This can be significanly more efficient by writing each value directly
    // into the socket.
    var fmt = new TypeConverter();
    var parameters = _task.values == null
        ? []
        : _task.values.map((v) {
          if (v == null) return null;
          var s = v is String ? v : fmt.encode(v, null); // Just a quick hack for now. Fix this later.
          return UTF8.encode(s);
        }).toList();
    
    _client.sendAll([
      new Parse("", _task.sql, []),
      new Bind("", "", [], parameters, []),
      new Describe('S'.codeUnitAt(0), ""),
      new Execute("", 0),
      new Sync()
    ]);
  }
  
  // http://www.postgresql.org/docs/9.2/static/protocol-flow.html#AEN95294
  void _busy(ProtocolMessage msg) {
    assert(_state == CState.busy || _state == CState.streaming);
    
    var out = _task.controller;
         
    if (msg is DataRow) {
        if (!out.isClosed && !_task.isExecute)
          out.add(_task.mapper(_task.desc, _task.cmd, msg));

    } else if (msg is ParseComplete) {
        // Can ignore these when expecting results.
    } else if (msg is BindComplete) {
        // Can ignore these when expecting results.
    } else if (msg is ParameterDescription) {
    } else if (msg is CommandComplete) {
      _task.cmd++;
      if (!out.isClosed && _task.isExecute)
        out.add(msg.rowsAffected);
      
    } else if (msg is CopyInResponse) {
      if (_task.copyIn == null)
        throw new Exception('No CopyInCallback provided.'); //FIXME
      
      _state = CState.copyIn;
      
      // could use. ctl.stream.map ??
      var ctl = new StreamController<List<int>>();
      ctl.stream.listen(null)
        ..onData((data) => _client.send(new CopyData(data)))
        ..onError((err) => _client.send(new CopyFail(err.toString())))
        ..onDone(() {
          //TODO figure out why I get a bad state error if this is run synchronously.
          // putting it in a microtask seems to fix it.
          new Future.microtask(() => _client.send(new CopyDone()))
              .then((_) { _state = CState.streaming; }); //TODO not sure if this is the correct state.
// TODO handle send (i.e.socket flush) failure. 
//              .catchError((err) {
//                out.addError(err);
//                out.close();
//                //FIXME
//                // close connection if send fails?
//                //_state = error ??
//              });
          });
          
          // Call user's code and get then to copy the data in.
          new Future.microtask(() => _task.copyIn(ctl.sink));
        
      } else if (msg is CopyOutResponse) {
        if (_task.copyOut == null)
          throw new Exception('No CopyOutCallback provided.'); //FIXME
        
        assert(_task.copyOutController == null);
        var c = new StreamController<List<int>>();
        _task.copyOutController = c; 
        _task.copyOut(c.stream);
        
        _state = CState.copyOut;
        
      } else if (msg is RowDescription) {
        _task.desc = msg;
        _state = CState.streaming;
        
      } else if (msg is EmptyQueryResponse) {
        // No action required.
      
      } else if (msg is ReadyForQuery) {
        if (!out.isClosed) out.close();
        _state = CState.idle;
        //TODO _txState = msg.transactionState;
        _processTask();
      
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
      } else {
        throw new Exception('Invalid message type while using simple query protocol. $msg'); 
      }
  }
  
  _copyOut(ProtocolMessage msg) {
    assert(_state == CState.copyOut);
    var ctl = _task.copyOutController; 
    
    if (msg is CopyData) {
      ctl.add(msg.data);
    } else if (msg is CopyDone) {
      ctl.close();
      _task.copyOutController = null;
      _state = CState.streaming; //TODO not sure if this is correct.
    } else if (msg is CopyFail) {
      var err = new Exception(msg.message); //FIXME
      ctl.addError(err);
    }
  }
  
  
  Stream xquery(String sql) {
    var parse = new Parse('foo', r'select $1', []);
    _client.send(parse);
    return null;
  }
  
}
