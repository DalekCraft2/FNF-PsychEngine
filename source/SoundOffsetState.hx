package;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import options.OptionsState;

// TODO: turn this into a chart thing
class SoundOffsetState extends MusicBeatState
{
	public var playingAudio:Bool = false;
	public var status:FlxText;
	public var beatCounter:Float = 0;
	public var beatCounts:Array<Float> = [];
	public var currOffset:Int = Options.save.data.noteOffset;
	public var offsetTxt:FlxText;
	public var metronome:Character;

	override public function create():Void
	{
		super.create();

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Calibrating audio');
		#end

		// var menuBG:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.getGraphic('menuDesat'));
		// menuBG.color = 0xFFFFEA72; // Tint used to get menuBG from menuDesat (or, at least, it is close to what the tint is)
		var menuBG:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.getGraphic('menuBG'));
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		add(menuBG);

		var title:FlxText = new FlxText(0, 20, 0, 'Audio Calibration', 32);
		title.setFormat(Paths.font('vcr.ttf'), title.size, CENTER, OUTLINE, FlxColor.BLACK);
		title.screenCenter(X);
		add(title);

		status = new FlxText(0, 50, 0, 'Audio is paused', 24);
		status.setFormat(Paths.font('vcr.ttf'), status.size, CENTER, OUTLINE, FlxColor.BLACK);
		status.screenCenter(X);
		add(status);

		offsetTxt = new FlxText(0, 80, 0, 'Current offset: 0ms', 24);
		offsetTxt.setFormat(Paths.font('vcr.ttf'), offsetTxt.size, CENTER, OUTLINE, FlxColor.BLACK);
		offsetTxt.screenCenter(X);
		add(offsetTxt);

		var instructions:FlxText = new FlxText(0, 125, 0,
			'Press the spacebar to pause/play the beat\nPress enter in time with the beat to get an approximate offset\nPress R to reset\nPress left and right to adjust the offset manually. Hold shift for precision.\nPress ESC to go back and save the current offset',
			24);
		instructions.setFormat(Paths.font('vcr.ttf'), instructions.size, CENTER, OUTLINE, FlxColor.BLACK);
		instructions.screenCenter(X);
		add(instructions);

		metronome = new Character(FlxG.width / 2, 300, 'gf');
		metronome.setGraphicSize(Std.int(metronome.width * 0.6));
		metronome.screenCenter(XY);
		metronome.y += 100;
		add(metronome);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (playingAudio)
		{
			if (FlxG.sound.music.volume > 0)
			{
				FlxG.sound.music.volume -= 0.5 * FlxG.elapsed;
			}
			beatCounter += elapsed * 1000;
			status.text = 'Audio is playing';
			Conductor.changeBPM(50);
			Conductor.songPosition += FlxG.elapsed * 1000;
		}
		else
		{
			if (FlxG.sound.music.volume < 0.7)
			{
				FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
			}
			status.text = 'Audio is paused';
			Conductor.changeBPM(0);
			Conductor.songPosition = 0;
			beatCounter = 0;
		}

		offsetTxt.text = 'Current offset:  ${currOffset}ms';

		status.screenCenter(X);
		if (FlxG.keys.justPressed.SPACE)
		{
			playingAudio = !playingAudio;
			if (!playingAudio)
			{
				Options.save.data.noteOffset = currOffset;
			}
		}

		if (playingAudio)
		{
			if (FlxG.keys.justPressed.ENTER)
			{
				beatCounts.push(beatCounter);
				var total:Float = 0;
				for (i in beatCounts)
				{
					total += i;
				}
				currOffset = Std.int(total / beatCounts.length);
			}
		}
		if (FlxG.keys.justPressed.R)
		{
			beatCounts = [];
			currOffset = 0;
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			Options.save.data.noteOffset = currOffset;
			EngineData.flushSave();
			FlxG.switchState(new OptionsState());
		}

		if (!FlxG.keys.pressed.SHIFT)
		{
			if (FlxG.keys.pressed.LEFT)
			{
				currOffset--;
			}
			if (FlxG.keys.pressed.RIGHT)
			{
				currOffset++;
			}
		}
		else
		{
			if (FlxG.keys.justPressed.LEFT)
			{
				currOffset--;
			}
			if (FlxG.keys.justPressed.RIGHT)
			{
				currOffset++;
			}
		}
	}

	override public function beatHit(beat:Int):Void
	{
		super.beatHit(beat);

		beatCounter = 0;
		if (playingAudio)
		{
			FlxG.sound.play(Paths.getSound('beat'), 1);
			metronome.dance();
		}
	}
}
