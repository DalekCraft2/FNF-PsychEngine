package;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import openfl.text.Font;
import openfl.media.Sound;
import openfl.utils.IAssetCache;

// WIP!
class FnfCache implements IAssetCache
{
	public var enabled(get, set):Bool;

	public static var dumpExclusions:Array<String> = [
		'assets/music/freakyMenu.$SOUND_EXT',
		'shared:assets/shared/music/breakfast.$SOUND_EXT',
		'shared:assets/shared/music/tea-time.$SOUND_EXT',
	];

	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static var currentTrackedGraphics:Map<String, BitmapData> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];

	public function clear(?prefix:String):Void
	{
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			var obj:FlxGraphic = FlxG.bitmap._cache.get(key);
			if (obj != null && !currentTrackedGraphics.exists(key))
			{
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		Assets.cache.clear('shared');
	}

	public function getBitmapData(id:String):BitmapData
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function getFont(id:String):Font
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function getSound(id:String):Sound
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function hasBitmapData(id:String):Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function hasFont(id:String):Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function hasSound(id:String):Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function removeBitmapData(id:String):Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function removeFont(id:String):Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function removeSound(id:String):Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	public function setBitmapData(id:String, bitmapData:BitmapData):Void
	{
	}

	public function setFont(id:String, font:Font):Void
	{
	}

	public function setSound(id:String, sound:Sound):Void
	{
	}

	private function get_enabled():Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}

	private function set_enabled(value:Bool):Bool
	{
		throw new haxe.exceptions.NotImplementedException();
	}
}
