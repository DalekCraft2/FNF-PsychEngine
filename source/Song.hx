package;

import Section.SectionData;
import haxe.Json;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef SongData =
{
	/**
	 * The readable name of the song, as displayed to the user.
	 		* Can be any string.
	 */
	var songName:String;

	/**
	 * The internal name of the song, as used in the file system.
	 */
	var songId:String;

	var notes:Array<SectionData>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var arrowSkin:String;
	var splashSkin:String;
	var ?validScore:Bool;
}

typedef SongMeta =
{
	var ?offset:Int;
	var ?name:String;
}

class Song
{
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
		var rawMetaJson = Paths.loadJson('$folder/_meta');

		var songData:SongData = parseJson(songId, rawJson, rawMetaJson);
		if (songId != 'events')
			Stage.loadDirectory(songData);
		onLoadJson(songData);
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
