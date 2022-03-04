package;

import Section.SectionData;
import haxe.Json;

using StringTools;

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

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var bpm:Float;
	var speed:Float;
	var needsVoices:Bool;
	var arrowSkin:String;
	var splashSkin:String;
	var ?validScore:Bool;
	var notes:Array<SectionData>;
	var events:Array<Dynamic>;
}

typedef SongMeta =
{
	var ?offset:Int;
	var ?name:String;
}

class Song
{
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
	public var events:Array<Dynamic>;

	public function new(songId:String, difficulty:String, ?folder:String)
	{
		// TODO Set the song's ID and name in this constructor, and remove those two fields from SongData so they can be isolated to _meta.json files
		id = songId;
		var songData:SongData = loadFromJson(songId, difficulty, folder);
		copyDataFields(songData);
	}

	public function copyDataFields(songData:SongData)
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
		sections = new Array();
		for (sectionData in songData.notes)
		{
			var section:Section = new Section(sectionData);
			sections.push(section);
		}
		events = songData.events;
	}

	private static function onLoadJson(songData:SongData) // Convert old charts to newest format
	{
		if (songData.events == null)
		{
			songData.events = [];
			for (secNum in 0...songData.notes.length)
			{
				var sec:SectionData = songData.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
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

	public static function loadFromJsonRaw(rawJson:String)
	{
		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}
		var jsonData = Json.parse(rawJson);

		return parseJson("rawsong", jsonData, ["name" => jsonData.name]);
	}

	public static function loadFromJson(songId:String, difficulty:String, ?folder:String):SongData
	{
		if (folder == null)
		{
			folder = songId;
		}

		var songPath = '$folder/$songId$difficulty';
		var songMetaPath = '$folder/_meta';

		var rawJson = Paths.loadJson(songPath);
		var rawMetaJson = Paths.loadJson(songMetaPath);

		var songData:SongData = parseJson(songId, rawJson, rawMetaJson);
		onLoadJson(songData);
		if (songId != 'events')
			Stage.loadDirectory(songData);
		return songData;
	}

	public static function parseJson(songId:String, jsonData:Dynamic, jsonMetaData:Dynamic):SongData
	{
		var songData:SongData = cast jsonData.song;

		songData.songId = songId;

		// Enforce default values for optional fields.
		if (songData.validScore == null)
			songData.validScore = true;

		// Inject info from _meta.json.
		var songMetaData:SongMeta = cast jsonMetaData;
		if (songMetaData.name != null)
		{
			songData.songName = songMetaData.name;
		}
		else
		{
			songData.songName = songId.split('-').join(' ');
		}

		// songData.offset = songMetaData.offset != null ? songMetaData.offset : 0;

		return songData;
	}
}
