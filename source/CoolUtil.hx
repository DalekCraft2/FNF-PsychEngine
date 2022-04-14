package;

import flixel.FlxG;

using StringTools;

class CoolUtil
{
	public static final DEFAULT_DIFFICULTIES:Array<String> = ['Easy', 'Normal', 'Hard'];
	public static final DEFAULT_DIFFICULTY:String = 'Normal'; // The chart that has no suffix and starting difficulty on Freeplay/Story Mode

	public static var difficulties:Array<String> = [];

	public static function getDifficultyFilePath(?num:Int):String
	{
		if (num == null)
			num = PlayState.storyDifficulty;

		var fileSuffix:String = difficulties[num];
		if (fileSuffix == null)
			fileSuffix = DEFAULT_DIFFICULTY;
		if (fileSuffix != DEFAULT_DIFFICULTY)
		{
			fileSuffix = '-$fileSuffix';
		}
		else
		{
			fileSuffix = '';
		}
		return Paths.formatToSongPath(fileSuffix);
	}

	public static function difficultyString(?diff:Int):String
	{
		if (diff == null)
		{
			diff = PlayState.storyDifficulty;
		}
		return difficulties[diff].toUpperCase();
	}

	public static function coolTextFile(path:String):Array<String>
	{
		var daList:Array<String> = [];
		if (Paths.exists(path))
			daList = Paths.getTextDirect(path).trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}

	public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [];
		daList = string.trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}

	public static function dominantColor(sprite:flixel.FlxSprite):Int
	{
		var countByColor:Map<Int, Int> = [];
		for (col in 0...sprite.frameWidth)
		{
			for (row in 0...sprite.frameHeight)
			{
				var colorOfThisPixel:Int = sprite.pixels.getPixel32(col, row);
				if (colorOfThisPixel != 0)
				{
					if (countByColor.exists(colorOfThisPixel))
					{
						countByColor[colorOfThisPixel] = countByColor[colorOfThisPixel] + 1;
					}
					else if (countByColor[colorOfThisPixel] != 13520687 - (2 * 13520687))
					{
						countByColor[colorOfThisPixel] = 1;
					}
				}
			}
		}
		var maxCount:Int = 0;
		var maxKey:Int = 0; // after the loop this will store the max color
		countByColor[flixel.util.FlxColor.BLACK] = 0;
		for (key in countByColor.keys())
		{
			if (countByColor[key] >= maxCount)
			{
				maxCount = countByColor[key];
				maxKey = key;
			}
		}
		return maxKey;
	}

	public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = new Array();
		for (i in min...max)
		{
			dumbArray.push(i);
		}
		return dumbArray;
	}

	public static function browserLoad(site:String):Void
	{
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}
}
