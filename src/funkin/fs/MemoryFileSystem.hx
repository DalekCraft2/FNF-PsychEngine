package funkin.fs;

// TODO Determine what this could be used for
// ... Also, start using TODO comments for actual code-related things instead of reminders
#if polymod
typedef MemoryFileSystem = polymod.fs.MemoryFileSystem;
#else
import funkin.Mod.ModMetadata;
import funkin.fs.FileSystemCP.IFileSystem;
import haxe.io.Bytes;
import haxe.io.Path;

/**
 * This simple virtual file system demonstrates that anything can be used
 * as the backend filesystem for Polymod, as long as you can fulfill the
 * IFileSystem interface.
 * 
 * Instantiate the MemoryFileSystem, call `addFileBytes` to add mod files to it,
 * then pass it to Polymod. Any mod files you add will be available to Polymod
 * as though they were accessed from the file system.
 */
class MemoryFileSystem implements IFileSystem
{
	private var files:Map<String, Bytes> = [];
	private var directories:Array<String> = [];

	/**
	 * Receive parameters to instantiate the MemoryFileSystem.
	 */
	public function new()
	{
		// No-op constructor.
	}

	/**
	 * Call this function to add a text document to the virtual file system.
	 * 
	 * Example: `addFileBytes("mod1/_polymod_meta.json", "...")`
	 * 
	 * @param path The path name of the file to add.
	 * @param data The text of the document.
	 */
	public function addFileBytes(path:String, data:Bytes):Void
	{
		files.set(path, data);
		directories = directories.concat(listAllParentDirs(path));
	}

	/**
	 * Call this function to remove a given file from the virtual file system.
	 */
	public function removeFile(path:String):Void
	{
		files.remove(path);
	}

	/**
	 * Call this function to clear all files from the virtual file system.
	 */
	public function clear():Void
	{
		files = [];
		directories = [];
	}

	public inline function exists(path:String):Bool
	{
		return files.exists(path);
	}

	public inline function isDirectory(path:String):Bool
	{
		return directories.indexOf(path) != -1;
	}

	/**
	 * List all files AND directories at the given path.
	 */
	public inline function readDirectory(path:String):Array<String>
	{
		var result:Array<String> = [];
		for (key => _v in files)
		{
			// Directory must exactly match.
			if (Path.directory(key) == path)
			{
				result.push(key);
			}
		}
		for (dir in directories)
		{
			if (Path.directory(dir) == path)
			{
				result.push(dir);
			}
		}
		return result;
	}

	public inline function getFileContent(path:String):String
	{
		return files.get(path).toString();
	}

	public inline function getFileBytes(path:String):Bytes
	{
		return files.get(path);
	}

	/**
	 * List all files at or below the given path.
	 */
	public inline function readDirectoryRecursive(path:String):Array<String>
	{
		var result:Array<String> = [];
		for (key => _v in files)
		{
			// Directory OR PARENT must exactly match.
			if (key.indexOf(path) == 0)
			{
				result.push(key);
			}
		}
		result.concat(directories.filter((dir:String) -> dir.indexOf(path) == 0));

		return result;
	}

	/**
	 * For a given file, return a list of all its parent directories.
	 * @param filePath
	 * @return Array<String>
	 */
	public static function listAllParentDirs(filePath:String):Array<String>
	{
		var parentDirs:Array<String> = new Array<String>();
		var parentDir:String = filePath;
		while (parentDir != null && parentDir != '')
		{
			parentDirs.push(parentDir);
			parentDir = Path.directory(parentDir);
		}
		return parentDirs;
	}

	public inline function scanMods():Array<String>
	{
		var dirs:Array<String> = readDirectory('');
		var l:Int = dirs.length;
		for (i in 0...l)
		{
			var j:Int = l - i - 1;
			var dir:String = dirs[j];
			if (!isDirectory(dir) || !exists(dir))
			{
				dirs.splice(j, 1);
			}
		}
		return dirs;
	}

	public inline function getMetadata(modId:String):ModMetadata
	{
		if (exists(modId))
		{
			var meta:ModMetadata = null;

			var metaFile:String = Path.join([modId, Path.withExtension('_meta', Paths.JSON_EXT)]);
			var iconFile:String = Path.join([modId, Path.withExtension('_icon', Paths.IMAGE_EXT)]);

			if (!exists(metaFile))
			{
				Debug.logWarn('Could not find mod metadata file: $metaFile');
				return null;
			}
			else
			{
				var metaText:String = getFileContent(metaFile);
				// meta = ModMetadata.fromJsonStr(metaText);
				// if (meta == null)
				// 	return null;
			}

			if (!exists(iconFile))
			{
				Debug.logWarn('Could not find mod icon file: $iconFile');
			}
			else
			{
				var iconBytes:Bytes = getFileBytes(iconFile);
				// meta.icon = iconBytes;
				// meta.iconPath = iconFile;
			}
			return meta;
		}
		else
		{
			Debug.logError('Could not find mod directory: $modId');
		}
		return null;
	}
}
#end
