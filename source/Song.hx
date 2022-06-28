package;

import Difficulty.DifficultyDef;
import Event.EventGroup;
import compat.chart.ChartParser;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import haxe.Json;
import haxe.io.Path;

using StringTools;

typedef SongWrapper =
{
	var song:Song;
}

typedef SongDef =
{
	/**
	 * The internal name of the song, as used in the file system.
	 */
	var songId:String;

	/**
	 * The readable name of the song, as displayed to the user.
	 * Can be any string.
	 */
	var songName:String;

	// /**
	//  * Since this is sometimes used to play a song with a different ID from the chart, I may add it again for that.
	//  */
	// var ?song:String;
	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var arrowSkin:String;
	var splashSkin:String;
	var ?bpm:Float;
	var ?speed:Float;
	var ?needsVoices:Bool;
	var ?validScore:Bool;
	var notes:Array<Section>;
	var ?events:Array<EventGroup>;
	var chartVersion:String;
}

@:forward
@:structInit // Allows creating a Song as if it were an anonymous structure
abstract Song(SongDef) from SongDef to SongDef
{
	/**
	 * The song ID used in case the requested song is missing.
	 */
	public static inline final DEFAULT_SONG:String = 'tutorial';

	public static final LATEST_CHART:String = 'MOCK 1.0';

	public static function createTemplateSong():Song
	{
		var song:Song = {
			songId: 'test',
			songName: 'Test',
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			arrowSkin: 'NOTE_assets',
			splashSkin: 'noteSplashes',
			bpm: 150,
			speed: 1,
			needsVoices: true,
			validScore: false,
			notes: [],
			events: [],
			chartVersion: LATEST_CHART
		};
		return song;
	}

	public static function fromJsonString(rawJson:String):Song
	{
		var songWrapper:SongWrapper = Json.parse(rawJson);
		var songMetadataDef:SongMetadataDef = {name: songWrapper.song.songName};

		return parseJson('rawsong', songWrapper, songMetadataDef);
	}

	public static function getSongDef(id:String, difficulty:String, ?folder:String):Song
	{
		if (folder == null)
		{
			folder = id;
		}

		var songWrapper:SongWrapper = getSongWrapper(id, difficulty, folder);
		var songMetadataDef:SongMetadataDef = SongMetadata.getSongMetadata(id, folder);

		var song:Song = parseJson(id, songWrapper, songMetadataDef);
		return conversionChecks(song);
	}

	public static function loadSong(id:String, difficulty:String, ?folder:String):Song
	{
		return getSongDef(id, difficulty, folder);
	}

	public static function getSongWrapper(id:String, difficulty:String, ?folder:String):SongWrapper
	{
		if (folder == null)
		{
			folder = id;
		}
		var songWrapper:SongWrapper = Paths.getJson(Path.join(['songs', folder, '$id$difficulty']));
		return songWrapper;
	}

	public static function parseJson(id:String, songWrapper:SongWrapper, songMetadataDef:SongMetadataDef):Song
	{
		if (songWrapper == null)
		{
			Debug.logError('Could not find song data for song "$id"; using default');
			songWrapper = getSongWrapper(DEFAULT_SONG, '');
		}

		var song:Song = songWrapper.song;

		song.songId = id;

		// Inject info from _meta.json.
		if (songMetadataDef != null && songMetadataDef.name != null)
		{
			song.songName = songMetadataDef.name;
		}
		else
		{
			song.songName = song.songId.split('-').join(' ');
		}

		// This is for in case I want to add something to the JSON files which allows for playing a song with a different ID than the chart
		// if (song.song == null)
		// {
		// 	song.song = song.songId;
		// }

		// song.offset = songMetadataDef.offset != null ? songMetadataDef.offset : 0;

		return song;
	}

	public static function generateTimings(song:Song, songMultiplier:Float = 1):Void
	{
		TimingStruct.clearTimings();

		var currentIndex:Int = 0;
		for (eventGroup in song.events)
		{
			for (event in eventGroup.events)
			{
				if (event.type == 'Change BPM')
				{
					var startBeat:Float = eventGroup.beat;

					var endBeat:Float = Math.POSITIVE_INFINITY;

					var bpm:Float = Std.parseFloat(event.value1) * songMultiplier;

					TimingStruct.addTiming(startBeat, bpm, endBeat, 0); // offset in this case = start time since we don't have a offset

					if (currentIndex != 0)
					{
						var data:TimingStruct = TimingStruct.allTimings[currentIndex - 1];
						data.endBeat = startBeat;
						data.length = ((data.endBeat - data.startBeat) / (data.bpm / TimingConstants.SECONDS_PER_MINUTE)) / songMultiplier;
						var step:Float = Conductor.calculateSemiquaverLength(data.bpm);
						TimingStruct.allTimings[currentIndex].startStep = Math.floor((((data.endBeat / (data.bpm / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / step) / songMultiplier);
						TimingStruct.allTimings[currentIndex].startTime = data.startTime + data.length / songMultiplier;
					}

					currentIndex++;
				}
			}
		}
	}

	public static function recalculateAllSectionTimes(song:Song):Void
	{
		for (i => section in song.notes) // loops through sections
		{
			var currentBeat:Int = i * Conductor.CROTCHETS_PER_MEASURE;

			var start:Float = TimingStruct.getTimeFromBeat(currentBeat);

			if (start == -1)
				continue;

			section.startTime = start;

			if (i != 0)
				song.notes[i - 1].endTime = section.startTime;
			section.endTime = Math.POSITIVE_INFINITY;
		}
	}

	private static function conversionChecks(song:Song):Song // Convert old charts to newest format
	{
		// if (song.player1 == null)
		// {
		// 	song.player1 = 'bf';
		// }
		// if (song.player2 == null)
		// {
		// 	song.player2 = 'dad';
		// }
		// if (song.gfVersion == null)
		// {
		// 	song.gfVersion = 'gf';
		// }
		// if (song.stage == null)
		// {
		// 	song.stage = 'stage';
		// }
		// if (song.arrowSkin == null)
		// {
		// 	song.arrowSkin = 'NOTE_assets';
		// }
		// if (song.splashSkin == null)
		// {
		// 	song.splashSkin = 'noteSplashes';
		// }
		// if (song.bpm == null)
		// {
		// 	song.bpm = 150; // Just the BPM of the test song
		// }
		// if (song.speed == null)
		// {
		// 	song.speed = 1;
		// }
		// if (song.needsVoices == null)
		// {
		// 	song.needsVoices = true;
		// }
		// if (song.validScore == null)
		// {
		// 	song.validScore = true;
		// }
		// if (song.notes == null)
		// {
		// 	song.notes = [];
		// }

		song = ChartParser.convertToMock(song);

		Song.generateTimings(song);

		for (eventGroup in song.events)
		{
			if (!Reflect.hasField(eventGroup, 'beat'))
			{
				eventGroup.beat = TimingStruct.getBeatFromTime(eventGroup.strumTime);
			}
			else if (eventGroup.beat < 0)
			{
				eventGroup.beat = TimingStruct.getBeatFromTime(eventGroup.strumTime);
			}
			else
			{
				eventGroup.strumTime = TimingStruct.getTimeFromBeat(eventGroup.beat);
			}
		}

		Song.recalculateAllSectionTimes(song);

		for (section in song.notes)
		{
			for (note in section.sectionNotes)
			{
				if (note.beat == null)
				{
					note.beat = TimingStruct.getBeatFromTime(note.strumTime);
				}
			}

			Reflect.deleteField(section, 'changeBPM');
			Reflect.deleteField(section, 'bpm');
			Reflect.deleteField(section, 'typeOfSection');
		}

		song.events.sort((obj1:EventGroup, obj2:EventGroup) -> FlxSort.byValues(FlxSort.ASCENDING, obj1.beat, obj2.beat));

		song.chartVersion = LATEST_CHART;

		return song;
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
