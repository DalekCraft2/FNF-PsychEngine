package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
#if CHECK_FOR_UPDATES
import haxe.Http;
#end
import haxe.Json;
import openfl.Assets;
import options.Options.OptionUtils;
#if FEATURE_MODS
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef TitleData =
{
	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	gfx:Float,
	gfy:Float,
	backgroundSprite:String,
	bpm:Int
}

// FIXME Null object reference if Enter is pressed too quickly when returning to title from main menu

class TitleState extends MusicBeatState
{
	public static var initialized:Bool = false;

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	#if TITLE_SCREEN_EASTER_EGG
	var easterEggKeys:Array<String> = ['SHADOW', 'RIVER', 'SHUBS', 'BBPANZU'];
	var allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	var mustUpdate:Bool = false;

	var titleJSON:TitleData;

	public static var updateVersion:String = '';

	override public function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		super.create();

		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		Week.loadTheFirstEnabledMod();

		// Debug.logTrace(path, FileSystem.exists(path));

		// TODO Try to switch to Polymod because I am so sick of this custom asset system.
		/*#if (polymod && !html5)
			if (FileSystem.exists('mods/')) {
				var folders:Array<String> = [];
				for (file in FileSystem.readDirectory('mods/')) {
					var path:String = haxe.io.Path.join(['mods/', file]);
					if (FileSystem.isDirectory(path)) {
						folders.push(file);
					}
				}
				if(folders.length > 0) {
					polymod.Polymod.init({modRoot: "mods", dirs: folders});
				}
			}
			#end */

		#if CHECK_FOR_UPDATES
		if (!closedState)
		{
			Debug.logTrace('Checking for update');
			var http:Http = new Http("https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/main/gitVersion.txt");

			http.onData = (data:String) ->
			{
				updateVersion = data.split('\n')[0].trim();
				var curVersion:String = MainMenuState.psychEngineVersion.trim();
				Debug.logTrace('Version online: ' + updateVersion + ', Your version: ' + curVersion);
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
		titleJSON = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));

		#if TITLE_SCREEN_EASTER_EGG
		if (FlxG.save.data.psychDevsEasterEgg == null)
			FlxG.save.data.psychDevsEasterEgg = ''; // Crash prevention
		switch (FlxG.save.data.psychDevsEasterEgg.toUpperCase())
		{
			case 'SHADOW':
				titleJSON.gfx += 210;
				titleJSON.gfy += 40;
			case 'RIVER':
				titleJSON.gfx += 100;
				titleJSON.gfy += 20;
			case 'SHUBS':
				titleJSON.gfx += 160;
				titleJSON.gfy -= 10;
			case 'BBPANZU':
				titleJSON.gfx += 45;
				titleJSON.gfy += 100;
		}
		#end

		FlxG.mouse.visible = false;
		if (OptionUtils.options.flashing == null && !FlashingState.leftState)
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

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro():Void
	{
		if (!initialized)
		{
			if (FlxG.sound.music == null)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

				FlxG.sound.music.fadeIn(4, 0, 0.7);
			}
		}

		Conductor.changeBPM(titleJSON.bpm);
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();

		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none")
		{
			bg.loadGraphic(Paths.image(titleJSON.backgroundSprite));
		}
		else
		{
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		}

		// bg.antialiasing = OptionUtils.options.globalAntialiasing;
		// bg.setGraphicSize(Std.int(bg.width * 0.6));
		// bg.updateHitbox();
		add(bg);

		logoBl = new FlxSprite(titleJSON.titlex, titleJSON.titley);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');

		logoBl.antialiasing = OptionUtils.options.globalAntialiasing;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();
		// logoBl.screenCenter();
		// logoBl.color = FlxColor.BLACK;

		swagShader = new ColorSwap();
		gfDance = new FlxSprite(titleJSON.gfx, titleJSON.gfy);

		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		switch (easterEgg.toUpperCase())
		{
			#if TITLE_SCREEN_EASTER_EGG
			case 'SHADOW':
				gfDance.frames = Paths.getSparrowAtlas('ShadowBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shadow Title Bump', 24);
				gfDance.animation.addByPrefix('danceRight', 'Shadow Title Bump', 24);
			case 'RIVER':
				gfDance.frames = Paths.getSparrowAtlas('RiverBump');
				gfDance.animation.addByIndices('danceLeft', 'River Title Bump', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'River Title Bump', [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
			case 'SHUBS':
				gfDance.frames = Paths.getSparrowAtlas('ShubBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shub Title Bump', 24, false);
				gfDance.animation.addByPrefix('danceRight', 'Shub Title Bump', 24, false);
			case 'BBPANZU':
				gfDance.frames = Paths.getSparrowAtlas('BBBump');
				gfDance.animation.addByIndices('danceLeft', 'BB Title Bump', [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'BB Title Bump', [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], "", 24, false);
			#end

			default:
				// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
				// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
				// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
				gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
				gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		}
		gfDance.antialiasing = OptionUtils.options.globalAntialiasing;

		add(gfDance);
		gfDance.shader = swagShader.shader;
		add(logoBl);
		logoBl.shader = swagShader.shader;

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);
		#if (desktop && FEATURE_MODS)
		var path:String = 'mods/${Paths.currentModDirectory}/images/titleEnter.png';
		// Debug.logTrace(path, FileSystem.exists(path));
		if (!FileSystem.exists(path))
		{
			path = "mods/images/titleEnter.png";
		}
		// Debug.logTrace(path, FileSystem.exists(path));
		if (!FileSystem.exists(path))
		{
			path = "assets/images/titleEnter.png";
		}
		// Debug.logTrace(path, FileSystem.exists(path));
		titleText.frames = FlxAtlasFrames.fromSparrow(BitmapData.fromFile(path), File.getContent(path.replace(".png", ".xml")));
		#else
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		#end
		titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
		titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		titleText.antialiasing = OptionUtils.options.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		// titleText.screenCenter(X);
		add(titleText);

		var logo:FlxSprite = new FlxSprite().loadGraphic(Paths.image('logo'));
		logo.screenCenter();
		logo.antialiasing = OptionUtils.options.globalAntialiasing;
		// add(logo);

		// FlxTween.tween(logoBl, {y: logoBl.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG});
		// FlxTween.tween(logo, {y: logoBl.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG, startDelay: 0.1});

		credGroup = new FlxGroup();
		add(credGroup);
		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();

		// credTextShit.alignment = CENTER;

		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		add(ngSpr);
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = OptionUtils.options.globalAntialiasing;

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		if (initialized)
			skipIntro();
		else
			initialized = true;
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var fullText:String = Assets.getText(Paths.txt('introText'));

		var firstArray:Array<String> = fullText.split('\n');
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;

	private static var playJingle:Bool = false;

	override function update(elapsed:Float):Void
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
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;
				// FlxG.sound.music.stop();

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
				// FlxG.sound.play(Paths.music('titleShoot'), 0.7);
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
							if (FlxG.save.data.psychDevsEasterEgg == word)
								FlxG.save.data.psychDevsEasterEgg = '';
							else
								FlxG.save.data.psychDevsEasterEgg = word;
							FlxG.save.flush();

							FlxG.sound.play(Paths.sound('ToggleJingle'));

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

	function createCoolText(textArray:Array<String>, ?offset:Float = 0):Void
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

	function addMoreText(text:String, ?offset:Float = 0):Void
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

	function deleteCoolText():Void
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0; // Basically curBeat but won't be skipped if you hold the tab or resize the screen

	public static var closedState:Bool = false;

	override function beatHit():Void
	{
		super.beatHit();

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

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;

	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			Debug.logInfo("Skipping intro...");

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
				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null)
					easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:FlxSound = null;
				switch (easteregg)
				{
					case 'RIVER':
						sound = FlxG.sound.play(Paths.sound('JingleRiver'));
					case 'SHUBS':
						sound = FlxG.sound.play(Paths.sound('JingleShubs'));
					case 'SHADOW':
						FlxG.sound.play(Paths.sound('JingleShadow'));
					case 'BBPANZU':
						sound = FlxG.sound.play(Paths.sound('JingleBB'));

					default: // Go back to normal ugly ass boring GF
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 2);
						skippedIntro = true;
						playJingle = false;

						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
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
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
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

				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null)
					easteregg = '';
				easteregg = easteregg.toUpperCase();
				#if TITLE_SCREEN_EASTER_EGG
				if (easteregg == 'SHADOW')
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
