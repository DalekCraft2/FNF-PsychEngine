package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;

	override function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		warnText = new FlxText(0, 0, FlxG.width, "Sup bro, looks like you're running an   \n
			outdated version of Psych Engine ("
			+ MainMenuState.PSYCH_ENGINE_VERSION
			+ "),\n
			please update to "
			+ TitleState.updateVersion
			+ "!\n
			Press ESCAPE to proceed anyway.\n
			\n
			Thank you for using the Engine!", 32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!leftState)
		{
			if (controls.ACCEPT)
			{
				leftState = true;
				CoolUtil.browserLoad("https://github.com/ShadowMario/FNF-PsychEngine/releases");
			}
			else if (controls.BACK)
			{
				leftState = true;
			}

			if (leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
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
