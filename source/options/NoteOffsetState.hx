package options;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;

class NoteOffsetState extends MusicBeatState
{
	private var boyfriend:Character;
	private var gf:Character;

	private var camHUD:FlxCamera;
	private var camGame:FlxCamera;
	private var camOther:FlxCamera;

	private var coolText:FlxText;
	private var rating:FlxSprite;
	private var comboNums:FlxSpriteGroup;
	private var dumbTexts:FlxTypedGroup<FlxText>;

	private var barPercent:Float = 0;
	private var delayMin:Int = 0;
	private var delayMax:Int = 500;
	private var timeBarBG:FlxSprite;
	private var timeBar:FlxBar;
	private var timeTxt:FlxText;
	private var beatText:Alphabet;
	private var beatTween:FlxTween;

	private var changeModeText:FlxText;

	public function new()
	{
		super();

		if (Options.save.data.comboOffset == null)
			Options.save.data.comboOffset = [0, 0, 0, 0];
	}

	override public function create():Void
	{
		super.create();

		// Cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		FlxG.camera.scroll.set(120, 130);

		persistentUpdate = true;
		FlxG.sound.pause();
		// Stage
		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
		add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);

		if (!Options.save.data.lowQuality)
		{
			var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();
			add(stageLight);
			stageLight = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();
			stageLight.flipX = true;
			add(stageLight);

			var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
			stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
			stageCurtains.updateHitbox();
			add(stageCurtains);
		}

		// Characters
		gf = new Character(400, 130, 'gf');
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
		gf.scrollFactor.set(0.95, 0.95);
		boyfriend = new Character(770, 100, true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(gf);
		add(boyfriend);

		// Combo stuff

		coolText = new FlxText(FlxG.width * 0.35, 0, 0, 32);
		coolText.screenCenter(Y);

		rating = new FlxSprite().loadGraphic(Paths.getGraphic('sick'));
		rating.cameras = [camHUD];
		rating.setGraphicSize(Std.int(rating.width * 0.7));
		rating.updateHitbox();
		rating.antialiasing = Options.save.data.globalAntialiasing;

		add(rating);

		comboNums = new FlxSpriteGroup();
		comboNums.cameras = [camHUD];
		add(comboNums);

		var seperatedScore:Array<Int> = [];
		for (i in 0...3)
		{
			seperatedScore.push(FlxG.random.int(0, 9));
		}

		var loopsDone:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite(43 * loopsDone).loadGraphic(Paths.getGraphic('num$i'));
			numScore.cameras = [camHUD];
			numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			numScore.updateHitbox();
			numScore.antialiasing = Options.save.data.globalAntialiasing;
			comboNums.add(numScore);
			loopsDone++;
		}

		dumbTexts = new FlxTypedGroup();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);
		createTexts();

		repositionCombo();

		// Note delay stuff

		beatText = new Alphabet(0, 0, 'Beat Hit!', true, false, 0.05, 0.6);
		beatText.x += 260;
		beatText.alpha = 0;
		beatText.acceleration.y = 250;
		beatText.visible = false;
		add(beatText);

		timeTxt = new FlxText(0, 600, FlxG.width, 32);
		timeTxt.setFormat(Paths.font('vcr.ttf'), timeTxt.size, CENTER, OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.borderSize = 2;
		timeTxt.visible = false;
		timeTxt.cameras = [camHUD];

		barPercent = Options.save.data.noteOffset;
		updateNoteDelay();

		timeBarBG = new FlxSprite(0, timeTxt.y + 8).loadGraphic(Paths.getGraphic('timeBar'));
		timeBarBG.setGraphicSize(Std.int(timeBarBG.width * 1.2));
		timeBarBG.updateHitbox();
		timeBarBG.cameras = [camHUD];
		timeBarBG.screenCenter(X);
		timeBarBG.visible = false;

		timeBar = new FlxBar(0, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this, 'barPercent', delayMin,
			delayMax);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; // How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.visible = false;
		timeBar.cameras = [camHUD];

		add(timeBarBG);
		add(timeBar);
		add(timeTxt);

		///////////////////////

		var blackBox:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		blackBox.scrollFactor.set();
		blackBox.alpha = 0.6;
		blackBox.cameras = [camHUD];
		add(blackBox);

		changeModeText = new FlxText(0, 4, FlxG.width, 32);
		changeModeText.setFormat(Paths.font('vcr.ttf'), changeModeText.size, CENTER);
		changeModeText.scrollFactor.set();
		changeModeText.cameras = [camHUD];
		add(changeModeText);
		updateMode();

		Conductor.changeBPM(128.0);
		FlxG.sound.playMusic(Paths.getMusic('offsetSong'), 1, true);
	}

	private var holdTime:Float = 0;
	private var onComboMenu:Bool = true;
	private var holdingObjectType:Null<Bool>;

	private var startMousePos:FlxPoint = new FlxPoint();
	private var startComboOffset:FlxPoint = new FlxPoint();

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var addNum:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			addNum = 10;

		if (onComboMenu)
		{
			var controlArray:Array<Bool> = [
				FlxG.keys.justPressed.LEFT,
				FlxG.keys.justPressed.RIGHT,
				FlxG.keys.justPressed.UP,
				FlxG.keys.justPressed.DOWN,

				FlxG.keys.justPressed.A,
				FlxG.keys.justPressed.D,
				FlxG.keys.justPressed.W,
				FlxG.keys.justPressed.S
			];

			if (controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if (controlArray[i])
					{
						switch (i)
						{
							case 0:
								Options.save.data.comboOffset[0] -= addNum;
							case 1:
								Options.save.data.comboOffset[0] += addNum;
							case 2:
								Options.save.data.comboOffset[1] += addNum;
							case 3:
								Options.save.data.comboOffset[1] -= addNum;
							case 4:
								Options.save.data.comboOffset[2] -= addNum;
							case 5:
								Options.save.data.comboOffset[2] += addNum;
							case 6:
								Options.save.data.comboOffset[3] += addNum;
							case 7:
								Options.save.data.comboOffset[3] -= addNum;
						}
					}
				}
				repositionCombo();
			}

			// probably there's a better way to do this but, oh well.
			if (FlxG.mouse.justPressed)
			{
				holdingObjectType = null;
				FlxG.mouse.getScreenPosition(camHUD, startMousePos);
				if (startMousePos.x - comboNums.x >= 0
					&& startMousePos.x - comboNums.x <= comboNums.width
					&& startMousePos.y - comboNums.y >= 0
					&& startMousePos.y - comboNums.y <= comboNums.height)
				{
					holdingObjectType = true;
					startComboOffset.x = Options.save.data.comboOffset[2];
					startComboOffset.y = Options.save.data.comboOffset[3];
					// Debug.logTrace('yo bro');
				}
				else if (startMousePos.x - rating.x >= 0
					&& startMousePos.x - rating.x <= rating.width
					&& startMousePos.y - rating.y >= 0
					&& startMousePos.y - rating.y <= rating.height)
				{
					holdingObjectType = false;
					startComboOffset.x = Options.save.data.comboOffset[0];
					startComboOffset.y = Options.save.data.comboOffset[1];
					// Debug.logTrace('heya');
				}
			}
			if (FlxG.mouse.justReleased)
			{
				holdingObjectType = null;
				// Debug.logTrace('dead');
			}

			if (holdingObjectType != null)
			{
				if (FlxG.mouse.justMoved)
				{
					var mousePos:FlxPoint = FlxG.mouse.getScreenPosition(camHUD);
					var addNum:Int = holdingObjectType ? 2 : 0;
					Options.save.data.comboOffset[addNum + 0] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
					Options.save.data.comboOffset[addNum + 1] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
					repositionCombo();
				}
			}

			if (controls.RESET)
			{
				for (i in 0...Options.save.data.comboOffset.length)
				{
					Options.save.data.comboOffset[i] = 0;
				}
				repositionCombo();
			}
		}
		else
		{
			if (controls.UI_LEFT_P)
			{
				barPercent = Math.max(delayMin, Math.min(Options.save.data.noteOffset - 1, delayMax));
				updateNoteDelay();
			}
			else if (controls.UI_RIGHT_P)
			{
				barPercent = Math.max(delayMin, Math.min(Options.save.data.noteOffset + 1, delayMax));
				updateNoteDelay();
			}

			var mult:Int = 1;
			if (controls.UI_LEFT || controls.UI_RIGHT)
			{
				holdTime += elapsed;
				if (controls.UI_LEFT)
					mult = -1;
			}

			if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
				holdTime = 0;

			if (holdTime > 0.5)
			{
				barPercent += 100 * elapsed * mult;
				barPercent = Math.max(delayMin, Math.min(barPercent, delayMax));
				updateNoteDelay();
			}

			if (controls.RESET)
			{
				holdTime = 0;
				barPercent = 0;
				updateNoteDelay();
			}
		}

		if (controls.ACCEPT)
		{
			onComboMenu = !onComboMenu;
			updateMode();
		}

		if (controls.BACK)
		{
			if (zoomTween != null)
				zoomTween.cancel();
			if (beatTween != null)
				beatTween.cancel();

			persistentUpdate = false;
			FlxG.switchState(new OptionsState());
			FlxG.mouse.visible = false;
		}

		Conductor.songPosition = FlxG.sound.music.time;
	}

	private var zoomTween:FlxTween;

	override public function beatHit(beat:Int):Void
	{
		super.beatHit(beat);

		if (beat % 2 == 0)
		{
			boyfriend.dance();
			gf.dance();
		}

		if (beat % 4 == 2)
		{
			FlxG.camera.zoom = 1.15;

			if (zoomTween != null)
				zoomTween.cancel();
			zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1}, 1, {
				ease: FlxEase.circOut,
				onComplete: (twn:FlxTween) ->
				{
					zoomTween = null;
				}
			});

			beatText.alpha = 1;
			beatText.y = 320;
			beatText.velocity.y = -150;
			if (beatTween != null)
				beatTween.cancel();
			beatTween = FlxTween.tween(beatText, {alpha: 0}, 1, {
				ease: FlxEase.sineIn,
				onComplete: (twn:FlxTween) ->
				{
					beatTween = null;
				}
			});
		}
	}

	private function repositionCombo():Void
	{
		rating.screenCenter();
		rating.x = coolText.x - 40 + Options.save.data.comboOffset[0];
		rating.y -= 60 + Options.save.data.comboOffset[1];

		comboNums.screenCenter();
		comboNums.x = coolText.x - 90 + Options.save.data.comboOffset[2];
		comboNums.y += 80 - Options.save.data.comboOffset[3];
		reloadTexts();
	}

	private function createTexts():Void
	{
		for (i in 0...4)
		{
			var text:FlxText = new FlxText(10, 48 + (i * 30), 0, 24);
			text.setFormat(Paths.font('vcr.ttf'), text.size, LEFT, OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 2;
			dumbTexts.add(text);
			text.cameras = [camHUD];

			if (i > 1)
			{
				text.y += 24;
			}
		}
	}

	private function reloadTexts():Void
	{
		for (i in 0...dumbTexts.length)
		{
			switch (i)
			{
				case 0:
					dumbTexts.members[i].text = 'Rating Offset:';
				case 1:
					dumbTexts.members[i].text = '[${Options.save.data.comboOffset[0]}, ${Options.save.data.comboOffset[1]}]';
				case 2:
					dumbTexts.members[i].text = 'Numbers Offset:';
				case 3:
					dumbTexts.members[i].text = '[${Options.save.data.comboOffset[2]}, ${Options.save.data.comboOffset[3]}]';
			}
		}
	}

	private function updateNoteDelay():Void
	{
		Options.save.data.noteOffset = Math.round(barPercent);
		timeTxt.text = 'Current offset: ${Math.floor(barPercent)} ms';
	}

	private function updateMode():Void
	{
		rating.visible = onComboMenu;
		comboNums.visible = onComboMenu;
		dumbTexts.visible = onComboMenu;

		timeBarBG.visible = !onComboMenu;
		timeBar.visible = !onComboMenu;
		timeTxt.visible = !onComboMenu;
		beatText.visible = !onComboMenu;

		if (onComboMenu)
			changeModeText.text = '< Combo Offset (Press Accept to Switch) >';
		else
			changeModeText.text = '< Note/Beat Delay (Press Accept to Switch) >';

		changeModeText.text = changeModeText.text.toUpperCase();
		FlxG.mouse.visible = onComboMenu;
	}
}
