package fs;

#if polymod
typedef StubFileSystem = polymod.fs.StubFileSystem;
#else
import fs.FileSystemCP.IFileSystem;
import haxe.io.Bytes;
#if FEATURE_MODS
import Mod.ModMetadata;
#end

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

	public inline function getMetadata(modId:String):Null<ModMetadata>
		return null;
	#end
}
#end
