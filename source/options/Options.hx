package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.util.FlxSave;

class Options
{
	public static var noteSkins:Array<String> = [];

	public static final UNBINDABLE_KEYS:Array<FlxKey> = [ALT, SHIFT, TAB, CAPSLOCK, CONTROL, ENTER];

	public static var save(default, null):FlxSave = new FlxSave(); // Used only for options (at least, for now)

	public static function bindSave(?name:String = 'mockEngineOptions', ?path:String):Void
	{
		save.bind(name, path);
		Debug.logTrace('Options loaded!');
	}

	public static function fillMissingOptionFields():Void
	{
		var fields:Array<String> = Type.getClassFields(OptionDefaults);
		for (f in fields)
		{
			if (!Reflect.hasField(save.data, f) || Reflect.field(save.data, f) == null)
				Reflect.setField(save.data, f, Reflect.field(OptionDefaults, f));
		}
	}

	public static function flushSave():Void
	{
		save.flush();
		Debug.logTrace('Options saved!');
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
	public static final loadLuaScripts:Bool = true;
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
	public static final allowNoteModifiers:Bool = true;
	public static final bgAlpha:Float = 0;
	public static final cameraFocus:String = 'Default';
	public static final healthBarColors:Bool = true;
	public static final onlyScore:Bool = false;
	public static final smoothHPBar:Bool = false;
	public static final fcBasedComboColor:Bool = false;
	public static final holdsBehindStrums:Bool = false;
	// public static final noteSkin:?? = ??; // I'll do this when I implement it.
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
	// public static final shouldCache:Bool = false;
	// public static final cacheSongs:Bool = false;
	// public static final cacheSounds:Bool = false;
	// public static final cacheImages:Bool = false;
	// public static final persistentImages:Bool = false;
}

// Try to use custom options instead of states, so they can be safely opened in a PauseSubState without closing the PlayState
class StateOption extends Option
{
	private var state:FlxState;

	public function new(?name:String, ?description:String, state:FlxState)
	{
		super(name, description);

		this.state = state;
	}

	override public function accept():Bool
	{
		FlxG.switchState(state);
		return false;
	}
}

/**
 * A class made to simplify the reading/writing of values in the save file
 */
class ValueOption<T> extends Option
{
	public var property:String = 'dummy';

	public var value(get, set):T;
	public var defaultValue(get, never):T;

	public function new(property:String, ?name:String, ?description:String)
	{
		super(name, description);

		this.property = property;
	}

	private function get_value():T
	{
		if (!Reflect.hasField(Options.save.data, property) || Reflect.field(Options.save.data, property) == null)
			Reflect.setField(Options.save.data, property, defaultValue);
		return Reflect.field(Options.save.data, property);
	}

	private function set_value(value:T):T
	{
		Reflect.setField(Options.save.data, property, value);
		return this.value;
	}

	private function get_defaultValue():T
	{
		if (!Reflect.hasField(OptionDefaults, property))
			Debug.logError('OptionDefaults does not contain default value for option "$property"');
		return Reflect.field(OptionDefaults, property);
	}
}

/**
 * A class made to reduce the duplicated code for the options with left and right arrows
 */
class ArrowOption<T> extends ValueOption<T>
{
	private var label:String;
	private var labelAlphabet:Alphabet;
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;

	public function new(property:String, ?name:String, ?description:String)
	{
		super(property, name, description);

		label = Std.string(value);

		leftArrow = new FlxSprite(0, 0);
		leftArrow.frames = Paths.getSparrowAtlas('arrows');
		leftArrow.setGraphicSize(Std.int(leftArrow.width * 0.7));
		leftArrow.updateHitbox();
		leftArrow.animation.addByPrefix('pressed', 'arrow push left', 24, false);
		leftArrow.animation.addByPrefix('static', 'arrow left', 24, false);
		leftArrow.animation.play('static');

		rightArrow = new FlxSprite(0, 0);
		rightArrow.frames = Paths.getSparrowAtlas('arrows');
		rightArrow.setGraphicSize(Std.int(rightArrow.width * 0.7));
		rightArrow.updateHitbox();
		rightArrow.animation.addByPrefix('pressed', 'arrow push right', 24, false);
		rightArrow.animation.addByPrefix('static', 'arrow right', 24, false);
		rightArrow.animation.play('static');

		add(rightArrow);
		add(leftArrow);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;

		if (PlayerSettings.player1.controls.UI_LEFT && isSelected)
		{
			leftArrow.animation.play('pressed');
			leftArrow.offset.x = 0;
			leftArrow.offset.y = -3;
		}
		else
		{
			leftArrow.animation.play('static');
			leftArrow.offset.x = 0;
			leftArrow.offset.y = 0;
		}

		if (PlayerSettings.player1.controls.UI_RIGHT && isSelected)
		{
			rightArrow.animation.play('pressed');
			rightArrow.offset.x = 0;
			rightArrow.offset.y = -3;
		}
		else
		{
			rightArrow.animation.play('static');
			rightArrow.offset.x = 0;
			rightArrow.offset.y = 0;
		}
		rightArrow.x = labelAlphabet.x + labelAlphabet.width + 10;
		leftArrow.x = labelAlphabet.x - 60;
		leftArrow.y = labelAlphabet.y - 10;
		rightArrow.y = labelAlphabet.y - 10;
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		super.createOptionText(curSelected, optionText);

		remove(labelAlphabet);
		labelAlphabet = new Alphabet(0, (70 * curSelected), label, false, false);
		labelAlphabet.isMenuItem = true;
		labelAlphabet.xAdd = text.width + 120;
		labelAlphabet.targetY = text.targetY;
		add(labelAlphabet);
		return text;
	}

	override public function updateOptionText():Void
	{
		super.updateOptionText();

		labelAlphabet.changeText(label);
	}
}

class OptionCheckbox extends FlxSprite
{
	public var tracker:FlxSprite;

	private var state:Bool;
	private var copyAlpha:Bool = true;
	private var offsetX:Float = 0;
	private var offsetY:Float = 0;

	public function new(state:Bool = false)
	{
		super();

		this.state = state;
		frames = Paths.getSparrowAtlas('checkbox');
		animation.addByPrefix('unchecked', 'unchecked', 24, false);
		animation.addByPrefix('unchecking', 'unchecking', 24, false);
		animation.addByPrefix('checking', 'checking', 24, false);
		animation.addByPrefix('checked', 'checked', 24, false);

		antialiasing = Options.save.data.globalAntialiasing;
		setGraphicSize(Std.int(0.9 * width));
		updateHitbox();

		animationFinished(state ? 'checking' : 'unchecking');
		animation.finishCallback = animationFinished;
	}

	public function changeState(state:Bool):Void
	{
		this.state = state;
		if (state)
		{
			if (animation.curAnim.name != 'checked' && animation.curAnim.name != 'checking')
			{
				animation.play('checking', true);
				offset.set(34, 25);
			}
		}
		else if (animation.curAnim.name != 'unchecked' && animation.curAnim.name != 'unchecking')
		{
			animation.play('unchecking', true);
			offset.set(25, 28);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (tracker != null)
		{
			setPosition(tracker.x - 130 + offsetX, tracker.y + offsetY);
			if (copyAlpha)
			{
				alpha = tracker.alpha;
			}
		}
	}

	private function animationFinished(name:String):Void
	{
		switch (name)
		{
			case 'checking':
				animation.play('checked', true);
				offset.set(3, 12);

			case 'unchecking':
				animation.play('unchecked', true);
				offset.set(0, 2);
		}
	}
}

class BooleanOption extends ValueOption<Bool>
{
	private var callback:(Bool) -> Void;
	private var checkbox:OptionCheckbox;

	public function new(property:String, name:String, ?description:String, ?callback:(value:Bool) -> Void)
	{
		super(property, name, description);

		this.callback = callback;
		checkbox = new OptionCheckbox(value);
		add(checkbox);
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		super.createOptionText(curSelected, optionText);

		text.xAdd = 145;
		checkbox.tracker = text;
		return text;
	}

	override public function accept():Bool
	{
		value = !value;
		checkbox.changeState(value);
		if (callback != null)
		{
			callback(value);
		}
		return false;
	}
}

class IntegerOption extends ArrowOption<Int>
{
	private var step:Int;
	private var min:Int;
	private var max:Int;
	// private var scrollSpeed:Int = 50;
	private var suffix:String;
	private var prefix:String;
	private var callback:(Int, Int) -> Void;

	public function new(property:String, name:String, ?description:String, ?step:Int = 1, ?min:Int = -1, ?max:Int = -1, ?suffix:String = '',
			?prefix:String = '', ?callback:(value:Int, change:Int) -> Void)
	{
		super(property, name, description);

		this.step = step;
		this.min = min;
		this.max = max;
		this.suffix = suffix;
		this.prefix = prefix;
		this.callback = callback;
		label = '$prefix$value$suffix';
	}

	override public function left():Bool
	{
		return changeSelection(-step);
	}

	override public function right():Bool
	{
		return changeSelection(step);
	}

	private function changeSelection(change:Int = 0):Bool
	{
		value += change;
		if (min != -1 && value < min)
			value = max;
		else if (max != -1 && value > max)
			value = min;

		label = '$prefix$value$suffix';
		if (callback != null)
			callback(value, change);
		return true;
	}
}

class FloatOption extends ArrowOption<Float>
{
	private var step:Float;
	private var min:Float;
	private var max:Float;
	// private var scrollSpeed:Float = 50;
	private var suffix:String;
	private var prefix:String;
	private var truncateFloat:Bool;
	private var callback:(Float, Float) -> Void;

	public function new(property:String, name:String, ?description:String, ?step:Float = 1, ?min:Float = -1, ?max:Float = -1, ?suffix:String = '',
			?prefix:String = '', ?truncateFloat = false, ?callback:(value:Float, change:Float) -> Void)
	{
		super(property, name, description);

		this.step = step;
		this.suffix = suffix;
		this.prefix = prefix;
		this.callback = callback;
		this.max = max;
		this.min = min;
		this.truncateFloat = truncateFloat;
		if (truncateFloat)
			value = FlxMath.roundDecimal(value, 2);
		label = '$prefix$value$suffix';
	}

	override public function left():Bool
	{
		return changeSelection(-step);
	}

	override public function right():Bool
	{
		return changeSelection(step);
	}

	private function changeSelection(change:Float = 0):Bool
	{
		value += change;
		if (min != -1 && value < min)
			value = max;
		else if (max != -1 && value > max)
			value = min;

		if (truncateFloat)
			value = FlxMath.roundDecimal(value, 2);
		label = '$prefix$value$suffix';
		if (callback != null)
			callback(value, change);
		return true;
	}
}

class StringOption extends ArrowOption<String>
{
	private var min:Int;
	private var max:Int;
	private var names:Array<String>;
	private var callback:(Int, String, Int) -> Void;

	// i wish there was a better way to do this ^
	// if there is and you're reading this and know a better way, PR please!

	public function new(property:String, name:String, ?description:String, ?min:Int = -1, ?max:Int = -1, ?names:Array<String>,
			?callback:(index:Int, value:String, change:Int) -> Void)
	{
		super(property, name, description);

		this.min = min;
		this.max = max;
		this.names = names;
		this.callback = callback;
	}

	override public function left():Bool
	{
		return changeSelection(-1);
	}

	override public function right():Bool
	{
		return changeSelection(1);
	}

	private function changeSelection(change:Int = 0):Bool
	{
		var index:Int = names.indexOf(value) + change;
		if (min != -1 && index < min)
			index = max;
		else if (max != -1 && index > max)
			index = min;

		value = names != null ? names[index] : Std.string(index);
		label = value;
		if (callback != null)
			callback(index, value, change);
		return true;
	}
}

// TODO Combine this with Psych's options for directly editing judgements

/*class JudgementsOption extends ArrowOption<String>
	{
	private var names:Array<String> = [];

	public function new(property:String, name:String, description:String)
	{
		super(property, name, description);

		var index:Int = 0;

		var judgementOrder:Array<String> = CoolUtil.coolTextFile(Paths.txt('judgementOrder'));

		for (judgement in judgementOrder)
		{
			names.push(judgement);
			if (value == judgement)
				curValue = index;
			index++;
		}

		for (judgement in Reflect.fields(JudgementManager.rawJudgements))
		{
			if (!names.contains(judgement))
			{
				names.push(judgement);
				if (value == judgement)
					curValue = index;
				index++;
			}
		}

		label = names[index];
	}

	override public function left():Bool
	{
		return changeSelection(-1);
	}

	override public function right():Bool
	{
		return changeSelection(1);
	}

	private function changeSelection(change:Int = 0):Bool
	{
		var index:Int = names.indexOf(value) + change;

		if (index < 0)
			index = names.length - 1;
		else if (index > names.length - 1)
			index = 0;

		value = names[index];
		label = value;
		return true;
	}
	}

	class NoteskinOption extends ArrowOption<String>
	{
	private var names:Array<String> = [];
	private final defaultDesc:String;

	public function new(property:String, name:String, description:String)
	{
		super(property, name, description);

		this.defaultDesc = description;

		var noteskinOrder:Array<String> = CoolUtil.coolTextFile(Paths.file('images/skins/noteskinOrder.txt', TEXT));
		for (skin in noteskinOrder)
			if (Options.noteSkins.contains(skin) && skin != 'fallback')
				names.push(skin);
		for (skin in Options.noteSkins)
			if (!names.contains(skin) && skin != 'fallback')
				names.push(skin);

		var index:Int = names.contains(value) ? names.indexOf(value) : 0;
		label = Note.skinManifest.get(names[index]).name;
		updateDescription();
	}

	override public function left():Bool
	{
		return changeSelection(-1);
	}

	override public function right():Bool
	{
		return changeSelection(1);
	}

	private function changeSelection(change:Int = 0):Bool
	{
		var index:Int = names.indexOf(value) + change;
		if (index < 0)
			index = names.length - 1;
		else if (index > names.length - 1)
			index = 0;

		value = names[index];
		label = Note.skinManifest.get(value).name;
		updateDescription();
		return true;
	}

	private function updateDescription():Void
	{
		description = '${defaultDesc}.\nSkin description: ${Note.skinManifest.get(value).desc}';
	}
}*/
class ControlOption extends ValueOption<Array<FlxKey>>
{
	public var forceUpdate:Bool = false;

	private var controls:Controls;
	private var callback:(Array<FlxKey>) -> Void;

	public function new(property:String, controls:Controls, ?callback:(keys:Array<FlxKey>) -> Void)
	{
		super(property);

		name = '$property : ${value[0].toString()}';
		this.controls = controls;
	}

	override public function keyPressed(pressed:FlxKey):Bool
	{
		if (Options.UNBINDABLE_KEYS.contains(pressed))
		{
			pressed = NONE;
		}
		value[0] = pressed;
		name = '${property} : ${value[0].toString()}';
		if (pressed != NONE)
		{
			Debug.logTrace('Pressed: $pressed');
			controls.setKeyboardScheme(CUSTOM, true);
			allowMultiKeyInput = false;
		}
		if (callback != null)
			callback(value);
		return true;
	}

	// TODO These are the same as the overridden functions at the moment, but I will probably change them to generate Alphabets for
	// both keybinds of each option
	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		return super.createOptionText(curSelected, optionText);
	}

	override public function updateOptionText():Void
	{
		super.updateOptionText();
	}

	override public function accept():Bool
	{
		controls.setKeyboardScheme(NONE, true);
		allowMultiKeyInput = true;
		name = '<Press any key to rebind>';
		return true;
	}

	override private function get_value():Array<FlxKey>
	{
		if (Options.save.data.keyBinds == null)
			Options.save.data.keyBinds = new Map<String, Array<FlxKey>>();

		var keyBinds:Map<String, Array<FlxKey>> = Options.save.data.keyBinds;

		if (!keyBinds.exists(property) || keyBinds.get(property) == null)
			keyBinds.set(property, defaultValue);
		return keyBinds.get(property);
	}

	override private function set_value(value:Array<FlxKey>):Array<FlxKey>
	{
		if (Options.save.data.keyBinds == null)
			Options.save.data.keyBinds = new Map<String, Array<FlxKey>>();

		Reflect.setField(Options.save.data, property, value);
		return this.value;
	}

	override private function get_defaultValue():Array<FlxKey>
	{
		if (!OptionDefaults.keyBinds.exists(property))
			Debug.logError('OptionDefaults.keyBinds does not contain default value for keybind "$property"');
		return OptionDefaults.keyBinds.get(property).copy(); // Copy so we don't affect the original value in OptionDefaults
	}
}
