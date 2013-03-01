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
//const int _BUSY = 6; //FIXME
//const int _STREAMING = 7; //FIXME
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




// Taken from:
// https://github.com/bmizerany/pq/blob/master/types.go

const int t_bool = 16;
const int t_bytea = 17;
const int t_char = 18;
//const int t_name = 19;
const int t_int8 = 20;
const int t_int2 = 21;
//const int t_int2vector = 22;
const int t_int4 = 23;
//const int t_regproc = 24;
const int t_text = 25;
const int t_oid = 26;
const int t_tid = 27;
const int t_xid = 28;
const int t_cid = 29;
//const int t_oidvector = 30;
//const int t_pg_type = 71;
//const int t_pg_attribute = 75;
//const int t_pg_proc = 81;
//const int t_pg_class = 83;
//const int t_xml = 142;
//const int t__xml = 143;
//const int t_pg_node_tree = 194;
//const int t_smgr = 210;
//const int t_point = 600;
//const int t_lseg = 601;
//const int t_path = 602;
//const int t_box = 603;
//const int t_polygon = 604;
//const int t_line = 628;
//const int t__line = 629;
const int t_float4 = 700;
const int t_float8 = 701;
const int t_abstime = 702;
const int t_reltime = 703;
const int t_tinterval = 704;
const int t_unknown = 705;
//const int t_circle = 718;
//const int t__circle = 719;
//const int t_money = 790;
//const int t__money = 791;
//const int t_macaddr = 829;
//const int t_inet = 869;
//const int t_cidr = 650;
const int t__bool = 1000;
const int t__bytea = 1001;
const int t__char = 1002;
//const int t__name = 1003;
const int t__int2 = 1005;
//const int t__int2vector = 1006;
const int t__int4 = 1007;
//const int t__regproc = 1008;
const int t__text = 1009;
const int t__oid = 1028;
const int t__tid = 1010;
const int t__xid = 1011;
const int t__cid = 1012;
//const int t__oidvector = 1013;
//const int t__bpchar = 1014;
const int t__varchar = 1015;
const int t__int8 = 1016;
//const int t__point = 1017;
//const int t__lseg = 1018;
//const int t__path = 1019;
//const int t__box = 1020;
const int t__float4 = 1021;
const int t__float8 = 1022;
const int t__abstime = 1023;
const int t__reltime = 1024;
const int t__tinterval = 1025;
//const int t__polygon = 1027;
//const int t_aclitem = 1033;
//const int t__aclitem = 1034;
//const int t__macaddr = 1040;
//const int t__inet = 1041;
//const int t__cidr = 651;
//const int t__cstring = 1263;
//const int t_bpchar = 1042;
const int t_varchar = 1043;
const int t_date = 1082;
const int t_time = 1083;
const int t_timestamp = 1114;
const int t__timestamp = 1115;
const int t__date = 1182;
const int t__time = 1183;
const int t_timestamptz = 1184;
const int t__timestamptz = 1185;
const int t_interval = 1186;
const int t__interval = 1187;
const int t__numeric = 1231;
const int t_timetz = 1266;
const int t__timetz = 1270;
const int t_bit = 1560;
const int t__bit = 1561;
const int t_varbit = 1562;
const int t__varbit = 1563;
const int t_numeric = 1700;
//const int t_refcursor = 1790;
//const int t__refcursor = 2201;
//const int t_regprocedure = 2202;
//const int t_regoper = 2203;
//const int t_regoperator = 2204;
//const int t_regclass = 2205;
//const int t_regtype = 2206;
//const int t__regprocedure = 2207;
//const int t__regoper = 2208;
//const int t__regoperator = 2209;
//const int t__regclass = 2210;
//const int t__regtype = 2211;
//const int t_uuid = 2950;
//const int t__uuid = 2951;
//const int t_tsvector = 3614;
//const int t_gtsvector = 3642;
//const int t_tsquery = 3615;
//const int t_regconfig = 3734;
//const int t_regdictionary = 3769;
//const int t__tsvector = 3643;
//const int t__gtsvector = 3644;
//const int t__tsquery = 3645;
//const int t__regconfig = 3735;
//const int t__regdictionary = 3770;
//const int t_txid_snapshot = 2970;
//const int t__txid_snapshot = 2949;
//const int t_record = 2249;
//const int t__record = 2287;
//const int t_cstring = 2275;
const int t_any = 2276;
//const int t_anyarray = 2277;
const int t_void = 2278;
//const int t_trigger = 2279;
//const int t_language_handler = 2280;
//const int t_internal = 2281;
//const int t_opaque = 2282;
//const int t_anyelement = 2283;
//const int t_anynonarray = 2776;
//const int t_anyenum = 3500;
//const int t_fdw_handler = 3115;
//const int t_pg_attrdef = 10000;
//const int t_pg_constraint = 10001;
//const int t_pg_inherits = 10002;
//const int t_pg_index = 10003;
//const int t_pg_operator = 10004;
//const int t_pg_opfamily = 10005;
//const int t_pg_opclass = 10006;
//const int t_pg_am = 10117;
//const int t_pg_amop = 10118;
//const int t_pg_amproc = 10478;
//const int t_pg_language = 10731;
//const int t_pg_largeobject_metadata = 10732;
//const int t_pg_largeobject = 10733;
//const int t_pg_aggregate = 10734;
//const int t_pg_statistic = 10735;
//const int t_pg_rewrite = 10736;
//const int t_pg_trigger = 10737;
//const int t_pg_description = 10738;
//const int t_pg_cast = 10739;
//const int t_pg_enum = 10936;
//const int t_pg_namespace = 10937;
//const int t_pg_conversion = 10938;
//const int t_pg_depend = 10939;
//const int t_pg_database = 1248;
//const int t_pg_db_role_setting = 10940;
//const int t_pg_tablespace = 10941;
//const int t_pg_pltemplate = 10942;
//const int t_pg_authid = 2842;
//const int t_pg_auth_members = 2843;
//const int t_pg_shdepend = 10943;
//const int t_pg_shdescription = 10944;
//const int t_pg_ts_config = 10945;
//const int t_pg_ts_config_map = 10946;
//const int t_pg_ts_dict = 10947;
//const int t_pg_ts_parser = 10948;
//const int t_pg_ts_template = 10949;
//const int t_pg_extension = 10950;
//const int t_pg_foreign_data_wrapper = 10951;
//const int t_pg_foreign_server = 10952;
//const int t_pg_user_mapping = 10953;
//const int t_pg_foreign_table = 10954;
//const int t_pg_default_acl = 10955;
//const int t_pg_seclabel = 10956;
//const int t_pg_collation = 10957;
//const int t_pg_toast_2604 = 10958;
//const int t_pg_toast_2606 = 10959;
//const int t_pg_toast_2609 = 10960;
//const int t_pg_toast_1255 = 10961;
//const int t_pg_toast_2618 = 10962;
//const int t_pg_toast_3596 = 10963;
//const int t_pg_toast_2619 = 10964;
//const int t_pg_toast_2620 = 10965;
//const int t_pg_toast_1262 = 10966;
//const int t_pg_toast_2396 = 10967;
//const int t_pg_toast_2964 = 10968;
//const int t_pg_roles = 10970;
//const int t_pg_shadow = 10973;
//const int t_pg_group = 10976;
//const int t_pg_user = 10979;
//const int t_pg_rules = 10982;
//const int t_pg_views = 10986;
//const int t_pg_tables = 10989;
//const int t_pg_indexes = 10993;
//const int t_pg_stats = 10997;
//const int t_pg_locks = 11001;
//const int t_pg_cursors = 11004;
//const int t_pg_available_extensions = 11007;
//const int t_pg_available_extension_versions = 11010;
//const int t_pg_prepared_xacts = 11013;
//const int t_pg_prepared_statements = 11017;
//const int t_pg_seclabels = 11020;
//const int t_pg_settings = 11024;
//const int t_pg_timezone_abbrevs = 11029;
//const int t_pg_timezone_names = 11032;
//const int t_pg_stat_all_tables = 11035;
//const int t_pg_stat_xact_all_tables = 11039;
//const int t_pg_stat_sys_tables = 11043;
//const int t_pg_stat_xact_sys_tables = 11047;
//const int t_pg_stat_user_tables = 11050;
//const int t_pg_stat_xact_user_tables = 11054;
//const int t_pg_statio_all_tables = 11057;
//const int t_pg_statio_sys_tables = 11061;
//const int t_pg_statio_user_tables = 11064;
//const int t_pg_stat_all_indexes = 11067;
//const int t_pg_stat_sys_indexes = 11071;
//const int t_pg_stat_user_indexes = 11074;
//const int t_pg_statio_all_indexes = 11077;
//const int t_pg_statio_sys_indexes = 11081;
//const int t_pg_statio_user_indexes = 11084;
//const int t_pg_statio_all_sequences = 11087;
//const int t_pg_statio_sys_sequences = 11090;
//const int t_pg_statio_user_sequences = 11093;
//const int t_pg_stat_activity = 11096;
//const int t_pg_stat_replication = 11099;
//const int t_pg_stat_database = 11102;
//const int t_pg_stat_database_conflicts = 11105;
//const int t_pg_stat_user_functions = 11108;
//const int t_pg_stat_xact_user_functions = 11112;
//const int t_pg_stat_bgwriter = 11116;
//const int t_pg_user_mappings = 11119;
//const int t_cardinal_number = 11669;
//const int t_character_data = 11671;
//const int t_sql_identifier = 11672;
//const int t_information_schema_catalog_name = 11674;
//const int t_time_stamp = 11676;
//const int t_yes_or_no = 11677;
//const int t_applicable_roles = 11680;
//const int t_administrable_role_authorizations = 11684;
//const int t_attributes = 11687;
//const int t_character_sets = 11691;
//const int t_check_constraint_routine_usage = 11695;
//const int t_check_constraints = 11699;
//const int t_collations = 11703;
//const int t_collation_character_set_applicability = 11706;
//const int t_column_domain_usage = 11709;
//const int t_column_privileges = 11713;
//const int t_column_udt_usage = 11717;
//const int t_columns = 11721;
//const int t_constraint_column_usage = 11725;
//const int t_constraint_table_usage = 11729;
//const int t_domain_constraints = 11733;
//const int t_domain_udt_usage = 11737;
//const int t_domains = 11740;
//const int t_enabled_roles = 11744;
//const int t_key_column_usage = 11747;
//const int t_parameters = 11751;
//const int t_referential_constraints = 11755;
//const int t_role_column_grants = 11759;
//const int t_routine_privileges = 11762;
//const int t_role_routine_grants = 11766;
//const int t_routines = 11769;
//const int t_schemata = 11773;
//const int t_sequences = 11776;
//const int t_sql_features = 11780;
//const int t_pg_toast_11779 = 11782;
//const int t_sql_implementation_info = 11785;
//const int t_pg_toast_11784 = 11787;
//const int t_sql_languages = 11790;
//const int t_pg_toast_11789 = 11792;
//const int t_sql_packages = 11795;
//const int t_pg_toast_11794 = 11797;
//const int t_sql_parts = 11800;
//const int t_pg_toast_11799 = 11802;
//const int t_sql_sizing = 11805;
//const int t_pg_toast_11804 = 11807;
//const int t_sql_sizing_profiles = 11810;
//const int t_pg_toast_11809 = 11812;
//const int t_table_constraints = 11815;
//const int t_table_privileges = 11819;
//const int t_role_table_grants = 11823;
//const int t_tables = 11826;
//const int t_triggered_update_columns = 11830;
//const int t_triggers = 11834;
//const int t_usage_privileges = 11838;
//const int t_role_usage_grants = 11842;
//const int t_view_column_usage = 11845;
//const int t_view_routine_usage = 11849;
//const int t_view_table_usage = 11853;
//const int t_views = 11857;
//const int t_data_type_privileges = 11861;
//const int t_element_types = 11865;
//const int t__pg_foreign_data_wrappers = 11869;
//const int t_foreign_data_wrapper_options = 11872;
//const int t_foreign_data_wrappers = 11875;
//const int t__pg_foreign_servers = 11878;
//const int t_foreign_server_options = 11882;
//const int t_foreign_servers = 11885;
//const int t__pg_foreign_tables = 11888;
//const int t_foreign_table_options = 11892;
//const int t_foreign_tables = 11895;
//const int t__pg_user_mappings = 11898;
//const int t_user_mapping_options = 11901;
//const int t_user_mappings = 11905;
//const int t_t = 16806;
//const int t__t = 16805;
//const int t_temp = 16810;
//const int t__temp = 16809;

String _pgTypeToString(int pgType) {
  switch(pgType) {
    case 16: return 't_bool';
    case 17: return 't_bytea';
    case 18: return 't_char';
    case 19: return 't_name';
    case 20: return 't_int8';
    case 21: return 't_int2';
    case 22: return 't_int2vector';
    case 23: return 't_int4';
    case 24: return 't_regproc';
    case 25: return 't_text';
    case 26: return 't_oid';
    case 27: return 't_tid';
    case 28: return 't_xid';
    case 29: return 't_cid';
    case 30: return 't_oidvector';
    case 71: return 't_pg_type';
    case 75: return 't_pg_attribute';
    case 81: return 't_pg_proc';
    case 83: return 't_pg_class';
    case 142: return 't_xml';
    case 143: return 't__xml';
    case 194: return 't_pg_node_tree';
    case 210: return 't_smgr';
    case 600: return 't_point';
    case 601: return 't_lseg';
    case 602: return 't_path';
    case 603: return 't_box';
    case 604: return 't_polygon';
    case 628: return 't_line';
    case 629: return 't__line';
    case 700: return 't_float4';
    case 701: return 't_float8';
    case 702: return 't_abstime';
    case 703: return 't_reltime';
    case 704: return 't_tinterval';
    case 705: return 't_unknown';
    case 718: return 't_circle';
    case 719: return 't__circle';
    case 790: return 't_money';
    case 791: return 't__money';
    case 829: return 't_macaddr';
    case 869: return 't_inet';
    case 650: return 't_cidr';
    case 1000: return 't__bool';
    case 1001: return 't__bytea';
    case 1002: return 't__char';
    case 1003: return 't__name';
    case 1005: return 't__int2';
    case 1006: return 't__int2vector';
    case 1007: return 't__int4';
    case 1008: return 't__regproc';
    case 1009: return 't__text';
    case 1028: return 't__oid';
    case 1010: return 't__tid';
    case 1011: return 't__xid';
    case 1012: return 't__cid';
    case 1013: return 't__oidvector';
    case 1014: return 't__bpchar';
    case 1015: return 't__varchar';
    case 1016: return 't__int8';
    case 1017: return 't__point';
    case 1018: return 't__lseg';
    case 1019: return 't__path';
    case 1020: return 't__box';
    case 1021: return 't__float4';
    case 1022: return 't__float8';
    case 1023: return 't__abstime';
    case 1024: return 't__reltime';
    case 1025: return 't__tinterval';
    case 1027: return 't__polygon';
    case 1033: return 't_aclitem';
    case 1034: return 't__aclitem';
    case 1040: return 't__macaddr';
    case 1041: return 't__inet';
    case 651: return 't__cidr';
    case 1263: return 't__cstring';
    case 1042: return 't_bpchar';
    case 1043: return 't_varchar';
    case 1082: return 't_date';
    case 1083: return 't_time';
    case 1114: return 't_timestamp';
    case 1115: return 't__timestamp';
    case 1182: return 't__date';
    case 1183: return 't__time';
    case 1184: return 't_timestamptz';
    case 1185: return 't__timestamptz';
    case 1186: return 't_interval';
    case 1187: return 't__interval';
    case 1231: return 't__numeric';
    case 1266: return 't_timetz';
    case 1270: return 't__timetz';
    case 1560: return 't_bit';
    case 1561: return 't__bit';
    case 1562: return 't_varbit';
    case 1563: return 't__varbit';
    case 1700: return 't_numeric';
    case 1790: return 't_refcursor';
    case 2201: return 't__refcursor';
    case 2202: return 't_regprocedure';
    case 2203: return 't_regoper';
    case 2204: return 't_regoperator';
    case 2205: return 't_regclass';
    case 2206: return 't_regtype';
    case 2207: return 't__regprocedure';
    case 2208: return 't__regoper';
    case 2209: return 't__regoperator';
    case 2210: return 't__regclass';
    case 2211: return 't__regtype';
    case 2950: return 't_uuid';
    case 2951: return 't__uuid';
    case 3614: return 't_tsvector';
    case 3642: return 't_gtsvector';
    case 3615: return 't_tsquery';
    case 3734: return 't_regconfig';
    case 3769: return 't_regdictionary';
    case 3643: return 't__tsvector';
    case 3644: return 't__gtsvector';
    case 3645: return 't__tsquery';
    case 3735: return 't__regconfig';
    case 3770: return 't__regdictionary';
    case 2970: return 't_txid_snapshot';
    case 2949: return 't__txid_snapshot';
    case 2249: return 't_record';
    case 2287: return 't__record';
    case 2275: return 't_cstring';
    case 2276: return 't_any';
    case 2277: return 't_anyarray';
    case 2278: return 't_void';
    case 2279: return 't_trigger';
    case 2280: return 't_language_handler';
    case 2281: return 't_internal';
    case 2282: return 't_opaque';
    case 2283: return 't_anyelement';
    case 2776: return 't_anynonarray';
    case 3500: return 't_anyenum';
    case 3115: return 't_fdw_handler';
    case 10000: return 't_pg_attrdef';
    case 10001: return 't_pg_constraint';
    case 10002: return 't_pg_inherits';
    case 10003: return 't_pg_index';
    case 10004: return 't_pg_operator';
    case 10005: return 't_pg_opfamily';
    case 10006: return 't_pg_opclass';
    case 10117: return 't_pg_am';
    case 10118: return 't_pg_amop';
    case 10478: return 't_pg_amproc';
    case 10731: return 't_pg_language';
    case 10732: return 't_pg_largeobject_metadata';
    case 10733: return 't_pg_largeobject';
    case 10734: return 't_pg_aggregate';
    case 10735: return 't_pg_statistic';
    case 10736: return 't_pg_rewrite';
    case 10737: return 't_pg_trigger';
    case 10738: return 't_pg_description';
    case 10739: return 't_pg_cast';
    case 10936: return 't_pg_enum';
    case 10937: return 't_pg_namespace';
    case 10938: return 't_pg_conversion';
    case 10939: return 't_pg_depend';
    case 1248: return 't_pg_database';
    case 10940: return 't_pg_db_role_setting';
    case 10941: return 't_pg_tablespace';
    case 10942: return 't_pg_pltemplate';
    case 2842: return 't_pg_authid';
    case 2843: return 't_pg_auth_members';
    case 10943: return 't_pg_shdepend';
    case 10944: return 't_pg_shdescription';
    case 10945: return 't_pg_ts_config';
    case 10946: return 't_pg_ts_config_map';
    case 10947: return 't_pg_ts_dict';
    case 10948: return 't_pg_ts_parser';
    case 10949: return 't_pg_ts_template';
    case 10950: return 't_pg_extension';
    case 10951: return 't_pg_foreign_data_wrapper';
    case 10952: return 't_pg_foreign_server';
    case 10953: return 't_pg_user_mapping';
    case 10954: return 't_pg_foreign_table';
    case 10955: return 't_pg_default_acl';
    case 10956: return 't_pg_seclabel';
    case 10957: return 't_pg_collation';
    case 10958: return 't_pg_toast_2604';
    case 10959: return 't_pg_toast_2606';
    case 10960: return 't_pg_toast_2609';
    case 10961: return 't_pg_toast_1255';
    case 10962: return 't_pg_toast_2618';
    case 10963: return 't_pg_toast_3596';
    case 10964: return 't_pg_toast_2619';
    case 10965: return 't_pg_toast_2620';
    case 10966: return 't_pg_toast_1262';
    case 10967: return 't_pg_toast_2396';
    case 10968: return 't_pg_toast_2964';
    case 10970: return 't_pg_roles';
    case 10973: return 't_pg_shadow';
    case 10976: return 't_pg_group';
    case 10979: return 't_pg_user';
    case 10982: return 't_pg_rules';
    case 10986: return 't_pg_views';
    case 10989: return 't_pg_tables';
    case 10993: return 't_pg_indexes';
    case 10997: return 't_pg_stats';
    case 11001: return 't_pg_locks';
    case 11004: return 't_pg_cursors';
    case 11007: return 't_pg_available_extensions';
    case 11010: return 't_pg_available_extension_versions';
    case 11013: return 't_pg_prepared_xacts';
    case 11017: return 't_pg_prepared_statements';
    case 11020: return 't_pg_seclabels';
    case 11024: return 't_pg_settings';
    case 11029: return 't_pg_timezone_abbrevs';
    case 11032: return 't_pg_timezone_names';
    case 11035: return 't_pg_stat_all_tables';
    case 11039: return 't_pg_stat_xact_all_tables';
    case 11043: return 't_pg_stat_sys_tables';
    case 11047: return 't_pg_stat_xact_sys_tables';
    case 11050: return 't_pg_stat_user_tables';
    case 11054: return 't_pg_stat_xact_user_tables';
    case 11057: return 't_pg_statio_all_tables';
    case 11061: return 't_pg_statio_sys_tables';
    case 11064: return 't_pg_statio_user_tables';
    case 11067: return 't_pg_stat_all_indexes';
    case 11071: return 't_pg_stat_sys_indexes';
    case 11074: return 't_pg_stat_user_indexes';
    case 11077: return 't_pg_statio_all_indexes';
    case 11081: return 't_pg_statio_sys_indexes';
    case 11084: return 't_pg_statio_user_indexes';
    case 11087: return 't_pg_statio_all_sequences';
    case 11090: return 't_pg_statio_sys_sequences';
    case 11093: return 't_pg_statio_user_sequences';
    case 11096: return 't_pg_stat_activity';
    case 11099: return 't_pg_stat_replication';
    case 11102: return 't_pg_stat_database';
    case 11105: return 't_pg_stat_database_conflicts';
    case 11108: return 't_pg_stat_user_functions';
    case 11112: return 't_pg_stat_xact_user_functions';
    case 11116: return 't_pg_stat_bgwriter';
    case 11119: return 't_pg_user_mappings';
    case 11669: return 't_cardinal_number';
    case 11671: return 't_character_data';
    case 11672: return 't_sql_identifier';
    case 11674: return 't_information_schema_catalog_name';
    case 11676: return 't_time_stamp';
    case 11677: return 't_yes_or_no';
    case 11680: return 't_applicable_roles';
    case 11684: return 't_administrable_role_authorizations';
    case 11687: return 't_attributes';
    case 11691: return 't_character_sets';
    case 11695: return 't_check_constraint_routine_usage';
    case 11699: return 't_check_constraints';
    case 11703: return 't_collations';
    case 11706: return 't_collation_character_set_applicability';
    case 11709: return 't_column_domain_usage';
    case 11713: return 't_column_privileges';
    case 11717: return 't_column_udt_usage';
    case 11721: return 't_columns';
    case 11725: return 't_constraint_column_usage';
    case 11729: return 't_constraint_table_usage';
    case 11733: return 't_domain_constraints';
    case 11737: return 't_domain_udt_usage';
    case 11740: return 't_domains';
    case 11744: return 't_enabled_roles';
    case 11747: return 't_key_column_usage';
    case 11751: return 't_parameters';
    case 11755: return 't_referential_constraints';
    case 11759: return 't_role_column_grants';
    case 11762: return 't_routine_privileges';
    case 11766: return 't_role_routine_grants';
    case 11769: return 't_routines';
    case 11773: return 't_schemata';
    case 11776: return 't_sequences';
    case 11780: return 't_sql_features';
    case 11782: return 't_pg_toast_11779';
    case 11785: return 't_sql_implementation_info';
    case 11787: return 't_pg_toast_11784';
    case 11790: return 't_sql_languages';
    case 11792: return 't_pg_toast_11789';
    case 11795: return 't_sql_packages';
    case 11797: return 't_pg_toast_11794';
    case 11800: return 't_sql_parts';
    case 11802: return 't_pg_toast_11799';
    case 11805: return 't_sql_sizing';
    case 11807: return 't_pg_toast_11804';
    case 11810: return 't_sql_sizing_profiles';
    case 11812: return 't_pg_toast_11809';
    case 11815: return 't_table_constraints';
    case 11819: return 't_table_privileges';
    case 11823: return 't_role_table_grants';
    case 11826: return 't_tables';
    case 11830: return 't_triggered_update_columns';
    case 11834: return 't_triggers';
    case 11838: return 't_usage_privileges';
    case 11842: return 't_role_usage_grants';
    case 11845: return 't_view_column_usage';
    case 11849: return 't_view_routine_usage';
    case 11853: return 't_view_table_usage';
    case 11857: return 't_views';
    case 11861: return 't_data_type_privileges';
    case 11865: return 't_element_types';
    case 11869: return 't__pg_foreign_data_wrappers';
    case 11872: return 't_foreign_data_wrapper_options';
    case 11875: return 't_foreign_data_wrappers';
    case 11878: return 't__pg_foreign_servers';
    case 11882: return 't_foreign_server_options';
    case 11885: return 't_foreign_servers';
    case 11888: return 't__pg_foreign_tables';
    case 11892: return 't_foreign_table_options';
    case 11895: return 't_foreign_tables';
    case 11898: return 't__pg_user_mappings';
    case 11901: return 't_user_mapping_options';
    case 11905: return 't_user_mappings';
    case 16806: return 't_t';
    case 16805: return 't__t';
    case 16810: return 't_temp';
    case 16809: return 't__temp';
    default:
      return 'Unknown pgType: $pgType';
   }
}