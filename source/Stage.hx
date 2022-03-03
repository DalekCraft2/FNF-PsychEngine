package;

import Song.SongData;
import haxe.Json;
#if FEATURE_MODS
import sys.FileSystem;
import sys.io.File;
#else
import openfl.utils.Assets;
#end

using StringTools;

typedef StageData =
{
	var directory:String;
	var defaultZoom:Float;
	var isPixelStage:Bool;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
}

class Stage
{
	public static var forceNextDirectory:String = null;

	public static function loadDirectory(SONG:SongData)
	{
		var stage:String = '';
		if (SONG.stage != null)
		{
			stage = SONG.stage;
		}
		else if (SONG.songId != null)
		{
			switch (SONG.songId)
			{
				case 'spookeez' | 'south' | 'monster':
					stage = 'spooky';
				case 'pico' | 'blammed' | 'philly' | 'philly-nice':
					stage = 'philly';
				case 'milf' | 'satin-panties' | 'high':
					stage = 'limo';
				case 'cocoa' | 'eggnog':
					stage = 'mall';
				case 'winter-horrorland':
					stage = 'mallEvil';
				case 'senpai' | 'roses':
					stage = 'school';
				case 'thorns':
					stage = 'schoolEvil';
				default:
					stage = 'stage';
			}
		}
		else
		{
			stage = 'stage';
		}

		var stageData:StageData = getStageFile(stage);
		if (stageData == null)
		{ // preventing crashes
			forceNextDirectory = '';
		}
		else
		{
			forceNextDirectory = stageData.directory;
		}
	}

	public static function getStageFile(stage:String):StageData
	{
		var rawJson:String = null;
		var path:String = Paths.getPreloadPath('stages/$stage.json');

		#if FEATURE_MODS
		var modPath:String = Paths.modFolders('stages/$stage.json');
		if (FileSystem.exists(modPath))
		{
			rawJson = File.getContent(modPath);
		}
		else if (FileSystem.exists(path))
		{
			rawJson = File.getContent(path);
		}
		#else
		if (Assets.exists(path))
		{
			rawJson = Assets.getText(path);
		}
		#end
	else
	{
		return null;
	}
		return cast Json.parse(rawJson);
	}
}
