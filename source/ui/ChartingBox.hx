package ui;

import Note.NoteDef;
import flixel.FlxSprite;
import flixel.util.FlxColor;

class ChartingBox extends FlxSprite
{
	public var connectedNote:Note;
	public var connectedNoteData:NoteDef;

	public function new(x:Float, y:Float, originalNote:Note)
	{
		super(x, y);
		connectedNote = originalNote;

		makeGraphic(40, 40, FlxColor.fromRGB(173, 216, 230));
		alpha = 0.4;
	}
}
