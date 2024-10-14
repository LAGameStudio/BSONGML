# BSONGML
A modern gamemaker language implementation of simple, robust and performant buffering of large complex structured mixed-type data stored in binary files that resolves issues with json_stringify.

As always, if you use this library, we'd love it if you mentioned us in your game credits as LostAstronaut.com and Lost Astronaut Studios.

## Rationale

This library was created to resolve issues I discovered using json_stringify().  I noticed other binary file libraries on Github also use json_stringify() and I wanted to write something closer to a BSON implementation so that I could make sure it didn't run into the various issues one might face using json_stringify() ... I also wanted to support ".bak" and ".bak.0" ... OS-style file automatic backups.

As the story goes, I was working with my RPG map editor that I had just made, and with some light testing it seemed to be fine.  One aspect of the map data was a large array of identical structures.  At some point using this editor, I was not aware of a file lock created by Windows, resulting in a zero length file, or perhaps a failure in json_stringify() where it failed without a try..catch and returned an empty string, which it then saved. I lost all of my work. Fed up with this need, I created this reusable library since I often want to create a "level file format" or a "save game file format" but don't want to write a unique proprietary format each time.

## Feature Summary

* Non-asynchronous: Super simple two function interface, where you pass in a few options and can expect it to work.
* Async event functions available as well.
* Support for converting "Real" decimals to ints automatically.
* Support for compressed files.
* Detects simple arrays versus complex mono-structured and heterogynous arrays. By default, optimizes for "arrays of identical structures" to avoid needing to repeat key value pairs in the file, overcomplicating the structure of the data buffer.
* Support for .bak automatic backup. (when overwriting)
* Support for .bak.X where X is an incremental backup that is automatically incremented for providing multiple previous version backups. (when overwriting)
* Comprehensive test suite demonstrates all features.

## Considerations

You cannot save "function methods" in a file.  It is expected that methods and pointers, and looping structures, will not be saved if you pass an object that contains them.  There is a protection against looping structures, but methods are an unsupported variable type and while ignored during saving will not be saved and it is best if you keep methods out of your data.  Your data should be plain old data (int, string, bool, decimal) and arrays or structures containing what I just listed.  This is considered "static" or "simple" data structures.  

## Basic Usage Examples

```javascript
// Some complex data.
var data = { name: "Player", attributes: { strength: 16, dexterity: 14 }, hitpoints: 7, max_hitpoints: 10, dead: false, score: 123789, handicap: 1.5, inventory: [ "a sword", "meat cleaver", "pistol" ] };

// Write the file.
var result = BSONWrite( data, "player.sav" );
if ( result.error != BSONRead_success ) show_message("Error writing player.sav");

// Read it back in.
var result = BSONRead( "player.sav" );

// For testing purposes, did it all save?
if ( result.error == BSONRead_success and BSONDeepCompare( data, result.data ) ) show_message("All good!");
else show_message("Uh oh!");
```

## Asyncronous Example

TBD

## Function Documentation

#### "Interface" Functions

``BSONWrite(data, filename, compress=true, nobackup=true, multibackup=false, clear_existing=false, support_u64=false, support_realint=false, assume_hetero=false )``

Write a Binary JSON file based on some data. Parameters:
* ``data`` - a "plain old struct" of data which can either be an array, a single int/string/bool/decimal, or a struct
* ``compress`` - when _true_ compress the buffer before writing
* ``nobackup`` - when _false_, enables backup features. if you attempt to overwrite a file, it will copy the file to filename.bak first
* ``multibackup`` - when _false_, no incremental backup will be written. when _true_, and nobackup is also _false_, it will and a .X where X is an incremental number of backups.  sacrifices disk space but provides multiple previous versions in case you want to roll back.  good for editors.
* ``clear_existing`` - when _true_ will actively delete the file before writing, in an attempt to avoid locking issues.
* ``support_u64`` - this feature supports int64, but there seems to be some issues with it so I recommend leave it as _false_ and must be set the same for BSONWrite and BSONRead operations for this filename
* ``support_realint`` - a minor optimization feature that when _true_, converts decimals with xxx.0 to int32 before saving, but in doing so may resolve by normalizing erroneous data values (that are stored as a decimal but are actually integers) or it may create unintentional heterogynous arrays (by converting integers-as-decimals to integers), either resolving or unintentionally complicating this duality; turned off to decrease the chance of failures or unintended consequences. if you don't know why you need this, don't use it. must be set the same for BSONWrite and BSONRead operations for this filename
* ``assume_hetero`` - a minor deoptimization feature that forces all arrays to be treated generally as heterogynous, and turns off the mono_struct detection optimization feature that is on by default, if you don't know why you need this, don't use it. turned off by default. must be set the same for BSONWrite and BSONRead operations for this filename

Returns: a struct like ``{ error: <error message>, [kind], [type], [step], [element], [key], [keyname], ... }`` and when error = 0, success.

``BSONWriteErrorString( code )``

Returns an error string provided by the ``result.error`` returned by ``BSONWrite(...)``.

``BSONRead( filename, decompress=false, support_u64=false, support_realint=false, assume_hetero=false )``

Read a previously written Binary JSON file. Parameter options should match values in the BSONWrite call that was used to write the file. Parameters:
* ``decompress`` - when _true_ decompress the buffer after loading and before reading
* ``support_u64`` - this feature supports int64, but there seems to be some issues with it so I recommend leave it as _false_ and must be set the same for BSONWrite and BSONRead operations for this filename
* ``support_realint`` - a minor optimization feature that when _true_, converts decimals with xxx.0 to int32 before saving, but in doing so may resolve by normalizing erroneous data values (that are stored as a decimal but are actually integers) or it may create unintentional heterogynous arrays (by converting integers-as-decimals to integers), either resolving or unintentionally complicating this duality; turned off to decrease the chance of failures or unintended consequences. if you don't know why you need this, don't use it. must be set the same for BSONWrite and BSONRead operations for this filename
* ``assume_hetero`` - a minor deoptimization feature that forces all arrays to be treated generally as heterogynous, and turns off the mono_struct detection optimization feature that is on by default, if you don't know why you need this, don't use it. turned off by default. must be set the same for BSONWrite and BSONRead operations for this filename

Returns: a struct like ``{ data: <your data or partial read>, error: <error message>, [kind], [type], [step], [element], [key], [keyname], ... }`` and when error = 0, success.

``BSONReadErrorString( code )``

Returns an error string provided by the ``result.error`` returned by ``BSONRead(...)``.

``BSONDeepCompare( A,B, support_u64=false, support_realint=false, assume_hetero=false )``

Peforms a deep comparison between to data structs, and returns _true_ when identical, _false_ when not identical.  

_Please note use of the ``support_u64`` feature will cause a false negative (appears not identical) when an int64 appears in the data.  It seems though, despite this, the data was read properly from the file._

#### "Internal" Functions

``BSONCopyFile( filenamea, filenameb )``

Maps to ``file_copy``, used by BSONWrite

``BSONFileCanExist(filename)``

Exhaustive quest to see if a filename is valid, used by BSONWrite

``BSONGetType(data, support_u64=false, support_realint=false)``

Get data node's type, used by BSONWrite and BSONDeepCompare

``BSONGetStructInfo( data, support_u64=false, support_realint=false )``

Get struct info for a node; the key list and size, used by BSONWrite and BSONDeepCompare

``BSONCompareStructInfo( structinfoa, structinfob )``

Compares struct info for BSONReadNode internal logic

``BSONArrayType( arr, support_u64=false, support_realint=false, assume_hetero=false )``

Advanced classifier for arrays that implements the heterogynous and mono-struct types, used by BSONWrite and BSONDeepCompare

``BSONis_realint( value )``

Determines if the "real" is actually an integer, for the support_realint features a pseudo-optimization

``BSONWriteNode( buffer, data, support_u64=false, support_realint=false, assume_hetero=false, calldepth=0 )``

Used by BSONWrite to generalize the reading of data nodes in the data tree

``BSONReadNode( buffer, support_u64=false, support_realint=false, assume_hetero=false, calldepth=0 )``

Used by BSONRead to generalize the reading of data nodes in the data tree

``BSONDeepCompareNode( a,b, support_u64=false, support_realint=false, assume_hetero=false, calldepth=0 )``

Used by BSONDeepCompare, performs a comparison of types and values in the data tree
