package;

#if polymod
import polymod.Polymod;
#else
import Mod.ModMetadata;
import haxe.io.Bytes;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#elseif nodefs
import haxe.io.UInt8Array;
import js.Browser;
import js.Lib;
import js.html.ScriptElement;
#end

using StringTools;
#end

/**
 * For cross-platform FileSystem stuff.
 * I ripped most of this stuff from Polymod.
 */
class FileSystemCP
{
	public static function getFileSystem():IFileSystem
	{
		#if polymod
		return Polymod.getFileSystem();
		#elseif sys
		return new SysFileSystem(Paths.mods());
		#elseif nodefs
		return new NodeFileSystem(Paths.mods());
		#else
		return new StubFileSystem();
		#end
	}
}

#if !polymod
/**
 * A standard interface for the various file systems that Polymod supports.
 */
interface IFileSystem
{
	/**
	 * Returns whether the file or directory at the given path exists.
	 * @param path The path to check.
	 * @return Whether there is a file or directory there.
	 */
	public function exists(path:String):Bool;

	/**
	 * Returns whether the provided path is a directory.
	 * @param path The path to check.
	 * @return Whether the path is a directory.
	 */
	public function isDirectory(path:String):Bool;

	/**
	 * Returns a list of files and folders contained within the provided directory path.
	 * Does not return files in subfolders, use readDirectoryRecursive for that.
	 * @param path The path to check.
	 * @return An array of file paths and folder paths.
	 */
	public function readDirectory(path:String):Array<String>;

	/**
	 * Returns a list of files contained within the provided directory path.
	 * Checks all subfolders recursively. Returns only files.
	 * @param path The path to check.
	 * @return An array of file paths.
	 */
	public function readDirectoryRecursive(path:String):Array<String>;

	/**
	 * Returns the content of a given file as a string.
	 * Returns null if the file can't be found.
	 * @param path The file to read.
	 * @return The text content of the file.
	 */
	public function getFileContent(path:String):Null<String>;

	/**
	 * Returns the content of a given file as Bytes.
	 * Returns null if the file can't be found.
	 * @param path The file to read.
	 * @return The byte content of the file.
	 */
	public function getFileBytes(path:String):Null<Bytes>;

	#if FEATURE_MODS
	/**
	 * Provide a list of valid mods for this file system to load.
	 * @return An array of mod IDs.
	 */
	public function scanMods():Array<String>;

	/**
	 * Provides the metadata for a given mod. Returns null if the mod does not exist.
	 * @param modId The ID of the mod.
	 * @return The mod metadata.
	 */
	public function getMetadata(modId:String):Null<ModMetadata>;
	#end
}

#if sys
/**
 * An implementation of IFileSystem which accesses files from the local directory.
 * This is the default file system for desktop platforms.
 */
class SysFileSystem implements IFileSystem
{
	public var modRoot(default, null):String;

	public function new(modRoot:String)
	{
		this.modRoot = modRoot;
	}

	public inline function exists(path:String)
	{
		return FileSystem.exists(path);
	}

	public inline function isDirectory(path:String)
		return FileSystem.isDirectory(path);

	public inline function readDirectory(path:String)
		return FileSystem.readDirectory(path);

	public inline function getFileContent(path:String)
	{
		if (exists(path))
			return File.getContent(path);
		return null;
	}

	public inline function getFileBytes(path:String)
	{
		if (exists(path))
			return File.getBytes(path);
		return null;
	}

	#if FEATURE_MODS
	public function scanMods()
	{
		var dirs:Array<String> = readDirectory(modRoot);
		var l:Int = dirs.length;
		for (i in 0...l)
		{
			var j:Int = l - i - 1;
			var dir:String = dirs[j];
			var testDir:String = Path.join([modRoot, dir]);
			if (!isDirectory(testDir) || !exists(testDir))
			{
				dirs.splice(j, 1);
			}
		}
		return dirs;
	}

	public function getMetadata(modId:String)
	{
		if (exists(modId))
		{
			var meta:ModMetadata = null;
			var metaFile:String = Path.join([modId, Path.withExtension('_meta', Paths.JSON_EXT)]);
			var iconFile:String = Path.join([modId, Path.withExtension('_icon', Paths.IMAGE_EXT)]);
			if (exists(metaFile))
			{
				var metaText:String = getFileContent(metaFile);
				// meta = ModMetadata.fromJsonStr(metaText);
				if (meta == null)
					return null;
			}
			else
			{
				Debug.logWarn('Could not find mod metadata file: $metaFile');
				return null;
			}
			if (exists(iconFile))
			{
				var iconBytes:Bytes = getFileBytes(iconFile);
				// meta.icon = iconBytes;
			}
			else
			{
				Debug.logWarn('Could not find mod icon file: $iconFile');
			}
			return meta;
		}
		else
		{
			Debug.logError('Could not find mod directory: $modId');
		}
		return null;
	}
	#end

	public function readDirectoryRecursive(path:String):Array<String>
	{
		var all:Array<String> = _readDirectoryRecursive(path);
		for (i in 0...all.length)
		{
			var f:String = all[i];
			var stri:Int = f.indexOf(path + '/');
			if (stri == 0)
			{
				f = f.substr((path + '/').length, f.length);
				all[i] = f;
			}
		}
		return all;
	}

	private function _readDirectoryRecursive(str:String):Array<String>
	{
		if (exists(str) && isDirectory(str))
		{
			var all:Array<String> = readDirectory(str);
			if (all == null)
				return [];
			var results:Array<String> = [];
			for (thing in all)
			{
				if (thing == null)
					continue;
				var pathToThing:String = Path.join([str, thing]);
				if (isDirectory(pathToThing))
				{
					var subs:Array<String> = _readDirectoryRecursive(pathToThing);
					if (subs != null)
					{
						results = results.concat(subs);
					}
				}
				else
				{
					results.push(pathToThing);
				}
			}
			return results;
		}
		return [];
	}
}
#elseif nodefs
// TODO I'd like to use js.html.FileSystem for JS and HTML5 but I have absolutely no idea how to get an instance of it. It also may be for the client's filesystem, and not the server's.

/**
 * An implementation of IFileSystem which accesses files from the local directory,
 * when running in Node.js via Electron.
 */
class NodeFileSystem implements IFileSystem
{
	// hack to make sure NodeUtils.injectJSCode is called
	private static var _jsCodeInjected:Bool = injectJSCode();

	public var modRoot(default, null):String;

	public function new(modRoot:String)
	{
		this.modRoot = modRoot;
	}

	// -----------------------------------------------------------------------------------------------
	// -----------------------------------------------------------------------------------------------

	/**
	 * Injects JS code needed to interact with Node's file system into the head element of the HTML document.
	 * @return
	 */
	private static function injectJSCode():Bool
	{
		// array for adding JS text
		var jsCode:Array<String> = [];

		// get the node file system
		jsCode.push("let _nodefs = require('fs')");

		// utility function for getting directory contents
		jsCode.push("function getDirectoryContents(path, recursive, dirContents=null)");
		jsCode.push('{');
		jsCode.push("	if ( dirContents == null ) {");
		jsCode.push("		dirContents = [];");
		jsCode.push("	}");
		jsCode.push("	if ( isDirectory(path) ) {");
		jsCode.push("		if ( path.charAt(path.length - 1) != '/' ) {");
		jsCode.push("			path += '/';");
		jsCode.push("		}");
		jsCode.push("		var entries = _nodefs.readdirSync(path, { withFileTypes:true } );");
		jsCode.push("		for ( var i = 0; i < entries.length; ++i ) {");
		jsCode.push("			var entryPath = path + entries[i].name;");
		jsCode.push("			if ( entries[i].isDirectory() && recursive ) {");
		jsCode.push("				getDirectoryContents( entryPath, true, dirContents );");
		jsCode.push("			}");
		jsCode.push("			else {");
		jsCode.push("				dirContents.push( entryPath );");
		jsCode.push("			}");
		jsCode.push("		}");
		jsCode.push("	}");
		jsCode.push("	return dirContents;");
		jsCode.push('}');

		// functions needed by Polymod
		jsCode.push("function exists(path) { return _nodefs.existsSync(path); }");
		jsCode.push("function getStats(path) { return exists(path) ? _nodefs.statSync(path) : null; }");
		jsCode.push("function isDirectory(path) { var stats = getStats(path); return stats != null && stats.isDirectory(); }");
		jsCode.push("function getFileContent(path) { return exists(path) ? _nodefs.readFileSync(path, {encoding:'utf8', flag:'r'}) : ''; }");
		jsCode.push("function getFileBytes(path) { return exists(path) ? Uint8Array.from( _nodefs.readFileSync(path) ) : null; }");
		jsCode.push("function readDirectory(path) { return getDirectoryContents(path, false, []) }");
		jsCode.push("function readDirectoryRecursive(path) { return getDirectoryContents(path, true, []) }");

		// create the script element
		var scriptElement:ScriptElement = Browser.document.createScriptElement();
		scriptElement.type = 'text/javascript';
		scriptElement.text = jsCode.join("\n");

		// inject into the head tag
		Browser.document.head.appendChild(scriptElement);

		return true;
	}

	// -----------------------------------------------------------------------------------------------

	/**
	 * Pulled and modified from OpenFL's ExternalInterface implementation
	 * @param	functionName
	 * @param	arg
	 * @return
	 */
	private function callFunc(functionName:String, arg:Dynamic = null):Dynamic
	{
		if (!~/^\(.+\)$/.match(functionName))
		{
			var thisArg:String = functionName.split('.').slice(0, -1).join('.');
			if (thisArg.length > 0)
			{
				functionName += '.bind(${thisArg})';
			}
		}

		var fn:Dynamic = Lib.eval(functionName);

		return fn(arg);
	}

	// -----------------------------------------------------------------------------------------------
	public function santizePaths(path:String, directories:Array<String>):Void
	{
		for (i in 0...directories.length)
		{
			directories[i] = directories[i].replace(path, '');
			if (directories[i].charAt(0) == '/')
			{
				directories[i] = directories[i].substr(1);
			}
		}
	}

	// -----------------------------------------------------------------------------------------------
	public inline function exists(path:String):Bool
	{
		return callFunc('exists', path);
	}

	// -----------------------------------------------------------------------------------------------
	public inline function isDirectory(path:String):Bool
	{
		return callFunc('isDirectory', path);
	}

	// -----------------------------------------------------------------------------------------------
	public inline function readDirectory(path:String):Array<String>
	{
		var arr:Array<String> = callFunc('readDirectory', path);
		santizePaths(path, arr);
		return arr;
	}

	// -----------------------------------------------------------------------------------------------
	public inline function getFileContent(path:String):String
	{
		return callFunc('getFileContent', path);
	}

	// -----------------------------------------------------------------------------------------------
	public inline function getFileBytes(path:String):Bytes
	{
		var intArr:UInt8Array = callFunc('getFileBytes', path);
		return intArr != null ? intArr.view.buffer : null;
	}

	// -----------------------------------------------------------------------------------------------
	public inline function readDirectoryRecursive(path:String):Array<String>
	{
		var arr:Array<String> = callFunc('readDirectoryRecursive', path);
		santizePaths(path, arr);
		return arr;
	}

	#if FEATURE_MODS
	// -----------------------------------------------------------------------------------------------
	public function getMetadata(modId:String)
	{
		if (exists(modId))
		{
			var meta:ModMetadata = null;

			var metaFile:String = Path.join([modId, Path.withExtension('_meta', Paths.JSON_EXT)]);
			var iconFile:String = Path.join([modId, Path.withExtension('_icon', Paths.IMAGE_EXT)]);

			if (exists(metaFile))
			{
				var metaText:String = getFileContent(metaFile);
				// meta = ModMetadata.fromJsonStr(metaText);
			}
			else
			{
				Debug.logWarn('Could not find mod metadata file: $metaFile');
			}
			if (exists(iconFile))
			{
				var iconBytes:Bytes = getFileBytes(iconFile);
				// meta.icon = iconBytes;
			}
			else
			{
				Debug.logWarn('Could not find mod icon file: $iconFile');
			}
			return meta;
		}
		else
		{
			Debug.logError('Could not find mod directory: "$modId"');
		}
		return null;
	}

	// -----------------------------------------------------------------------------------------------
	public function scanMods()
	{
		var dirs:Array<String> = readDirectory(modRoot);
		var l:Int = dirs.length;
		for (i in 0...l)
		{
			var j:Int = l - i - 1;
			var dir:String = dirs[j];
			var testDir:String = '$modRoot/$dir';
			if (!isDirectory(testDir) || !exists(testDir))
			{
				dirs.splice(j, 1);
			}
		}
		return dirs;
	}
	#end
}
#else

/**
 * This stub file system returns false for all requests.
 * This is the fallback used when the desired file system can't be accessed.
 *
 * Mods WILL NOT LOAD if this is used, but asset localization will still work.
 */
class StubFileSystem implements IFileSystem
{
	public function new()
	{
	}

	public inline function exists(path:String):Bool
		return false;

	public inline function isDirectory(path:String):Bool
		return false;

	public inline function readDirectory(path:String):Array<String>
		return [];

	public inline function getFileContent(path:String):String
		return null;

	public inline function getFileBytes(path:String):Bytes
		return null;

	public inline function readDirectoryRecursive(path:String):Array<String>
		return [];

	#if FEATURE_MODS
	public inline function scanMods():Array<String>
		return [];

	public inline function getMetadata(modId:String):Array<ModMetadata>
		return null;
	#end
}
#end

#else
typedef IFileSystem = polymod.fs.PolymodFileSystem.IFileSystem;
#end
