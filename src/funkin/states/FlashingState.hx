package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	private var warnText:FlxText;

	override public function create():Void
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		warnText = new FlxText(0, 0, FlxG.width,
			'Hey, watch out!\nThis Mod contains some flashing lights!\nPress ENTER to disable them now or go to Options Menu.\nPress ESCAPE to ignore this message.\nYou\'ve been warned!',
			32);
		warnText.setFormat(Paths.font('vcr.ttf'), warnText.size, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!leftState)
		{
			var back:Bool = controls.BACK;
			if (controls.ACCEPT || back)
			{
				leftState = true;
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				if (back)
				{
					FlxG.sound.play(Paths.getSound('cancelMenu'));
					FlxTween.tween(warnText, {alpha: 0}, 1, {
						onComplete: (twn:FlxTween) ->
						{
							FlxG.switchState(new TitleState());
						}
					});
				}
				else
				{
					Options.profile.flashing = false;
					Options.flushSave();
					FlxG.sound.play(Paths.getSound('confirmMenu'));
					FlxFlicker.flicker(warnText, 1, 0.1, false, true, (flk:FlxFlicker) ->
					{
						new FlxTimer().start(0.5, (tmr:FlxTimer) ->
						{
							FlxG.switchState(new TitleState());
						});
					});
				}
			}
		}
	}
}
