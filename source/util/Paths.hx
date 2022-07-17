package util;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.system.FlxSound;
import fs.FileSystemCP;
import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.AssetType;

using StringTools;

#if FEATURE_MODS
import Mod.ModEnableState;
#end
#if USE_CUSTOM_CACHE
import flixel.graphics.FlxGraphic;
import flixel.util.FlxArrayUtil;
import openfl.system.System;
#end

// TODO For the cache, make a class implement openfl.utils.IAssetCache, and make an instance of it in here
class Paths
{
	#if FEATURE_MODS
	public static inline final MOD_DIRECTORY:String = 'mods'; // TODO Move a lot of the mod-related stuff from this file to ModCore.hx or Mod.hx
	#end
	public static inline final TEXT_EXT:String = 'txt';
	public static inline final JSON_EXT:String = 'json';
	#if FEATURE_SCRIPTS
	public static inline final SCRIPT_EXT:String = #if FEATURE_LUA 'lua' #elseif hscript 'hscript' #else '' #end;
	#end
	public static inline final IMAGE_EXT:String = 'png';
	public static inline final XML_EXT:String = 'xml';
	public static inline final FRAG_EXT:String = 'frag';
	public static inline final VERT_EXT:String = 'vert';
	// Just as a note, Flash uses the .wav format
	public static inline final AUDIO_EXT:String = 'ogg';
	public static inline final VIDEO_EXT:String = 'mp4';

	public static var dumpExclusions:Array<String> = [
		Path.withExtension('assets/music/freakyMenu', AUDIO_EXT),
		Path.withExtension('assets/music/breakfast', AUDIO_EXT),
		Path.withExtension('assets/music/tea-time', AUDIO_EXT),
	];

	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory():Void
	{
		#if USE_CUSTOM_CACHE
		// clear non local assets in the tracked assets list
		for (key in currentTrackedGraphics.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				// get rid of it
				var obj:FlxGraphicAsset = currentTrackedGraphics.get(key);
				if (obj != null)
				{
					Assets.cache.removeBitmapData(key);
					FlxG.bitmap.removeByKey(key);
					if (obj is FlxGraphic)
					{
						cast(obj, FlxGraphic).destroy();
					}
					currentTrackedGraphics.remove(key);
				}
			}
		}
		// run the garbage collector for good measure lmfao
		System.gc();
		#end
	}

	#if USE_CUSTOM_CACHE
	// define the locally tracked assets
	private static var localTrackedAssets:Array<String> = [];
	#end

	public static function clearStoredMemory():Void
	{
		#if USE_CUSTOM_CACHE
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj:FlxGraphicAsset = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedGraphics.exists(key))
			{
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap.removeByKey(key);
				if (obj is FlxGraphic)
				{
					cast(obj, FlxGraphic).destroy();
				}
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		FlxArrayUtil.clearArray(localTrackedAssets);
		#end
	}

	public static var currentModDirectory(default, set):String = '';

	private static function set_currentModDirectory(value:String = ''):String
	{
		if (currentModDirectory != value)
		{
			// Debug.logTrace('Setting mod directory to "$value"');
			currentModDirectory = value;
		}
		return value;
	}

	public static var currentLevel(default, set):String;

	private static function set_currentLevel(value:String):String
	{
		if (currentLevel != value)
		{
			Debug.logTrace('Setting asset folder to "$value"');
			currentLevel = value;
		}
		return value;
	}

	public static var fileSystem(get, null):IFileSystem;

	private static function get_fileSystem():IFileSystem
	{
		if (fileSystem == null)
			fileSystem = FileSystemCP.getFileSystem();

		return fileSystem;
	}

	public static function getPath(file:String):String
	{
		return Assets.getPath(file); // TODO Figure out how to properly use this OpenFL function
	}

	public static function getLibraryPath(file:String, library = 'preload'):String
	{
		return library == 'preload' || library == 'default' ? getPreloadPath(file) : getLibraryPathForce(file, library);
	}

	private static inline function getLibraryPathForce(file:String, library:String):String
	{
		return '$library:${getPreloadPath(Path.join([library, file]))}';
	}

	public static inline function getPreloadPath(file:String = ''):String
	{
		return Path.join(['assets', file]);
	}

	public static function file(file:String, type:AssetType = TEXT, ?library:String):String
	{
		#if FEATURE_MODS
		var modPath:String = modFolders(file);
		if (exists(modPath, type))
		{
			return modPath;
		}
		#end

		if (library != null)
		{
			var libraryPath:String = getLibraryPath(file, library);
			if (exists(libraryPath, type))
			{
				return libraryPath;
			}
		}

		if (currentLevel != null)
		{
			var levelPath:String = getLibraryPath(file, currentLevel);
			if (exists(levelPath, type))
			{
				return levelPath;
			}
		}

		var preloadPath:String = getPreloadPath(file);
		if (exists(preloadPath, type))
		{
			return preloadPath;
		}

		return null;
	}

	public static inline function txt(key:String, ?library:String):String
	{
		return file(Path.join(['data', Path.withExtension(key, TEXT_EXT)]), TEXT, library);
	}

	public static inline function json(key:String, ?library:String):String
	{
		return file(Path.join(['data', Path.withExtension(key, JSON_EXT)]), TEXT, library);
	}

	#if FEATURE_SCRIPTS
	public static inline function script(key:String, ?library:String):String
	{
		return file(Path.join(['data', Path.withExtension(key, SCRIPT_EXT)]), TEXT, library);
	}
	#end

	public static inline function image(key:String, ?library:String):String
	{
		return file(Path.join(['images', Path.withExtension(key, IMAGE_EXT)]), IMAGE, library);
	}

	public static inline function xml(key:String, ?library:String):String
	{
		return file(Path.join(['images', Path.withExtension(key, XML_EXT)]), TEXT, library);
	}

	// TODO Possibly make use of these shader methods
	public static inline function shaderFragment(key:String, ?library:String):String
	{
		return file(Path.join(['shaders', Path.withExtension(key, FRAG_EXT)]), TEXT, library);
	}

	public static inline function shaderVertex(key:String, ?library:String):String
	{
		return file(Path.join(['shaders', Path.withExtension(key, VERT_EXT)]), TEXT, library);
	}

	public static inline function sound(key:String, ?library:String):String
	{
		return file(Path.join(['sounds', Path.withExtension(key, AUDIO_EXT)]), SOUND, library);
	}

	public static inline function music(key:String, ?library:String):String
	{
		return file(Path.join(['music', Path.withExtension(key, AUDIO_EXT)]), MUSIC, library);
	}

	public static inline function voices(songId:String):String
	{
		return music(Path.join(['songs', songId, 'Voices']));
	}

	public static inline function inst(songId:String):String
	{
		return music(Path.join(['songs', songId, 'Inst']));
	}

	public static inline function video(key:String, ?library:String):String
	{
		return file(Path.join(['videos', Path.withExtension(key, VIDEO_EXT)]), BINARY, library);
	}

	public static inline function font(key:String, ?library:String):String
	{
		return file(Path.join(['fonts', key]), FONT, library);
	}

	public static inline function exists(path:String, type:AssetType = TEXT):Bool
	{
		if (path == null)
		{
			return false;
		}

		return (Assets.exists(path, type) || fileSystem.exists(path));
	}

	public static function getText(key:String, ?library:String, ignoreMods:Bool = false):String
	{
		var path:String = file(key, TEXT, library);
		return getTextDirect(path);
	}

	public static function getTextDirect(path:String):String
	{
		if (exists(path))
		{
			if (Assets.exists(path, TEXT))
			{
				return Assets.getText(path);
			}
			else if (fileSystem.exists(path))
			{
				return fileSystem.getFileContent(path);
			}
		}
		Debug.logError('Could not find text file at path "$path"');
		return null;
	}

	public static function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var imagePath:String = image(key, library);
		var xmlPath:String = xml(key, library);
		if (exists(xmlPath))
		{
			return FlxAtlasFrames.fromSparrow(exists(imagePath, IMAGE) ? getGraphicDirect(imagePath) : imagePath,
				exists(xmlPath) ? getTextDirect(xmlPath) : xmlPath);
		}
		Debug.logError('Could not find sparrow atlas with key "$key", and library "$library"');
		return null;
	}

	public static function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var imagePath:String = image(key, library);
		var txtPath:String = file(Path.join(['images', Path.withExtension(key, TEXT_EXT)]), library);
		if (exists(txtPath))
		{
			return FlxAtlasFrames.fromSpriteSheetPacker(exists(imagePath, IMAGE) ? getGraphicDirect(imagePath) : imagePath,
				exists(txtPath) ? getTextDirect(txtPath) : txtPath);
		}
		Debug.logError('Could not find packer atlas with key "$key", and library "$library"');
		return null;
	}

	#if USE_CUSTOM_CACHE
	private static var currentTrackedGraphics:Map<String, FlxGraphicAsset> = [];
	#end

	public static inline function getGraphic(key:String, ?library:String):FlxGraphicAsset
	{
		var path:String = image(key, library);
		return getGraphicDirect(path);
	}

	public static function getGraphicDirect(path:String):FlxGraphicAsset
	{
		if (exists(path, IMAGE))
		{
			#if USE_CUSTOM_CACHE
			if (!currentTrackedGraphics.exists(path))
			#end
			{
				var newGraphic:Null<FlxGraphicAsset> = null;
				if (Assets.exists(path, IMAGE))
				{
					newGraphic = Assets.getBitmapData(path);
				}
				else if (fileSystem.exists(path))
				{
					newGraphic = BitmapData.fromFile(path);
					Assets.cache.setBitmapData(path, newGraphic);
				}
				#if !USE_CUSTOM_CACHE
				return newGraphic;
				#else
				currentTrackedGraphics.set(path, newGraphic);
				#end
			}
			#if USE_CUSTOM_CACHE
			localTrackedAssets.push(path);
			return currentTrackedGraphics.get(path);
			#end
		}
		Debug.logError('Could not find graphic at path "$path"');
		return null;
	}

	#if USE_CUSTOM_CACHE
	private static var currentTrackedSounds:Map<String, FlxSoundAsset> = [];
	#end

	public static inline function getSound(key:String, ?library:String):FlxSoundAsset
	{
		return getAudio(Path.join(['sounds', key]), library);
	}

	public static inline function getMusic(key:String, ?library:String):FlxSoundAsset
	{
		return getAudio(Path.join(['music', key]), library);
	}

	public static inline function getVoices(songId:String):FlxSoundAsset
	{
		return getAudioDirect(voices(songId));
	}

	public static inline function getInst(songId:String):FlxSoundAsset
	{
		return getAudioDirect(inst(songId));
	}

	public static inline function getAudio(key:String, ?library:String):FlxSoundAsset
	{
		var path:String = file(Path.withExtension(key, AUDIO_EXT), SOUND, library);
		return getAudioDirect(path);
	}

	public static function getAudioDirect(path:String):FlxSoundAsset
	{
		if (exists(path, SOUND))
		{
			#if USE_CUSTOM_CACHE
			if (!currentTrackedSounds.exists(path))
			#end
			{
				var newSound:Null<FlxSoundAsset> = null;
				if (Assets.exists(path, SOUND))
				{
					newSound = Assets.getSound(path);
				}
				else if (fileSystem.exists(path))
				{
					newSound = Sound.fromFile(path);
					Assets.cache.setSound(path, newSound);
				}
				#if !USE_CUSTOM_CACHE
				return newSound;
				#else
				currentTrackedSounds.set(path, newSound);
				#end
			}
			#if USE_CUSTOM_CACHE
			localTrackedAssets.push(path);
			return currentTrackedSounds.get(path);
			#end
		}
		Debug.logError('Could not find sound at path "$path"');
		return null;
	}

	public static inline function getRandomSound(key:String, min:Int, max:Int, ?library:String):FlxSoundAsset
	{
		return getSound('$key${FlxG.random.int(min, max)}', library);
	}

	public static inline function getJson(key:String, ?library:String):Any
	{
		var path:String = json(key, library);
		return getJsonDirect(path);
	}

	public static function getJsonDirect(path:String):Any
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
				catch (e:Exception)
				{
					Debug.logError('Error parsing a JSON file from path "$path": ${e.message}');
					return null;
				}
			}
		}
		Debug.logError('Could not find JSON at path "$path"');
		return null;
	}

	public static function precacheGraphic(key:String, ?library:String):Void
	{
		FlxG.bitmap.add(getGraphic(key, library));
	}

	public static inline function precacheSound(key:String, ?library:String):Void
	{
		precacheAudioDirect(sound(key, library));
	}

	public static inline function precacheMusic(key:String, ?library:String):Void
	{
		precacheAudioDirect(music(key, library));
	}

	public static function precacheAudioDirect(path:String):Void
	{
		var audio:FlxSoundAsset = getAudioDirect(path);
		var flxSound:FlxSound = new FlxSound().loadEmbedded(audio);
		FlxG.sound.list.add(flxSound);
	}

	public static inline function formatToSongPath(path:String):String
	{
		return path.toLowerCase().replace(' ', '-'); // TODO Replace a bunch of usages of dashes with underscores because reasons
	}

	public static inline function formatFromSongPath(path:String):String
	{
		return path.replace('-', ' ');
	}

	#if FEATURE_MODS
	public static function modFolders(key:String):String
	{
		if (currentModDirectory != null && currentModDirectory.length > 0)
		{
			var fileToCheck:String = Path.join([currentModDirectory, key]);
			if (exists(fileToCheck))
			{
				return fileToCheck;
			}

			var fileToCheck:String = Path.join([Paths.MOD_DIRECTORY, currentModDirectory, key]);
			if (exists(fileToCheck))
			{
				return fileToCheck;
			}
		}
		return null;
	}

	public static function getModDirectories():Array<String>
	{
		var directories:Array<String> = [];
		var modsFolder:String = MOD_DIRECTORY;
		if (fileSystem.exists(modsFolder))
		{
			for (folder in fileSystem.readDirectory(modsFolder))
			{
				if (fileSystem.isDirectory(Path.join([Paths.MOD_DIRECTORY, folder])) && !directories.contains(folder))
				{
					directories.push(folder);
				}
			}
		}

		directories.sort((a:String, b:String) -> // Alphabetical sort
		{
			if (a > b)
			{
				return 1;
			}
			else if (a < b)
			{
				return -1;
			}
			else
			{
				return 0;
			}
		});

		return directories;
	}

	public static function getSortedModDirectories(omitDisabledMods:Bool = true):Array<String>
	{
		var directories:Array<String> = [];
		var disabledMods:Array<String> = [];
		var modListPath:String = 'modList.txt';
		if (exists(modListPath))
		{
			var modList:Array<String> = CoolUtil.listFromTextFile(modListPath);
			for (mod in modList)
			{
				var splitName:Array<String> = mod.trim().split('|');
				var directory:String = splitName[0];
				if (splitName[1] == '0') // Disable mod
				{
					disabledMods.push(directory);
				}
				else // Sort mod loading order based on modList.txt file
				{
					if (fileSystem.isDirectory(Path.join([Paths.MOD_DIRECTORY, directory]))
						&& !directories.contains(directory)
						&& directory != ''
						&& !omitDisabledMods
						|| !disabledMods.contains(directory))
					{
						directories.push(directory);
					}
				}
			}
		}

		var modsDirectories:Array<String> = getModDirectories();
		for (modDirectory in modsDirectories)
		{
			if (!directories.contains(modDirectory) && modDirectory != '' && !omitDisabledMods || !disabledMods.contains(modDirectory))
			{
				directories.push(modDirectory);
			}
		}

		return directories;
	}

	public static function getSortedModEnableStates():Array<ModEnableState>
	{
		var enableStates:Array<ModEnableState> = [];
		var modListPath:String = Path.withExtension('modList', TEXT_EXT);
		if (exists(modListPath))
		{
			var modList:Array<String> = CoolUtil.listFromTextFile(modListPath);
			for (mod in modList)
			{
				var splitName:Array<String> = mod.trim().split('|');
				var enabled:Bool = splitName[1] == '1';
				var enableState:ModEnableState = {
					title: splitName[0],
					enabled: enabled
				};
				if (!enableStates.contains(enableState) && enableState.title != '')
					enableStates.push(enableState);
			}
		}

		var modsDirectories:Array<String> = getModDirectories();
		for (modDirectory in modsDirectories)
		{
			var contains:Bool = false;
			for (enableState in enableStates)
			{
				if (enableState.title == modDirectory)
				{
					contains = true;
					break;
				}
			}
			if (!contains)
			{
				enableStates.push({
					title: modDirectory,
					enabled: true
				});
			}
		}

		return enableStates;
	}
	#end

	public static function getDirectoryLoadOrder(onlyIncludeCurrentMod:Bool = false):Array<String>
	{
		var directories:Array<String> = [];

		#if FEATURE_MODS
		if (onlyIncludeCurrentMod)
		{
			directories.push(Path.join([Paths.MOD_DIRECTORY, currentModDirectory]));
		}
		else
		{
			directories = directories.concat([
				for (i in getSortedModDirectories())
					Path.join([Paths.MOD_DIRECTORY, i])
			]);
		}
		#end

		directories.push(getPreloadPath());

		return directories;
	}

	// This is just taken from Kade Engine so the CachingState class doesn't have errors (even though it can compile without that class because I don't use it)
	public static function listSongsToCache():Array<String>
	{
		// We need to query OpenFlAssets, not the file system, because of Polymod.
		var soundAssets:Array<String> = Assets.list(MUSIC).concat(Assets.list(SOUND));

		// TODO: Maybe rework this to pull from a text file rather than scan the list of assets.
		var songNames:Array<String> = [];

		for (sound in soundAssets)
		{
			// Parse end-to-beginning to support mods.
			var path:Array<String> = sound.split('/');
			path.reverse();

			var fileName:String = path[0];
			var songName:String = path[1];

			if (path[2] != 'songs')
				continue;

			// Remove duplicates.
			if (songNames.indexOf(songName) != -1)
				continue;

			songNames.push(songName);
		}

		return songNames;
	}
}
