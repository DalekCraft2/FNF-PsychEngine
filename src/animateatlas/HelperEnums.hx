package animateatlas;

enum abstract LoopMode(String) from String to String
{
	public static inline final LOOP:LoopMode = 'loop';
	public static inline final PLAY_ONCE:LoopMode = 'playonce';
	public static inline final SINGLE_FRAME:LoopMode = 'singleframe';

	public static function isValid(value:LoopMode):Bool
	{
		return value == LOOP || value == PLAY_ONCE || value == SINGLE_FRAME;
	}
}

enum abstract SymbolType(String) from String to String
{
	public static inline final GRAPHIC:SymbolType = 'graphic';
	public static inline final MOVIE_CLIP:SymbolType = 'movieclip';
	public static inline final BUTTON:SymbolType = 'button';

	public static function isValid(value:SymbolType):Bool
	{
		return value == GRAPHIC || value == MOVIE_CLIP || value == BUTTON;
	}
}
