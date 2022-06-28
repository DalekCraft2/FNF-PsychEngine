package;

import flixel.util.FlxArrayUtil;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.text.Font;
import openfl.utils.IAssetCache;

using StringTools;

// WIP!
class FnfCache implements IAssetCache
{
	public var enabled(get, set):Bool;

	public static var dumpExclusions:Array<String> = [
		Path.withExtension('assets/music/freakyMenu', Paths.AUDIO_EXT),
		Path.withExtension('assets/music/breakfast', Paths.AUDIO_EXT),
		Path.withExtension('assets/music/tea-time', Paths.AUDIO_EXT),
	];

	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static var bitmaps:Map<String, BitmapData> = [];
	public static var fonts:Map<String, Font> = [];
	public static var sounds:Map<String, Sound> = [];

	private var __enabled:Bool = true;

	public function clear(?prefix:String):Void
	{
		// clear anything not in the tracked assets list
		for (key => value in bitmaps)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				if (key.startsWith(prefix))
				{
					removeBitmapData(key);
					if (value != null)
					{
						value.dispose();
					}
				}
			}
		}

		for (key in fonts.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				if (key.startsWith(prefix))
				{
					removeFont(key);
					// Fonts don't have a method for disposing, so we can't do that with them
				}
			}
		}

		// clear all sounds that are cached
		for (key => value in sounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				if (key.startsWith(prefix))
				{
					removeSound(key);
					if (value != null)
					{
						value.close();
					}
				}
			}
		}

		// flags everything to be cleared out next unused memory clear
		FlxArrayUtil.clearArray(localTrackedAssets);
	}

	public function getBitmapData(id:String):BitmapData
	{
		return bitmaps.get(id);
	}

	public function getFont(id:String):Font
	{
		return fonts.get(id);
	}

	public function getSound(id:String):Sound
	{
		return sounds.get(id);
	}

	public function hasBitmapData(id:String):Bool
	{
		return bitmaps.exists(id);
	}

	public function hasFont(id:String):Bool
	{
		return fonts.exists(id);
	}

	public function hasSound(id:String):Bool
	{
		return sounds.exists(id);
	}

	public function removeBitmapData(id:String):Bool
	{
		return bitmaps.remove(id);
	}

	public function removeFont(id:String):Bool
	{
		return fonts.remove(id);
	}

	public function removeSound(id:String):Bool
	{
		return sounds.remove(id);
	}

	public function setBitmapData(id:String, bitmapData:BitmapData):Void
	{
		bitmaps.set(id, bitmapData);
	}

	public function setFont(id:String, font:Font):Void
	{
		fonts.set(id, font);
	}

	public function setSound(id:String, sound:Sound):Void
	{
		sounds.set(id, sound);
	}

	private function get_enabled():Bool
	{
		return __enabled;
	}

	private function set_enabled(value:Bool):Bool
	{
		return __enabled = value;
	}
}
