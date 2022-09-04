package;

import flixel.math.FlxMath;
import options.Options.OptionDefaults;

class Ratings
{
	public static function generateComboRank(misses:Int, shits:Int, bads:Int, goods:Int):ComboRank // generate a combo ranking
	{
		var ranking:ComboRank = 'N/A';

		if (misses == 0 && bads == 0 && shits == 0 && goods == 0) // Marvelous (SICK) Full Combo
			ranking = ComboRank.MFC;
		else if (misses == 0 && bads == 0 && shits == 0 && goods >= 1) // Good Full Combo (Nothing but Goods & Sicks)
			ranking = ComboRank.GFC;
		else if (misses == 0) // Regular FC
			ranking = ComboRank.FC;
		else if (misses < 10) // Single Digit Combo Break
			ranking = ComboRank.SDCB;
		else
			ranking = ComboRank.CLEAR;

		return ranking;
	}

	// TODO Is there any way to simplify this code?
	public static function generateGrade(accuracy:Float):String
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

		for (i => b in wifeConditions)
		{
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

	public static function generateComboLetterRank(misses:Int, shits:Int, bads:Int, goods:Int, accuracy:Float):String // generate a letter ranking
	{
		var ranking:String = 'N/A';

		ranking = '(${generateComboRank(misses, shits, bads, goods)}) ${generateGrade(accuracy)}';

		if (accuracy == 0)
			ranking = 'N/A';

		return ranking;
	}

	public static var timingWindows:Array<Float> = [];

	public static function judgeNote(noteDiff:Float):Judgement
	{
		// tryna do MS based judgment due to popular demand
		// TODO Make these options Floats?
		// TODO Also, do what Kade Engine does and make this only update the timingWindows field in the Options menu.
		timingWindows = [
			Options.save.data.sickWindow,
			Options.save.data.goodWindow,
			Options.save.data.badWindow
		];
		var windowNames:Array<String> = [Judgement.SICK, Judgement.GOOD, Judgement.BAD];

		var diff:Float = Math.abs(noteDiff);
		for (i in 0...timingWindows.length) // based on 4 timing windows, will break with anything else
		{
			// var time:Float = timingWindows[i];
			// var nextTime:Float = i + 1 > timingWindows.length - 1 ? 0 : timingWindows[i + 1];
			// if (diff < time && diff >= nextTime)
			if (diff <= timingWindows[Math.round(Math.min(i, timingWindows.length - 1))])
			{
				return windowNames[i];
			}
		}
		return Judgement.SHIT;
	}

	// TODO Make an object for storing score data, yeesh
	public static function calculateRanking(score:Int, scoreDefault:Int, nps:Int, maxNPS:Int, misses:Int, shits:Int, bads:Int, goods:Int,
			accuracy:Float):String
	{
		// var showAll:Bool = !PlayStateChangeables.botPlay || PlayState.loadRep;
		var showAll:Bool = true; // I just like seeing everything.

		var npsString:String = Options.save.data.npsDisplay ? 'NPS: $nps (Max $maxNPS)${showAll ? ' | ' : ''}' : ''; // NPS
		var scoreString:String = 'Score: ${Options.save.data.safeFrames != OptionDefaults.safeFrames ? '$score ($scoreDefault)' : Std.string(score)}'; // Score
		var comboBreaksString:String = 'Combo Breaks: ${misses}'; // Misses/Combo Breaks
		var accuracyString:String = 'Accuracy: ${showAll ? '${FlxMath.roundDecimal(accuracy, 2)}%' : 'N/A'}'; // Accuracy
		var comboLetterRankString:String = generateComboLetterRank(misses, shits, bads, goods, accuracy); // Combo Rank + Letter Rank
		var fullAccuracyString:String = Options.save.data.accuracyDisplay ? ' | $comboBreaksString | $accuracyString | $comboLetterRankString' : '';

		return '$npsString${(showAll ? '$scoreString$fullAccuracyString' : '')}';
	}
}

enum abstract ComboRank(String) from String to String
{
	/**
	 * Marvelous Full Combo; gotten by hitting only Sicks on every note
	 */
	public static final MFC:ComboRank = 'MFC';

	/**
	 * Great Full Combo; gotten by hitting only Sicks or Goods on every note
	 */
	public static final GFC:ComboRank = 'GFC';

	/**
	 * Full Combo; gotten by hitting every note, regardless of judgement
	 */
	public static final FC:ComboRank = 'FC';

	/**
	 * Single-Digit Combo Break; gotten by missing between 1 and 9 notes, inclusive
	 */
	public static final SDCB:ComboRank = 'SDCB';

	/**
	 * Clear; gotten by missing 10 or more notes
	 */
	public static final CLEAR:ComboRank = 'Clear';

	// /**
	//  * N/A; the combo rank at the beginning of the song before the player has hit/missed any note
	//  */
	// public static final NA:ComboRank = 'N/A';
}

enum abstract Judgement(String) from String to String
{
	public static final SICK:Judgement = 'sick';
	public static final GOOD:Judgement = 'good';
	public static final BAD:Judgement = 'bad';
	public static final SHIT:Judgement = 'shit';
	public static final MISS:Judgement = 'miss';
}
