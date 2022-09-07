package funkin.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import funkin.Options.OptionDefaults;
import funkin.util.InputFormatter;

abstract class Option extends FlxTypedGroup<FlxSprite>
{
	public var name:String;
	public var description:String;

	public var parent:OptionCategory;
	public var allowMultiKeyInput:Bool = false;
	public var text:Alphabet;
	public var isSelected:Bool = false;

	public function new(name:String = 'Option', description:String = '')
	{
		super();

		this.name = name;
		this.description = description;
	}

	public function keyPressed(key:FlxKey):Void
	{
	}

	public function keyReleased(key:FlxKey):Void
	{
	}

	public function accept():Void
	{
	}

	public function left():Void
	{
	}

	public function right():Void
	{
	}

	public function selected():Void
	{
	}

	public function deselected():Void
	{
	}

	public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Void
	{
		remove(text);
		text = new Alphabet(0, (70 * curSelected), name, true, false);
		text.isMenuItem = true;
		add(text);
	}

	public function updateOptionText():Void
	{
		text.changeText(name);
	}
}

class OptionCategory extends Option
{
	public var options:Array<Option> = [];
	public var curSelected:Int = 0;

	public function new(name:String, opts:Array<Option>)
	{
		super();

		this.name = name;
		for (opt in opts)
		{
			addOption(opt);
		}
	}

	public function addOption(opt:Option):Void
	{
		if (opt.parent != null)
		{
			opt.parent.delOption(opt);
		}
		opt.parent = this;
		options.push(opt);
	}

	public function delOption(opt:Option):Void
	{
		opt.parent = null;
		options.remove(opt);
	}
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

	override public function accept():Void
	{
		FlxG.switchState(state);
	}
}

class SubStateOption extends Option
{
	private var subState:FlxSubState;

	public function new(?name:String, ?description:String, subState:FlxSubState)
	{
		super(name, description);

		this.subState = subState;
	}

	override public function accept():Void
	{
		FlxG.state.openSubState(subState);
	}
}

/**
 * A class made to simplify the reading/writing of values in the save file
 */
class ValueOption<T> extends Option
{
	public var field:String;

	public var value(get, set):T;
	public var defaultValue(get, never):T;

	public function new(field:String, ?name:String, ?description:String)
	{
		super(name, description);

		this.field = field;
	}

	private function get_value():T
	{
		return Reflect.field(Options.profile, field);
	}

	private function set_value(value:T):T
	{
		if (this.value != value)
			Reflect.setField(Options.profile, field, value);
		return value;
	}

	private function get_defaultValue():T
	{
		if (!Reflect.hasField(OptionDefaults, field))
		{
			Debug.logError('OptionDefaults does not contain default value for option "$field"');
			return null;
		}
		return Reflect.field(OptionDefaults, field);
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

	public function new(field:String, ?name:String, ?description:String)
	{
		super(field, name, description);

		label = Std.string(value);

		leftArrow = new FlxSprite(0, 0);
		leftArrow.frames = Paths.getFrames('arrows');
		leftArrow.scale.set(0.7, 0.7);
		leftArrow.updateHitbox();
		leftArrow.animation.addByPrefix('pressed', 'arrow push left', 24, false);
		leftArrow.animation.addByPrefix('static', 'arrow left', 24, false);
		leftArrow.animation.play('static');

		rightArrow = new FlxSprite(0, 0);
		rightArrow.frames = Paths.getFrames('arrows');
		rightArrow.scale.set(0.7, 0.7);
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

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Void
	{
		super.createOptionText(curSelected, optionText);

		remove(labelAlphabet);
		labelAlphabet = new Alphabet(0, (70 * curSelected), label, true, false);
		labelAlphabet.isMenuItem = true;
		labelAlphabet.xAdd = text.width + 120;
		labelAlphabet.targetY = text.targetY;
		add(labelAlphabet);

		updateOptionText();
	}

	override public function updateOptionText():Void
	{
		super.updateOptionText();

		labelAlphabet.changeText(label);
	}
}

class BooleanOption extends ValueOption<Bool>
{
	private var callback:(value:Bool) -> Void;
	private var checkbox:Checkbox;

	public function new(field:String, name:String, ?description:String, ?callback:(value:Bool) -> Void)
	{
		super(field, name, description);

		this.callback = callback;
		checkbox = new Checkbox(value);
		add(checkbox);
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Void
	{
		super.createOptionText(curSelected, optionText);

		text.xAdd = 145;
		checkbox.sprTracker = text;
	}

	override public function accept():Void
	{
		value = !value;
		checkbox.value = value;
		if (callback != null)
		{
			callback(value);
		}
	}
}

class IntegerOption extends ArrowOption<Int>
{
	public var step:Int;
	public var min:Int;
	public var max:Int;
	public var scrollSpeed:Int = 50;

	private var suffix:String;
	private var prefix:String;
	private var callback:(value:Int, change:Int) -> Void;

	public function new(field:String, name:String, ?description:String, step:Int = 1, min:Int = -1, max:Int = -1, suffix:String = '', prefix:String = '',
			?callback:(value:Int, change:Int) -> Void)
	{
		super(field, name, description);

		this.step = step;
		this.min = min;
		this.max = max;
		this.suffix = suffix;
		this.prefix = prefix;
		this.callback = callback;
		label = '$prefix$value$suffix';
	}

	override public function updateOptionText():Void
	{
		label = '$prefix$value$suffix';
		super.updateOptionText();
	}

	override public function left():Void
	{
		changeSelection(-step);
	}

	override public function right():Void
	{
		changeSelection(step);
	}

	private function changeSelection(change:Int = 0):Void
	{
		value += change;
		if (min != -1 && value < min)
			value = max;
		else if (max != -1 && value > max)
			value = min;

		if (callback != null)
			callback(value, change);
		updateOptionText();
	}
}

class FloatOption extends ArrowOption<Float>
{
	public var step:Float;
	public var min:Float;
	public var max:Float;
	public var scrollSpeed:Float = 50;

	private var suffix:String;
	private var prefix:String;

	public var decimals:Int;

	private var callback:(value:Float, change:Float) -> Void;

	public function new(field:String, name:String, ?description:String, step:Float = 1, min:Float = -1, max:Float = -1, suffix:String = '',
			prefix:String = '', decimals:Int = -1, ?callback:(value:Float, change:Float) -> Void)
	{
		super(field, name, description);

		this.step = step;
		this.suffix = suffix;
		this.prefix = prefix;
		this.callback = callback;
		this.max = max;
		this.min = min;
		this.decimals = decimals;
		if (decimals >= 0)
			value = FlxMath.roundDecimal(value, decimals);
		label = '$prefix$value$suffix';
	}

	override public function updateOptionText():Void
	{
		label = '$prefix$value$suffix';
		super.updateOptionText();
	}

	override public function left():Void
	{
		changeSelection(-step);
	}

	override public function right():Void
	{
		changeSelection(step);
	}

	private function changeSelection(change:Float = 0):Void
	{
		value += change;
		if (min != -1 && value < min)
			value = max;
		else if (max != -1 && value > max)
			value = min;

		if (decimals >= 0)
			value = FlxMath.roundDecimal(value, decimals);
		if (callback != null)
			callback(value, change);
		updateOptionText();
	}
}

class StringOption extends ArrowOption<String>
{
	private var min:Int;
	private var max:Int;
	private var names:Array<String>;
	private var callback:(index:Int, value:String, change:Int) -> Void;

	// i wish there was a better way to do this ^
	// if there is and you're reading this and know a better way, PR please!

	public function new(field:String, name:String, ?description:String, min:Int = -1, max:Int = -1, ?names:Array<String>,
			?callback:(index:Int, value:String, change:Int) -> Void)
	{
		super(field, name, description);

		this.min = min;
		this.max = max;
		this.names = names;
		this.callback = callback;
	}

	override public function updateOptionText():Void
	{
		label = value;
		super.updateOptionText();
	}

	override public function left():Void
	{
		changeSelection(-1);
	}

	override public function right():Void
	{
		changeSelection(1);
	}

	private function changeSelection(change:Int = 0):Void
	{
		var index:Int = names.indexOf(value) + change;
		if (min != -1 && index < min)
			index = max;
		else if (max != -1 && index > max)
			index = min;

		value = names != null ? names[index] : Std.string(index);
		if (callback != null)
			callback(index, value, change);
		updateOptionText();
	}
}

// TODO Implement a way to set a keybind to NONE
class ControlOption extends ArrowOption<Array<FlxKey>>
{
	public var forceUpdate:Bool = false;

	private var keyArrayIndex:Int = 0;

	private var controls:Controls;
	private var callback:(keys:Array<FlxKey>) -> Void;

	public function new(field:String, controls:Controls, ?callback:(keys:Array<FlxKey>) -> Void)
	{
		super(field, field,
			'Use the left and right arrow keys to select the primary or secondary key for the control.\nUse the accept key to change the key bind.');

		this.controls = controls;
	}

	override public function keyPressed(pressed:FlxKey):Void
	{
		if (Options.UNBINDABLE_KEYS.contains(pressed))
		{
			pressed = NONE;
		}
		value[keyArrayIndex] = pressed;
		if (pressed != NONE)
		{
			Debug.logTrace('Pressed: $pressed');
			controls.setKeyboardScheme(CUSTOM, true);
			allowMultiKeyInput = false;
		}
		if (callback != null)
			callback(value);
		updateOptionText();
	}

	// TODO Make the primary and secondary keys visible at the same time, or display which one is currently selected
	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Void
	{
		label = InputFormatter.getKeyName(value[keyArrayIndex]);
		super.createOptionText(curSelected, optionText);
	}

	override public function updateOptionText():Void
	{
		if (allowMultiKeyInput)
		{
			label = '<Press any key to rebind>';
		}
		else
		{
			label = InputFormatter.getKeyName(value[keyArrayIndex]);
		}
		super.updateOptionText();
	}

	override public function accept():Void
	{
		controls.setKeyboardScheme(NONE, true);
		allowMultiKeyInput = true;
		updateOptionText();
	}

	override public function left():Void
	{
		if (!allowMultiKeyInput)
		{
			keyArrayIndex = FlxMath.wrap(keyArrayIndex - 1, 0, value.length - 1);
			updateOptionText();
		}
	}

	override public function right():Void
	{
		if (!allowMultiKeyInput)
		{
			keyArrayIndex = FlxMath.wrap(keyArrayIndex + 1, 0, value.length - 1);
			updateOptionText();
		}
	}

	override private function get_value():Array<FlxKey>
	{
		if (Options.profile.keyBinds == null)
			Options.profile.keyBinds = new Map<String, Array<FlxKey>>();

		var keyBinds:Map<String, Array<FlxKey>> = Options.profile.keyBinds;

		if (!keyBinds.exists(field) || keyBinds.get(field) == null)
			keyBinds.set(field, defaultValue);
		return keyBinds.get(field);
	}

	override private function set_value(value:Array<FlxKey>):Array<FlxKey>
	{
		if (Options.profile.keyBinds == null)
			Options.profile.keyBinds = new Map<String, Array<FlxKey>>();

		Reflect.setField(Options.profile, field, value);
		return value;
	}

	override private function get_defaultValue():Array<FlxKey>
	{
		if (!OptionDefaults.keyBinds.exists(field))
			Debug.logError('OptionDefaults.keyBinds does not contain default value for keybind "$field"');
		return OptionDefaults.keyBinds.get(field).copy(); // Copy so we don't affect the original value in OptionDefaults
	}
}
