package funkin;

import flixel.FlxSprite;
import funkin.util.CoolUtil;
import haxe.io.Path;

class BackgroundGirls extends FlxSprite implements Danceable
{
	private var danceDir:Bool = false;
	private var isPissed:Bool = true;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		// BG fangirls dissuaded
		frames = Paths.getFrames(Path.join(['stages', 'weeb', 'bgFreaks']));

		swapDanceType();

		animation.play('danceLeft');
	}

	public function dance(force:Bool = true):Void
	{
		danceDir = !danceDir;

		if (danceDir)
			animation.play('danceRight', force);
		else
			animation.play('danceLeft', force);
	}

	public function swapDanceType():Void
	{
		isPissed = !isPissed;
		if (isPissed)
		{
			// Pisses
			animation.addByIndices('danceLeft', 'BG fangirls dissuaded', CoolUtil.numberArray(14), '', 24, false);
			animation.addByIndices('danceRight', 'BG fangirls dissuaded', CoolUtil.numberArray(30, 15), '', 24, false);
		}
		else
		{
			// Gets unpissed
			animation.addByIndices('danceLeft', 'BG girls group', CoolUtil.numberArray(14), '', 24, false);
			animation.addByIndices('danceRight', 'BG girls group', CoolUtil.numberArray(30, 15), '', 24, false);
		}
		dance();
	}
}
