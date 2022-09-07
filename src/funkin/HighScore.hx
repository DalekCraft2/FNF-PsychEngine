package funkin;

import funkin.Ratings.ComboRank;

using StringTools;

class HighScore
{
	private static var weekScores:Map<String, Int> = [];
	private static var songScores:Map<String, Int> = [];
	private static var songRating:Map<String, Float> = [];
	private static var songCombos:Map<String, String> = [];

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var formattedSong:String = formatSong(song, diff);
		setScore(formattedSong, 0);
		setRating(formattedSong, 0);
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var formattedWeek:String = formatSong(week, diff);
		setWeekScore(formattedWeek, 0);
	}

	public static function saveScore(song:String, score:Int = 0, diff:Int = 0, rating:Float = -1):Void
	{
		var formattedSong:String = formatSong(song, diff);

		if (songScores.exists(formattedSong))
		{
			if (songScores.get(formattedSong) < score)
			{
				setScore(formattedSong, score);
				if (rating >= 0)
					setRating(formattedSong, rating);
			}
		}
		else
		{
			setScore(formattedSong, score);
			if (rating >= 0)
				setRating(formattedSong, rating);
		}
	}

	public static function saveCombo(song:String, combo:String, diff:Int = 0):Void
	{
		var formattedSong:String = formatSong(song, diff);
		var finalCombo:String = combo.split(')')[0].replace('(', '');

		if (!PlayStateChangeables.botPlay)
		{
			if (songCombos.exists(formattedSong))
			{
				if (getComboInt(songCombos.get(formattedSong)) < getComboInt(finalCombo))
					setCombo(formattedSong, finalCombo);
			}
			else
				setCombo(formattedSong, finalCombo);
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0, diff:Int = 0):Void
	{
		var formattedWeek:String = formatSong(week, diff);

		if (weekScores.exists(formattedWeek))
		{
			if (weekScores.get(formattedWeek) < score)
				setWeekScore(formattedWeek, score);
		}
		else
			setWeekScore(formattedWeek, score);
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	private static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		EngineData.save.data.songScores = songScores;
		EngineData.flushSave();
	}

	private static function setCombo(song:String, combo:String):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songCombos.set(song, combo);
		EngineData.save.data.songCombos = songCombos;
		EngineData.flushSave();
	}

	private static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		EngineData.save.data.weekScores = weekScores;
		EngineData.flushSave();
	}

	private static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		EngineData.save.data.songRating = songRating;
		EngineData.flushSave();
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + Difficulty.getDifficultyFilePath(diff);
	}

	private static function getComboInt(combo:ComboRank):Int
	{
		switch (combo)
		{
			case ComboRank.MFC:
				return 4;
			case ComboRank.GFC:
				return 3;
			case ComboRank.FC:
				return 2;
			case ComboRank.SDCB:
				return 1;
			default:
				return 0;
		}
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var formattedSong:String = formatSong(song, diff);
		if (!songScores.exists(formattedSong))
			setScore(formattedSong, 0);

		return songScores.get(formattedSong);
	}

	public static function getCombo(song:String, diff:Int):String
	{
		var formattedSong:String = formatSong(song, diff);
		if (!songCombos.exists(formattedSong))
			setCombo(formattedSong, '');

		return songCombos.get(formattedSong);
	}

	public static function getRating(song:String, diff:Int):Float
	{
		var formattedSong:String = formatSong(song, diff);
		if (!songRating.exists(formattedSong))
			setRating(formattedSong, 0);

		return songRating.get(formattedSong);
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var formattedWeek:String = formatSong(week, diff);
		if (!weekScores.exists(formattedWeek))
			setWeekScore(formattedWeek, 0);

		return weekScores.get(formattedWeek);
	}

	public static function load():Void
	{
		if (EngineData.save.data.weekScores != null)
		{
			weekScores = EngineData.save.data.weekScores;
		}
		if (EngineData.save.data.songScores != null)
		{
			songScores = EngineData.save.data.songScores;
		}
		if (EngineData.save.data.songRating != null)
		{
			songRating = EngineData.save.data.songRating;
		}
	}
}
