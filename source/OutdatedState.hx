package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	private var warnText:FlxText;

	override public function create():Void
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		warnText = new FlxText(0, 0, FlxG.width,
			'Sup bro, looks like you\'re running an\noutdated version of Psych Engine (${EngineData.ENGINE_VERSION}),\nplease update to ${TitleState.updateVersion}!\nPress ESCAPE to proceed anyway.\n\nThank you for using the Engine!\n',
			32);
		warnText.setFormat(Paths.font('vcr.ttf'), warnText.size, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!leftState)
		{
			if (controls.ACCEPT)
			{
				leftState = true;
				CoolUtil.browserLoad('https://github.com/ShadowMario/FNF-PsychEngine/releases');
			}
			else if (controls.BACK)
			{
				leftState = true;
			}

			if (leftState)
			{
				FlxG.sound.play(Paths.getSound('cancelMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: (twn:FlxTween) ->
					{
						FlxG.switchState(new MainMenuState());
					}
				});
			}
		}
	}
}
