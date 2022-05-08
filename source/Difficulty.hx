package;

typedef DifficultyDef =
{
	var ?hidden:Bool;
	var name:String;
	var chart:String;
	var displayName:String;
}

class Difficulty
{
	public static final DEFAULT_DIFFICULTIES:Array<String> = ['Easy', 'Normal', 'Hard'];

	/**
	 * The chart that has no suffix and starting difficulty on Freeplay/Story Mode
	 */
	public static final DEFAULT_DIFFICULTY:String = 'Normal';

	public static var difficulties:Array<String> = [];

	public var hidden:Bool;
	public var name:String;
	public var chart:String;
	public var displayName:String;

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
}
