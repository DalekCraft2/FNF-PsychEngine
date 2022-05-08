package;

import Difficulty.DifficultyDef;
import Section.SectionDef;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.io.Path;

using StringTools;

typedef SongWrapper =
{
	var song:SongDef;
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
	var bpm:Float;
	var speed:Float;
	var needsVoices:Bool;
	var ?validScore:Bool;
	var notes:Array<SectionDef>;
	var events:Array<Array<Dynamic>>;
}

class Song
{
	/**
	 * The song ID used in case the requested song is missing.
	 */
	public static inline final DEFAULT_SONG:String = 'tutorial';

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
	public var bpm:Float;
	public var speed:Float = 1;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var validScore:Bool = true;
	public var sections:Array<Section>;
	// public var events:Array<EventNoteDef>;
	public var events:Array<Array<Dynamic>>;

	public static function createTemplateSongDef():SongDef
	{
		var songDef:SongDef = {
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
			events: []
		};
		return songDef;
	}

	private static function conversionChecks(songDef:SongDef):Void // Convert old charts to newest format
	{
		if (songDef.events == null)
		{
			songDef.events = [];
			for (section in songDef.notes)
			{
				var i:Int = 0;
				var notes:Array<Array<Dynamic>> = section.sectionNotes;
				var len:Int = notes.length;
				while (i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if (note[1] < 0)
					{
						songDef.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else
						i++;
				}

				// Compatibility with Kade Engine 1.8's per-section alt animations
				if (section.CPUAltAnim)
				{
					section.altAnim = true;
				}
				// ... and with Myth's
				if (section.CPUPrimaryAltAnim)
				{
					section.altAnim = true;
				}
			}
		}
	}

	public static function fromJsonString(rawJson:String):SongDef
	{
		var songWrapper:SongWrapper = Json.parse(rawJson);
		var songMetadataDef:SongMetadataDef = {name: songWrapper.song.songName};

		return parseJson('rawsong', songWrapper, songMetadataDef);
	}

	public static function getSongDef(id:String, difficulty:String, ?folder:String):SongDef
	{
		if (folder == null)
		{
			folder = id;
		}

		var songWrapper:SongWrapper = getSongWrapper(id, difficulty, folder);
		var songMetadataDef:SongMetadataDef = SongMetadata.getSongMetadata(id, folder);

		var songDef:SongDef = parseJson(id, songWrapper, songMetadataDef);
		conversionChecks(songDef);
		return songDef;
	}

	public static function getSong(id:String, difficulty:String, ?folder:String):Song
	{
		var songDef:SongDef = getSongDef(id, difficulty, folder);
		var songMetadataDef:SongMetadataDef = SongMetadata.getSongMetadata(id, difficulty);

		var song:Song = new Song(songDef);

		song.id = id;

		// Inject info from _meta.json.
		if (songMetadataDef != null && songMetadataDef.name != null)
		{
			song.name = songMetadataDef.name;
		}
		else
		{
			song.name = song.id.split('-').join(' ');
		}

		return song;
	}

	public static function loadSong(id:String, difficulty:String, ?folder:String):SongDef
	{
		var songDef:SongDef = getSongDef(id, difficulty, folder);
		if (id != 'events')
			Stage.loadDirectory(songDef);
		return songDef;
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

	public static function parseJson(id:String, songWrapper:SongWrapper, songMetadataDef:SongMetadataDef):SongDef
	{
		if (songWrapper == null)
		{
			Debug.logError('Could not find song data for song "$id"; using default');
			songWrapper = getSongWrapper(DEFAULT_SONG, '');
		}

		var songDef:SongDef = songWrapper.song;

		songDef.songId = id;

		// Enforce default values for optional fields.
		if (songDef.validScore == null)
			songDef.validScore = true;

		// Inject info from _meta.json.
		if (songMetadataDef != null && songMetadataDef.name != null)
		{
			songDef.songName = songMetadataDef.name;
		}
		else
		{
			songDef.songName = songDef.songId.split('-').join(' ');
		}

		// This is for in case I want to add something to the JSON files which allows for playing a song with a different ID than the chart
		// if (songDef.song == null)
		// {
		// 	songDef.song = songDef.songId;
		// }

		// songDef.offset = songMetadataDef.offset != null ? songMetadataDef.offset : 0;

		return songDef;
	}

	public function new(songDef:SongDef)
	{
		// TODO Set the song's ID and name in this constructor, and remove those two fields from SongDef so they can be isolated to _meta.json files
		player1 = songDef.player1;
		player2 = songDef.player2;
		gfVersion = songDef.gfVersion;
		stage = songDef.stage;
		bpm = songDef.bpm;
		speed = songDef.speed;
		needsVoices = songDef.needsVoices;
		arrowSkin = songDef.arrowSkin;
		splashSkin = songDef.splashSkin;
		validScore = songDef.validScore;
		sections = [];
		for (sectionDef in songDef.notes)
		{
			var section:Section = new Section(sectionDef);
			sections.push(section);
		}
		// events = [];
		events = songDef.events;
	}
}

// TODO SongMetadataEditorState?
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
			colors: ["0xFF9271FD"]
		}
		return songMetadataDef;
	}

	public static function getSongMetadata(id:String, ?folder:String):SongMetadataDef
	{
		if (folder == null)
		{
			folder = id;
		}
		var songMetadataDef:SongMetadataDef = Paths.getJson(Path.join(['songs', folder, '_meta']));

		if (songMetadataDef == null)
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
		this.week = songMetadataDef.week == null ? week : songMetadataDef.week;
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
