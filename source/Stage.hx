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
	var hide_girlfriend:Bool;
	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;
}

/* TODO Move the hard-coded stage generation to here, 
	and use a map for storing the sprites (like Kade 1.8) instead of having dedicated variables for each one */
class Stage
{
	/**
	 * The internal name of the stage, as used in the file system.
	 */
	public var id:String;

	public var directory:String;
	public var defaultZoom:Float;
	public var isPixelStage:Bool;
	public var boyfriend:Array<Dynamic>;
	public var girlfriend:Array<Dynamic>;
	public var opponent:Array<Dynamic>;
	public var hide_girlfriend:Bool;
	public var camera_boyfriend:Array<Float>;
	public var camera_opponent:Array<Float>;
	public var camera_girlfriend:Array<Float>;
	public var camera_speed:Null<Float>;

	public function new(stageId:String)
	{
		id = stageId;
		var stageData:StageData = getStageData(stageId);
		copyDataFields(stageData);
	}

	public function copyDataFields(stageData:StageData)
	{
		directory = stageData.directory;
		defaultZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;
		boyfriend = stageData.boyfriend;
		girlfriend = stageData.girlfriend;
		opponent = stageData.opponent;
		hide_girlfriend = stageData.hide_girlfriend;
		camera_boyfriend = stageData.camera_boyfriend;
		camera_opponent = stageData.camera_opponent;
		camera_girlfriend = stageData.camera_girlfriend;
		camera_speed = stageData.camera_speed;
	}

	public static var forceNextDirectory:String = null;

	public static function loadDirectory(song:SongData)
	{
		var stage:String = '';
		if (song.stage != null)
		{
			stage = song.stage;
		}
		else if (song.songId != null)
		{
			switch (song.songId)
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

		var stageData:StageData = getStageData(stage);
		if (stageData == null)
		{ // preventing crashes
			forceNextDirectory = '';
		}
		else
		{
			forceNextDirectory = stageData.directory;
		}
	}

	public static function getStageData(stage:String):StageData
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
