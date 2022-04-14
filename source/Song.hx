package;

import haxe.Json;
import Section.SectionData;

using StringTools;

typedef SongWrapper =
{
	var song:SongData;
}

typedef SongData =
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
	var notes:Array<SectionData>;
	var events:Array<Array<Dynamic>>;
}

// TODO SongMetaEditorState?
typedef SongMetaData =
{
	var ?offset:Int;
	var ?name:String;
	var ?icon:String;
	var ?color:Array<Int>; // TODO Make this an FlxColor (or an array of FlxColors, like Myth (They're actually hex Strings))
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
	// public var events:Array<EventNoteData>;
	public var events:Array<Array<Dynamic>>;

	public static function createTemplateSongData():SongData
	{
		var songData:SongData = {
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
		return songData;
	}

	public static function createTemplateSongMetaData():SongMetaData
	{
		var songMetaData:SongMetaData = {
			offset: 0,
			name: 'Test',
			icon: 'face',
			color: [146, 113, 253]
		}
		return songMetaData;
	}

	public function new(songId:String, difficulty:String, ?folder:String)
	{
		// TODO Set the song's ID and name in this constructor, and remove those two fields from SongData so they can be isolated to _meta.json files
		id = songId;
		var songData:SongData = loadFromJson(songId, difficulty, folder);
		copyDataFields(songData);
	}

	public function copyDataFields(songData:SongData):Void
	{
		player1 = songData.player1;
		player2 = songData.player2;
		gfVersion = songData.gfVersion;
		stage = songData.stage;
		bpm = songData.bpm;
		speed = songData.speed;
		needsVoices = songData.needsVoices;
		arrowSkin = songData.arrowSkin;
		splashSkin = songData.splashSkin;
		validScore = songData.validScore;
		sections = [];
		for (sectionData in songData.notes)
		{
			var section:Section = new Section(sectionData);
			sections.push(section);
		}
		// events = [];
		events = songData.events;
	}

	private static function conversionChecks(songData:SongData):Void // Convert old charts to newest format
	{
		if (songData.events == null)
		{
			songData.events = [];
			for (section in songData.notes)
			{
				var i:Int = 0;
				var notes:Array<Array<Dynamic>> = section.sectionNotes;
				var len:Int = notes.length;
				while (i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if (note[1] < 0)
					{
						songData.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else
						i++;
				}
			}
		}
	}

	public static function loadFromJsonDirect(rawJson:String):SongData
	{
		var songWrapper:SongWrapper = Json.parse(rawJson);
		var songMetaData:SongMetaData = {name: songWrapper.song.songName};

		return parseJson('rawsong', songWrapper, songMetaData);
	}

	public static function loadFromJson(id:String, difficulty:String, ?folder:String):SongData
	{
		if (folder == null)
		{
			folder = id;
		}

		var songWrapper:SongWrapper = getSongWrapper(id, difficulty, folder);
		var songMetaData:SongMetaData = getSongMetaData(id, folder);

		var songData:SongData = parseJson(id, songWrapper, songMetaData);
		conversionChecks(songData);
		if (id != 'events')
			Stage.loadDirectory(songData);
		return songData;
	}

	public static function getSongWrapper(id:String, difficulty:String, ?folder:String):SongWrapper
	{
		if (folder == null)
		{
			folder = id;
		}
		var songPath:String = 'songs/$folder/$id$difficulty';
		var songWrapper:SongWrapper = Paths.getJson(songPath);
		return songWrapper;
	}

	public static function getSongMetaData(id:String, ?folder:String):SongMetaData
	{
		if (folder == null)
		{
			folder = id;
		}
		var songMetaPath:String = Paths.json('songs/$folder/_meta');
		var songMetaData:SongMetaData = Paths.getJsonDirect(songMetaPath);

		if (songMetaData == null)
		{
			songMetaData = createTemplateSongMetaData();
			songMetaData.name = id.split('-').join(' ');
		}
		if (songMetaData.offset == null)
		{
			songMetaData.offset = 0;
		}
		if (songMetaData.name == null)
		{
			songMetaData.name = id.split('-').join(' ');
		}
		if (songMetaData.icon == null)
		{
			songMetaData.icon = 'face';
		}
		if (songMetaData.color == null || songMetaData.color.length != 3)
		{
			songMetaData.color = [146, 113, 253];
		}

		return songMetaData;
	}

	public static function parseJson(id:String, songWrapper:SongWrapper, songMetaData:SongMetaData):SongData
	{
		if (songWrapper == null)
		{
			Debug.logError('Could not find song data for song "$id"; using default');
			songWrapper = getSongWrapper(DEFAULT_SONG, '');
		}

		var songData:SongData = songWrapper.song;

		songData.songId = id;

		// Enforce default values for optional fields.
		if (songData.validScore == null)
			songData.validScore = true;

		// Inject info from _meta.json.
		if (songMetaData != null && songMetaData.name != null)
		{
			songData.songName = songMetaData.name;
		}
		else
		{
			songData.songName = id.split('-').join(' ');
		}

		// This is for in case I want to add something to the JSON files which allows for playing a song with a different ID than the chart
		// if (songData.song == null)
		// {
		// 	songData.song = songData.songId;
		// }

		// songData.offset = songMetaData.offset != null ? songMetaData.offset : 0;

		return songData;
	}
}
