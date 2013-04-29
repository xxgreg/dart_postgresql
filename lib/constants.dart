part of postgresql;

const int _NOT_CONNECTED = 1;
const int _SOCKET_CONNECTED = 2;
const int _AUTHENTICATING = 3;
const int _AUTHENTICATED = 4;
const int _IDLE = 5;
const int _BUSY = 6;
const int _STREAMING = 7; // state is called "ready" in libpq. Doesn't make sense in a non-blocking impl. 
const int _CLOSED = 8;

String _stateToString(int s) {
  if (s < 0 || s > 8)
    return '?';
  return ['?', 'NOT_CONNECTED', 'SOCKET_CONNECTED', 'AUTHENTICATING', 'AUTHENTICATED', 'IDLE', 'BUSY', 'STREAMING', 'CLOSED'][s];
}

const int _QUEUED = 1;
//const int _BUSY = 6;
//const int _STREAMING = 7;
const int _DONE = 8;

String _queryStateToString(int s) {
  if (s < 0 || s > 8)
    return '?';
  return ['?', 'QUEUED', '?', '?', '?', '?', 'BUSY', 'STREAMING', 'DONE'][s];
}

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


//TODO Yuck - enums please. Must be a better way of doing consts.
String _messageName(int msg) {
  switch (msg) {
    case _MSG_AUTH_REQUEST: return 'AuthenticationRequest';
    case _MSG_ERROR_RESPONSE: return 'ErrorResponse';
    case _MSG_BACKEND_KEY_DATA: return 'BackendKeyData';
    case _MSG_PARAMETER_STATUS: return 'ParameterStatus';
    case _MSG_NOTICE_RESPONSE: return 'NoticeResponse';
    case _MSG_NOTIFICATION_RESPONSE: return 'NotificationResponse';
    case _MSG_BIND: return 'Bind';
    case _MSG_BIND_COMPLETE: return 'BindComplete';
    case _MSG_CLOSE_COMPLETE: return 'CloseComplete'; 
    case _MSG_COMMAND_COMPLETE: return 'CommandComplete'; 
    case _MSG_COPY_DATA: return 'CopyData';
    case _MSG_COPY_DONE: return 'CopyDone';
    case _MSG_COPY_IN_RESPONSE: return 'CopyInResponse';
    case _MSG_COPY_OUT_RESPONSE: return 'CopyOutResponse';
    case _MSG_COPY_BOTH_RESPONSE: return 'CopyBothResponse';
    case _MSG_DATA_ROW: return 'DataRow';
    case _MSG_EMPTY_QUERY_REPONSE: return 'EmptyQueryResponse';
    case _MSG_FUNCTION_CALL_RESPONSE: return 'FunctionCallResponse';
    case _MSG_NO_DATA: return 'NoData';
    case _MSG_PARAMETER_DESCRIPTION: return 'ParameterDescription';
    case _MSG_PARSE_COMPLETE: return 'ParseComplete';
    case _MSG_PORTAL_SUSPENDED: return 'PortalSuspended';
    case _MSG_READY_FOR_QUERY: return 'ReadyForQuery';
    case _MSG_ROW_DESCRIPTION: return 'RowDescription';
    default:
      return 'Unknown message type: ${_itoa(msg)} $msg.';
  }
}

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

String _pgTypeToString(int pgType) {
  switch(pgType) {
    case 16: return 'bool';
    case 17: return 'bytea';
    case 18: return 'char';
    case 19: return 'name';
    case 20: return 'int8';
    case 21: return 'int2';
    case 22: return 'int2vector';
    case 23: return 'int4';
    case 24: return 'regproc';
    case 25: return 'text';
    case 26: return 'oid';
    case 27: return 'tid';
    case 28: return 'xid';
    case 29: return 'cid';
    case 30: return 'oidvector';
    case 71: return 'pg_type';
    case 75: return 'pg_attribute';
    case 81: return 'pg_proc';
    case 83: return 'pg_class';
    case 142: return 'xml';
    case 143: return 'xml';
    case 194: return 'pg_node_tree';
    case 210: return 'smgr';
    case 600: return 'point';
    case 601: return 'lseg';
    case 602: return 'path';
    case 603: return 'box';
    case 604: return 'polygon';
    case 628: return 'line';
    case 629: return 'line';
    case 700: return 'float4';
    case 701: return 'float8';
    case 702: return 'abstime';
    case 703: return 'reltime';
    case 704: return 'tinterval';
    case 705: return 'unknown';
    case 718: return 'circle';
    case 719: return 'circle';
    case 790: return 'money';
    case 791: return 'money';
    case 829: return 'macaddr';
    case 869: return 'inet';
    case 650: return 'cidr';
    case 1000: return 'bool';
    case 1001: return 'bytea';
    case 1002: return 'char';
    case 1003: return 'name';
    case 1005: return 'int2';
    case 1006: return 'int2vector';
    case 1007: return 'int4';
    case 1008: return 'regproc';
    case 1009: return 'text';
    case 1028: return 'oid';
    case 1010: return 'tid';
    case 1011: return 'xid';
    case 1012: return 'cid';
    case 1013: return 'oidvector';
    case 1014: return 'bpchar';
    case 1015: return 'varchar';
    case 1016: return 'int8';
    case 1017: return 'point';
    case 1018: return 'lseg';
    case 1019: return 'path';
    case 1020: return 'box';
    case 1021: return 'float4';
    case 1022: return 'float8';
    case 1023: return 'abstime';
    case 1024: return 'reltime';
    case 1025: return 'tinterval';
    case 1027: return 'polygon';
    case 1033: return 'aclitem';
    case 1034: return 'aclitem';
    case 1040: return 'macaddr';
    case 1041: return 'inet';
    case 651: return 'cidr';
    case 1263: return 'cstring';
    case 1042: return 'bpchar';
    case 1043: return 'varchar';
    case 1082: return 'date';
    case 1083: return 'time';
    case 1114: return 'timestamp';
    case 1115: return 'timestamp';
    case 1182: return 'date';
    case 1183: return 'time';
    case 1184: return 'timestamptz';
    case 1185: return 'timestamptz';
    case 1186: return 'interval';
    case 1187: return 'interval';
    case 1231: return 'numeric';
    case 1266: return 'timetz';
    case 1270: return 'timetz';
    case 1560: return 'bit';
    case 1561: return 'bit';
    case 1562: return 'varbit';
    case 1563: return 'varbit';
    case 1700: return 'numeric';
    case 1790: return 'refcursor';
    case 2201: return 'refcursor';
    case 2202: return 'regprocedure';
    case 2203: return 'regoper';
    case 2204: return 'regoperator';
    case 2205: return 'regclass';
    case 2206: return 'regtype';
    case 2207: return 'regprocedure';
    case 2208: return 'regoper';
    case 2209: return 'regoperator';
    case 2210: return 'regclass';
    case 2211: return 'regtype';
    case 2950: return 'uuid';
    case 2951: return 'uuid';
    case 3614: return 'tsvector';
    case 3642: return 'gtsvector';
    case 3615: return 'tsquery';
    case 3734: return 'regconfig';
    case 3769: return 'regdictionary';
    case 3643: return 'tsvector';
    case 3644: return 'gtsvector';
    case 3645: return 'tsquery';
    case 3735: return 'regconfig';
    case 3770: return 'regdictionary';
    case 2970: return 'txid_snapshot';
    case 2949: return 'txid_snapshot';
    case 2249: return 'record';
    case 2287: return 'record';
    case 2275: return 'cstring';
    case 2276: return 'any';
    case 2277: return 'anyarray';
    case 2278: return 'void';
    case 2279: return 'trigger';
    case 2280: return 'language_handler';
    case 2281: return 'internal';
    case 2282: return 'opaque';
    case 2283: return 'anyelement';
    case 2776: return 'anynonarray';
    case 3500: return 'anyenum';
    case 3115: return 'fdw_handler';
    case 10000: return 'pg_attrdef';
    case 10001: return 'pg_constraint';
    case 10002: return 'pg_inherits';
    case 10003: return 'pg_index';
    case 10004: return 'pg_operator';
    case 10005: return 'pg_opfamily';
    case 10006: return 'pg_opclass';
    case 10117: return 'pg_am';
    case 10118: return 'pg_amop';
    case 10478: return 'pg_amproc';
    case 10731: return 'pg_language';
    case 10732: return 'pg_largeobject_metadata';
    case 10733: return 'pg_largeobject';
    case 10734: return 'pg_aggregate';
    case 10735: return 'pg_statistic';
    case 10736: return 'pg_rewrite';
    case 10737: return 'pg_trigger';
    case 10738: return 'pg_description';
    case 10739: return 'pg_cast';
    case 10936: return 'pg_enum';
    case 10937: return 'pg_namespace';
    case 10938: return 'pg_conversion';
    case 10939: return 'pg_depend';
    case 1248: return 'pg_database';
    case 10940: return 'pg_db_role_setting';
    case 10941: return 'pg_tablespace';
    case 10942: return 'pg_pltemplate';
    case 2842: return 'pg_authid';
    case 2843: return 'pg_auth_members';
    case 10943: return 'pg_shdepend';
    case 10944: return 'pg_shdescription';
    case 10945: return 'pg_ts_config';
    case 10946: return 'pg_ts_config_map';
    case 10947: return 'pg_ts_dict';
    case 10948: return 'pg_ts_parser';
    case 10949: return 'pg_ts_template';
    case 10950: return 'pg_extension';
    case 10951: return 'pg_foreign_data_wrapper';
    case 10952: return 'pg_foreign_server';
    case 10953: return 'pg_user_mapping';
    case 10954: return 'pg_foreign_table';
    case 10955: return 'pg_default_acl';
    case 10956: return 'pg_seclabel';
    case 10957: return 'pg_collation';
    case 10958: return 'pg_toast_2604';
    case 10959: return 'pg_toast_2606';
    case 10960: return 'pg_toast_2609';
    case 10961: return 'pg_toast_1255';
    case 10962: return 'pg_toast_2618';
    case 10963: return 'pg_toast_3596';
    case 10964: return 'pg_toast_2619';
    case 10965: return 'pg_toast_2620';
    case 10966: return 'pg_toast_1262';
    case 10967: return 'pg_toast_2396';
    case 10968: return 'pg_toast_2964';
    case 10970: return 'pg_roles';
    case 10973: return 'pg_shadow';
    case 10976: return 'pg_group';
    case 10979: return 'pg_user';
    case 10982: return 'pg_rules';
    case 10986: return 'pg_views';
    case 10989: return 'pg_tables';
    case 10993: return 'pg_indexes';
    case 10997: return 'pg_stats';
    case 11001: return 'pg_locks';
    case 11004: return 'pg_cursors';
    case 11007: return 'pg_available_extensions';
    case 11010: return 'pg_available_extension_versions';
    case 11013: return 'pg_prepared_xacts';
    case 11017: return 'pg_prepared_statements';
    case 11020: return 'pg_seclabels';
    case 11024: return 'pg_settings';
    case 11029: return 'pg_timezone_abbrevs';
    case 11032: return 'pg_timezone_names';
    case 11035: return 'pg_stat_all_tables';
    case 11039: return 'pg_stat_xact_all_tables';
    case 11043: return 'pg_stat_sys_tables';
    case 11047: return 'pg_stat_xact_sys_tables';
    case 11050: return 'pg_stat_user_tables';
    case 11054: return 'pg_stat_xact_user_tables';
    case 11057: return 'pg_statio_all_tables';
    case 11061: return 'pg_statio_sys_tables';
    case 11064: return 'pg_statio_user_tables';
    case 11067: return 'pg_stat_all_indexes';
    case 11071: return 'pg_stat_sys_indexes';
    case 11074: return 'pg_stat_user_indexes';
    case 11077: return 'pg_statio_all_indexes';
    case 11081: return 'pg_statio_sys_indexes';
    case 11084: return 'pg_statio_user_indexes';
    case 11087: return 'pg_statio_all_sequences';
    case 11090: return 'pg_statio_sys_sequences';
    case 11093: return 'pg_statio_user_sequences';
    case 11096: return 'pg_stat_activity';
    case 11099: return 'pg_stat_replication';
    case 11102: return 'pg_stat_database';
    case 11105: return 'pg_stat_database_conflicts';
    case 11108: return 'pg_stat_user_functions';
    case 11112: return 'pg_stat_xact_user_functions';
    case 11116: return 'pg_stat_bgwriter';
    case 11119: return 'pg_user_mappings';
    case 11669: return 'cardinal_number';
    case 11671: return 'character_data';
    case 11672: return 'sql_identifier';
    case 11674: return 'information_schema_catalog_name';
    case 11676: return 'time_stamp';
    case 11677: return 'yes_or_no';
    case 11680: return 'applicable_roles';
    case 11684: return 'administrable_role_authorizations';
    case 11687: return 'attributes';
    case 11691: return 'character_sets';
    case 11695: return 'check_constraint_routine_usage';
    case 11699: return 'check_constraints';
    case 11703: return 'collations';
    case 11706: return 'collation_character_set_applicability';
    case 11709: return 'column_domain_usage';
    case 11713: return 'column_privileges';
    case 11717: return 'column_udt_usage';
    case 11721: return 'columns';
    case 11725: return 'constraint_column_usage';
    case 11729: return 'constraint_table_usage';
    case 11733: return 'domain_constraints';
    case 11737: return 'domain_udt_usage';
    case 11740: return 'domains';
    case 11744: return 'enabled_roles';
    case 11747: return 'key_column_usage';
    case 11751: return 'parameters';
    case 11755: return 'referential_constraints';
    case 11759: return 'role_column_grants';
    case 11762: return 'routine_privileges';
    case 11766: return 'role_routine_grants';
    case 11769: return 'routines';
    case 11773: return 'schemata';
    case 11776: return 'sequences';
    case 11780: return 'sql_features';
    case 11782: return 'pg_toast_11779';
    case 11785: return 'sql_implementation_info';
    case 11787: return 'pg_toast_11784';
    case 11790: return 'sql_languages';
    case 11792: return 'pg_toast_11789';
    case 11795: return 'sql_packages';
    case 11797: return 'pg_toast_11794';
    case 11800: return 'sql_parts';
    case 11802: return 'pg_toast_11799';
    case 11805: return 'sql_sizing';
    case 11807: return 'pg_toast_11804';
    case 11810: return 'sql_sizing_profiles';
    case 11812: return 'pg_toast_11809';
    case 11815: return 'table_constraints';
    case 11819: return 'table_privileges';
    case 11823: return 'role_table_grants';
    case 11826: return 'tables';
    case 11830: return 'triggered_update_columns';
    case 11834: return 'triggers';
    case 11838: return 'usage_privileges';
    case 11842: return 'role_usage_grants';
    case 11845: return 'view_column_usage';
    case 11849: return 'view_routine_usage';
    case 11853: return 'view_table_usage';
    case 11857: return 'views';
    case 11861: return 'data_type_privileges';
    case 11865: return 'element_types';
    case 11869: return 'pg_foreign_data_wrappers';
    case 11872: return 'foreign_data_wrapper_options';
    case 11875: return 'foreign_data_wrappers';
    case 11878: return 'pg_foreign_servers';
    case 11882: return 'foreign_server_options';
    case 11885: return 'foreign_servers';
    case 11888: return 'pg_foreign_tables';
    case 11892: return 'foreign_table_options';
    case 11895: return 'foreign_tables';
    case 11898: return 'pg_user_mappings';
    case 11901: return 'user_mapping_options';
    case 11905: return 'user_mappings';
    case 16806: return 't';
    case 16805: return 't';
    case 16810: return 'temp';
    case 16809: return 'temp';
    default:
      return 'Unknown pgType: $pgType';
   }
}