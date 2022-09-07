package funkin.chart.container;

import flixel.util.FlxColor;
import funkin.Difficulty.DifficultyDef;
import haxe.io.Path;

using StringTools;

typedef SongMetadataDef =
{
	?name:String,
	?artist:String,
	?week:Int,
	?freeplayDialogue:Bool,
	?difficulties:Array<DifficultyDef>,
	?initDifficulty:String,
	// ?songOptions:Array<Dynamic>,
	// ?hasExtraDifficulties:Bool,
	?icon:String,
	?background:String,
	?colors:Array<String>
}

class SongMetadata
{
	public var id:String = 'test';
	public var folder:String = '';

	public var name:String = 'Test';
	public var artist:String = '';
	public var week:Int = 0;
	public var freeplayDialogue:Bool = false;
	// TODO Use individual song difficulties in Freeplay
	public var difficulties:Array<DifficultyDef> = [];
	public var initDifficulty:String = 'Normal';
	// public var songOptions:Array<Dynamic>;
	// public var hasExtraDifficulties:Bool;
	public var icon:String = 'face';
	public var background:String = 'default';
	public var colors:Array<FlxColor> = [new FlxColor(0xFF9271FD)];

	public static function createTemplateSongMetadataDef():SongMetadataDef
	{
		var songMetadataDef:SongMetadataDef = {
			name: 'Test',
			icon: 'face',
			colors: ['0xFF9271FD']
		}
		return songMetadataDef;
	}

	public static function getSongMetadataDef(id:String, ?folder:String):SongMetadataDef
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

	public static function getSongMetadata(id:String, ?folder:String, week:Int):SongMetadata
	{
		var songMetadata:SongMetadata = new SongMetadata();

		songMetadata.id = id;
		songMetadata.folder = Paths.currentModDirectory;

		var songMetadataDef:SongMetadataDef = getSongMetadataDef(id);
		songMetadata.name = songMetadataDef.name == null ? Paths.formatFromSongPath(id) : songMetadataDef.name;
		songMetadata.artist = songMetadataDef.artist == null ? '' : songMetadataDef.artist;
		// songMetadata.week = songMetadataDef.week == null ? 0 : songMetadataDef.week;
		// FIXME Week number can be wrong depending on the mod order (E.G. a song with week 0 near the bottom of the Freeplay menu will have the difficulties of the first song)
		// songMetadata.week = songMetadataDef.week == null ? week : songMetadataDef.week;
		songMetadata.week = week;
		songMetadata.freeplayDialogue = songMetadataDef.freeplayDialogue == null ? false : songMetadataDef.freeplayDialogue;
		songMetadata.difficulties = songMetadataDef.difficulties == null ? [] : songMetadataDef.difficulties;
		songMetadata.initDifficulty = songMetadataDef.initDifficulty == null ? 'normal' : songMetadataDef.initDifficulty;
		songMetadata.icon = songMetadataDef.icon == null ? 'face' : songMetadataDef.icon;
		songMetadata.background = songMetadataDef.background == null ? 'default' : songMetadataDef.background;
		songMetadata.colors = songMetadataDef.colors == null ? [] : [for (hexString in songMetadataDef.colors) Std.parseInt(hexString)];
		if (songMetadata.colors.length == 0)
		{
			songMetadata.colors.push(0xFF9271FD);
		}
		return songMetadata;
	}

	public function new()
	{
	}
}
