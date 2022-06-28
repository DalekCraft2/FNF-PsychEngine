package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;

class SectionRender extends FlxSprite
{
	public var section:Section;
	public var icon:FlxSprite;
	public var lastUpdated:Bool;

	public function new(x:Float, y:Float, GRID_SIZE:Int, height:Int = Conductor.SEMIQUAVERS_PER_MEASURE)
	{
		super(x, y);

		makeGraphic(GRID_SIZE * 8, GRID_SIZE * height, 0xffe7e6e6);

		var h:Int = GRID_SIZE;
		if (Math.floor(h) != h)
			h = GRID_SIZE;

		if (FlxG.save.data.editorBG)
			FlxGridOverlay.overlay(this, GRID_SIZE, Std.int(h), GRID_SIZE * 8, GRID_SIZE * height);
	}
}
