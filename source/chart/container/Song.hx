package chart.container;

import Difficulty.DifficultyDef;
import chart.container.Event.EventGroup;
import chart.io.ChartUtils;
import chart.io.MockChartReader.MockNote;
import chart.io.MockChartReader.MockSection;
import chart.io.MockChartReader.MockSong;
import chart.io.MockChartReader.MockSongWrapper;
import flixel.FlxG;
import flixel.system.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import haxe.Json;
import haxe.io.Path;

using StringTools;

class Song
{
	/**
	 * The song ID used in case the requested song is missing.
	 */
	public static inline final DEFAULT_SONG:String = 'tutorial';

	public static final LATEST_CHART:String = 'MOCK 1.0';

	/**
	 * The internal name of the song, as used in the file system.
	 */
	public var id:String;

	/**
	 * The readable name of the song, as displayed to the user.
	 * Can be any string.
	 */
	public var name:String;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var stage:String = 'stage';
	public var noteSkin:String = 'NOTE_assets';
	public var splashSkin:String = 'noteSplashes';

	public var bpm:Float = 120;
	public var speed:Float = 1;
	public var needsVoices:Bool = true;
	public var validScore:Bool = true;

	public var notes:Array<Section> = [];

	public var events:Array<EventGroup> = [];

	public var chartVersion:String = LATEST_CHART;

	public var vocals:FlxSound;
	public var inst(get, never):FlxSound;

	// public var timings:Array<TimingStruct>;

	private function get_inst():FlxSound
	{
		return FlxG.sound.music;
	}

	public static function createTemplateSong():Song
	{
		var song:Song = new Song();
		song.id = 'test';
		song.name = 'Test';
		song.bpm = 150; // This is the tempo of the "Test" song

		return song;
	}

	public static function fromJsonString(rawJson:String):Song
	{
		var songWrapper:MockSongWrapper = Json.parse(rawJson);
		var songDef:MockSong = songWrapper.song;

		var song:Song = createFromSongDef(songDef);
		song.id = 'rawsong';
		song.name = 'Raw Song';
		return song;
	}

	public static function getSongDef(id:String, difficulty:String, ?folder:String):MockSong
	{
		if (folder == null)
		{
			folder = id;
		}

		var songWrapper:MockSongWrapper = getSongWrapper(id, difficulty, folder);
		if (songWrapper == null)
		{
			Debug.logError('Could not find song data for song "$id"; using default');
			songWrapper = getSongWrapper(DEFAULT_SONG, '');
		}
		var songDef:MockSong = songWrapper.song;
		return songDef;
	}

	public static function loadSong(id:String, difficulty:String, ?folder:String):Song
	{
		var songDef:MockSong = getSongDef(id, difficulty, folder);
		var songMetadataDef:SongMetadataDef = SongMetadata.getSongMetadata(id, folder);

		var song:Song = createFromSongDef(songDef);
		song.id = id;
		song.name = songMetadataDef == null ? Paths.formatFromSongPath(id) : songMetadataDef.name;

		return song;
	}

	public static function getSongWrapper(id:String, difficulty:String, ?folder:String):MockSongWrapper
	{
		if (folder == null)
		{
			folder = id;
		}
		var songWrapper:MockSongWrapper = Paths.getJson(Path.join(['songs', folder, '$id$difficulty']));
		return songWrapper;
	}

	public static function createFromSongDef(songDef:MockSong):Song
	{
		var song:Song = ChartUtils.read(songDef);

		TimingStruct.generateTimings(song);

		song.recalculateAllSectionTimes();

		song.events.sort((obj1:EventGroup, obj2:EventGroup) -> FlxSort.byValues(FlxSort.ASCENDING, obj1.beat, obj2.beat));

		song.chartVersion = LATEST_CHART;

		return song;
	}

	public static function toSongDef(song:Song):MockSong
	{
		var songDef:MockSong = {
			player1: song.player1,
			player2: song.player2,
			gfVersion: song.gfVersion,
			stage: song.stage,
			noteSkin: song.noteSkin,
			splashSkin: song.splashSkin,
			bpm: song.bpm,
			speed: song.speed,
			needsVoices: song.needsVoices,
			validScore: song.validScore,
			notes: [],
			events: song.events,
			chartVersion: LATEST_CHART
		}

		for (section in song.notes)
		{
			// TODO Marking this so I can change this if I change the note format
			var sectionNotes:Array<MockNote> = [
				for (note in section.sectionNotes)
					{
						beat: note.beat,
						data: note.data,
						sustainLength: note.sustainLength,
						type: note.type
					}
			];
			var sectionDef:MockSection = {
				sectionNotes: sectionNotes,
				lengthInSteps: section.lengthInSteps,
				mustHitSection: section.mustHitSection,
				gfSection: section.gfSection,
				altAnim: section.altAnim
			}
			songDef.notes.push(sectionDef);
		}

		return songDef;
	}

	public function recalculateAllSectionTimes():Void
	{
		var startBeat:Float = 0;
		for (i => section in notes) // loops through sections
		{
			var endBeat:Float = startBeat + Math.floor(section.lengthInSteps / Conductor.SEMIQUAVERS_PER_CROTCHET);

			var startTime:Float = TimingStruct.getTimeFromBeat(startBeat);
			var endTime:Float = TimingStruct.getTimeFromBeat(endBeat);

			section.startBeat = startBeat;
			section.endBeat = endBeat;
			section.startTime = startTime;
			section.endTime = endTime;

			startBeat = endBeat;
		}
	}

	public function new()
	{
	}
}

typedef SongMetadataDef =
{
	var ?offset:Int;
	var ?name:String;
	var ?artist:String;
	var ?week:Int;
	var ?freeplayDialogue:Bool;
	var ?difficulties:Array<DifficultyDef>;
	var ?initDifficulty:String;
	// var ?songOptions:Array<Dynamic>;
	// var ?hasExtraDifficulties:Bool;
	var ?icon:String;
	var ?background:String;
	var ?colors:Array<String>;
}

class SongMetadata
{
	public var id:String;
	public var folder:String;

	public var name:String;
	public var artist:String;
	public var week:Int;
	public var freeplayDialogue:Bool;
	// TODO Use individual song difficulties in Freeplay
	public var difficulties:Array<DifficultyDef>;
	public var initDifficulty:String;
	// public var songOptions:Array<Dynamic>;
	// public var hasExtraDifficulties:Bool;
	public var icon:String;
	public var background:String;
	public var colors:Array<FlxColor>;

	public static function createTemplateSongMetadataDef():SongMetadataDef
	{
		var songMetadataDef:SongMetadataDef = {
			offset: 0,
			name: 'Test',
			icon: 'face',
			colors: ['0xFF9271FD']
		}
		return songMetadataDef;
	}

	public static function getSongMetadata(id:String, ?folder:String):SongMetadataDef
	{
		if (folder == null)
		{
			folder = id;
		}

		var path:String = Paths.json(Path.join(['songs', folder, '_meta']));
		var songMetadataDef:SongMetadataDef = null;

		if (Paths.exists(path))
		{
			songMetadataDef = Paths.getJsonDirect(path);
		}
		else
		{
			songMetadataDef = createTemplateSongMetadataDef();
			songMetadataDef.name = id.split('-').join(' ');
		}

		return songMetadataDef;
	}

	public function new(songId:String, week:Int)
	{
		this.id = songId;
		folder = Paths.currentModDirectory;

		var songMetadataDef:SongMetadataDef = getSongMetadata(songId);
		name = songMetadataDef.name == null ? songId.split('-').join(' ') : songMetadataDef.name;
		artist = songMetadataDef.artist == null ? '' : songMetadataDef.artist;
		// this.week = songMetadataDef.week == null ? 0 : songMetadataDef.week;
		// FIXME Week number can be wrong depending on the mod order (E.G. a song with week 0 near the bottom of the Freeplay menu will have the difficulties of the first song)
		// this.week = songMetadataDef.week == null ? week : songMetadataDef.week;
		this.week = week;
		freeplayDialogue = songMetadataDef.freeplayDialogue == null ? false : songMetadataDef.freeplayDialogue;
		difficulties = songMetadataDef.difficulties == null ? [] : songMetadataDef.difficulties;
		initDifficulty = songMetadataDef.initDifficulty == null ? 'normal' : songMetadataDef.initDifficulty;
		icon = songMetadataDef.icon == null ? 'face' : songMetadataDef.icon;
		background = songMetadataDef.background == null ? 'default' : songMetadataDef.background;
		colors = songMetadataDef.colors == null ? [] : [for (hexString in songMetadataDef.colors) Std.parseInt(hexString)];
		if (colors.length == 0)
		{
			colors.push(0xFF9271FD);
		}
	}
}
