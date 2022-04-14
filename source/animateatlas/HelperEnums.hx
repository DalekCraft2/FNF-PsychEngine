package animateatlas;

enum abstract LoopMode(String) from String to String
{
	public static inline final LOOP:SymbolType = 'loop';
	public static inline final PLAY_ONCE:SymbolType = 'playonce';
	public static inline final SINGLE_FRAME:SymbolType = 'singleframe';

	public static function isValid(value:SymbolType):Bool
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
