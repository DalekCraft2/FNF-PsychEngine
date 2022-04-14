package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.system.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

using StringTools;

#if CHECK_FOR_UPDATES
import haxe.Http;
#end

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Int;
}

// FIXME Null object reference if Enter is pressed too quickly when returning to title from main menu

class TitleState extends MusicBeatState
{
	public static var initialized:Bool = false;

	private var blackScreen:FlxSprite;
	private var credGroup:FlxGroup;
	private var credTextShit:Alphabet;
	private var textGroup:FlxGroup;
	private var ngSpr:FlxSprite;

	private var curWacky:Array<String> = [];

	#if TITLE_SCREEN_EASTER_EGG
	private var easterEggKeys:Array<String> = ['SHADOW', 'RIVER', 'SHUBS', 'BBPANZU'];
	private var allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	private var easterEggKeysBuffer:String = '';
	#end

	private var mustUpdate:Bool = false;

	public static var titleData:TitleData;

	public static var updateVersion:String = '';

	override public function create():Void
	{
		super.create();

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		Week.loadTheFirstEnabledMod();

		// TODO Try to switch to Polymod because I am so sick of this custom asset system.
		/*#if (polymod && !html5)
			if (FileSystem.exists(Paths.mods()))
			{
				var folders:Array<String> = [];
				for (file in FileSystem.readDirectory(Paths.mods()))
				{
					var path:String = Paths.mods(file);
					if (FileSystem.isDirectory(path))
					{
						folders.push(file);
					}
				}
				if (folders.length > 0)
				{
					polymod.Polymod.init({modRoot: 'mods', dirs: folders});
				}
			}
			#end */

		#if CHECK_FOR_UPDATES
		if (!closedState)
		{
			Debug.logTrace('Checking for update');
			var http:Http = new Http('https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/main/gitVersion.txt');

			http.onData = (data:String) ->
			{
				updateVersion = data.split('\n')[0].trim();
				var curVersion:String = EngineData.ENGINE_VERSION.trim();
				Debug.logTrace('Version online: $updateVersion, Your version: $curVersion');
				if (updateVersion != curVersion)
				{
					Debug.logTrace('Versions aren\'t matching!');
					mustUpdate = true;
				}
			}

			http.onError = (error) ->
			{
				Debug.logError('Error: $error');
			}

			http.request();
		}
		#end

		curWacky = FlxG.random.getObject(getIntroTextShit());

		// DEBUG BULLSHIT

		swagShader = new ColorSwap();

		// IGNORE THIS!!!
		titleData = Paths.getJsonDirect(Paths.file('images/gfDanceTitle.json'));

		#if TITLE_SCREEN_EASTER_EGG
		if (EngineData.save.data.psychDevsEasterEgg == null)
			EngineData.save.data.psychDevsEasterEgg = ''; // Crash prevention
		switch (EngineData.save.data.psychDevsEasterEgg.toUpperCase())
		{
			case 'SHADOW':
				titleData.gfx += 210;
				titleData.gfy += 40;
			case 'RIVER':
				titleData.gfx += 100;
				titleData.gfy += 20;
			case 'SHUBS':
				titleData.gfx += 160;
				titleData.gfy -= 10;
			case 'BBPANZU':
				titleData.gfx += 45;
				titleData.gfy += 100;
		}
		#end

		FlxG.mouse.visible = false;

		if (Options.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new FlashingState());
		}
		else
		{
			new FlxTimer().start(1, (tmr:FlxTimer) ->
			{
				startIntro();
			});
		}
	}

	private var transitioning:Bool = false;

	private static var playJingle:Bool = false;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// Debug.quickWatch('amp', FlxG.sound.music.amplitude);

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		// EASTER EGG

		if (initialized && !transitioning && skippedIntro)
		{
			if (pressedEnter)
			{
				if (titleText != null)
					titleText.animation.play('press');

				FlxG.camera.flash(FlxColor.WHITE, 1);
				FlxG.sound.play(Paths.getSound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(1, (tmr:FlxTimer) ->
				{
					if (mustUpdate)
					{
						FlxG.switchState(new OutdatedState());
					}
					else
					{
						FlxG.switchState(new MainMenuState());
					}
					closedState = true;
				});
			}
			#if TITLE_SCREEN_EASTER_EGG
			else if (FlxG.keys.firstJustPressed() != FlxKey.NONE)
			{
				var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
				var keyName:String = Std.string(keyPressed);
				if (allowedKeys.contains(keyName))
				{
					easterEggKeysBuffer += keyName;
					if (easterEggKeysBuffer.length >= 32)
						easterEggKeysBuffer = easterEggKeysBuffer.substring(1);
					// Debug.logTrace('Test! Allowed Key pressed!!! Buffer: $easterEggKeysBuffer');

					for (wordRaw in easterEggKeys)
					{
						var word:String = wordRaw.toUpperCase(); // just for being sure you're doing it right
						if (easterEggKeysBuffer.contains(word))
						{
							// Debug.logTrace('YOOO! $word');
							if (EngineData.save.data.psychDevsEasterEgg == word)
								EngineData.save.data.psychDevsEasterEgg = '';
							else
								EngineData.save.data.psychDevsEasterEgg = word;
							EngineData.flushSave();

							FlxG.sound.play(Paths.getSound('ToggleJingle'));

							var black:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
							black.alpha = 0;
							add(black);

							FlxTween.tween(black, {alpha: 1}, 1, {
								onComplete: (twn:FlxTween) ->
								{
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									FlxG.switchState(new TitleState());
								}
							});
							FlxG.sound.music.fadeOut();
							closedState = true;
							transitioning = true;
							playJingle = true;
							easterEggKeysBuffer = '';
							break;
						}
					}
				}
			}
			#end
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if (swagShader != null)
		{
			if (controls.UI_LEFT)
				swagShader.hue -= elapsed * 0.1;
			if (controls.UI_RIGHT)
				swagShader.hue += elapsed * 0.1;
		}
	}

	// TODO Maybe just switch back to curBeat
	private var sickBeats:Int = 0; // Basically curBeat but won't be skipped if you hold the tab or resize the screen

	public static var closedState:Bool = false;

	override public function beatHit(beat:Int):Void
	{
		super.beatHit(beat);

		if (logoBl != null)
			logoBl.animation.play('bump', true);

		if (gfDance != null)
		{
			danceLeft = !danceLeft;
			if (danceLeft)
				gfDance.animation.play('danceRight');
			else
				gfDance.animation.play('danceLeft');
		}

		if (!closedState)
		{
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					#if PSYCH_WATERMARKS
					createCoolText(['Psych Engine by'], 15);
					#else
					createCoolText(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
					#end
				case 3:
					#if PSYCH_WATERMARKS
					addMoreText('Shadow Mario', 15);
					addMoreText('RiverOaken', 15);
					addMoreText('shubs', 15);
					#else
					addMoreText('present');
					#end
				case 4:
					deleteCoolText();
				case 5:
					#if PSYCH_WATERMARKS
					createCoolText(['Not associated', 'with'], -40);
					#else
					createCoolText(['In association', 'with'], -40);
					#end
				case 7:
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				case 8:
					deleteCoolText();
					ngSpr.visible = false;
				case 9:
					createCoolText([curWacky[0]]);
				case 11:
					addMoreText(curWacky[1]);
				case 12:
					deleteCoolText();
				case 13:
					addMoreText('Friday');
				case 14:
					addMoreText('Night');
				case 15:
					addMoreText('Funkin');
				case 16:
					skipIntro();
			}
		}
	}

	private var logoBl:FlxSprite;
	private var gfDance:FlxSprite;
	private var danceLeft:Bool = false;
	private var titleText:FlxSprite;
	private var swagShader:ColorSwap;

	private function startIntro():Void
	{
		if (!initialized)
		{
			if (FlxG.sound.music == null)
			{
				FlxG.sound.playMusic(Paths.getMusic('freakyMenu'), 0);

				FlxG.sound.music.fadeIn(4, 0, 0.7);
			}
		}

		Conductor.changeBPM(titleData.bpm);
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();

		if (titleData.backgroundSprite != null && titleData.backgroundSprite.length > 0 && titleData.backgroundSprite != 'none')
		{
			bg.loadGraphic(Paths.getGraphic(titleData.backgroundSprite));
		}
		else
		{
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		}
		add(bg);

		logoBl = new FlxSprite(titleData.titlex, titleData.titley);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');

		logoBl.antialiasing = Options.save.data.globalAntialiasing;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		swagShader = new ColorSwap();
		gfDance = new FlxSprite(titleData.gfx, titleData.gfy);

		#if TITLE_SCREEN_EASTER_EGG
		var easterEgg:String = EngineData.save.data.psychDevsEasterEgg;
		#else
		var easterEgg:String = '';
		#end
		switch (easterEgg.toUpperCase())
		{
			#if TITLE_SCREEN_EASTER_EGG
			case 'SHADOW':
				gfDance.frames = Paths.getSparrowAtlas('ShadowBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shadow Title Bump', 24);
				gfDance.animation.addByPrefix('danceRight', 'Shadow Title Bump', 24);
			case 'RIVER':
				gfDance.frames = Paths.getSparrowAtlas('RiverBump');
				gfDance.animation.addByIndices('danceLeft', 'River Title Bump', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], '', 24, false);
				gfDance.animation.addByIndices('danceRight', 'River Title Bump', [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], '', 24, false);
			case 'SHUBS':
				gfDance.frames = Paths.getSparrowAtlas('ShubBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shub Title Bump', 24, false);
				gfDance.animation.addByPrefix('danceRight', 'Shub Title Bump', 24, false);
			case 'BBPANZU':
				gfDance.frames = Paths.getSparrowAtlas('BBBump');
				gfDance.animation.addByIndices('danceLeft', 'BB Title Bump', [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], '', 24, false);
				gfDance.animation.addByIndices('danceRight', 'BB Title Bump', [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], '', 24, false);
			#end

			default:
				// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
				// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
				// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
				gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
				gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], '', 24, false);
				gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], '', 24, false);
		}
		gfDance.antialiasing = Options.save.data.globalAntialiasing;

		add(gfDance);
		gfDance.shader = swagShader.shader;
		add(logoBl);
		logoBl.shader = swagShader.shader;

		titleText = new FlxSprite(titleData.startx, titleData.starty);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		titleText.animation.addByPrefix('idle', 'Press Enter to Begin', 24);
		titleText.animation.addByPrefix('press', 'ENTER PRESSED', 24);
		titleText.antialiasing = Options.save.data.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.getGraphic('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = Options.save.data.globalAntialiasing;
		add(ngSpr);

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		if (initialized)
			skipIntro();
		else
			initialized = true;
	}

	private function getIntroTextShit():Array<Array<String>>
	{
		var firstArray:Array<String> = CoolUtil.coolTextFile(Paths.txt('introText'));

		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	private function createCoolText(textArray:Array<String>, ?offset:Float = 0):Void
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true, false);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if (credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	private function addMoreText(text:String, ?offset:Float = 0):Void
	{
		if (textGroup != null && credGroup != null)
		{
			var coolText:Alphabet = new Alphabet(0, 0, text, true, false);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	private function deleteCoolText():Void
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var skippedIntro:Bool = false;

	private function skipIntro():Void
	{
		if (!skippedIntro)
		{
			Debug.logInfo('Skipping intro...');

			// Make the logo do wacky waving inflatable arm-flailing angle tweens
			FlxTween.tween(logoBl, {y: -100}, 1.4, {ease: FlxEase.expoInOut});
			logoBl.angle = -4;
			new FlxTimer().start(0.01, (tmr:FlxTimer) ->
			{
				if (logoBl.angle == -4)
					FlxTween.angle(logoBl, logoBl.angle, 4, 4, {ease: FlxEase.quartInOut});
				if (logoBl.angle == 4)
					FlxTween.angle(logoBl, logoBl.angle, -4, 4, {ease: FlxEase.quartInOut});
			}, 0);

			if (playJingle) // Ignore deez
			{
				var easteregg:String = EngineData.save.data.psychDevsEasterEgg;
				if (easteregg == null)
					easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:Null<FlxSound> = null;
				switch (easteregg)
				{
					case 'RIVER':
						sound = FlxG.sound.play(Paths.getSound('JingleRiver'));
					case 'SHUBS':
						sound = FlxG.sound.play(Paths.getSound('JingleShubs'));
					case 'SHADOW':
						FlxG.sound.play(Paths.getSound('JingleShadow'));
					case 'BBPANZU':
						sound = FlxG.sound.play(Paths.getSound('JingleBB'));

					default: // Go back to normal ugly ass boring GF
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 2);
						skippedIntro = true;
						playJingle = false;

						FlxG.sound.playMusic(Paths.getMusic('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						return;
				}

				transitioning = true;
				if (easteregg == 'SHADOW')
				{
					new FlxTimer().start(3.2, (tmr:FlxTimer) ->
					{
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 0.6);
						transitioning = false;
					});
				}
				else
				{
					remove(ngSpr);
					remove(credGroup);
					FlxG.camera.flash(FlxColor.WHITE, 3);
					sound.onComplete = () ->
					{
						FlxG.sound.playMusic(Paths.getMusic('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						transitioning = false;
					};
				}
				playJingle = false;
			}
			else // Default! Edit this one!!
			{
				remove(ngSpr);
				remove(credGroup);
				FlxG.camera.flash(FlxColor.WHITE, 4);

				var easterEgg:String = EngineData.save.data.psychDevsEasterEgg;
				if (easterEgg == null)
					easterEgg = '';
				easterEgg = easterEgg.toUpperCase();
				#if TITLE_SCREEN_EASTER_EGG
				if (easterEgg == 'SHADOW')
				{
					FlxG.sound.music.fadeOut();
				}
				#end

				// It always bugged me that it didn't do this before.
				// Skip ahead in the song to the drop.
				FlxG.sound.music.time = 9400; // 9.4 seconds
			}
			skippedIntro = true;
		}
	}
}
