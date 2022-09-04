package util;

import flixel.FlxSprite;
import flixel.util.FlxColor;

using StringTools;

// TODO Just putting this here because this class has "Util" in the name: I want to make a class which works like a sorted Map so we don't have to use both arrays and maps for storing things
class CoolUtil
{
	public static function listFromTextFile(path:String):Array<String>
	{
		var textArray:Array<String> = [];
		if (Paths.exists(path))
		{
			textArray = listFromString(Paths.getTextDirect(path));
		}

		return textArray;
	}

	public static function listFromString(string:String):Array<String>
	{
		var textArray:Array<String> = string.trim().split('\n').map((f:String) -> f.trim());

		return textArray;
	}

	public static function dominantColor(sprite:FlxSprite):Int
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
		countByColor[FlxColor.BLACK] = 0;
		for (key => count in countByColor)
		{
			if (count >= maxCount)
			{
				maxCount = count;
				maxKey = key;
			}
		}
		return maxKey;
	}

	public static inline function numberArray(max:Int, min = 0):Array<Int>
	{
		return [
			for (i in min...max)
				i
		];
	}
}
