package funkin;

import funkin.Ratings.Judgement;
import funkin.chart.container.BasicNote;
import funkin.states.PlayState;
import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

// This probably isn't the correct word for it but I will leave it for now until I find another because this has a nice ring to it
class Analytic
{
	public var hitTime:Float;
	public var nearestNote:BasicNote;
	public var hit:Bool;
	public var hitJudge:Judgement;
	public var key:Int;

	public function new(_hitTime:Float, _nearestNote:BasicNote, _hit:Bool, _hitJudge:Judgement, _key:Int)
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
	public var anaArray:Array<Analytic> = [];

	public function new()
	{
	}
}

typedef ReplayDef =
{
	replayGameVer:String,
	timestamp:Date,
	songId:String,
	songName:String,
	songDiff:Int,
	songNotes:Array<Array<Any>>,
	songJudgements:Array<String>,
	noteSpeed:Float,
	chartPath:String,
	isDownscroll:Bool,
	sf:Float,
	sm:Bool,
	ana:Analysis
}

class Replay
{
	public static final REPLAY_VERSION:String = '1.2'; // replay file version

	public var path:String = '';
	public var replay:ReplayDef;

	public function new(path:String)
	{
		this.path = path;
		replay = {
			songId: 'nosong',
			songName: 'No Song Found',
			songDiff: 1,
			noteSpeed: 1.5,
			isDownscroll: false,
			songNotes: [],
			replayGameVer: REPLAY_VERSION,
			chartPath: '',
			sm: false,
			timestamp: Date.now(),
			sf: Options.profile.safeFrames,
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

	public function saveReplay(notearray:Array<Array<Any>>, judge:Array<String>, ana:Analysis):Void
	{
		var chartPath:String = #if FEATURE_STEPMANIA PlayState.isSM ? Path.join([PlayState.pathToSm, Path.withExtension('converted', Paths.JSON_EXT)]) : #end
		'';

		var json:ReplayDef = {
			songId: PlayState.song.id,
			songName: PlayState.song.name,
			songDiff: PlayState.storyDifficulty,
			chartPath: chartPath,
			sm: PlayState.isSM,
			timestamp: Date.now(),
			replayGameVer: REPLAY_VERSION,
			sf: Options.profile.safeFrames,
			noteSpeed: PlayState.instance.scrollSpeed,
			isDownscroll: Options.profile.downScroll,
			songNotes: notearray,
			songJudgements: judge,
			ana: ana
		};

		var data:String = Json.stringify(json, Constants.JSON_SPACE);

		var time:Float = Date.now().getTime();

		path = Path.withExtension('replay-${PlayState.song.id}-time$time', 'kadeReplay'); // for score screen shit

		#if sys
		var replayDirectory:String = Path.join(['assets', 'replays']);
		if (!Paths.fileSystem.exists(replayDirectory))
			FileSystem.createDirectory(replayDirectory);
		File.saveContent(Path.join([replayDirectory, path]), data);

		loadFromJson();

		replay.ana = ana;
		#end
	}

	public function loadFromJson():Void
	{
		var replayDirectory:String = Path.join(['assets', 'replays']);
		Debug.logTrace('Loading ${Path.join([replayDirectory, path])} replay...');
		try
		{
			var repl:ReplayDef = Paths.getJsonDirect(Path.join([replayDirectory, path]));
			replay = repl;
		}
		catch (e:Exception)
		{
			Debug.logError('Error loading replay: ${e.message}');
		}
	}
}
