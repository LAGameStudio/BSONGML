// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function BSON_Tests() {
	
	var int32_testvalue=2147483640;
	var neg_int32_testvalue=-2147483640;
	var int64_testvalue=int64(9223372036854775800); // + 7 is max int64
	var deepdecimal_testvalue = 3.14159265358979323846264338327950288419716939937510582097494459;
	var decimal_testvalue = 3.14159265358979323;
	var shallowdecimal_testvalue = 3.1416;
	var string_testvalue="consectetur adipiscing elit";
	var longstring_testvalue="Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
	var bool_testvalue=false;
	var bool_testvalue2=true;
	
	var mono_struct_array_testdata = [
	 { name: "a my name", index: 0, another: 3.14159 },
	 { name: "b my name", index: 1, another: 2*3.14159 },
	 { name: "c my name", index: 2, another: 3*3.14159 },
	 { name: "d my name", index: 3, another: 4*3.14159 },
	 { name: "E my name", index: 4, another: 3.14159/5 },
	 { name: "f my name", index: 5, another: false },
	 { name: "G my name", index: 6, another: 12345 },
	 { name: "H my name", index: 7, another: 3.14159/8 },
	 { name: "I my name", index: 8, another: 3.14159/9 },
	 { name: "JKLMNO my name", index: 9, another: "another another another!" }
	];	
	
	var numeric_pod_array_testdata = [
	  1, 2, 3, 123, 4, 5, 6, 789, 10, -123, -456, -789, -0, 0, 1
	];
	
	var string_array_testdata = [
	 "apple", "banana", "canteloupe", "fig", "pear", "pineapple"
	];
	
	var bool_array_testdata = [
	 true, false, false, false, true, false
	];
	
	var struct_array_testdata = [
	  { hetero: true, name: "rogyinous" },
	  { multi: "variable", type: false, decimal: 1.2345, integer: 42 },
	  { kind: "bud", friend: "sister", mom: "pop" },
	  { pen15: 80085, oscar: false, emmy: true }
	];
	
	var hetero_array_testdata = [
	 1.7, 4.4, { obvious: "structure", path: true }, "crimes", "grimes", "times", 9, 9, 9,
	 [ "whoa nested", "tested", "bested" ],
	 [ [ 123 ], [4], [ 4, 6, 7 ], [ { who: "Lost Astronaut", where: "lostastronaut.com" }, false ] ],
	 false
	];
	
	var complex_struct = {
		land: hetero_array_testdata,
		air: struct_array_testdata,
		mono: mono_struct_array_testdata,
		omni: bool_array_testdata,
		strung: string_array_testdata,
		num: numeric_pod_array_testdata,
		dumb: [
			int32_testvalue, 
			neg_int32_testvalue,
//			int64_testvalue,
			deepdecimal_testvalue,
			decimal_testvalue, 
			shallowdecimal_testvalue,
			string_testvalue,
			longstring_testvalue,
			bool_testvalue,
			bool_testvalue2
		],
		dumber: {
			a: int32_testvalue, 
			b: neg_int32_testvalue,
//			c: int64_testvalue,
			d: deepdecimal_testvalue,
			e: decimal_testvalue, 
			f: shallowdecimal_testvalue,
			g: string_testvalue,
			h: longstring_testvalue,
			i: bool_testvalue,
			j: bool_testvalue2
		}
	};
	
	var too_deep_testdata = {
		two: { three: { four: { five: 
			{ six: { seven: { eight: { nine: { ten: 
				{ eleven: { twelve: { thirteen: { fourteen: 
					{ fifteen: { sixteen: { seventeen: { eighteen: "too deep" } }
		}}}}}}}}}}}}}}
	};
	
	var massive_array_testdata = [];
#macro MASSIVE_ARRAY_TEST_SIZE 256*256 //123456
	for ( var i=0; i<MASSIVE_ARRAY_TEST_SIZE; i++ )	massive_array_testdata[i] = 123 * numeric_pod_array_testdata[i%array_length(numeric_pod_array_testdata)]; 
	
	var res;
	var stopwatch;
	
	var report="";
	
	var write_tests = [
	  { p: [  int32_testvalue,				"int32.bsongml",				true, false, true, false, true, true, false  ] },
	  { p: [  neg_int32_testvalue,			"neg_int32.bsongml",			true, false, true, false, true, true, false  ] },
	  { p: [  int64_testvalue,				"int64.bsongml",				true, false, true, false, true, true, false  ] },
	  { p: [  deepdecimal_testvalue,		"deepdecimal.bsongml",			true, false, true, false, true, true, false  ] },
	  { p: [  decimal_testvalue,			"decimal.bsongml",				true, false, true, false, true, true, false  ] },
	  { p: [  shallowdecimal_testvalue,		"shallowdecimal.bsongml",		true, false, true, false, true, true, false  ] },
	  { p: [  string_testvalue,				"string.bsongml",				true, false, true, false, true, true, false  ] },
	  { p: [  longstring_testvalue,			"longstring.bsongml",			true, false, true, false, true, true, false  ] },
	  { p: [  bool_testvalue,				"bool.bsongml",					true, false, true, false, true, true, false  ] },
	  { p: [  bool_testvalue2,				"bool2.bsongml",				true, false, true, false, true, true, false  ] },
	  { p: [  mono_struct_array_testdata,	"mono_struct_array.bsongml",	true, false, true, false, true, true, false  ] },
	  { p: [  numeric_pod_array_testdata,	"numeric_pod_array.bsongml",	true, false, true, false, true, true, false  ] },
	  { p: [  string_array_testdata,		"string_array.bsongml",			true, false, true, false, true, true, false  ] },
	  { p: [  bool_array_testdata,			"bool_array.bsongml",			true, false, true, false, true, true, false  ] },
	  { p: [  struct_array_testdata,		"struct_array.bsongml",			true, false, true, false, true, true, false  ] },
	  { p: [  hetero_array_testdata,		"hetero_array.bsongml",			true, false, true, false, true, true, false  ] },
	  { p: [  complex_struct,				"complex_struct.bsongml",		true, false, true, false, true, true, false  ] },
	  { p: [  too_deep_testdata,			"too_deep.bsongml",				true, false, true, false, true, true, false  ] },
	  { p: [  massive_array_testdata,		"massive_array.bsongml",		true, false, true, false, true, true, false  ] },
	];
	
	var wlen=array_length(write_tests);
	for ( var i=0; i<wlen; i++ ) {
		var test=write_tests[i];
	
		stopwatch = get_timer();
		res = BSONWrite( test.p[0], test.p[1], test.p[2], test.p[3], test.p[4], test.p[5], test.p[6], test.p[7], test.p[8] );
		report += ( test.p[1]+" "+string_format( (get_timer()-stopwatch)/1000.0, 1, 2 )+"ms "
		            +"and result was: "+string_format(res.error,1,0)+" "+BSONWriteErrorString(res.error) );
		report += "\n";
	}
	
	show_message( "BSONWrite Report\n------------------\n" + report );
	
	report = "";
	for ( var i=0; i<wlen; i++ ) {
		var test=write_tests[i];
		var temp={};
		stopwatch = get_timer();
		res = BSONRead( test.p[1], test.p[2], test.p[6], test.p[7], test.p[8] );
		temp = res.data;
		report += ( test.p[1]+" "+string_format( (get_timer()-stopwatch)/1000.0, 1, 2 )+"ms "
		            +"and result was: "+string_format(res.error,1,0)+" "+BSONWriteErrorString(res.error) );
		report += "\n";
		if ( BSONDeepCompare( test.p[0], temp ) ) report+="Comparison showed identical for "+test.p[1]+"\n";
		else {
			report+="Comparison showed NOT IDENTICAL for "+test.p[1]+"\n---\n";
			report+="A = "+json_stringify(test.p[0])+"\n---\n";
			report+="B = "+json_stringify(temp)+"\n---\n";
		}
	}

	show_message( "BSONRead Report\n------------------\n" + report );

}

