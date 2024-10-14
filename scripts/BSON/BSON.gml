// Saving and loading binary "JSON" files.  To avoid conflict with actual BSON specification, this
// is actually a unique approach that writes a binary buffer to a file without relying on JSON stringify, 
// which may return an empty string in corner cases.

// If you are relying on JSON, and you do something like json_stringify, it may result in a 0 byte
// error.

// You should be made aware that there is support for automatic backups of files, and you can
// turn that on with an option.

// This is useful for storing things like maps, save game data, etc.  The restriction is that
// you cannot use JSON that contains methods or data loops via pointers.  These used to be referred
// to as "static structs" and/or "plain old data" (POD) ... meaning the JSON can contain nodes
// that are:  int, decimal, struct, string, array

// There is some support for a special kind of array that is "mono", meaning that it has a
// repeating struct that is always of the same keywords (it may contain sub-structures but no optimization
// is made)

// There is support for buffer compression.

//Generally, a buffer is set up the following way:
//BSONGML   a string header indicating the file type
//<one array, one struct, or a single value, for struct containing some number of sub structures, for array some number of elements>
//EOFBSONGML a string footer indicating the intended end of the file has been reached

// This is the maximum depth limiter for reads and writes.  Increase if needed.  This refers to how many levels of reference
// you will allow.  For example one[0].two.three.four[6].five.six.seven ... is probably enough??  This avoids infinite loops.

#macro BSON_MAX_DEPTH 16

// How to use:

// BSONWrite(data, filename, compress=true, nobackup=true, multibackup=false, clear_existing=false, support_u64=false, support_realint=false, assume_hetero=false )
// write a "BSONGML" file
// parameters:
// "data" - any array, int, decimal (real), boolean, string or struct value, as long as the struct is simple and does not contain pointers or methods
// "filename" - a valid filename / filepath
// "compress" - when true, will use buffer_compress
// "nobackup" - when false, will copy the existing file to a ".bak" or multibackup behavior
// "multibackup" - when true, will maintain a growing number of backup files, use with caution, good for editors
// "clear_existing" - when true, will delete target file before writing it, after any backups, though in either case the file will be overwritten
// *"support_u64" - when true, support the int64 datatype automagically
// "support_realint" - when true, attempt to convert reals to int32 when possible
// "assume_hetero" - when true, assume all arrays are heterogynously typed
// returns: struct { error: <a numeric code indicating error, or 0 for success>, other data about issue }

// Caveats:
// - You cannot pass in a looping structure, for instance one that contains pointers to itself or
//   to any data within itself that is not unique.  Ie A contains B which contains a pointer to A,
//   as this will create an infinite loop.
// - You shouldn't pass in a structure that contains methods, and the methods will not be saved,
//   and the keywords associated with the methods will be saved, which may not be ideal,
//   so it is not recommended that you pass in complex objects with methods.  Instead, you should
//   write your own pre and post parser that converts the methods into a meaningful integer or string.
// - Pointers are not supported and are treated as the same as methods, so ignored.
// - NaN and Infinity are not supported explicitly. This means they may create undefined or undesired
//   behavior if your data contains this.  These values are sometimes returned by functions that are
//   handling mathematical operations, or in other scenarios, so you need to "police" for these
//   values in your data.  They are not checked for.
// - For some reason, GameMaker does not support signed 64-bit integers, so in writing integers,
//   int32 is used instead, unless you turn on support for int64, which is an unsigned value.
// - The value of -4 is used to indicate "none" or "noone" or "null"
// *"support_u64" - when true, support the int64 datatype automagically
// "support_realint" - when true, attempt to convert reals to int32 when possible
// "assume_hetero" - when true, assume all arrays are heterogynously typed

// BSONRead(filename, compress=true, support_u64=false, support_realint=false, assume_hetero=false )
// returns: struct { data: <data content>, error: <numeric code or 0 for success>, other data if issue }

// "support_u64" was an attempt to support int64() as a readable type, but I was unable to determine why
// it caused the comparison to fail in a false negative, so I've turned the feature off and I don't
// recommend using it.  It's really only important for certain session key information for STEAM,
// and a few other places.  Write your own support if you need that.

// Maps to the GML file_bin options.  I ended up not using these but left them here.

#macro BSON_file_r 0
#macro BSON_file_w 1
#macro BSON_file_rw 2

// Simply copies a file.
function BSONCopyFile( filenamea, filenameb ) {
	return file_copy(filenamea, filenameb);
}


// Checks as best we can if a file _can_ exist (by creating a test file if it doesn't already exist).
function BSONFileCanExist(filename) {
	if ( not ( os_browser == browser_not_a_browser ) ) return true;
	if ( file_exists(filename) ) return true;
	var _buffer = buffer_create(string_byte_length("TEST") + 1, buffer_fixed, 1);
	buffer_seek(_buffer,buffer_seek_start,0);
	buffer_write(_buffer, buffer_string, "TEST");
	buffer_save(_buffer, filename);
	buffer_delete(_buffer);
	var result = file_exists(filename);
	file_delete(filename);
	return result;
}


// Valid node types
#macro BSON_type_int32 0 // a 32-bit int, usually used in graphics files
#macro BSON_type_int64 1 // "an int" or a real that is an int
#macro BSON_type_decimal 2 // aka a "real"
#macro BSON_type_string 3 // a null-terminated string
#macro BSON_type_bool 4 // a boolean value of true or false, which is also an int
#macro BSON_type_struct 5 // a structure / data-only object
#macro BSON_type_array 6 // an array of values
#macro BSON_type_unsupported 8 // a method, or a pointer
function BSONGetType(data, support_u64=false, support_realint=false) {
	if ( is_struct(data) ) {
		return BSON_type_struct;
	} else if ( is_string(data) ) {
		return BSON_type_string;
	} else if ( is_array(data) ) {
		return BSON_type_array;
	} else if ( is_bool(data) ) {
		return BSON_type_bool;
	} else if ( is_int32(data) ) {
		return BSON_type_int32;
	} else if ( is_int64(data) ) {
		if ( support_u64 ) return BSON_type_int64;
		else return BSON_type_int32;
	} else if ( support_realint and BSONis_realint(data) ) {
		if ( support_u64 ) return BSON_type_int64;
		else return BSON_type_int32;
	} else if ( is_real(data) ) {
		return BSON_type_decimal;
	}
	return BSON_type_unsupported;
}

function BSONGetStructInfo( data, support_u64=false, support_realint=false ) {
	if ( !is_struct(data) ) return false;
	var keys = variable_struct_get_names(data);
	var s={};
	var klen=array_length(keys);
	for ( var i=0; i<klen; i++ ) {
		variable_struct_set(s,keys[i],BSONGetType(variable_struct_get(data,keys[i]),support_u64,support_realint));
	}
	return { template: s, keys: keys, klen: klen };
}

function BSONCompareStructInfo( structinfoa, structinfob ) {
	if ( !is_struct(structinfoa) || !is_struct(structinfob) ) return false;
	if ( !variable_struct_exists(structinfoa,"klen") || !variable_struct_exists(structinfob,"klen") ) {
	  show_error("Programmer error, BSONCompareStructInfo should never compare non-structinfos",true);
	  return false;
    }
	if ( structinfoa.klen != structinfob.klen ) return false;
	for ( var i=0; i<structinfoa.klen; i++ ) {
		if ( structinfoa.keys[i] != structinfob.keys[i] ) return false;
	}
	return true;
}

// Array types are used for optimizing the saving and loading of arrays.  In a lot of cases,
// you want to be able to store a bunch of data in one shot, rather than iterating, but
// sometimes arrays contain heterogynous mixes of data types, and it's not possible to
// take advantage of any optimizations here.  This basically saves you some data i/o when writing
// and reading, if the values are all of the same type.  This feature can be turned off.
#macro BSON_array_type_numeric_pod 0 // A "pod" array is an array of all integers or "reals"
#macro BSON_array_type_string 1 // A "string" array is an array of variable length strings
#macro BSON_array_type_bool 2 // An array of boolean
#macro BSON_array_type_mono_struct 3 // A "mono struct" array contains objects that all have the same base keywords.
#macro BSON_array_type_struct 4 // A "struct" array contains objects that do not have the same base keywords.
#macro BSON_array_type_hetero 5 // A mixture of types or structs
#macro BSON_array_type_empty 6 // The array does not contain any values.
function BSONArrayType( arr, support_u64=false, support_realint=false, assume_hetero=false ) {
	if ( assume_hetero ) return BSON_array_type_hetero;
	var len=array_length(arr);
	if ( len == 0 ) return BSON_array_type_empty;
	var type=-1;
	var struct_info=false;
	var struct_mono=true;
	for ( var i=0; i<len; i++ ) {
		var this_type=BSONGetType(arr[i],support_u64,support_realint);
		if ( type == -1 ) {
			type=this_type;
			if ( type == BSON_type_struct ) struct_info=BSONGetStructInfo(arr[i],support_u64,support_realint);
		} else {
			if ( this_type != type ) {
				return BSON_array_type_hetero;
			} else {
				if ( this_type == BSON_type_struct ) {
					var this_struct_info=BSONGetStructInfo(arr[i],support_u64,support_realint);
					if ( not BSONCompareStructInfo(struct_info,this_struct_info) ) {
						struct_mono=false;
					}
				}
			}
		}
	}
	if ( type == BSON_type_string ) return BSON_array_type_string;
	if ( type == BSON_type_struct ) {
		if ( struct_mono ) return BSON_array_type_mono_struct;
		else return BSON_array_type_struct;
	}
	if ( type == BSON_type_decimal || type == BSON_type_int32 || type == BSON_type_int64 )
		return BSON_array_type_numeric_pod;
	if ( type == BSON_type_bool ) return BSON_array_type_bool;
	if ( type == BSON_type_unsupported ) return BSON_array_type_empty;
	return BSON_array_type_hetero;	
}

// Determines if the "real" is actually an integer
function BSONis_realint( value ) {
	return ( is_real(value) and floor(value) == value );
}

// Error codes for BSONWrite and BSONWriteNode
#macro BSONWrite_success 0
#macro BSONWrite_fail_filename 1
#macro BSONWrite_fail_buffer_create 2
#macro BSONWrite_fail_file_bin_rewrite 3
#macro BSONWrite_fail_write_node 4
#macro BSONWrite_fail_buffer_compress 5
#macro BSONWrite_fail_buffer_save 6

function BSONWriteErrorString( code ) {
	switch ( code ) {
		case BSONWrite_success: return "success"
		case BSONWrite_fail_filename: return "bad filename";
		case BSONWrite_fail_buffer_create: return "could not create buffer";
		case BSONWrite_fail_file_bin_rewrite: return "unable to delete old file";
		case BSONWrite_fail_write_node: return "fail on node write";
		case BSONWrite_fail_buffer_compress: return "fail on buffer compress";
		case BSONWrite_fail_buffer_save: return "fail on buffer save";
		default: return "unknown error code ("+string_format(code,1,0)+")";
	}
}

function BSONWriteNode( buffer, data, support_u64=false, support_realint=false, assume_hetero=false, calldepth=0 ) {
	if ( calldepth > BSON_MAX_DEPTH ) return { data: data, error: BSONWrite_fail_write_node, MAX_DEPTH: BSON_MAX_DEPTH, calldepth: calldepth };
	var type=BSONGetType(data,support_u64,support_realint);
	try { buffer_write(buffer,buffer_u8,type); } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, step: 0, calldepth: calldepth }; }
	switch ( type ) {
		default: break;
     case BSON_type_int32:	 try { buffer_write(buffer,buffer_s32,data); 	 } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, kind: type, step: 1, calldepth: calldepth }; } break;
     case BSON_type_int64: 	 try { buffer_write(buffer,buffer_u64,data); 	 } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, kind: type, step: 1, calldepth: calldepth }; } break;
     case BSON_type_decimal: try { buffer_write(buffer,buffer_f64,data);     } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, kind: type, step: 1, calldepth: calldepth }; } break;
     case BSON_type_string:  try { buffer_write(buffer,buffer_string,data);  } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, kind: type, step: 1, calldepth: calldepth }; } break;
     case BSON_type_bool:    try { buffer_write(buffer,buffer_bool,data);	 } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, kind: type, step: 1, calldepth: calldepth }; } break;
     case BSON_type_struct: {
		var struct_info=BSONGetStructInfo(data,support_u64,support_realint);
		if ( struct_info == false ) return { struct_info: struct_info, error: BSONWrite_fail_write_node, data: data, type: type };
		try { buffer_write(buffer,buffer_u16,struct_info.klen); } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, step: 1, kind: type, struct_info: struct_info, calldepth: calldepth }; }
		for ( var i=0; i<struct_info.klen; i++ ) {
			try { buffer_write(buffer,buffer_string,struct_info.keys[i]); } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, step: 2, kind: type, struct_info: struct_info, key: i, calldepth: calldepth }; }
			var value = variable_struct_get(data,struct_info.keys[i]);
			var result = BSONWriteNode(buffer,value,support_u64,support_realint,assume_hetero,calldepth+1);
			if ( result.error != BSONWrite_success ) return  { error: BSONWrite_fail_write_node, calldepth: calldepth, result: result, step: 3, kind: type, struct_info: struct_info, calldepth: calldepth, element: i, value: value, data: data };
		}
	 }
	 break;
     case BSON_type_array: {
		var array_type = BSONArrayType(data,support_u64,support_realint,assume_hetero);
		try { buffer_write(buffer,buffer_u8,array_type); } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 1, calldepth: calldepth }; } 
		if ( array_type != BSON_array_type_empty ) {
			var len=array_length(data);
			try { buffer_write(buffer,buffer_u32,len); } catch (e) { return { data: data, caught: e, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 2, calldepth: calldepth, len: len }; } 
			switch ( array_type ) {
				case BSON_array_type_numeric_pod: {
					var type=BSONGetType(data[0],support_u64,support_realint);
					buffer_write(buffer,buffer_u8,type);
					switch ( type ) {
						case BSON_type_int32:
							for ( var i=0; i<len; i++ ) {
								try { buffer_write(buffer,buffer_s32,data[i]); } catch (e) { return { data: data, caught: e, element: i, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 1, calldepth: calldepth }; } 
							}
						break;
						case BSON_type_int64:
							for ( var i=0; i<len; i++ ) {
								try { buffer_write(buffer,buffer_u64,data[i]); } catch (e) { return { data: data, caught: e, element: i, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 1, calldepth: calldepth }; } 
							}
						break;
						case BSON_type_decimal:
							for ( var i=0; i<len; i++ ) {
								try { buffer_write(buffer,buffer_f64,data[i]); } catch (e) { return { data: data, caught: e, element: i, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 1, calldepth: calldepth }; } 
							}
						break;
						default:
							show_error("Programmer error, BSON write array unsupported data type",true);
							return { data: data, caught: e, type: type, error: BSONWrite_fail_write_node, calldepth: calldepth };
						break;
					}
				}
				break;
				case BSON_array_type_string: {
					for ( var i=0; i<len; i++ ) {
						try { buffer_write(buffer,buffer_string,data[i]); } catch (e) { return { data: data, caught: e, element: i, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 1, calldepth: calldepth }; } 
					}
				}
				break;
				case BSON_array_type_bool: {
					for ( var i=0; i<len; i++ ) {
						try { buffer_write(buffer,buffer_u8,(data[i]?1:0)); } catch (e) { return { data: data, caught: e, element: i, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 1, calldepth: calldepth }; } 
					}
				}
				break;
				case BSON_array_type_mono_struct: {
					var struct_info=BSONGetStructInfo(data[0],support_u64,support_realint);
					try { buffer_write(buffer,buffer_u16,struct_info.klen); } catch (e) { return { data: data, caught: e, struct_info: struct_info, error: BSONWrite_fail_write_node, kind: type, array_type: array_type, step: 1, calldepth: calldepth }; } 
					for ( var i=0; i<struct_info.klen; i++ ) buffer_write(buffer,buffer_string,struct_info.keys[i]);
					for ( var i=0; i<len; i++ ) {
						for ( var j=0; j<struct_info.klen; j++ ) {
							var value=variable_struct_get(data[i],struct_info.keys[j]);
							var result=BSONWriteNode(buffer,value,support_u64,support_realint,assume_hetero,calldepth+1);
							if ( result.error != BSONWrite_success ) return  { error: BSONWrite_fail_write_node, calldepth: calldepth, result: result, element: i, key: j, keyname: struct_info.keys[j], data: value };
						}
					}
				}
				break;
				case BSON_array_type_struct: {
					for ( var i=0; i<len; i++ ) {
						var result = BSONWriteNode(buffer,data[i],support_u64,support_realint,assume_hetero,calldepth+1);
						if ( result.error != BSONWrite_success ) return  { error: BSONWrite_fail_write_node, calldepth: calldepth, result: result, element: i, data: data[i] };
					}
				}
				break;
				case BSON_array_type_hetero: {
					for ( var i=0; i<len; i++ ) {
						var result = BSONWriteNode(buffer,data[i],support_u64,support_realint,assume_hetero,calldepth+1);
						if ( result.error != BSONWrite_success ) return  { error: BSONWrite_fail_write_node, calldepth: calldepth, result: result, element: i, data: data[i] };
					}
				}
				break;
				case BSON_array_type_empty: break;
			}
		}
	 }
	 break;
	}
	return { error: BSONWrite_success, calldepth: calldepth };
}

function BSONWrite(data, filename, compress=true, nobackup=true, multibackup=false, clear_existing=false, support_u64=false, support_realint=false, assume_hetero=false ){
	
	// Maintain a single or multi-backup scenario
	if (!nobackup and file_exists(filename)) {
		var backupname=filename+".bak";
		if (multibackup) {
			var i=0;
			while ( file_exists(filename+".bak."+string_format(i,1,0)) ) i++;
			backupname += "."+string_format(i,1,0);
		}
		BSONCopyFile(filename,backupname);
	}
	
	var buffer=-1,preexisting=false;
	
	// Check if the file is validly named
	try { preexisting = file_exists(filename); } catch(e) {
		return { error: BSONWrite_fail_filename };	}
	
	// Generate the outgoing data buffer.
	try { buffer = buffer_create(256, buffer_grow, 1); } catch(e) {
		return { error: BSONWrite_fail_buffer_create };
	}
	
	// Seek the buffer start position, seems superfluous
	buffer_seek(buffer, buffer_seek_start, 0);
	// Write the file header
	buffer_write(buffer, buffer_string, "BSONGML");
	// Recursively write all nodes
	var result = BSONWriteNode( buffer, data, support_u64, support_realint, assume_hetero );
	// Fast exist if error
	if ( result.error != BSONWrite_success ) {
		buffer_delete(buffer);
		return { error: BSONWrite_fail_write_node, result: result };
	}
	// Write the file footer
	buffer_write(buffer, buffer_string, "EOFBSONGML");	
	// Write the outgoing data buffer
	if ( compress ) {
		var compressed=-1;
		// Compress the buffer
		try {
			compressed=buffer_compress(buffer,0,buffer_tell(buffer));
		} catch(e) {
			buffer_delete(buffer);
			return { error: BSONWrite_fail_buffer_compress };
		}
		// Clear any pre-existing file, prepare to write.
		if ( clear_existing ) try {	if ( preexisting ) file_delete(filename); } catch(e) {
			return { error: BSONWrite_fail_file_bin_rewrite };
		}
		// Save the buffer
		try {
			buffer_save(compressed,filename);
		} catch(e) {
			buffer_delete(buffer);
			buffer_delete(compressed);
			return { error: BSONWrite_fail_buffer_save };
		}
		// Delete both buffers
		buffer_delete(compressed);
		buffer_delete(buffer);
	} else {
		// Clear any pre-existing file, prepare to write.
		if ( clear_existing ) try {	if ( preexisting ) file_delete(filename); } catch(e) {
			return { error: BSONWrite_fail_file_bin_rewrite };
		}
		// Save the buffer
		try {
			buffer_save(buffer,filename);
		} catch(e) {
			buffer_delete(buffer);
			return { error: BSONWrite_fail_buffer_save };
		}
		// Delete the buffer
		buffer_delete(buffer);
	}
		
	return { error: BSONWrite_success };
}


// Error codes for BSONRead and BSONReadNode

#macro BSONRead_success 0
#macro BSONRead_file_not_found 1
#macro BSONRead_fail_buffer_load 2
#macro BSONRead_fail_decompress 3
#macro BSONRead_fail_read_header 4
#macro BSONRead_fail_read_node 5
#macro BSONRead_fail_read_footer 6
#macro BSONRead_fail_read_int32 7
#macro BSONRead_fail_read_int64 8
#macro BSONRead_fail_read_decimal 9
#macro BSONRead_fail_read_string 10
#macro BSONRead_fail_read_bool 11
#macro BSONRead_fail_read_struct 12
#macro BSONRead_fail_read_array 13
#macro BSONRead_fail_beyond_depth 14

function BSONReadErrorString( code ) {
	switch ( code ) {
		case BSONRead_success: return "success"
		case BSONRead_file_not_found: return "file not found";
		case BSONRead_fail_buffer_load: return "could not load buffer";
		case BSONRead_fail_decompress: return "failed to decompress";
		case BSONRead_fail_read_header: return "failed to read header";
		case BSONRead_fail_read_node: return "failed to read node";
		case BSONRead_fail_read_footer: return "failed to read footer";
		case BSONRead_fail_read_int32: return "failed reading int32";
		case BSONRead_fail_read_int64: return "failed reading int64";
		case BSONRead_fail_read_decimal: return "failed reading decimal";
		case BSONRead_fail_read_string: return "failed reading string";
		case BSONRead_fail_read_bool: return "failed reading bool";
		case BSONRead_fail_read_struct: return "failed reading struct";
		case BSONRead_fail_read_array: return "failed reading array";
		case BSONRead_fail_beyond_depth: return "failed read beyond depth";
		default: return "unknown error code ("+string_format(code,1,0)+")";
	}
}

function BSONReadNode( buffer, support_u64=false, support_realint=false, assume_hetero=false, calldepth=0 ) {
	if ( calldepth > BSON_MAX_DEPTH ) return { data: data, error: BSONRead_fail_beyond_depth, MAX_DEPTH: BSON_MAX_DEPTH, calldepth: calldepth };
	var data=noone;
	// Read the type of the data
	var type=-1;
	try { type=buffer_read(buffer,buffer_u8); } catch(e) { return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_node, step: 0 }; }
	switch ( type ) {
		default: return { data: data, calldepth: calldepth, error: BSONRead_fail_read_node, kind: BSON_type_unsupported, step: 0 }; break;
     case BSON_type_int32:	 try { data=buffer_read(buffer,buffer_s32); 	} catch(e) { return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_int32 }; }   break;
     case BSON_type_int64: 	 try { data=buffer_read(buffer,buffer_u64); 	} catch(e) { return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_int64 }; }   break;
     case BSON_type_decimal: try { data=buffer_read(buffer,buffer_f64);    } catch(e) { return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_decimal }; } break;
     case BSON_type_string:  try { data=buffer_read(buffer,buffer_string); } catch(e) { return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_string }; }  break;
     case BSON_type_bool:    try { data=buffer_read(buffer,buffer_bool);	} catch(e) { return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_bool }; }    break;
     case BSON_type_struct: {
		 data={};
		 var struct_info={};
		 try { struct_info.klen=buffer_read(buffer,buffer_u16); } catch (e) {
			 return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_struct, step: 1 };
		 }
		 struct_info.keys=[];
		 for ( var i=0; i<struct_info.klen; i++ ) {
			 try { struct_info.keys[i]=buffer_read(buffer,buffer_string); } catch(e) {
				 return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_struct, step: 2 };
			 }
 			 if ( string_length(struct_info.keys[i]) < 1 ) { return { data: data, caught: e, error: BSONRead_fail_read_struct, step: 3 }; }
			 var value=BSONReadNode(buffer,support_u64,support_realint,assume_hetero,calldepth+1);
			 if ( value.error != BSONRead_success ) return { data: data, calldepth: calldepth, error: value.error, result: value };
			 variable_struct_set(data,struct_info.keys[i],value.data);
		 }
	 }
	 break;
     case BSON_type_array: {
		data = [];
		var array_type = -1;
		try { array_type=buffer_read(buffer,buffer_u8); } catch (e) {
			 return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, step: 1 };
		}
		if ( array_type != BSON_array_type_empty ) {
			var len=0;
			try { len=buffer_read(buffer,buffer_u32); } catch(e) {				
				return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, step: 2 };
			}
			switch ( array_type ) {
				case BSON_array_type_numeric_pod: {
					var type=-1;
					try { type=buffer_read(buffer,buffer_u8); } catch(e) {
						return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, step: 3, kind: BSON_array_type_numeric_pod };
					}
					switch ( type ) {
						case BSON_type_int32:
							for ( var i=0; i<len; i++ ) {
								try { data[i]=buffer_read(buffer,buffer_s32); } catch(e) {
									return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, step: 3, kind: BSON_array_type_numeric_pod, type: BSON_type_int32 };
								}
							}
						break;
						case BSON_type_int64:
							for ( var i=0; i<len; i++ ) {
								try { data[i]=buffer_read(buffer,buffer_u64); } catch(e) {
									return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, step: 3, kind: BSON_array_type_numeric_pod, type: BSON_type_int64 };
								}
							}
						break;
						case BSON_type_decimal:
							for ( var i=0; i<len; i++ ) {
								try { data[i]=buffer_read(buffer,buffer_f64); } catch(e) {
									return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, step: 3, kind: BSON_array_type_numeric_pod, type: BSON_type_decimal };
								}
							}
						break;
						default: return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, step: 3, kind: BSON_array_type_numeric_pod, type: BSON_type_unsupported }; break;
					}
				}
				break;
				case BSON_array_type_string: {
					for ( var i=0; i<len; i++ ) {
						try { data[i]=buffer_read(buffer,buffer_string); } catch(e) {
							return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, kind: BSON_array_type_string };
						}
					}
				}
				break;
				case BSON_array_type_bool: {
					for ( var i=0; i<len; i++ ) {
						try { data[i]=buffer_read(buffer,buffer_u8); } catch(e) {
							return { data: data, calldepth: calldepth, caught: e, error: BSONRead_fail_read_array, kind: BSON_array_type_bool };
						}
						if ( data[i] == 0 ) data[i]=false;
						else data[i]=true;
					}
				}
				break;
				case BSON_array_type_mono_struct: {
					var struct_info={};
					try { struct_info.klen=buffer_read(buffer,buffer_u16); } catch(e) {
						return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_array, step: 1, kind: BSON_array_type_mono_struct };
					}
					for ( var i=0; i<struct_info.klen; i++ ) {
						try { struct_info.keys[i]=buffer_read(buffer,buffer_string); } catch(e) {
							return { data: data, caught: e, calldepth: calldepth, error: BSONRead_fail_read_array, step: 2, keynum: i, struct_info: struct_info, kind: BSON_array_type_mono_struct };
						}
					}
					for ( var i=0; i<len; i++ ) {
						data[i]={};
						for ( var j=0; j<struct_info.klen; j++ ) {
							var value=BSONReadNode(buffer,support_u64,support_realint,assume_hetero);
							if ( value.error != BSONRead_success ) 
								return { data: data, calldepth: calldepth, error: BSONRead_fail_read_array, step: 2, element: i, keynum: j, struct_info: struct_info, kind: BSON_array_type_mono_struct };
							variable_struct_set(data[i],struct_info.keys[j],value.data);
						}
					}
				}
				break;
				case BSON_array_type_struct: {
					for ( var i=0; i<len; i++ ) {
						var value=BSONReadNode(buffer,support_u64,support_realint,assume_hetero,calldepth+1);
						if ( value.error != BSONRead_success ) 
							return { data: data, calldepth: calldepth, error: BSONRead_fail_read_array, step: 1, element: i, kind: BSON_array_type_struct };
						data[i] = value.data;
					}
				}
				break;
				case BSON_array_type_hetero: {
					for ( var i=0; i<len; i++ ) {
						var value=BSONReadNode(buffer,support_u64,support_realint,assume_hetero);
						if ( value.error != BSONRead_success ) 
							return { data: data, calldepth: calldepth, error: BSONRead_fail_read_array, step: 1, element: i, kind: BSON_array_type_hetero };
						data[i] = value.data;
					}
				}
				break;
				case BSON_array_type_empty: break;
			} // array_type
		} // if array_type is not empty array
	 }
	 break;
	} // switch type
	return { data: data, error: BSONRead_success };
}

function BSONRead( filename, decompress=false, support_u64=false, support_realint=false, assume_hetero=false ) {
	
	var buffer=-1,default_data=noone,header="",footer="";

	if ( not file_exists(filename) ) return { data: default_data, error: BSONRead_file_not_found };

	// Generate the outgoing data buffer.
	try { buffer = buffer_load(filename); } catch(e) {
		 return { data: default_data, caught: e, error: BSONRead_fail_buffer_load };
	}
	
	// Decompress
	if ( decompress ) {
		var compressed;
		try {
			compressed=buffer;
			buffer = buffer_decompress(compressed);
		} catch(e) {
			buffer_delete(compressed);
			return { data: default_data, caught: e, error: BSONRead_fail_decompress };
		}			
		buffer_delete(compressed);
	}
	
	// Seek the buffer start position, seems superfluous
	buffer_seek(buffer, buffer_seek_start, 0);
	
	// Read the file header
	try {
		header=buffer_read(buffer, buffer_string);
	} catch (e) {
		buffer_delete(buffer);
		return { data: default_data, caught: e, error: BSONRead_fail_read_header };
	}
	if ( header != "BSONGML" ) {
		buffer_delete(buffer);
		return { data: default_data, caught: e, error: BSONRead_fail_read_header };
	}
	
	// Recursively read all nodes
	var result = BSONReadNode( buffer, support_u64, support_realint, assume_hetero );
	if ( result.error != BSONWrite_success ) {
		buffer_delete(buffer);
		return { data: result.data, error: BSONRead_fail_read_node, returned: result };
	}
	
	// Read the file footer
	try { footer=buffer_read(buffer, buffer_string); } catch (e) {
		buffer_delete(buffer);
		return { data: result.data, caught: e, error: BSONRead_fail_read_footer };
	}
	if ( footer != "EOFBSONGML" ) {
		buffer_delete(buffer);
		return { data: result.data, error: BSONRead_fail_read_footer };
	}
	
	buffer_delete(buffer);
	
	return { data: result.data, error: BSONWrite_success };
}



function BSONDeepCompareNode( a,b, support_u64=false, support_realint=false, assume_hetero=false, calldepth=0 ) {
	if ( calldepth > BSON_MAX_DEPTH ) return false; // though technically you could return "true" here, this is an out of bounds error.
	var type_a=BSONGetType(a,support_u64,support_realint);
	var type_b=BSONGetType(b,support_u64,support_realint);
	if ( type_a != type_b ) return false;
	switch ( type_a ) {
		default: break;
     case BSON_type_int32:	
     case BSON_type_int64: 	
     case BSON_type_decimal:
     case BSON_type_string: 
     case BSON_type_bool:   return a==b;
     case BSON_type_struct: {
		 if ( !is_struct(a) or !is_struct(b) ) return false;
		 var struct_info_a=BSONGetStructInfo(a,support_u64,support_realint);
		 var struct_info_b=BSONGetStructInfo(b,support_u64,support_realint);
		 if ( struct_info_a == false xor struct_info_b == false ) return false;
		 if ( struct_info_a == false and struct_info_b == false ) return true;
		 if ( struct_info_a.klen != struct_info_b.klen ) return false; // this can also mean a value was filtered out due to not being supported
		 for ( var i=0; i<struct_info_a.klen; i++ ) {
		 	if ( struct_info_a.keys[i] != struct_info_b.keys[i] ) return false;
		 	if ( !BSONDeepCompareNode( variable_struct_get(a,struct_info_a.keys[i]), variable_struct_get(b,struct_info_b.keys[i]) ) ) return false;
		 }
	 }
	 break;
     case BSON_type_array: {
		var array_type_a = BSONArrayType(a,assume_hetero);
		var array_type_b = BSONArrayType(b,assume_hetero);
		if ( array_type_a != array_type_b ) return false;
		if ( !is_array(a) or !is_array(b) ) return false;
		if ( array_length(a) != array_length(b) ) return false;
		var len=array_length(a);
		for ( var i=0; i<len; i++ ) {
			if ( !BSONDeepCompareNode(a[i],b[i],support_u64, support_realint, assume_hetero) ) return false;
		}
	 }
	 break;
	}
	return true;
}

function BSONDeepCompare( A,B, support_u64=false, support_realint=false, assume_hetero=false ) {
	return BSONDeepCompareNode(A,B, support_u64, support_realint, assume_hetero );
}




function BSONRead_Async( filename ) {
	
	var buffer=-1,default_data=noone,header="",footer="";

	if ( not file_exists(filename) ) return { data: default_data, error: BSONRead_file_not_found };

	// Generate the outgoing data buffer.
	try { buffer = buffer_load_async(filename); } catch(e) {
		 return { data: default_data, caught: e, error: BSONRead_fail_buffer_load };
	}

}

// Call from your async function
function BSONRead_Async_Event( buffer, decompress=false, support_u64=false, support_realint=false, assume_hetero=false ) {
	
	// Decompress
	if ( decompress ) {
		var compressed;
		try {
			compressed=buffer;
			buffer = buffer_decompress(compressed);
		} catch(e) {
			buffer_delete(compressed);
			return { data: default_data, caught: e, error: BSONRead_fail_decompress };
		}			
		buffer_delete(compressed);
	}
	
	// Seek the buffer start position, seems superfluous
	buffer_seek(buffer, buffer_seek_start, 0);
	
	// Read the file header
	try {
		header=buffer_read(buffer, buffer_string);
	} catch (e) {
		buffer_delete(buffer);
		return { data: default_data, caught: e, error: BSONRead_fail_read_header };
	}
	if ( header != "BSONGML" ) {
		buffer_delete(buffer);
		return { data: default_data, caught: e, error: BSONRead_fail_read_header };
	}
	
	// Recursively read all nodes
	var result = BSONReadNode( buffer, support_u64, support_realint, assume_hetero );
	if ( result.error != BSONWrite_success ) {
		buffer_delete(buffer);
		return { data: result.data, error: BSONRead_fail_read_node, returned: result };
	}
	
	// Read the file footer
	try { footer=buffer_read(buffer, buffer_string); } catch (e) {
		buffer_delete(buffer);
		return { data: result.data, caught: e, error: BSONRead_fail_read_footer };
	}
	if ( footer != "EOFBSONGML" ) {
		buffer_delete(buffer);
		return { data: result.data, error: BSONRead_fail_read_footer };
	}
	
	buffer_delete(buffer);
	
	return { data: result.data, error: BSONWrite_success };
}



function BSONWrite_Async(data, filename, compress=true, nobackup=true, multibackup=false, clear_existing=false, support_u64=false, support_realint=false, assume_hetero=false ){
	
	// Maintain a single or multi-backup scenario
	if (!nobackup and file_exists(filename)) {
		var backupname=filename+".bak";
		if (multibackup) {
			var i=0;
			while ( file_exists(filename+".bak."+string_format(i,1,0)) ) i++;
			backupname += "."+string_format(i,1,0);
		}
		BSONCopyFile(filename,backupname);
	}
	
	var buffer=-1,preexisting=false;
	
	// Check if the file is validly named
	try { preexisting = file_exists(filename); } catch(e) {
		return { error: BSONWrite_fail_filename };	}
	
	// Generate the outgoing data buffer.
	try { buffer = buffer_create(256, buffer_grow, 1); } catch(e) {
		return { error: BSONWrite_fail_buffer_create };
	}
	
	// Seek the buffer start position, seems superfluous
	buffer_seek(buffer, buffer_seek_start, 0);
	// Write the file header
	buffer_write(buffer, buffer_string, "BSONGML");
	// Recursively write all nodes
	var result = BSONWriteNode( buffer, data, support_u64, support_realint, assume_hetero );
	// Fast exist if error
	if ( result.error != BSONWrite_success ) {
		buffer_delete(buffer);
		return { error: BSONWrite_fail_write_node, result: result };
	}
	// Write the file footer
	buffer_write(buffer, buffer_string, "EOFBSONGML");	
	// Write the outgoing data buffer
	if ( compress ) {
		var compressed=-1;
		// Compress the buffer
		try {
			compressed=buffer_compress(buffer,0,buffer_tell(buffer));
			buffer_delete(buffer);
			buffer=compressed;
		} catch(e) {
			buffer_delete(buffer);
			return { error: BSONWrite_fail_buffer_compress };
		}
	}
	// Clear any pre-existing file, prepare to write.
	if ( clear_existing ) try {	if ( preexisting ) file_delete(filename); } catch(e) {
		return { error: BSONWrite_fail_file_bin_rewrite };
	}
	// Save the buffer
	try {
		buffer_save_async(buffer,filename);
	} catch(e) {
		buffer_delete(buffer);
		return { error: BSONWrite_fail_buffer_save };
	}
		
	return { error: BSONWrite_success };
}

function BSONWrite_Async_Event( buffer, filename ) {
	buffer_delete(buffer);
	return { error: BSONWrite_success };
}
