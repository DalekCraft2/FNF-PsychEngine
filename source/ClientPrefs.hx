package;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSave;

class ClientPrefs
{
	public static var downScroll:Bool = false;
	public static var middleScroll:Bool = false;
	public static var showFPS:Bool = true;
	public static var flashing:Bool = true;
	public static var globalAntialiasing:Bool = true;
	public static var noteSplashes:Bool = true;
	public static var lowQuality:Bool = false;
	public static var frameRate:Int = 120;
	public static var cursing:Bool = true;
	public static var violence:Bool = true;
	public static var camZooms:Bool = true;
	public static var hideHud:Bool = false;
	public static var noteOffset:Int = 0;
	public static var arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
	public static var imagesPersist:Bool = false;
	public static var ghostTapping:Bool = true;
	public static var timeBarType:String = 'Time Left';
	public static var scoreZoom:Bool = true;
	public static var resetKey:Bool = true;
	public static var healthBarAlpha:Float = 1;
	public static var controllerMode:Bool = false;
	public static var hitsoundVolume:Float = 0;
	public static var pauseMusic:String = 'Tea Time';
	public static var gameplaySettings:Map<String, Dynamic> = [
		'scrollSpeed' => 1.0,
		'scrollType' => 'multiplicative',
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		'songSpeed' => 1.0,
		'healthGain' => 1.0,
		'healthLoss' => 1.0,
		'instakillOnMiss' => false,
		'practiceMode' => false,
		'botPlay' => false,
		'opponentPlay' => false
	];

	public static var comboOffset:Array<Int> = [0, 0, 0, 0];
	public static var ratingOffset:Int = 0;
	public static var sickWindow:Int = 45;
	public static var goodWindow:Int = 90;
	public static var badWindow:Int = 135;
	public static var safeFrames:Float = 10;

	// Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		// Key Bind, Name for ControlsSubState
		'note_left' => [A, LEFT],
		'note_down' => [S, DOWN],
		'note_up' => [W, UP],
		'note_right' => [D, RIGHT],
		'ui_left' => [A, LEFT],
		'ui_down' => [S, DOWN],
		'ui_up' => [W, UP],
		'ui_right' => [D, RIGHT],
		'accept' => [SPACE, ENTER],
		'back' => [BACKSPACE, ESCAPE],
		'pause' => [ENTER, ESCAPE],
		'reset' => [R, NONE],
		'volume_mute' => [ZERO, NONE],
		'volume_up' => [NUMPADPLUS, PLUS],
		'volume_down' => [NUMPADMINUS, MINUS],
		'debug_1' => [SEVEN, NONE],
		'debug_2' => [EIGHT, NONE]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>>;

	public static function loadDefaultKeys():Void
	{
		defaultKeys = keyBinds.copy();
		// Debug.logTrace(defaultKeys);
	}

	public static function saveSettings():Void
	{
		Options.save.data.downScroll = downScroll;
		Options.save.data.middleScroll = middleScroll;
		Options.save.data.showFPS = showFPS;
		Options.save.data.flashing = flashing;
		Options.save.data.globalAntialiasing = globalAntialiasing;
		Options.save.data.noteSplashes = noteSplashes;
		Options.save.data.lowQuality = lowQuality;
		Options.save.data.frameRate = frameRate;
		// Options.save.data.cursing = cursing;
		// Options.save.data.violence = violence;
		Options.save.data.camZooms = camZooms;
		Options.save.data.noteOffset = noteOffset;
		Options.save.data.hideHud = hideHud;
		Options.save.data.arrowHSV = arrowHSV;
		Options.save.data.imagesPersist = imagesPersist;
		Options.save.data.ghostTapping = ghostTapping;
		Options.save.data.timeBarType = timeBarType;
		Options.save.data.scoreZoom = scoreZoom;
		Options.save.data.resetKey = resetKey;
		Options.save.data.healthBarAlpha = healthBarAlpha;
		Options.save.data.comboOffset = comboOffset;

		Options.save.data.ratingOffset = ratingOffset;
		Options.save.data.sickWindow = sickWindow;
		Options.save.data.goodWindow = goodWindow;
		Options.save.data.badWindow = badWindow;
		Options.save.data.safeFrames = safeFrames;
		Options.save.data.gameplaySettings = gameplaySettings;
		Options.save.data.controllerMode = controllerMode;
		Options.save.data.hitsoundVolume = hitsoundVolume;
		Options.save.data.pauseMusic = pauseMusic;

		Options.save.flush();

		var save:FlxSave = new FlxSave();
		save.bind('controls_v2', 'ninjamuffin99'); // Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		save.data.customControls = keyBinds;
		save.flush();
		Debug.logTrace('Settings saved!');

		#if FEATURE_ACHIEVEMENTS
		EngineData.save.data.achievementsMap = Achievement.achievementMap;
		EngineData.save.data.henchmenDeath = Achievement.henchmenDeath;
		#end
	}

	public static function loadPrefs():Void
	{
		if (Options.save.data.downScroll != null)
		{
			downScroll = Options.save.data.downScroll;
		}
		if (Options.save.data.middleScroll != null)
		{
			middleScroll = Options.save.data.middleScroll;
		}
		if (Options.save.data.showFPS != null)
		{
			showFPS = Options.save.data.showFPS;
		}
		if (Options.save.data.flashing != null)
		{
			flashing = Options.save.data.flashing;
		}
		if (Options.save.data.globalAntialiasing != null)
		{
			globalAntialiasing = Options.save.data.globalAntialiasing;
		}
		if (Options.save.data.noteSplashes != null)
		{
			noteSplashes = Options.save.data.noteSplashes;
		}
		if (Options.save.data.lowQuality != null)
		{
			lowQuality = Options.save.data.lowQuality;
		}
		if (Options.save.data.frameRate != null)
		{
			frameRate = Options.save.data.frameRate;
			if (frameRate > FlxG.drawFramerate)
			{
				FlxG.updateFramerate = frameRate;
				FlxG.drawFramerate = frameRate;
			}
			else
			{
				FlxG.drawFramerate = frameRate;
				FlxG.updateFramerate = frameRate;
			}
		}
		/*if (Options.save.data.cursing != null)
			{
				cursing = Options.save.data.cursing;
			}
			if (Options.save.data.violence != null)
			{
				violence = Options.save.data.violence;
		}*/
		if (Options.save.data.camZooms != null)
		{
			camZooms = Options.save.data.camZooms;
		}
		if (Options.save.data.hideHud != null)
		{
			hideHud = Options.save.data.hideHud;
		}
		if (Options.save.data.noteOffset != null)
		{
			noteOffset = Options.save.data.noteOffset;
		}
		if (Options.save.data.arrowHSV != null)
		{
			arrowHSV = Options.save.data.arrowHSV;
		}
		if (Options.save.data.ghostTapping != null)
		{
			ghostTapping = Options.save.data.ghostTapping;
		}
		if (Options.save.data.timeBarType != null)
		{
			timeBarType = Options.save.data.timeBarType;
		}
		if (Options.save.data.scoreZoom != null)
		{
			scoreZoom = Options.save.data.scoreZoom;
		}
		if (Options.save.data.resetKey != null)
		{
			resetKey = Options.save.data.resetKey;
		}
		if (Options.save.data.healthBarAlpha != null)
		{
			healthBarAlpha = Options.save.data.healthBarAlpha;
		}
		if (Options.save.data.comboOffset != null)
		{
			comboOffset = Options.save.data.comboOffset;
		}

		if (Options.save.data.ratingOffset != null)
		{
			ratingOffset = Options.save.data.ratingOffset;
		}
		if (Options.save.data.sickWindow != null)
		{
			sickWindow = Options.save.data.sickWindow;
		}
		if (Options.save.data.goodWindow != null)
		{
			goodWindow = Options.save.data.goodWindow;
		}
		if (Options.save.data.badWindow != null)
		{
			badWindow = Options.save.data.badWindow;
		}
		if (Options.save.data.safeFrames != null)
		{
			safeFrames = Options.save.data.safeFrames;
		}
		if (Options.save.data.controllerMode != null)
		{
			controllerMode = Options.save.data.controllerMode;
		}
		if (Options.save.data.hitsoundVolume != null)
		{
			hitsoundVolume = Options.save.data.hitsoundVolume;
		}
		if (Options.save.data.pauseMusic != null)
		{
			pauseMusic = Options.save.data.pauseMusic;
		}
		if (Options.save.data.gameplaySettings != null)
		{
			var savedMap:Map<String, Dynamic> = Options.save.data.gameplaySettings;
			for (name => value in savedMap)
			{
				gameplaySettings.set(name, value);
			}
		}

		// flixel automatically saves your volume!
		if (EngineData.save.data.volume != null)
		{
			FlxG.sound.volume = EngineData.save.data.volume;
		}
		if (EngineData.save.data.mute != null)
		{
			FlxG.sound.muted = EngineData.save.data.mute;
		}

		var save:FlxSave = new FlxSave();
		save.bind('controls_v2', 'ninjamuffin99');
		if (save != null && save.data.customControls != null)
		{
			var loadedControls:Map<String, Array<FlxKey>> = save.data.customControls;
			for (control => keys in loadedControls)
			{
				keyBinds.set(control, keys);
			}
			reloadControls();
		}
	}

	public static inline function getGameplaySetting(name:String, defaultValue:Dynamic):Dynamic
	{
		return /*PlayState.isStoryMode ? defaultValue : */ (gameplaySettings.exists(name) ? gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadControls():Void
	{
		PlayerSettings.player1.controls.setKeyboardScheme(CUSTOM);

		InitState.muteKeys = copyKey(keyBinds.get('volume_mute'));
		InitState.volumeDownKeys = copyKey(keyBinds.get('volume_down'));
		InitState.volumeUpKeys = copyKey(keyBinds.get('volume_up'));
		FlxG.sound.muteKeys = InitState.muteKeys;
		FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;
	}

	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey>
	{
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len)
		{
			if (copiedArray[i] == NONE)
			{
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}
}
