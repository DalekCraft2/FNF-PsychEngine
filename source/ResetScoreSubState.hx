package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

class ResetScoreSubState extends MusicBeatSubState
{
	private var bg:FlxSprite;
	private var alphabetArray:Array<Alphabet> = [];
	private var icon:HealthIcon;
	private var onYes:Bool = false;
	private var yesText:Alphabet;
	private var noText:Alphabet;

	private var song:String;
	private var difficulty:Int;
	private var character:String;
	private var week:Int;

	// Week -1 = Freeplay
	public function new(song:String, difficulty:Int, character:String, week:Int = -1)
	{
		super();

		this.song = song;
		this.difficulty = difficulty;
		this.character = character;
		this.week = week;
	}

	override public function create():Void
	{
		var name:String = song;
		if (week > -1)
		{
			name = Week.weeksLoaded.get(Week.weekList[week]).weekName;
		}
		name += ' (${CoolUtil.difficulties[difficulty]})?';

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var tooLong:Float = (name.length > 18) ? 0.8 : 1; // Fucking Winter Horrorland
		var text:Alphabet = new Alphabet(0, 180, 'Reset the score of', true);
		text.screenCenter(X);
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		text = new Alphabet(0, text.y + 90, name, true, false, 0.05, tooLong);
		text.screenCenter(X);
		if (week == -1)
			text.x += 60 * tooLong;
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		if (week == -1)
		{
			icon = new HealthIcon(character);
			icon.setGraphicSize(Std.int(icon.width * tooLong));
			icon.updateHitbox();
			icon.setPosition(text.x - icon.width + (10 * tooLong), text.y - 30);
			icon.alpha = 0;
			add(icon);
		}

		yesText = new Alphabet(0, text.y + 150, 'Yes', true);
		yesText.screenCenter(X);
		yesText.x -= 200;
		add(yesText);
		noText = new Alphabet(0, text.y + 150, 'No', true);
		noText.screenCenter(X);
		noText.x += 200;
		add(noText);
		updateOptions();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		bg.alpha += elapsed * 1.5;
		if (bg.alpha > 0.6)
			bg.alpha = 0.6;

		for (spr in alphabetArray)
		{
			spr.alpha += elapsed * 2.5;
		}
		if (week == -1)
			icon.alpha += elapsed * 2.5;

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.getSound('scrollMenu'), 1);
			onYes = !onYes;
			updateOptions();
		}
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.getSound('cancelMenu'), 1);
			close();
		}
		else if (controls.ACCEPT)
		{
			if (onYes)
			{
				if (week == -1)
				{
					Highscore.resetSong(song, difficulty);
				}
				else
				{
					Highscore.resetWeek(Week.weekList[week], difficulty);
				}
			}
			FlxG.sound.play(Paths.getSound('cancelMenu'), 1);
			close();
		}
	}

	private function updateOptions():Void
	{
		var scales:Array<Float> = [0.75, 1];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		if (week == -1)
			icon.animation.curAnim.curFrame = confirmInt;
	}
}
