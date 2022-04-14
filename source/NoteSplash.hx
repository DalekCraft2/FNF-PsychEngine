package;

import NoteKey.NoteColor;
import flixel.FlxG;
import flixel.FlxSprite;

class NoteSplash extends FlxSprite
{
	public var colorSwap:ColorSwap;

	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0)
	{
		super(x, y);

		var skin:String = 'noteSplashes';
		if (PlayState.song.splashSkin != null && PlayState.song.splashSkin.length > 0)
			skin = PlayState.song.splashSkin;

		loadAnims(skin);

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		setupNoteSplash(x, y, note);
		antialiasing = Options.save.data.globalAntialiasing;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (animation.curAnim != null)
			if (animation.curAnim.finished)
				kill();
	}

	public function setupNoteSplash(x:Float, y:Float, note:Int = 0, ?texture:String, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0):Void
	{
		setPosition(x - Note.STRUM_WIDTH * 0.95, y - Note.STRUM_WIDTH);
		alpha = 0.6;

		if (texture == null)
		{
			texture = 'noteSplashes';
			if (PlayState.song.splashSkin != null && PlayState.song.splashSkin.length > 0)
				texture = PlayState.song.splashSkin;
		}

		loadAnims(texture);
		colorSwap.hue = hueColor;
		colorSwap.saturation = satColor;
		colorSwap.brightness = brtColor;
		offset.set(10, 10);

		var animNum:Int = FlxG.random.int(1, 2);
		animation.play('note$note-$animNum', true);
		if (animation.curAnim != null)
			animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
	}

	private function loadAnims(skin:String):Void
	{
		frames = Paths.getSparrowAtlas(skin);
		for (i in 1...3)
		{
			for (color in NoteColor.createAll())
			{
				animation.addByPrefix('note${color.getIndex()}-$i', 'note splash $color $i', 24, false);
			}
		}
	}
}
