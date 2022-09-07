package funkin.util;

import animateatlas.AtlasFrameMaker;
import animateatlas.JSONData.AnimationData;
import animateatlas.JSONData.AtlasData;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.system.FlxSound;
import funkin.fs.FileSystemCP;
import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.AssetType;

using StringTools;

#if FEATURE_MODS
import funkin.Mod.ModEnableState;
#end

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

	// TODO Make a function called folder() which can determine whether a folder exists and return its path
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

	public static inline function audio(key:String, ?library:String):String
	{
		return file(Path.join(['audios', Path.withExtension(key, AUDIO_EXT)]), SOUND, library);
	}

	public static inline function sound(key:String, ?library:String):String
	{
		return audio(Path.join(['sounds', key]), library);
	}

	public static inline function music(key:String, ?library:String):String
	{
		return audio(Path.join(['music', key]), library);
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
		if (exists(path))
		{
			return getTextDirect(path);
		}
		Debug.logError('Could not find text file with key "$key" and library "$library"');
		return null;
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

	public static function getFrames(key:String, ?library:String, format:FrameFormat = SPARROW):FlxFramesCollection
	{
		switch (format)
		{
			case SPARROW:
				return getSparrowFrames(key, library);
			case SPRITE_SHEET_PACKER:
				return getSpriteSheetPackerFrames(key, library);
			case TEXTURE_ATLAS:
				return getTextureAtlasFrames(key, library);
			case AUTO:
				var xmlPath:String = file(Path.join(['images', Path.withExtension(key, XML_EXT)]), library);
				if (exists(xmlPath))
					return getSparrowFrames(key, library);
				var txtPath:String = file(Path.join(['images', Path.withExtension(key, TEXT_EXT)]), library);
				if (exists(txtPath))
					return getSpriteSheetPackerFrames(key, library);
				var spritemapPath:String = file(Path.join(['images', key, Path.withExtension('Animation', JSON_EXT)]), library);
				if (exists(spritemapPath))
					return getTextureAtlasFrames(key, library);
				return null;
		}
	}

	// FIXME Failing to retrieve a sparrow atlas will eventually cause a crash due to a shader-related NPE
	public static function getSparrowFrames(key:String, ?library:String):FlxFramesCollection
	{
		var imagePath:String = image(key, library);
		if (exists(imagePath))
		{
			var xmlPath:String = file(Path.join(['images', Path.withExtension(key, XML_EXT)]), library);
			if (exists(xmlPath))
			{
				return FlxAtlasFrames.fromSparrow(getGraphicDirect(imagePath), getTextDirect(xmlPath));
			}
			Debug.logError('Could not find sparrow atlas XML file with key "$key" and library "$library"');
			return null;
		}
		Debug.logError('Could not find sparrow atlas graphic with key "$key" and library "$library"');
		return null;
	}

	public static function getSpriteSheetPackerFrames(key:String, ?library:String):FlxFramesCollection
	{
		var imagePath:String = image(key, library);
		if (exists(imagePath))
		{
			var txtPath:String = file(Path.join(['images', Path.withExtension(key, TEXT_EXT)]), library);
			if (exists(txtPath))
			{
				return FlxAtlasFrames.fromSpriteSheetPacker(getGraphicDirect(imagePath), getTextDirect(txtPath));
			}
			Debug.logError('Could not find spritesheet packer atlas text file with key "$key" and library "$library"');
			return null;
		}
		Debug.logError('Could not find spritesheet packer atlas graphic with key "$key" and library "$library"');
		return null;
	}

	public static function getTextureAtlasFrames(key:String, ?library:String, smoothing:Bool = true):FlxFramesCollection
	{
		if (Paths.exists(file(Path.join(['images', Path.withExtension('spritemap1', Paths.JSON_EXT)]), TEXT, library)))
		{
			Debug.logWarn('Only Spritemaps made with Adobe Animate 2018 are supported!');
			return null;
		}

		var imagePath:String = image(Path.join([key, 'spritemap']), library);
		var graphicAsset:FlxGraphicAsset = Paths.getGraphicDirect(imagePath);

		var atlasPath:String = file(Path.join(['images', Path.withExtension('spritemap', Paths.JSON_EXT)]), TEXT, library);
		var atlasData:AtlasData = null;
		try
		{
			atlasData = Json.parse(Paths.getTextDirect(atlasPath).replace('\uFEFF', ''));
		}
		catch (e:Exception)
		{
			Debug.logError('Error reading atlas JSON in directory $atlasPath: $e');
			return null;
		}

		var animationPath:String = file(Path.join(['images', Path.withExtension('Animation', Paths.JSON_EXT)]), TEXT, library);
		var animationData:AnimationData = Paths.getJsonDirect(animationPath);

		return AtlasFrameMaker.construct(graphicAsset, atlasData, animationData, null, smoothing);
	}

	public static function getGraphic(key:String, ?library:String):FlxGraphicAsset
	{
		var path:String = image(key, library);
		if (exists(path, IMAGE))
		{
			return getGraphicDirect(path);
		}
		Debug.logError('Could not find graphic with key "$key" and library "$library"');
		return null;
	}

	public static function getGraphicDirect(path:String):FlxGraphicAsset
	{
		if (exists(path, IMAGE))
		{
			var newGraphic:Null<FlxGraphicAsset> = null;
			if (Assets.exists(path, IMAGE))
			{
				newGraphic = Assets.getBitmapData(path);
				// newGraphic = FlxAssets.getBitmapData(path); // Flixel has REALLY strange and inefficient API...
			}
			else if (fileSystem.exists(path))
			{
				newGraphic = BitmapData.fromFile(path);
				Assets.cache.setBitmapData(path, newGraphic);
			}
			return newGraphic;
		}
		Debug.logError('Could not find graphic at path "$path"');
		return null;
	}

	public static function getSound(key:String, ?library:String):FlxSoundAsset
	{
		var path:String = sound(key, library);
		if (exists(path, SOUND))
		{
			return getAudioDirect(path);
		}
		Debug.logError('Could not find sound with key "$key" and library "$library"');
		return null;
	}

	public static function getMusic(key:String, ?library:String):FlxSoundAsset
	{
		var path:String = music(key, library);
		if (exists(path, SOUND))
		{
			return getAudioDirect(path);
		}
		Debug.logError('Could not find music with key "$key" and library "$library"');
		return null;
	}

	public static function getVoices(songId:String):FlxSoundAsset
	{
		var path:String = voices(songId);
		if (exists(path, SOUND))
		{
			return getAudioDirect(path);
		}
		Debug.logError('Could not find vocals for song "$songId"');
		return null;
	}

	public static function getInst(songId:String):FlxSoundAsset
	{
		var path:String = inst(songId);
		if (exists(path, SOUND))
		{
			return getAudioDirect(path);
		}
		Debug.logError('Could not find instrumental for song "$songId"');
		return null;
	}

	public static function getAudio(key:String, ?library:String):FlxSoundAsset
	{
		var path:String = audio(key, library);
		if (exists(path))
		{
			return getAudioDirect(path);
		}
		Debug.logError('Could not find audio with key "$key" and library "$library"');
		return null;
	}

	public static function getAudioDirect(path:String):FlxSoundAsset
	{
		if (exists(path, SOUND))
		{
			var newSound:Null<FlxSoundAsset> = null;
			if (Assets.exists(path, SOUND))
			{
				newSound = Assets.getSound(path);
				// newSound = FlxAssets.getSound(path);
			}
			else if (fileSystem.exists(path))
			{
				newSound = Sound.fromFile(path);
				Assets.cache.setSound(path, newSound);
			}
			return newSound;
		}
		Debug.logError('Could not find audio at path "$path"');
		return null;
	}

	public static function getRandomSound(key:String, min:Int, max:Int, ?library:String):FlxSoundAsset
	{
		return getSound('$key${FlxG.random.int(min, max)}', library);
	}

	public static function getJson(key:String, ?library:String):Any
	{
		var path:String = json(key, library);
		if (exists(path))
		{
			return getJsonDirect(path);
		}
		Debug.logError('Could not find JSON with key "$key" and library "$library"');
		return null;
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
					Debug.logError('Error parsing JSON file from path "$path": ${e.message}');
					return null;
				}
			}
		}
		Debug.logError('Could not find JSON at path "$path"');
		return null;
	}

	public static function getXml(key:String, ?library:String):Xml
	{
		var path:String = xml(key, library);
		if (exists(path))
		{
			return getXmlDirect(path);
		}
		Debug.logError('Could not find XML with key "$key" and library "$library"');
		return null;
	}

	public static function getXmlDirect(path:String):Xml
	{
		if (exists(path))
		{
			var rawXml:Null<String> = getTextDirect(path);
			if (rawXml != null)
			{
				try
				{
					// Attempt to parse and return the XML data.
					return Xml.parse(rawXml);
				}
				catch (e:Exception)
				{
					Debug.logError('Error parsing XML file from path "$path": ${e.message}');
					return null;
				}
			}
		}
		Debug.logError('Could not find XML at path "$path"');
		return null;
	}

	public static function precacheGraphic(key:String, ?library:String):Void
	{
		var path:String = image(key, library);
		if (exists(path, IMAGE))
		{
			precacheGraphicDirect(path);
			return;
		}
		Debug.logError('Could not find graphic to precache with key "$key" and library "$library"');
	}

	public static function precacheGraphicDirect(path:String):Void
	{
		FlxG.bitmap.add(getGraphicDirect(path));
	}

	public static function precacheSound(key:String, ?library:String):Void
	{
		var path:String = sound(key, library);
		if (exists(path, SOUND))
		{
			precacheAudioDirect(path);
			return;
		}
		Debug.logError('Could not find sound to precache with key "$key" and library "$library"');
	}

	public static function precacheMusic(key:String, ?library:String):Void
	{
		var path:String = music(key, library);
		if (exists(path, SOUND))
		{
			precacheAudioDirect(path);
			return;
		}
		Debug.logError('Could not find music to precache with key "$key" and library "$library"');
	}

	public static function precacheAudio(key:String, ?library:String):Void
	{
		var path:String = audio(key, library);
		if (exists(path, SOUND))
		{
			precacheAudioDirect(path);
			return;
		}
		Debug.logError('Could not find audio to precache with key "$key" and library "$library"');
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
}

enum FrameFormat
{
	SPARROW;
	SPRITE_SHEET_PACKER;
	TEXTURE_ATLAS;
	AUTO;
}
