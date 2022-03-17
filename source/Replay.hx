package;

import haxe.Json;
#if FEATURE_FILESYSTEM
import sys.FileSystem;
import sys.io.File;
#end

class Ana
{
	public var hitTime:Float;
	public var nearestNote:Array<Dynamic>;
	public var hit:Bool;
	public var hitJudge:String;
	public var key:Int;

	public function new(_hitTime:Float, _nearestNote:Array<Dynamic>, _hit:Bool, _hitJudge:String, _key:Int)
	{
		hitTime = _hitTime;
		nearestNote = _nearestNote;
		hit = _hit;
		hitJudge = _hitJudge;
		key = _key;
	}
}

class Analysis
{
	public var anaArray:Array<Ana>;

	public function new()
	{
		anaArray = [];
	}
}

typedef ReplayJSON =
{
	public var replayGameVer:String;
	public var timestamp:Date;
	public var songName:String;
	public var songDiff:Int;
	public var songNotes:Array<Array<Dynamic>>;
	public var songJudgements:Array<String>;
	public var noteSpeed:Float;
	public var chartPath:String;
	public var isDownscroll:Bool;
	public var sf:Int;
	public var sm:Bool;
	public var ana:Analysis;
}

class Replay
{
	public static final REPLAY_VERSION:String = "1.2"; // replay file version

	public var path:String = "";
	public var replay:ReplayJSON;

	public function new(path:String)
	{
		this.path = path;
		replay = {
			songName: "No Song Found",
			songDiff: 1,
			noteSpeed: 1.5,
			isDownscroll: false,
			songNotes: [],
			replayGameVer: REPLAY_VERSION,
			chartPath: "",
			sm: false,
			timestamp: Date.now(),
			sf: Options.save.data.safeFrames,
			ana: new Analysis(),
			songJudgements: []
		};
	}

	public static function loadReplay(path:String):Replay
	{
		var rep:Replay = new Replay(path);

		rep.loadFromJson();

		Debug.logTrace('Basic replay data:\nSong Name: ${rep.replay.songName}\nSong Diff: ${rep.replay.songDiff}');

		return rep;
	}

	public function saveReplay(notearray:Array<Array<Dynamic>>, judge:Array<String>, ana:Analysis):Void
	{
		#if FEATURE_STEPMANIA
		var chartPath:String = PlayState.isSM ? PlayState.pathToSm + "/converted.json" : "";
		#else
		var chartPath:String = "";
		#end

		var json /*:ReplayJSON*/ = {
			"songId": PlayState.song.songId,
			"songName": PlayState.song.songName,
			"songDiff": PlayState.storyDifficulty,
			"chartPath": chartPath,
			"sm": PlayState.isSM,
			"timestamp": Date.now(),
			"replayGameVer": REPLAY_VERSION,
			"sf": Options.save.data.safeFrames,
			"noteSpeed": PlayState.instance.songSpeed,
			"isDownscroll": Options.save.data.downScroll,
			"songNotes": notearray,
			"songJudgements": judge,
			"ana": ana
		};

		var data:String = Json.stringify(json, null, "");

		var time:Float = Date.now().getTime();

		#if FEATURE_FILESYSTEM
		if (!FileSystem.exists(Sys.getCwd() + "/assets/replays"))
			FileSystem.createDirectory(Sys.getCwd() + "/assets/replays");
		File.saveContent("assets/replays/replay-" + PlayState.song.songId + "-time" + time + ".kadeReplay", data);

		path = "replay-" + PlayState.song.songId + "-time" + time + ".kadeReplay"; // for score screen shit

		loadFromJson();

		replay.ana = ana;
		#end
	}

	public function loadFromJson():Void
	{
		#if FEATURE_FILESYSTEM
		Debug.logTrace('Loading ${Sys.getCwd()}assets/replays/$path replay...');
		try
		{
			var repl:ReplayJSON = cast Json.parse(File.getContent('${Sys.getCwd()}assets/replays/$path'));
			replay = repl;
		}
		catch (e)
		{
			Debug.logError('Error loading replay: ${e.message}');
		}
		#end
	}
}
