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
              conn._idle();
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
        finally0(() => completer0.completeError(e0, s0));
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
                var md5 = _md5CredentialsHash(_settings.user, _settings.password, msg.salt);
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
            finally0(() {
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
  
  
  String _md5s(String s) {
    var hash = new MD5();
    hash.add(s.codeUnits.toList());
    return CryptoUtils.bytesToHex(hash.close());
  }
  
  String _md5CredentialsHash(String user, String password, List<int> salt) {
    var hash = _md5s(password + user);
    var saltStr = new String.fromCharCodes(salt);
    return 'md5' + _md5s('$hash$saltStr');
  }
  
  
  void _idle() {
  final completer0 = new Completer();
  scheduleMicrotask(() {
    try {
      assert(_state == CState.idle);
      done0() {
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
        finally0(() => completer0.completeError(e0, s0));
      }
      stream0 = _client.messages.listen((x0) {
        var msg = x0;
        join0() {
          join1() {
          }
          if (msg is ErrorResponse || msg is NoticeResponse) {
            _messages.add(new ServerMessage(msg is ErrorResponse, msg.fields));
            join1();
          } else {
            join2() {
              join1();
            }
            if (msg is ParameterStatus) {
              _parameters[msg.name] = msg.value;
              join2();
            } else {
              join2();
            }
          }
        }
        if (_state != CState.idle) {
          finally0(() {
            completer0.complete(null);
          });
        } else {
          join0();
        }
      }, onError: catch0, onDone: done0);
    } catch (e, s) {
      completer0.completeError(e, s);
    }
  });
  return completer0.future;
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
