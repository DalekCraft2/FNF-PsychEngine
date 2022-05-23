package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import options.OptionsState;

class JudgeCustomizationState extends MusicBeatState
{
	private var stage:Stage;
	private var judge:FlxSprite;
	private var judgePlacementPos:FlxPoint;
	private var defaultPos:FlxPoint;
	private var draggingJudge:Bool = false;

	override public function create():Void
	{
		super.create();

		FlxG.mouse.visible = true;

		defaultPos = FlxPoint.get();
		judgePlacementPos = FlxPoint.get(Options.save.data.judgeX, Options.save.data.judgeY);
		stage = new Stage('stage');
		add(stage);

		add(stage.layers.get('gf'));
		add(stage.layers.get('dad'));
		add(stage.layers.get('boyfriend'));
		add(stage.foreground);

		add(stage.overlay);

		var coolText:FlxText = new FlxText(FlxG.width * 0.55, 0, 0, '100', 32);
		coolText.screenCenter(Y);

		judge = new FlxSprite(coolText.x - 40, 0);
		judge.loadGraphic(Paths.getGraphic('sick'));
		judge.screenCenter(Y);
		judge.antialiasing = true;
		judge.y -= 60;
		judge.setGraphicSize(Std.int(judge.width * 0.7));
		judge.updateHitbox();

		if (Options.save.data.ratingInHUD)
		{
			coolText.scrollFactor.set();
			judge.scrollFactor.set();

			judge.screenCenter();
			coolText.screenCenter();
			judge.y -= 25;
		}

		FlxG.camera.focusOn(judge.getPosition());

		add(judge);
		defaultPos.set(judge.x, judge.y);
		judge.x += Options.save.data.judgeX;
		judge.y += Options.save.data.judgeY;

		var title:FlxText = new FlxText(0, 20, 0, 'Judgement Movement', 32);
		title.scrollFactor.set();
		title.setFormat(Paths.font('vcr.ttf'), title.size, CENTER, OUTLINE, FlxColor.BLACK);
		title.screenCenter(X);
		add(title);

		var instructions:FlxText = new FlxText(0, 60, 0,
			'Click and drag the judgement around to move it\nPress R to place the judgement in its default position\nPress C to show the combo\nPress Enter to exit and save\nPress Escape to exit without saving',
			24);
		instructions.scrollFactor.set();
		instructions.setFormat(Paths.font('vcr.ttf'), instructions.size, CENTER, OUTLINE, FlxColor.BLACK);
		instructions.screenCenter(X);
		add(instructions);
	}

	private var mouseX:Float;
	private var mouseY:Float;

	override public function update(elapsed):Void
	{
		super.update(elapsed);

		var deltaX:Float = mouseX - FlxG.mouse.screenX;
		var deltaY:Float = mouseY - FlxG.mouse.screenY;
		mouseX = FlxG.mouse.screenX;
		mouseY = FlxG.mouse.screenY;
		if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.ENTER)
		{
			if (FlxG.keys.justPressed.ENTER)
			{
				Options.save.data.judgeX = judgePlacementPos.x;
				Options.save.data.judgeY = judgePlacementPos.y;
				EngineData.flushSave();
			}
			FlxG.switchState(new OptionsState());
		}

		if (FlxG.mouse.overlaps(judge) && FlxG.mouse.justPressed)
		{
			draggingJudge = true;
		}

		if (FlxG.mouse.justReleased)
		{
			draggingJudge = false;
		}

		if (FlxG.keys.justPressed.R)
		{
			judgePlacementPos.set(0, 0);
		}

		judge.x = defaultPos.x + judgePlacementPos.x;
		judge.y = defaultPos.y + judgePlacementPos.y;

		if (FlxG.keys.justPressed.C)
		{
			showCombo();
		}

		if (draggingJudge)
		{
			if (FlxG.mouse.pressed)
			{
				judgePlacementPos.x -= deltaX;
				judgePlacementPos.y -= deltaY;
			}
			else
			{
				draggingJudge = false;
			}
		}
	}

	override public function destroy():Void
	{
		super.destroy();

		defaultPos.put();
		judgePlacementPos.put();
	}

	private var comboSprites:Array<FlxSprite> = [];

	private function showCombo(combo:Int = 100):Void
	{
		var seperatedScore:Array<String> = Std.string(combo).split('');

		// WHY DOES HAXE NOT HAVE A DECREMENTING FOR LOOP
		// WHAT THE FUCK
		while (comboSprites.length > 0)
		{
			comboSprites[0].kill();
			comboSprites.remove(comboSprites[0]);
		}
		var placement:String = Std.string(combo);
		var coolText:FlxText = new FlxText(FlxG.width * 0.55, 0, 0, placement, 32);
		coolText.screenCenter(Y);
		if (Options.save.data.ratingInHUD)
		{
			coolText.scrollFactor.set();
			coolText.screenCenter();
		}

		var loopsDone:Float = 0;
		var idx:Int = -1;
		for (digit in seperatedScore)
		{
			idx++;
			if (digit == '-')
			{
				digit = 'Negative';
			}
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('num$i'));
			numScore.screenCenter(XY);
			numScore.x = coolText.x + (43 * loopsDone) - 90;
			numScore.y += 25;

			numScore.antialiasing = true;
			numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			numScore.updateHitbox();

			if (Options.save.data.ratingInHUD)
			{
				numScore.scrollFactor.set();
				numScore.y += 50;
				numScore.x -= 50;
			}

			numScore.x += judgePlacementPos.x;
			numScore.y += judgePlacementPos.y;

			add(numScore);
			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: (tween:FlxTween) ->
				{
					numScore.destroy();
				},
				startDelay: Conductor.calculateCrochet(100) * 0.002
			});
			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);

			loopsDone++;
		}
	}
}
