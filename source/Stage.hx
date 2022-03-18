package;

import Song.SongData;

using StringTools;

typedef StageData =
{
	var directory:String;
	var defaultZoom:Float;
	var isPixelStage:Bool;

	var boyfriend:Array<Float>;
	var girlfriend:Array<Float>;
	var opponent:Array<Float>;
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
	public var boyfriend:Array<Float>;
	public var girlfriend:Array<Float>;
	public var opponent:Array<Float>;
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

	public function copyDataFields(stageData:StageData):Void
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

	public static function loadDirectory(song:SongData):Void
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
		var stagePath:String = 'stages/$stage';
		return Paths.getJson(stagePath);
	}
}
