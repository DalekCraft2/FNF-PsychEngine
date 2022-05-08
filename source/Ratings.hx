package;

import flixel.math.FlxMath;
import options.Options.OptionDefaults;

class Ratings
{
	public static function generateComboRank():String // generate a combo ranking
	{
		var ranking:String = 'N/A';

		if (PlayState.instance.misses == 0 && PlayState.instance.bads == 0 && PlayState.instance.shits == 0 && PlayState.instance.goods == 0) // Marvelous (SICK) Full Combo
			ranking = 'MFC';
		else
			if (PlayState.instance.misses == 0 && PlayState.instance.bads == 0 && PlayState.instance.shits == 0 && PlayState.instance.goods >= 1) // Good Full Combo (Nothing but Goods & Sicks)
			ranking = 'GF';
		else if (PlayState.instance.misses == 0) // Regular FC
			ranking = 'FC';
		else if (PlayState.instance.misses < 10) // Single Digit Combo Breaks
			ranking = 'SDCB';
		else
			ranking = 'Clear';

		return ranking;
	}

	public static function generateLetterRank(accuracy:Float):String
	{
		var ranking:String = '';

		// WIFE TIME :)))) (based on Wife3)

		var wifeConditions:Array<Bool> = [
			accuracy >= 99.9935, // AAAAA
			accuracy >= 99.980, // AAAA:
			accuracy >= 99.970, // AAAA.
			accuracy >= 99.955, // AAAA
			accuracy >= 99.90, // AAA:
			accuracy >= 99.80, // AAA.
			accuracy >= 99.70, // AAA
			accuracy >= 99, // AA:
			accuracy >= 96.50, // AA.
			accuracy >= 93, // AA
			accuracy >= 90, // A:
			accuracy >= 85, // A.
			accuracy >= 80, // A
			accuracy >= 70, // B
			accuracy >= 60, // C
			accuracy < 60 // D
		];

		for (i in 0...wifeConditions.length)
		{
			var b:Bool = wifeConditions[i];
			if (b)
			{
				switch (i)
				{
					case 0:
						ranking = 'AAAAA';
					case 1:
						ranking = 'AAAA:';
					case 2:
						ranking = 'AAAA.';
					case 3:
						ranking = 'AAAA';
					case 4:
						ranking = 'AAA:';
					case 5:
						ranking = 'AAA.';
					case 6:
						ranking = 'AAA';
					case 7:
						ranking = 'AA:';
					case 8:
						ranking = 'AA.';
					case 9:
						ranking = 'AA';
					case 10:
						ranking = 'A:';
					case 11:
						ranking = 'A.';
					case 12:
						ranking = 'A';
					case 13:
						ranking = 'B';
					case 14:
						ranking = 'C';
					case 15:
						ranking = 'D';
				}
				break;
			}
		}

		return ranking;
	}

	public static function generateComboLetterRank(accuracy:Float):String // generate a letter ranking
	{
		var ranking:String = 'N/A';

		ranking = '(${generateComboRank()}) ${generateLetterRank(accuracy)}';

		if (accuracy == 0)
			ranking = 'N/A';

		return ranking;
	}

	public static var timingWindows:Array<Float> = [];

	public static function judgeNote(noteDiff:Float):String
	{
		// tryna do MS based judgment due to popular demand
		var timingWindows:Array<Int> = [
			Options.save.data.sickWindow,
			Options.save.data.goodWindow,
			Options.save.data.badWindow
		];
		var windowNames:Array<String> = ['sick', 'good', 'bad'];

		var diff:Float = Math.abs(noteDiff);
		// for (index in 0...timingWindows.length) // based on 4 timing windows, will break with anything else
		// {
		// 	var time:Float = timingWindows[index];
		// 	var nextTime:Float = index + 1 > timingWindows.length - 1 ? 0 : timingWindows[index + 1];
		// 	if (diff < time && diff >= nextTime)
		// 	{
		// 		return windowNames[index];
		// 	}
		// }
		for (i in 0...timingWindows.length) // based on 4 timing windows, will break with anything else
		{
			if (diff <= timingWindows[Math.round(Math.min(i, timingWindows.length - 1))])
			{
				return windowNames[i];
			}
		}
		return 'shit';
	}

	public static function calculateRanking(score:Int, scoreDefault:Int, nps:Int, maxNPS:Int, accuracy:Float):String
	{
		// var showAll:Bool = !PlayStateChangeables.botPlay || PlayState.loadRep;
		var showAll:Bool = true; // I just like seeing everything.

		var npsString:String = Options.save.data.npsDisplay ? 'NPS: $nps (Max $maxNPS)${showAll ? ' | ' : ''}' : ''; // NPS
		var scoreString:String = 'Score: ${Options.save.data.safeFrames != OptionDefaults.safeFrames ? '$score ($scoreDefault)' : Std.string(score)}'; // Score
		var comboBreaksString:String = 'Combo Breaks: ${PlayState.instance.misses}'; // Misses/Combo Breaks
		var accuracyString:String = 'Accuracy: ${showAll ? '${FlxMath.roundDecimal(accuracy, 2)}%' : 'N/A'}'; // Accuracy
		var comboLetterRankString:String = generateComboLetterRank(accuracy); // Combo Rank + Letter Rank
		var fullAccuracyString:String = Options.save.data.accuracyDisplay ? ' | $comboBreaksString | $accuracyString | $comboLetterRankString' : '';

		return '$npsString${(showAll ? '$scoreString$fullAccuracyString' : '')}';
	}
}
