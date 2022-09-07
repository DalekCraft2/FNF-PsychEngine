package funkin.fs;

#if sys
#if polymod
typedef SysFileSystem = polymod.fs.SysFileSystem;
#else
import funkin.Mod.ModMetadata;
import funkin.fs.FileSystemCP.IFileSystem;
import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * An implementation of IFileSystem which accesses files from the local directory.
 * This is the default file system for desktop platforms.
 */
class SysFileSystem implements IFileSystem
{
	#if FEATURE_MODS
	public var modRoot(default, null):String;

	public function new(modRoot:String)
	{
		this.modRoot = modRoot;
	}
	#else
	public function new()
	{
	}
	#end

	public inline function exists(path:String):Bool
	{
		return FileSystem.exists(path);
	}

	public inline function isDirectory(path:String):Bool
		return FileSystem.isDirectory(path);

	public inline function readDirectory(path:String):Array<String>
		return FileSystem.readDirectory(path);

	public inline function getFileContent(path:String):String
	{
		if (exists(path))
			return File.getContent(path);
		return null;
	}

	public inline function getFileBytes(path:String):Bytes
	{
		if (exists(path))
			return File.getBytes(path);
		return null;
	}

	#if FEATURE_MODS
	public function scanMods():Array<String>
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

	public function getMetadata(modId:String):Null<ModMetadata>
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
#end

#end
