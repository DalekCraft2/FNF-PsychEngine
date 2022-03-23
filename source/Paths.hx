package;

import flash.media.Sound;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets.FlxSoundAsset;
import haxe.Json;
import openfl.system.System;
import openfl.utils.Assets;
import openfl.utils.AssetType;
#if FEATURE_MODS
import haxe.io.Path;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class Paths
{
	public static inline final SOUND_EXT:String = #if web "mp3" #else "ogg" #end;
	public static inline final VIDEO_EXT:String = "mp4";

	#if FEATURE_MODS
	public static final IGNORE_MOD_FOLDERS:Array<String> = [
		'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds', 'shaders', 'videos', 'images', 'fonts', 'scripts'
	];
	#end

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/breakfast.$SOUND_EXT',
		'assets/shared/music/tea-time.$SOUND_EXT',
	];

	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory():Void
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				// get rid of it
				var obj:FlxGraphic = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null)
				{
					Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedAssets.remove(key);
				}
			}
		}
		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	public static function clearStoredMemory(?cleanUnused:Bool = false):Void
	{
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj:FlxGraphic = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedAssets.exists(key))
			{
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
			{
				// Debug.logTrace('test: $dumpExclusions', key);
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		Assets.cache.clear("songs");
	}

	public static var currentModDirectory:String = '';
	public static var currentLevel:String;

	public static function setCurrentLevel(name:String):Void
	{
		Debug.logTrace('Setting asset folder to $name');
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String>):String
	{
		#if FEATURE_MODS
		var path:String = modFolders(file);
		if (FileSystem.exists(path))
			return path;
		#end

		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if (currentLevel != 'shared')
			{
				levelPath = getLibraryPathForce(file, currentLevel);
				if (Assets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (Assets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	public static function getLibraryPath(file:String, library = "preload"):String
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	static inline function getLibraryPathForce(file:String, library:String):String
	{
		return '$library:assets/$library/$file';
	}

	public static inline function getPreloadPath(file:String = ''):String
	{
		return 'assets/$file';
	}

	public static inline function file(file:String, type:AssetType = TEXT, ?library:String):String
	{
		return getPath(file, type, library);
	}

	public static inline function txt(key:String, ?library:String):String
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	public static inline function json(key:String, ?library:String):String
	{
		return getPath('data/$key.json', TEXT, library);
	}

	public static inline function lua(key:String, ?library:String):String
	{
		// TODO Move lua files to data/, maybe
		return getPath('$key.lua', TEXT, library);
	}

	public static inline function image(key:String, ?library:String):String
	{
		return getPath('images/$key.png', IMAGE, library);
	}

	public static inline function xml(key:String, ?library:String):String
	{
		return getPath('images/$key.xml', TEXT, library);
	}

	public static inline function shaderFragment(key:String, ?library:String):String
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}

	public static inline function shaderVertex(key:String, ?library:String):String
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}

	public static inline function video(key:String, ?library:String):String
	{
		return getPath('videos/$key.$VIDEO_EXT', BINARY, library);
	}

	public static inline function sound(key:String, ?library:String):FlxSoundAsset
	{
		// return getPath('sounds/$key.$SOUND_EXT', SOUND, library);
		return getSound('sounds', key, library);
	}

	public static inline function music(key:String, ?library:String):FlxSoundAsset
	{
		// return getPath('music/$key.$SOUND_EXT', MUSIC, library);
		return getSound('music', key, library);
	}

	// TODO Move instrumentals and vocals to music/
	public static inline function voices(song:String):FlxSoundAsset
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		return getSound('songs', songKey);
	}

	public static inline function inst(song:String):FlxSoundAsset
	{
		var songKey:String = '${formatToSongPath(song)}/Inst';
		return getSound('songs', songKey);
	}

	public static inline function font(key:String, ?library:String):String
	{
		return getPath('fonts/$key', FONT, library);
	}

	/*public static inline function exists(path:String):Bool
		{
			if (#if FEATURE_MODS FileSystem.exists(path) || #end Assets.exists(path))
			{
				return true;
			}
			return false;
	}*/
	public static inline function fileExists(key:String, type:AssetType, ?library:String):Bool
	{
		var path:String = getPath(key, type, library);

		if (#if FEATURE_MODS FileSystem.exists(path) || #end Assets.exists(path, type))
		{
			return true;
		}
		return false;
	}

	public static function getTextFromFile(key:String, ?library:String, ?ignoreMods:Bool = false):String
	{
		#if FEATURE_FILESYSTEM
		#if FEATURE_MODS
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		if (FileSystem.exists(getPath(key, TEXT, library)))
			return File.getContent(getPath(key, TEXT, library));

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if (currentLevel != 'shared')
			{
				levelPath = getLibraryPathForce(key, currentLevel);
				if (FileSystem.exists(levelPath))
					return File.getContent(levelPath);
			}

			levelPath = getLibraryPathForce(key, 'shared');
			if (FileSystem.exists(levelPath))
				return File.getContent(levelPath);
		}
		#end
		return Assets.getText(getPath(key, TEXT, library));
	}

	public static inline function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if FEATURE_MODS
		var imageLoaded:FlxGraphic = getGraphic(key, library);
		var xmlExists:Bool = false;
		if (FileSystem.exists(xml(key, library)))
		{
			xmlExists = true;
		}
		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)),
			(xmlExists ? File.getContent(xml(key)) : xml(key, library)));
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), xml(key, library));
		#end
	}

	public static inline function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if FEATURE_MODS
		var imageLoaded:FlxGraphic = getGraphic(key, library);
		var txtExists:Bool = false;
		if (FileSystem.exists(file('images/$key.txt', library)))
		{
			txtExists = true;
		}
		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)),
			(txtExists ? File.getContent(file('images/$key.txt', library)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	public static inline function formatToSongPath(path:String):String
	{
		return path.toLowerCase().replace(' ', '-');
	}

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	public static function getGraphic(key:String, ?library:String):FlxGraphic
	{
		var path:String = image(key, library);
		#if FEATURE_MODS
		if (FileSystem.exists(path))
		{
			if (!currentTrackedAssets.exists(path))
			{
				var newBitmap:BitmapData = BitmapData.fromFile(path);
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(newBitmap, false, path);
				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		#end
		if (Assets.exists(path, IMAGE))
		{
			if (!currentTrackedAssets.exists(path))
			{
				var newGraphic:FlxGraphic = FlxG.bitmap.add(path, false, path);

				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		Debug.logError('Could not find graphic with name "$key" and library "$library" (path: $path)');
		return null;
	}

	public static var currentTrackedSounds:Map<String, FlxSoundAsset> = [];

	public static function getSound(path:String, key:String, ?library:String):FlxSoundAsset
	{
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		// Debug.logTrace(gottenPath);
		if (!currentTrackedSounds.exists(gottenPath))
		{
			#if FEATURE_MODS
			currentTrackedSounds.set(gottenPath, Sound.fromFile('./$gottenPath'));
			#else
			currentTrackedSounds.set(gottenPath, Assets.getSound(getPath('$path/$key.$SOUND_EXT', SOUND, library)));
			#end
		}
		localTrackedAssets.push(gottenPath);
		if (currentTrackedSounds.get(gottenPath) == null)
		{
			Debug.logError('Could not find sound with path "$path", name "$key", and library "$library"');
		}
		return currentTrackedSounds.get(gottenPath);
	}

	public static inline function getRandomSound(key:String, min:Int, max:Int, ?library:String):FlxSoundAsset
	{
		return getSound('$key${FlxG.random.int(min, max)}', library);
	}

	public static function getJson(key:String, ?library:String):Dynamic
	{
		var rawJson:String = null;

		var path:String = json(key, library);
		#if FEATURE_FILESYSTEM
		if (FileSystem.exists(path))
			rawJson = File.getContent(path);
		#else
		if (Assets.exists(path))
			rawJson = Assets.getText(path);
		#end

		try
		{
			// Attempt to parse and return the JSON data.
			return Json.parse(rawJson);
		}
		catch (e)
		{
			Debug.logError('Error parsing a JSON file with name "$key" and library "$library": $e');
			Debug.logError(e.stack);
			return null;
		}
	}

	#if FEATURE_MODS
	public static inline function mods(key:String = ''):String
	{
		return 'mods/$key';
	}

	public static function modFolders(key:String):String
	{
		if (currentModDirectory != null && currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods('$currentModDirectory/$key');
			if (FileSystem.exists(fileToCheck))
			{
				return fileToCheck;
			}
		}
		return 'mods/$key';
	}

	public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		var modsFolder:String = mods();
		if (FileSystem.exists(modsFolder))
		{
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				var path:String = Path.join([modsFolder, folder]);
				if (FileSystem.isDirectory(path) && !IGNORE_MOD_FOLDERS.contains(folder) && !list.contains(folder))
				{
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
