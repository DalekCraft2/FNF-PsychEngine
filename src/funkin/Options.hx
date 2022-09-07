package funkin;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSave;

class Options
{
	public static final UNBINDABLE_KEYS:Array<FlxKey> = [ALT, SHIFT, TAB, CAPSLOCK, CONTROL, ENTER];
	public static var profile(default, null):OptionProfile = new OptionProfile(); // Used for accessing options
	private static var save(default, null):FlxSave = new FlxSave(); // Used only for options (at least, for now)

	public static function bindSave(name:String = 'mockEngineOptions', ?path:String):Void
	{
		var success:Bool = save.bind(name, path);
		if (success)
		{
			Debug.logInfo('Options loaded!');
			for (field in Type.getInstanceFields(OptionProfile))
			{
				if (Reflect.hasField(save.data, field))
				{
					Reflect.setField(profile, field, Reflect.field(save.data, field));
				}
			}
		}
		else
		{
			Debug.logError('Could not bind option data!');
		}
	}

	public static function flushSave():Void
	{
		for (field in Type.getInstanceFields(OptionProfile))
		{
			Reflect.setField(save.data, field, Reflect.field(profile, field));
		}
		var success:Bool = save.flush();
		if (success)
		{
			Debug.logInfo('Options saved!');
		}
		else
		{
			Debug.logError('Could not flush option data!');
		}
	}

	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey>
	{
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();

		while (copiedArray.contains(NONE))
		{
			copiedArray.remove(NONE);
		}
		return copiedArray;
	}
}

class OptionProfile
{
	public function new()
	{
		keyBinds = OptionDefaults.keyBinds.copy(); // Must initialized be in here so the copy() call doesn't cause an NPE
	}

	// Gameplay settings
	public var keyBinds:Map<String, Array<FlxKey>>;

	public var controllerMode:Bool = OptionDefaults.controllerMode;
	public var resetKey:Bool = OptionDefaults.resetKey;
	public var loadScripts:Bool = OptionDefaults.loadScripts;
	public var ghostTapping:Bool = OptionDefaults.ghostTapping;
	public var scrollType:String = OptionDefaults.scrollType;
	public var scrollSpeed:Float = OptionDefaults.scrollSpeed;
	public var healthGain:Float = OptionDefaults.healthGain;
	public var healthLoss:Float = OptionDefaults.healthLoss;
	public var instakillOnMiss:Bool = OptionDefaults.instakillOnMiss;
	public var practiceMode:Bool = OptionDefaults.practiceMode;
	public var botPlay:Bool = OptionDefaults.botPlay;
	public var ratingOffset:Int = OptionDefaults.ratingOffset;
	public var sickWindow:Int = OptionDefaults.sickWindow;
	public var goodWindow:Int = OptionDefaults.goodWindow;
	public var badWindow:Int = OptionDefaults.badWindow;
	public var safeFrames:Float = OptionDefaults.safeFrames;
	public var noteOffset:Int = OptionDefaults.noteOffset;
	public var comboOffset:Array<Float> = OptionDefaults.comboOffset;

	// public var accuracySystem:String = OptionDefaults.accuracySystem;
	// public var attemptToAdjust:Bool = OptionDefaults.attemptToAdjust;
	// Appearance settings
	public var arrowHSV:Array<Array<Int>> = OptionDefaults.arrowHSV;
	public var showComboCounter:Bool = OptionDefaults.showComboCounter;
	public var showRatings:Bool = OptionDefaults.showRatings;
	public var showHitMS:Bool = OptionDefaults.showHitMS;
	public var showCounters:Bool = OptionDefaults.showCounters;
	public var downScroll:Bool = OptionDefaults.downScroll;
	public var middleScroll:Bool = OptionDefaults.middleScroll;
	public var showOpponentStrums:Bool = OptionDefaults.showOpponentStrums;
	public var distractions:Bool = OptionDefaults.distractions;
	public var violence:Bool = OptionDefaults.violence;
	public var allowNoteModifiers:Bool = OptionDefaults.allowNoteModifiers;
	public var bgAlpha:Float = OptionDefaults.bgAlpha;
	public var healthBarColors:Bool = OptionDefaults.healthBarColors;
	public var onlyScore:Bool = OptionDefaults.onlyScore;
	public var smoothHPBar:Bool = OptionDefaults.smoothHPBar;
	public var fcBasedComboColor:Bool = OptionDefaults.fcBasedComboColor;
	public var holdsBehindStrums:Bool = OptionDefaults.holdsBehindStrums;
	public var picoCameraShake:Bool = OptionDefaults.picoCameraShake;
	public var senpaiShaderStrength:String = OptionDefaults.senpaiShaderStrength;

	// Preferences settings
	public var noteSplashes:Bool = OptionDefaults.noteSplashes;
	public var camFollowsAnims:Bool = OptionDefaults.camFollowsAnims;
	public var hideHUD:Bool = OptionDefaults.hideHUD;
	public var timeBarType:String = OptionDefaults.timeBarType;
	public var scoreScreen:Bool = OptionDefaults.scoreScreen;
	public var inputShow:Bool = OptionDefaults.inputShow;
	public var accuracyDisplay:Bool = OptionDefaults.accuracyDisplay;
	public var npsDisplay:Bool = OptionDefaults.npsDisplay;
	// Setting this to null makes the FlashingState appear on the first startup
	public var flashing:Null<Bool> = OptionDefaults.flashing;
	public var camZooms:Bool = OptionDefaults.camZooms;
	public var scoreZoom:Bool = OptionDefaults.scoreZoom;
	public var healthBarAlpha:Float = OptionDefaults.healthBarAlpha;
	public var ratingInHUD:Bool = OptionDefaults.ratingInHUD;
	public var ratingOverNotes:Bool = OptionDefaults.ratingOverNotes;
	public var smJudges:Bool = OptionDefaults.smJudges;
	public var persistentCombo:Bool = OptionDefaults.persistentCombo;
	public var pauseHoldAnims:Bool = OptionDefaults.pauseHoldAnims;
	public var menuFlash:Bool = OptionDefaults.menuFlash;
	public var hitSound:Bool = OptionDefaults.hitSound;
	public var showFPS:Bool = OptionDefaults.showFPS;
	public var showMem:Bool = OptionDefaults.showMem;
	public var showMemPeak:Bool = OptionDefaults.showMemPeak;
	public var pauseMusic:String = OptionDefaults.pauseMusic;
	public var ghostTapSounds:Bool = OptionDefaults.ghostTapSounds;
	public var hitSoundVolume:Float = OptionDefaults.hitSoundVolume;
	public var fastTransitions:Bool = OptionDefaults.fastTransitions;

	// Performance settings
	public var frameRate:Int = OptionDefaults.frameRate;
	public var recycleComboJudges:Bool = OptionDefaults.recycleComboJudges;
	public var lowQuality:Bool = OptionDefaults.lowQuality;
	public var noChars:Bool = OptionDefaults.noChars;
	public var noStage:Bool = OptionDefaults.noStage;
	public var globalAntialiasing:Bool = OptionDefaults.globalAntialiasing;
	public var allowOrderSorting:Bool = OptionDefaults.allowOrderSorting;
}

class OptionDefaults
{
	// Gameplay settings
	public static final keyBinds:Map<String, Array<FlxKey>> = [
		// Key Bind => Name for Control
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
	public static final controllerMode:Bool = false;
	public static final resetKey:Bool = true;
	public static final loadScripts:Bool = true;
	public static final ghostTapping:Bool = true;
	public static final scrollType:String = 'multiplicative';
	public static final scrollSpeed:Float = 1;
	public static final healthGain:Float = 1;
	public static final healthLoss:Float = 1;
	public static final instakillOnMiss:Bool = false;
	public static final practiceMode:Bool = false;
	public static final botPlay:Bool = false;
	public static final ratingOffset:Int = 0;
	public static final sickWindow:Int = 45;
	public static final goodWindow:Int = 90;
	public static final badWindow:Int = 135;
	public static final safeFrames:Float = 10;
	public static final noteOffset:Int = 0;
	public static final comboOffset:Array<Float> = [0, 0, 0, 0];

	// public static final accuracySystem:String = 'Basic';
	// public static final attemptToAdjust:Bool = false;
	// Appearance settings
	public static final arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
	public static final showComboCounter:Bool = true;
	public static final showRatings:Bool = true;
	public static final showHitMS:Bool = false;
	public static final showCounters:Bool = true;
	public static final downScroll:Bool = false;
	public static final middleScroll:Bool = false;
	public static final showOpponentStrums:Bool = true;
	public static final distractions:Bool = true;
	public static final violence:Bool = false;
	public static final allowNoteModifiers:Bool = true;
	public static final bgAlpha:Float = 0;
	public static final healthBarColors:Bool = true;
	public static final onlyScore:Bool = false;
	public static final smoothHPBar:Bool = false;
	public static final fcBasedComboColor:Bool = false;
	public static final holdsBehindStrums:Bool = false;
	public static final picoCameraShake:Bool = true;
	public static final senpaiShaderStrength:String = 'All';

	// Preferences settings
	public static final noteSplashes:Bool = true;
	public static final camFollowsAnims:Bool = false;
	public static final hideHUD:Bool = false;
	public static final timeBarType:String = 'Time Left';
	public static final scoreScreen:Bool = false;
	public static final inputShow:Bool = false;
	public static final accuracyDisplay:Bool = true;
	public static final npsDisplay:Bool = false;
	// Setting this to null makes the FlashingState appear on the first startup
	public static final flashing:Null<Bool> = null;
	public static final camZooms:Bool = true;
	public static final scoreZoom:Bool = true;
	public static final healthBarAlpha:Float = 1;
	public static final ratingInHUD:Bool = false;
	public static final ratingOverNotes:Bool = false;
	public static final smJudges:Bool = false;
	public static final persistentCombo:Bool = false;
	public static final pauseHoldAnims:Bool = true;
	public static final menuFlash:Bool = true;
	public static final hitSound:Bool = false;
	public static final showFPS:Bool = false;
	public static final showMem:Bool = false;
	public static final showMemPeak:Bool = false;
	public static final pauseMusic:String = 'Tea Time';
	public static final ghostTapSounds:Bool = false;
	public static final hitSoundVolume:Float = 50;
	public static final fastTransitions:Bool = false;

	// Performance settings
	public static final frameRate:Int = #if cpp 120 #else 60 #end;
	public static final recycleComboJudges:Bool = false;
	public static final lowQuality:Bool = false;
	public static final noChars:Bool = false;
	public static final noStage:Bool = false;
	public static final globalAntialiasing:Bool = true;
	public static final allowOrderSorting:Bool = true;
}
