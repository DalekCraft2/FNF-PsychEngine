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
	public static var ignoreModFolders:Array<String> = [
		'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds', 'shaders', 'videos', 'images', 'fonts', 'scripts'
	];
	#end

	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/breakfast.$SOUND_EXT',
		'assets/shared/music/tea-time.$SOUND_EXT',
	];

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
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null):String
	{
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

	public static function loadJson(key:String, ?library:String):Dynamic
	{
		var rawJson:String = null;

		#if FEATURE_MODS
		var modPath:String = modsJson(key);
		if (FileSystem.exists(modPath))
		{
			rawJson = File.getContent(modPath);
		}
		#end

		if (rawJson == null)
		{
			var path:String = json(key, library);
			#if FEATURE_FILESYSTEM
			if (FileSystem.exists(path))
				rawJson = File.getContent(path);
			#else
			if (Assets.exists(path))
				rawJson = Assets.getText(path);
			#end
		}

		// Perform cleanup on files that have bad data at the end.
		rawJson = rawJson.trim();
		while (rawJson.length > 0 && !rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

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

	public static inline function xml(key:String, ?library:String):String
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	public static inline function json(key:String, ?library:String):String
	{
		return getPath('data/$key.json', TEXT, library);
	}

	public static inline function shaderFragment(key:String, ?library:String):String
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}

	public static inline function shaderVertex(key:String, ?library:String):String
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}

	public static inline function lua(key:String, ?library:String):String
	{
		return getPath('$key.lua', TEXT, library);
	}

	public static function video(key:String):String
	{
		#if FEATURE_MODS
		var file:String = modsVideo(key);
		if (FileSystem.exists(file))
		{
			return file;
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	// Whose idea was it to make the sound and music methods return actual sound objects instead of paths like almost every other method?
	public static function sound(key:String, ?library:String):FlxSoundAsset
	{
		// return getPath('sounds/$key.$SOUND_EXT', SOUND, library);
		return returnSound('sounds', key, library);
	}

	public static inline function soundRandom(key:String, min:Int, max:Int, ?library:String):FlxSoundAsset
	{
		return returnSound('$key${FlxG.random.int(min, max)}', library);
	}

	public static inline function music(key:String, ?library:String):FlxSoundAsset
	{
		// return getPath('music/$key.$SOUND_EXT', MUSIC, library);
		return returnSound('music', key, library);
	}

	public static inline function voices(song:String):FlxSoundAsset
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		return returnSound('songs', songKey);
	}

	public static inline function inst(song:String):FlxSoundAsset
	{
		var songKey:String = '${formatToSongPath(song)}/Inst';
		return returnSound('songs', songKey);
	}

	public static inline function image(key:String, ?library:String):FlxGraphic
	{
		// streamlined the assets process more
		return returnGraphic(key, library);
	}

	public static function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if FEATURE_FILESYSTEM
		#if FEATURE_MODS
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));

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
		return Assets.getText(getPath(key, TEXT));
	}

	public static inline function font(key:String):String
	{
		#if FEATURE_MODS
		var file:String = modsFont(key);
		if (FileSystem.exists(file))
		{
			return file;
		}
		#end
		return 'assets/fonts/$key';
	}

	public static inline function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String):Bool
	{
		#if FEATURE_MODS
		if (FileSystem.exists(mods('$currentModDirectory/$key')) || FileSystem.exists(mods(key)))
		{
			return true;
		}
		#end

		if (Assets.exists(getPath(key, type)))
		{
			return true;
		}
		return false;
	}

	public static inline function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if FEATURE_MODS
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var xmlExists:Bool = false;
		if (FileSystem.exists(modsXml(key)))
		{
			xmlExists = true;
		}

		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)),
			(xmlExists ? File.getContent(modsXml(key)) : file('images/$key.xml', library)));
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
		#end
	}

	public static inline function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if FEATURE_MODS
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var txtExists:Bool = false;
		if (FileSystem.exists(modsTxt(key)))
		{
			txtExists = true;
		}

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)),
			(txtExists ? File.getContent(modsTxt(key)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	public static inline function formatToSongPath(path:String):String
	{
		return path.toLowerCase().replace(' ', '-');
	}

	// completely rewritten asset loading? fuck!
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	public static function returnGraphic(key:String, ?library:String):FlxGraphic
	{
		#if FEATURE_MODS
		var modKey:String = modsImages(key);
		if (FileSystem.exists(modKey))
		{
			if (!currentTrackedAssets.exists(modKey))
			{
				var newBitmap:BitmapData = BitmapData.fromFile(modKey);
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(newBitmap, false, modKey);
				currentTrackedAssets.set(modKey, newGraphic);
			}
			localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end

		var path:String = getPath('images/$key.png', IMAGE, library);
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
		Debug.logWarn('Could not find asset at "$path"');
		return null;
	}

	public static var currentTrackedSounds:Map<String, FlxSoundAsset> = [];

	public static function returnSound(path:String, key:String, ?library:String):FlxSoundAsset
	{
		#if FEATURE_MODS
		var file:String = modsSounds(path, key);
		if (FileSystem.exists(file))
		{
			if (!currentTrackedSounds.exists(file))
			{
				currentTrackedSounds.set(file, Sound.fromFile(file));
			}
			localTrackedAssets.push(key);
			return currentTrackedSounds.get(file);
		}
		#end
		// I hate this so god damn much
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
			Debug.logWarn('Could not find sound at "$file"');
		return currentTrackedSounds.get(gottenPath);
	}

	#if FEATURE_MODS
	public static inline function mods(key:String = ''):String
	{
		return 'mods/$key';
	}

	public static inline function modsFont(key:String):String
	{
		return modFolders('fonts/$key');
	}

	public static inline function modsJson(key:String):String
	{
		return modFolders('data/$key.json');
	}

	public static inline function modsVideo(key:String):String
	{
		return modFolders('videos/$key.$VIDEO_EXT');
	}

	public static inline function modsSounds(path:String, key:String):String
	{
		return modFolders('$path/$key.$SOUND_EXT');
	}

	public static inline function modsImages(key:String):String
	{
		return modFolders('images/$key.png');
	}

	public static inline function modsXml(key:String):String
	{
		return modFolders('images/$key.xml');
	}

	public static inline function modsTxt(key:String):String
	{
		return modFolders('images/$key.txt');
	}

	public static inline function modsShaderFragment(key:String):String
	{
		return modFolders('shaders/$key.frag');
	}

	public static inline function modsShaderVertex(key:String):String
	{
		return modFolders('shaders/$key.vert');
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
				if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder))
				{
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
