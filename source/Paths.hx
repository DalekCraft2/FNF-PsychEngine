package;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.system.FlxAssets.FlxSoundAsset;
import haxe.Json;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets;

using StringTools;

#if sys
import haxe.io.Path;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;
#end

// TODO For the cache, make a class implement openfl.utils.IAssetCache, and make an instance of it in here
// TODO Also, in addition, use the normal Lime cache when on HTML5
class Paths
{
	// Just as a note, .wav is used on Flash instead of .mp3
	public static inline final SOUND_EXT:String = #if web 'mp3' #else 'ogg' #end;
	public static inline final VIDEO_EXT:String = 'mp4';

	#if FEATURE_MODS
	public static final IGNORE_MOD_FOLDERS:Array<String> = ['data', 'music', 'sounds', 'shaders', 'videos', 'images', 'fonts'];
	#end

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyMenu.$SOUND_EXT',
		'shared:assets/shared/music/breakfast.$SOUND_EXT',
		'shared:assets/shared/music/tea-time.$SOUND_EXT',
	];

	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory():Void
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedGraphics.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				// get rid of it
				var obj:FlxGraphic = currentTrackedGraphics.get(key);
				@:privateAccess
				if (obj != null)
				{
					Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedGraphics.remove(key);
				}
			}
		}
		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	public static function clearStoredMemory():Void
	{
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj:FlxGraphic = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedGraphics.exists(key))
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
		Assets.cache.clear('shared');
	}

	public static var currentModDirectory:String = '';
	public static var currentLevel:String;

	public static function setCurrentLevel(name:String):Void
	{
		Debug.logTrace('Setting asset folder to $name');
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:String):String
	{
		#if FEATURE_MODS
		var modPath:String = modFolders(file);
		if (exists(modPath))
		{
			return modPath;
		}
		#end

		if (library != null)
		{
			var libraryPath:String = getLibraryPath(file, library);
			if (exists(libraryPath))
			{
				return libraryPath;
			}
		}

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if (currentLevel != 'shared')
			{
				levelPath = getLibraryPathForce(file, currentLevel);
				if (exists(levelPath, type))
				{
					return levelPath;
				}
			}

			levelPath = getLibraryPathForce(file, 'shared');
			if (exists(levelPath, type))
			{
				return levelPath;
			}
		}

		// TODO Return null if a path does not exist
		var preloadPath:String = getPreloadPath(file);
		// if (exists(preloadPath))
		{
			return preloadPath;
		}

		// return null;
	}

	public static function getLibraryPath(file:String, library = 'preload'):String
	{
		return library == 'preload' || library == 'default' ? getPreloadPath(file) : getLibraryPathForce(file, library);
	}

	private static inline function getLibraryPathForce(file:String, library:String):String
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
		return file('data/$key.txt', TEXT, library);
	}

	public static inline function json(key:String, ?library:String):String
	{
		return file('data/$key.json', TEXT, library);
	}

	public static inline function lua(key:String, ?library:String):String
	{
		return file('data/$key.lua', TEXT, library);
	}

	public static inline function image(key:String, ?library:String):String
	{
		return file('images/$key.png', IMAGE, library);
	}

	public static inline function xml(key:String, ?library:String):String
	{
		return file('images/$key.xml', TEXT, library);
	}

	// TODO Possibly make use of these shader methods
	public static inline function shaderFragment(key:String, ?library:String):String
	{
		return file('shaders/$key.frag', TEXT, library);
	}

	public static inline function shaderVertex(key:String, ?library:String):String
	{
		return file('shaders/$key.vert', TEXT, library);
	}

	public static inline function video(key:String, ?library:String):String
	{
		return file('videos/$key.$VIDEO_EXT', BINARY, library);
	}

	public static inline function sound(key:String, ?library:String):String
	{
		return file('sounds/$key.$SOUND_EXT', SOUND, library);
	}

	public static inline function music(key:String, ?library:String):String
	{
		return file('music/$key.$SOUND_EXT', MUSIC, library);
	}

	public static inline function voices(songId:String):String
	{
		return music('songs/$songId/Voices', 'shared');
	}

	public static inline function inst(songId:String):String
	{
		return music('songs/$songId/Inst', 'shared');
	}

	public static inline function font(key:String, ?library:String):String
	{
		return file('fonts/$key', FONT, library);
	}

	public static inline function exists(path:String, type:AssetType = TEXT):Bool
	{
		return #if sys FileSystem.exists(path) || #end Assets.exists(path, type);
	}

	public static function getText(key:String, ?library:String, ?ignoreMods:Bool = false):String
	{
		var path:String = file(key, TEXT, library);
		return getTextDirect(path);
	}

	public static function getTextDirect(path:String):String
	{
		if (exists(path))
		{
			#if sys
			if (FileSystem.exists(path))
			{
				return File.getContent(path);
			}
			else
			#end
			if (Assets.exists(path, TEXT))
			{
				return Assets.getText(path);
			}
		}
		Debug.logError('Could not find text file at path "$path"');
		return null;
	}

	public static inline function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var imagePath:String = image(key, library);
		var xmlPath:String = xml(key, library);
		if (exists(xmlPath))
		{
			return FlxAtlasFrames.fromSparrow(exists(imagePath, IMAGE) ? getGraphicDirect(imagePath) : imagePath,
				exists(xmlPath) ? getTextDirect(xmlPath) : xmlPath);
		}
		Debug.logError('Could not find sparrow atlas at paths "$imagePath" and "$xmlPath"');
		return null;
	}

	public static inline function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var imagePath:String = image(key, library);
		var txtPath:String = file('images/$key.txt', library);
		if (exists(txtPath))
		{
			return FlxAtlasFrames.fromSpriteSheetPacker(exists(imagePath, IMAGE) ? getGraphicDirect(imagePath) : imagePath,
				exists(txtPath) ? getTextDirect(txtPath) : txtPath);
		}
		Debug.logError('Could not find packer atlas at paths "$imagePath" and "$txtPath"');
		return null;
	}

	public static var currentTrackedGraphics:Map<String, FlxGraphicAsset> = [];

	public static function getGraphic(key:String, ?library:String):FlxGraphicAsset
	{
		var path:String = image(key, library);
		return getGraphicDirect(path);
	}

	public static function getGraphicDirect(path:String):FlxGraphicAsset
	{
		if (exists(path, IMAGE))
		{
			if (!currentTrackedGraphics.exists(path))
			{
				var newGraphic:FlxGraphic;
				#if sys
				if (FileSystem.exists(path))
				{
					var newBitmap:BitmapData = BitmapData.fromFile(path);
					newGraphic = FlxGraphic.fromBitmapData(newBitmap, false, path);
				}
				else
				#end
				{
					newGraphic = FlxGraphic.fromAssetKey(path, false, path);
				}
				currentTrackedGraphics.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedGraphics.get(path);
		}
		Debug.logError('Could not find graphic at path "$path"');
		return null;
	}

	public static var currentTrackedSounds:Map<String, FlxSoundAsset> = [];

	public static function getSound(key:String, ?library:String):FlxSoundAsset
	{
		return getAudio('sounds/$key', library);
	}

	public static function getMusic(key:String, ?library:String):FlxSoundAsset
	{
		return getAudio('music/$key', library);
	}

	public static inline function getVoices(songId:String):FlxSoundAsset
	{
		return getMusic('songs/$songId/Voices', 'shared');
	}

	public static inline function getInst(songId:String):FlxSoundAsset
	{
		return getMusic('songs/$songId/Inst', 'shared');
	}

	public static function getAudio(key:String, ?library:String):FlxSoundAsset
	{
		var path:String = file('$key.$SOUND_EXT', SOUND, library);
		return getAudioDirect(path);
	}

	public static function getAudioDirect(path:String):FlxSoundAsset
	{
		if (exists(path, SOUND))
		{
			if (!currentTrackedSounds.exists(path))
			{
				var newSound:Sound;
				#if sys
				if (FileSystem.exists(path))
				{
					newSound = Sound.fromFile(path);
				}
				else
				#end
				{
					newSound = Assets.getSound(path);
				}
				currentTrackedSounds.set(path, newSound);
			}
			localTrackedAssets.push(path);
			return currentTrackedSounds.get(path);
		}
		Debug.logError('Could not find sound at path "$path"');
		return null;
	}

	public static inline function getRandomSound(key:String, min:Int, max:Int, ?library:String):FlxSoundAsset
	{
		return getSound('$key${FlxG.random.int(min, max)}', library);
	}

	public static function getJson(key:String, ?library:String):Dynamic
	{
		var path:String = json(key, library);
		return getJsonDirect(path);
	}

	public static function getJsonDirect(path:String):Dynamic
	{
		if (exists(path))
		{
			var rawJson:Null<String> = getTextDirect(path);
			if (rawJson != null)
			{
				try
				{
					// Attempt to parse and return the JSON data.
					return Json.parse(rawJson);
				}
				catch (e)
				{
					Debug.logError('Error parsing a JSON file from path "$path": $e');
					Debug.logError(e.stack);
					return null;
				}
			}
		}
		Debug.logError('Could not find JSON at path "$path"');
		return null;
	}

	public static inline function formatToSongPath(path:String):String
	{
		return path.toLowerCase().replace(' ', '-');
	}

	#if FEATURE_MODS
	public static inline function mods(key:String = ''):String
	{
		return Path.join(['mods', key]);
	}

	public static function modFolders(key:String):String
	{
		if (currentModDirectory != null && currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Path.join([currentModDirectory, key]));
			if (exists(fileToCheck))
			{
				return fileToCheck;
			}
		}
		return mods(key);
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

	public static function getDirectoryLoadOrder(onlyIncludeCurrentMod:Bool = false):Array<String>
	{
		var directories:Array<String> = [#if FEATURE_MODS mods(), #end getPreloadPath()];

		#if FEATURE_MODS
		if (onlyIncludeCurrentMod)
		{
			directories.push(mods(currentModDirectory));
		}
		#if sys
		else
		{
			var disabledMods:Array<String> = [];
			var modListPath:String = 'modList.txt';
			if (exists(modListPath))
			{
				var modList:Array<String> = CoolUtil.coolTextFile(modListPath);
				for (mod in modList)
				{
					var splitName:Array<String> = mod.trim().split('|');
					if (splitName[1] == '0') // Disable mod
					{
						disabledMods.push(splitName[0]);
					}
					else // Sort mod loading order based on modList.txt file
					{
						// TODO Maybe use the Path class as an object (or use its static methods) more often instead of Strings
						var path:String = mods(splitName[0]);
						if (FileSystem.isDirectory(path)
							&& !IGNORE_MOD_FOLDERS.contains(splitName[0])
							&& !disabledMods.contains(splitName[0])
							&& !directories.contains(path))
						{
							directories.push(path);
						}
					}
				}
			}

			var modsDirectories:Array<String> = getModDirectories();
			for (modDirectory in modsDirectories)
			{
				var modPath:String = mods(modDirectory);
				if (!disabledMods.contains(modDirectory) && !directories.contains(modPath))
				{
					directories.push(modPath);
				}
			}
		}
		#end
		#end

		return directories;
	}
}
