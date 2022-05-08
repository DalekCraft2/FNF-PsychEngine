package;

import flixel.util.FlxColor;
import haxe.io.Path;
#if polymod
import polymod.PolymodConfig;
#end

typedef ModEnableState =
{
	var title:String;
	var enabled:Bool;
}

typedef ModMetadataDef =
{
	var title:String;
	var description:String;
	var color:String;
	var restart:Bool;
}

class ModMetadata
{
	public var folder:String;
	public var title:String;
	public var description:String;
	public var color:FlxColor;
	public var restart:Bool; // trust me. this is very important
	public var alphabet:Alphabet;
	public var icon:AttachedSprite;

	public function new(folder:String)
	{
		this.folder = folder;
		this.title = folder;
		this.description = 'No description provided.';
		this.color = FreeplayState.DEFAULT_COLOR;
		this.restart = false;

		// Try loading json
		#if polymod
		var path:String = Paths.mods(Path.join([folder, PolymodConfig.modMetadataFile]));
		#else
		var path:String = Paths.mods(Path.join([folder, Path.withExtension('_meta', Paths.JSON_EXT)]));
		#end
		if (Paths.exists(path))
		{
			var modDef:ModMetadataDef = Paths.getJsonDirect(path);
			if (modDef != null)
			{
				if (modDef.title != null && modDef.title.length > 0)
				{
					this.title = modDef.title;
				}
				if (modDef.description != null && modDef.description.length > 0)
				{
					this.description = modDef.description;
				}
				if (modDef.color != null)
				{
					this.color = Std.parseInt(modDef.color);
				}
				this.restart = modDef.restart;
			}
		}
	}
}
