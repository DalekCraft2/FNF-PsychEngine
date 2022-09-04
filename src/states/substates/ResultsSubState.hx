package states.substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import ui.HitGraph;
import ui.OFLSprite;

using StringTools;

class ResultsSubState extends FlxSubState
{
	public var background:FlxSprite;
	public var text:FlxText;

	public var anotherBackground:FlxSprite;
	public var graph:HitGraph;
	public var graphSprite:OFLSprite;

	public var comboText:FlxText;
	public var contText:FlxText;
	public var settingsText:FlxText;

	public var music:FlxSound;

	override public function create():Void
	{
		super.create();

		background = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		background.scrollFactor.set();
		add(background);

		// This doesn't use FlxG.sound.music because that is being used by the song's instrumental
		music = new FlxSound().loadEmbedded(Paths.getMusic('breakfast'), true, true);
		music.volume = 0;
		music.play(false, FlxG.random.int(0, Std.int(music.length / 2)));
		FlxG.sound.list.add(music);

		background.alpha = 0;

		text = new FlxText(20, -55, 0, 'Song Cleared!', 34);
		text.setBorderStyle(OUTLINE, FlxColor.BLACK, 4, 1);
		text.color = FlxColor.WHITE;
		text.scrollFactor.set();
		add(text);

		var score:Int = PlayState.instance.score;
		if (PlayState.isStoryMode)
		{
			score = PlayState.campaignScore;
			text.text = 'Week Cleared!';
		}

		var sicks:Int = PlayState.isStoryMode ? PlayState.campaignSicks : PlayState.instance.sicks;
		var goods:Int = PlayState.isStoryMode ? PlayState.campaignGoods : PlayState.instance.goods;
		var bads:Int = PlayState.isStoryMode ? PlayState.campaignBads : PlayState.instance.bads;
		var shits:Int = PlayState.isStoryMode ? PlayState.campaignShits : PlayState.instance.shits;
		var misses:Int = PlayState.isStoryMode ? PlayState.campaignMisses : PlayState.instance.misses;

		var accuracy:Float = PlayState.instance.ratingPercent;

		comboText = new FlxText(20, -75, 0,
			'Judgements:\nSicks - ${sicks}\nGoods - ${goods}\nBads - ${bads}\nShits - ${shits}\nCombo Breaks: ${misses}\nHighest Combo: ${PlayState.highestCombo + 1}\nScore: ${PlayState.instance.score}\nAccuracy: ${FlxMath.roundDecimal(accuracy, 2)}%\n\n${Ratings.generateComboLetterRank(misses, shits, bads, goods, accuracy)}\nRate: ${PlayState.songMultiplier}x\n\n${!PlayState.loadRep ? '\nF1 - Replay Song' : ''}\n',
			28);
		comboText.setBorderStyle(OUTLINE, FlxColor.BLACK, 4, 1);
		comboText.color = FlxColor.WHITE;
		comboText.scrollFactor.set();
		add(comboText);

		contText = new FlxText(FlxG.width - 475, FlxG.height + 50, 0, 'Press ${Options.save.data.controllerMode ? 'A' : 'ENTER'} to continue.', 28);
		contText.setBorderStyle(OUTLINE, FlxColor.BLACK, 4, 1);
		contText.color = FlxColor.WHITE;
		contText.scrollFactor.set();
		add(contText);

		anotherBackground = new FlxSprite(FlxG.width - 500, 45).makeGraphic(450, 240, FlxColor.BLACK);
		anotherBackground.scrollFactor.set();
		anotherBackground.alpha = 0;
		add(anotherBackground);

		graph = new HitGraph(FlxG.width - 500, 45, 495, 240);
		graph.alpha = 0;

		graphSprite = new OFLSprite(FlxG.width - 510, 45, 460, 240, graph);

		graphSprite.scrollFactor.set();
		graphSprite.alpha = 0;

		add(graphSprite);

		var sicks:Float = FlxMath.roundDecimal(PlayState.instance.sicks / PlayState.instance.goods, 1);
		var goods:Float = FlxMath.roundDecimal(PlayState.instance.goods / PlayState.instance.bads, 1);

		if (sicks == Math.POSITIVE_INFINITY)
			sicks = 0;
		if (goods == Math.POSITIVE_INFINITY)
			goods = 0;

		var mean:Float = 0;

		for (i in 0...PlayState.rep.replay.songNotes.length)
		{
			// 0 = time
			// 1 = length
			// 2 = type
			// 3 = diff
			var note:Array<Any> = PlayState.rep.replay.songNotes[i];
			// judgement
			var judge:String = PlayState.rep.replay.songJudgements[i];

			var time:Float = note[0];
			var length:Float = note[1];
			var diff:Float = note[3];

			if (diff != (166 * Math.floor((PlayState.rep.replay.sf / TimingConstants.SECONDS_PER_MINUTE) * TimingConstants.MILLISECONDS_PER_SECOND) / 166))
				mean += diff;
			if (length != -1)
				graph.addToHistory(diff / PlayState.songMultiplier, judge, time / PlayState.songMultiplier);
		}

		if (sicks == Math.POSITIVE_INFINITY || sicks == Math.NaN)
			sicks = 0;
		if (goods == Math.POSITIVE_INFINITY || goods == Math.NaN)
			goods = 0;

		graph.update();

		mean = FlxMath.roundDecimal(mean / PlayState.rep.replay.songNotes.length, 2);

		settingsText = new FlxText(20, FlxG.height + 50, 0,
			'Mean: ${mean}ms (SICK:${Ratings.timingWindows[3]}ms,GOOD:${Ratings.timingWindows[2]}ms,BAD:${Ratings.timingWindows[1]}ms,SHIT:${Ratings.timingWindows[0]}ms)',
			16);
		settingsText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2, 1);
		settingsText.color = FlxColor.WHITE;
		settingsText.scrollFactor.set();
		add(settingsText);

		FlxTween.tween(background, {alpha: 0.5}, 0.5);
		FlxTween.tween(text, {y: 20}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(comboText, {y: 145}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(contText, {y: FlxG.height - 45}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(settingsText, {y: FlxG.height - 35}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(anotherBackground, {alpha: 0.6}, 0.5, {
			onUpdate: (tween:FlxTween) ->
			{
				graph.alpha = FlxMath.lerp(0, 1, tween.percent);
				graphSprite.alpha = FlxMath.lerp(0, 1, tween.percent);
			}
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (music != null)
			if (music.volume < 0.5)
				music.volume += 0.01 * elapsed;

		var goods:Int = PlayState.instance.goods;
		var bads:Int = PlayState.instance.bads;
		var shits:Int = PlayState.instance.shits;
		var misses:Int = PlayState.instance.misses;

		var accuracy:Float = PlayState.instance.ratingPercent;

		// keybinds

		if (PlayerSettings.player1.controls.ACCEPT)
		{
			if (music != null)
				music.fadeOut(0.3);

			PlayState.loadRep = false;
			PlayState.stageTesting = false;
			PlayState.rep = null;

			#if !switch
			Highscore.saveScore(PlayState.song.id, Math.round(PlayState.instance.score), PlayState.storyDifficulty);
			Highscore.saveCombo(PlayState.song.id, Ratings.generateComboLetterRank(misses, shits, bads, goods, accuracy), PlayState.storyDifficulty);
			#end

			if (PlayState.isStoryMode)
			{
				FlxG.switchState(new StoryMenuState());
			}
			else
				FlxG.switchState(new FreeplayState());
			// PlayState.instance.clean();
		}

		if (FlxG.keys.justPressed.F1 && !PlayState.loadRep)
		{
			PlayState.rep = null;

			PlayState.loadRep = false;
			PlayState.stageTesting = false;

			#if !switch
			Highscore.saveScore(PlayState.song.id, Math.round(PlayState.instance.score), PlayState.storyDifficulty);
			Highscore.saveCombo(PlayState.song.id, Ratings.generateComboLetterRank(misses, shits, bads, goods, accuracy), PlayState.storyDifficulty);
			#end

			if (music != null)
				music.fadeOut(0.3);

			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = PlayState.storyDifficulty;
			LoadingState.loadAndSwitchState(new PlayState());
			// PlayState.instance.clean();
		}
	}
}
