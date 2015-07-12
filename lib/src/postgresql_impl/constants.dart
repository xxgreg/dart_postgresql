part of postgresql.impl;

const int _QUEUED = 1;
const int _BUSY = 6;
const int _STREAMING = 7;
const int _DONE = 8;

const int _I = 73;
const int _T = 84;
const int _E = 69;

const int _t = 116;
const int _M = 77;
const int _S = 83;

const int _PROTOCOL_VERSION = 196608;

const int _AUTH_TYPE_MD5 = 5;
const int _AUTH_TYPE_OK = 0;

// Messages sent by client (Frontend).
const int _MSG_STARTUP = -1; // Fake message type as StartupMessage has no type in the header.
const int _MSG_PASSWORD = 112; // 'p'
const int _MSG_QUERY = 81; // 'Q'
const int _MSG_TERMINATE = 88; // 'X'

// Message types sent by the server.
const int _MSG_AUTH_REQUEST = 82; //'R'.charCodeAt(0);
const int _MSG_ERROR_RESPONSE = 69; //'E'.charCodeAt(0);
const int _MSG_BACKEND_KEY_DATA = 75; //'K'.charCodeAt(0);
const int _MSG_PARAMETER_STATUS = 83; //'S'.charCodeAt(0);
const int _MSG_NOTICE_RESPONSE = 78; //'N'.charCodeAt(0);
const int _MSG_NOTIFICATION_RESPONSE = 65; //'A'.charCodeAt(0);
const int _MSG_BIND = 66; //'B'.charCodeAt(0);
const int _MSG_BIND_COMPLETE = 50; //'2'.charCodeAt(0);
const int _MSG_CLOSE_COMPLETE = 51; //'3'.charCodeAt(0);
const int _MSG_COMMAND_COMPLETE = 67; //'C'.charCodeAt(0);
const int _MSG_COPY_DATA = 100; //'d'.charCodeAt(0);
const int _MSG_COPY_DONE = 99; //'c'.charCodeAt(0);
const int _MSG_COPY_IN_RESPONSE = 71; //'G'.charCodeAt(0);
const int _MSG_COPY_OUT_RESPONSE = 72; //'H'.charCodeAt(0);
const int _MSG_COPY_BOTH_RESPONSE = 87; //'W'.charCodeAt(0);
const int _MSG_DATA_ROW = 68; //'D'.charCodeAt(0);
const int _MSG_EMPTY_QUERY_REPONSE = 73; //'I'.charCodeAt(0);
const int _MSG_FUNCTION_CALL_RESPONSE = 86; //'V'.charCodeAt(0);
const int _MSG_NO_DATA = 110; //'n'.charCodeAt(0);
const int _MSG_PARAMETER_DESCRIPTION = 116; //'t'.charCodeAt(0);
const int _MSG_PARSE_COMPLETE = 49; //'1'.charCodeAt(0);
const int _MSG_PORTAL_SUSPENDED = 115; //'s'.charCodeAt(0);
const int _MSG_READY_FOR_QUERY = 90; //'Z'.charCodeAt(0);
const int _MSG_ROW_DESCRIPTION = 84; //'T'.charCodeAt(0);

String _itoa(int c) {
  try {
    return new String.fromCharCodes([c]);
  } catch (ex) {
    return 'Invalid';
  }
}

String _authTypeAsString(int authType) {
  const unknown = 'Unknown';
  const names = const <String> ['Authentication OK',
                                unknown,
                                'Kerberos v5',
                                'cleartext password',
                                unknown,
                                'MD5 password',
                                'SCM credentials',
                                'GSSAPI',
                                'GSSAPI or SSPI authentication data',
                                'SSPI'];
  var type = unknown;
  if (authType > 0 && authType < names.length)
    type = names[authType];
  return type;
}

/// Constants for postgresql datatypes
const int _PG_BOOL = 16;
const int _PG_BYTEA = 17;
const int _PG_CHAR = 18;
const int _PG_INT8 = 20;
const int _PG_INT2 = 21;
const int _PG_INT4 = 23;
const int _PG_TEXT = 25;
const int _PG_FLOAT4 = 700;
const int _PG_FLOAT8 = 701;
const int _PG_INTERVAL = 704;
const int _PG_UNKNOWN = 705;
const int _PG_MONEY = 790;
const int _PG_VARCHAR = 1043;
const int _PG_DATE = 1082;
const int _PG_TIME = 1083;
const int _PG_TIMESTAMP = 1114;
const int _PG_TIMESTAMPZ = 1184;
const int _PG_TIMETZ = 1266;
const int _PG_NUMERIC = 1700;
const int _PG_JSON = 114;
const int _PG_JSONB = 3802;
