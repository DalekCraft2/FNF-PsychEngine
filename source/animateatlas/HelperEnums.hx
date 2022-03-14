package animateatlas;

enum abstract LoopMode(String) from String to String
{
	public static inline final LOOP:String = "loop";
	public static inline final PLAY_ONCE:String = "playonce";
	public static inline final SINGLE_FRAME:String = "singleframe";

	public static function isValid(value:String):Bool
	{
		return value == LOOP || value == PLAY_ONCE || value == SINGLE_FRAME;
	}
}

enum abstract SymbolType(String) from String to String
{
	public static inline final GRAPHIC:String = "graphic";
	public static inline final MOVIE_CLIP:String = "movieclip";
	public static inline final BUTTON:String = "button";

	public static function isValid(value:String):Bool
	{
		return value == GRAPHIC || value == MOVIE_CLIP || value == BUTTON;
	}
}
