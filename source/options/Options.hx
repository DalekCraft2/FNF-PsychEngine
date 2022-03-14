package options;

import Controls;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.util.FlxSave;

class OptionUtils
{
	private static var save:FlxSave = new FlxSave();
	public static var noteSkins:Array<String> = [];

	public static var shit:Array<FlxKey> = [ALT, SHIFT, TAB, CAPSLOCK, CONTROL, ENTER];
	public static var options:Dynamic = {};

	public static function bindSave(?saveName:String = "mockEngineOptions"):Void
	{
		save.bind(saveName);
		options = save.data;
	}

	public static function saveOptions(options:Dynamic):Void
	{
		var fields:Array<String> = Reflect.fields(options);
		for (f in fields)
		{
			var shit:Dynamic = Reflect.field(options, f);
			// Debug.logTrace('$f, $shit');
			Reflect.setField(save.data, f, shit);
		}
		save.flush();
		Debug.logTrace("Settings saved!");
	}

	public static function loadOptions(options:Dynamic):Void
	{
		var fields:Array<String> = Reflect.fields(save.data);
		for (f in fields)
		{
			// Debug.logTrace('$f, ${Reflect.field(options, f)}');
			if (Reflect.field(options, f) != null)
				Reflect.setField(options, f, Reflect.field(save.data, f));
		}
	}

	public static function getKey(control:String):Array<FlxKey>
	{
		if (options.keyBinds == null)
			options.keyBinds = new Map<String, Array<FlxKey>>();
		return options.keyBinds.get(control);
	}
}

class StateOption extends Option
{
	private var state:FlxState;

	public function new(name:String, state:FlxState)
	{
		super();

		this.state = state;
		this.name = name;
	}

	override public function accept():Bool
	{
		FlxG.switchState(state);
		return false;
	}
}

class OptionCheckbox extends FlxSprite
{
	public var state:Bool = false;
	public var tracker:FlxSprite;
	public var copyAlpha:Bool = true;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;

	public function new(state:Bool)
	{
		super();

		this.state = state;
		frames = Paths.getSparrowAtlas('checkbox');
		animation.addByPrefix("unchecked", "unchecked", 24, false);
		animation.addByPrefix("unchecking", "unchecking", 24, false);
		animation.addByPrefix("checking", "checking", 24, false);
		animation.addByPrefix("checked", "checked", 24, false);

		antialiasing = OptionUtils.options.globalAntialiasing;
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
			animation.play("unchecking", true);
			offset.set(25, 28);
		}
	}

	override function update(elapsed:Float):Void
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

class BooleanOption extends Option
{
	private var property:String = "dummy";
	private var checkbox:OptionCheckbox;
	private var callback:(Bool) -> Void;

	public function new(property:String, defaultValue:Bool, ?name:String, ?description:String = '', ?callback:(Bool) -> Void)
	{
		super();

		this.property = property;
		this.name = name;
		this.callback = callback;
		this.description = description;
		if (Reflect.field(OptionUtils.options, property) == null)
			Reflect.setField(OptionUtils.options, property, defaultValue);
		checkbox = new OptionCheckbox(Reflect.field(OptionUtils.options, property));
		add(checkbox);
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		if (text == null)
		{
			remove(text);
			text = new Alphabet(0, (70 * curSelected), name, false, false);
			text.isMenuItem = true;
			text.xAdd = 145;
			checkbox.tracker = text;
			add(text);
		}
		else
		{
			text.changeText(name);
		}
		return text;
	}

	override public function accept():Bool
	{
		Reflect.setField(OptionUtils.options, property, !Reflect.field(OptionUtils.options, property));
		checkbox.changeState(Reflect.field(OptionUtils.options, property));
		if (callback != null)
		{
			callback(Reflect.field(OptionUtils.options, property));
		}
		return false;
	}
}

class IntegerOption extends Option
{
	private var prefix:String = '';
	private var suffix:String = '';
	private var property:String = "dummyInt";
	private var max:Int = -1;
	private var min:Int = 0;

	public function new(property:String, ?min:Int = 0, ?max:Int = -1, ?prefix:String = '', ?suffix:String = '')
	{
		super();

		this.property = property;
		this.min = min;
		this.max = max;
		var value:Int = Reflect.field(OptionUtils.options, property);
		this.prefix = prefix;
		this.suffix = suffix;

		name = prefix + " " + Std.string(value) + " " + suffix;
	}

	override public function left():Bool
	{
		var value:Int = Std.int(Reflect.field(OptionUtils.options, property) - 1);

		if (value < min)
			value = max;
		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);
		name = prefix + " " + Std.string(value) + " " + suffix;
		return true;
	}

	override public function right():Bool
	{
		var value:Int = Std.int(Reflect.field(OptionUtils.options, property) + 1);

		if (value < min)
			value = max;
		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);

		name = prefix + " " + Std.string(value) + " " + suffix;
		return true;
	}
}

class FloatOption extends Option
{
	private var names:Array<String>;
	private var property:String = "dummyInt";
	private var max:Float = -1;
	private var min:Float = 0;
	private var step:Float = 1;
	private var scrollSpeed:Float = 50;
	private var label:String = '';
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var labelAlphabet:Alphabet;
	private var callback:(Float, Float) -> Void;
	private var suffix:String = '';
	private var prefix:String = '';
	private var truncateFloat:Bool = false;

	public function new(property:String, defaultValue:Float, label:String, ?desc:String = '', ?step:Float = 1, ?min:Float = 0, ?max:Float = 100,
			?suffix:String = '', ?prefix:String = '', ?truncateFloat = false, ?callback:(Float, Float) -> Void)
	{
		super();

		this.property = property;
		this.label = label;
		this.description = desc;
		this.step = step;
		this.suffix = suffix;
		this.prefix = prefix;
		this.callback = callback;
		if (Reflect.field(OptionUtils.options, property) == null)
			Reflect.setField(OptionUtils.options, property, defaultValue);
		var value:Float = Reflect.field(OptionUtils.options, property);
		leftArrow = new FlxSprite(0, 0);
		leftArrow.frames = Paths.getSparrowAtlas("arrows");
		leftArrow.setGraphicSize(Std.int(leftArrow.width * .7));
		leftArrow.updateHitbox();
		leftArrow.animation.addByPrefix("pressed", "arrow push left", 24, false);
		leftArrow.animation.addByPrefix("static", "arrow left", 24, false);
		leftArrow.animation.play("static");

		rightArrow = new FlxSprite(0, 0);
		rightArrow.frames = Paths.getSparrowAtlas("arrows");
		rightArrow.setGraphicSize(Std.int(rightArrow.width * .7));
		rightArrow.updateHitbox();
		rightArrow.animation.addByPrefix("pressed", "arrow push right", 24, false);
		rightArrow.animation.addByPrefix("static", "arrow right", 24, false);
		rightArrow.animation.play("static");

		add(rightArrow);
		add(leftArrow);
		this.max = max;
		this.min = min;

		this.truncateFloat = truncateFloat;
		if (truncateFloat)
			value = CoolUtil.truncateFloat(value, 2);

		name = '${prefix}${Std.string(value)}${suffix}';
	}

	var holdTime:Float = 0;
	var holdValue:Float = 0;

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;

		if (PlayerSettings.player1.controls.UI_LEFT && isSelected)
		{
			leftArrow.animation.play("pressed");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = -3;
		}
		else
		{
			leftArrow.animation.play("static");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = 0;
		}

		if (PlayerSettings.player1.controls.UI_RIGHT && isSelected)
		{
			rightArrow.animation.play("pressed");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = -3;
		}
		else
		{
			rightArrow.animation.play("static");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = 0;
		}
		rightArrow.x = text.x + text.width + 10;
		leftArrow.x = text.x - 60;
		leftArrow.y = text.y - 10;
		rightArrow.y = text.y - 10;
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		Debug.logTrace('createOptionText($curSelected, $optionText)');
		if (labelAlphabet == null || text == null)
		{
			remove(text);
			remove(labelAlphabet);
			labelAlphabet = new Alphabet(0, (70 * curSelected), label, false, false);
			labelAlphabet.isMenuItem = true;

			text = new Alphabet(0, (70 * curSelected), name, false, false);
			text.isMenuItem = true;
			text.xAdd = labelAlphabet.width + 120;

			labelAlphabet.targetY = text.targetY;
			add(labelAlphabet);
			add(text);
		}
		else
		{
			updateOptionText();
		}
		return text;
	}

	public function updateOptionText():Void
	{
		labelAlphabet.changeText(label);
		text.changeText(name);
	}

	override public function left():Bool
	{
		Debug.logTrace('left()');
		var value:Float = Reflect.field(OptionUtils.options, property) - step;

		if (value < min)
			value = max;

		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);

		if (truncateFloat)
			value = CoolUtil.truncateFloat(value, 2);
		name = '${prefix}${Std.string(value)}${suffix}';
		if (callback != null)
			callback(value, -step);

		return true;
	}

	override public function right():Bool
	{
		Debug.logTrace('right()');
		var value:Float = Reflect.field(OptionUtils.options, property) + step;

		if (value < min)
			value = max;
		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);

		if (truncateFloat)
			value = CoolUtil.truncateFloat(value, 2);
		name = '${prefix}${Std.string(value)}${suffix}';
		if (callback != null)
			callback(value, step);

		return true;
	}
}

// If the time comes to add options which allow typing strings (like VS Online's username option), I'm renaming this to EnumOption
class StringOption extends Option
{
	private var names:Array<String>;
	private var property:String = "dummyInt";
	private var max:Int = -1;
	private var min:Int = 0;
	private var label:String = '';
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var labelAlphabet:Alphabet;
	private var callback:(Int, String, Int) -> Void;

	// i wish there was a better way to do this ^
	// if there is and you're reading this and know a better way, PR please!

	public function new(property:String, defaultValue:String, label:String, description:String, ?min:Int = 0, ?max:Int = -1, ?names:Array<String>,
			?callback:(Int, String, Int) -> Void)
	{
		super();

		this.property = property;
		this.label = label;
		this.description = description;
		this.names = names;
		this.callback = callback;
		if (Reflect.field(OptionUtils.options, property) == null)
			Reflect.setField(OptionUtils.options, property, defaultValue);
		var value:String = Reflect.field(OptionUtils.options, property);
		leftArrow = new FlxSprite(0, 0);
		leftArrow.frames = Paths.getSparrowAtlas("arrows");
		leftArrow.setGraphicSize(Std.int(leftArrow.width * .7));
		leftArrow.updateHitbox();
		leftArrow.animation.addByPrefix("pressed", "arrow push left", 24, false);
		leftArrow.animation.addByPrefix("static", "arrow left", 24, false);
		leftArrow.animation.play("static");

		rightArrow = new FlxSprite(0, 0);
		rightArrow.frames = Paths.getSparrowAtlas("arrows");
		rightArrow.setGraphicSize(Std.int(rightArrow.width * .7));
		rightArrow.updateHitbox();
		rightArrow.animation.addByPrefix("pressed", "arrow push right", 24, false);
		rightArrow.animation.addByPrefix("static", "arrow right", 24, false);
		rightArrow.animation.play("static");

		add(rightArrow);
		add(leftArrow);
		this.max = max;
		this.min = min;
		name = value;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;
		if (PlayerSettings.player1.controls.UI_LEFT && isSelected)
		{
			leftArrow.animation.play("pressed");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = -3;
		}
		else
		{
			leftArrow.animation.play("static");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = 0;
		}

		if (PlayerSettings.player1.controls.UI_RIGHT && isSelected)
		{
			rightArrow.animation.play("pressed");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = -3;
		}
		else
		{
			rightArrow.animation.play("static");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = 0;
		}
		rightArrow.x = text.x + text.width + 10;
		leftArrow.x = text.x - 60;
		leftArrow.y = text.y - 10;
		rightArrow.y = text.y - 10;
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		if (labelAlphabet == null || text == null)
		{
			remove(text);
			remove(labelAlphabet);
			labelAlphabet = new Alphabet(0, (70 * curSelected), label, false, false);
			labelAlphabet.isMenuItem = true;

			text = new Alphabet(0, (70 * curSelected), name, false, false);
			text.isMenuItem = true;
			text.xAdd = labelAlphabet.width + 120;

			labelAlphabet.targetY = text.targetY;
			add(labelAlphabet);
			add(text);
		}
		else
		{
			labelAlphabet.changeText(label);
			text.changeText(name);
		}
		return text;
	}

	override public function left():Bool
	{
		var value:String = Std.string(Reflect.field(OptionUtils.options, property));
		var index:Int = names.indexOf(value) - 1;

		if (index < min)
			index = max;

		if (index > max)
			index = min;

		if (names != null)
		{
			name = names[index];
		}
		else
		{
			name = Std.string(index);
		}

		Reflect.setField(OptionUtils.options, property, name);

		if (callback != null)
		{
			callback(index, name, -1);
		}
		return true;
	}

	override public function right():Bool
	{
		var value:String = Std.string(Reflect.field(OptionUtils.options, property));
		var index:Int = names.indexOf(value) + 1;

		if (index < min)
			index = max;

		if (index > max)
			index = min;

		if (names != null)
		{
			name = names[index];
		}
		else
		{
			name = Std.string(index);
		}

		Reflect.setField(OptionUtils.options, property, name);

		if (callback != null)
		{
			callback(index, name, 1);
		}
		return true;
	}
}

// TODO Combine this with Psych's options for directly editing judgements
class JudgementsOption extends Option
{
	private var names:Array<String>;
	private var property:String = "dummyInt";
	private var label:String = '';
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var labelAlphabet:Alphabet;
	private var judgementNames:Array<String> = [];
	private var curValue:Int = 0;

	public function new(property:String, defaultValue:String, label:String, description:String)
	{
		super();

		this.property = property;
		this.label = label;
		this.description = description;
		var idx:Int = 0;

		if (Reflect.field(OptionUtils.options, property) == null)
			Reflect.setField(OptionUtils.options, property, defaultValue);

		var judgementOrder:Array<String> = CoolUtil.coolTextFile(Paths.txt('judgementOrder'));

		for (i in 0...judgementOrder.length)
		{
			var judge:String = judgementOrder[i];
			judgementNames.push(judge);
			if (Reflect.field(OptionUtils.options, property) == judge)
			{
				curValue = idx;
			}
			idx++;
		}

		for (judgement in Reflect.fields(JudgementManager.rawJudgements))
		{
			if (!judgementNames.contains(judgement))
			{
				judgementNames.push(judgement);
				if (Reflect.field(OptionUtils.options, property) == judgement)
				{
					curValue = idx;
				}
				idx++;
			}
		}

		leftArrow = new FlxSprite(0, 0);
		leftArrow.frames = Paths.getSparrowAtlas("arrows");
		leftArrow.setGraphicSize(Std.int(leftArrow.width * .7));
		leftArrow.updateHitbox();
		leftArrow.animation.addByPrefix("pressed", "arrow push left", 24, false);
		leftArrow.animation.addByPrefix("static", "arrow left", 24, false);
		leftArrow.animation.play("static");

		rightArrow = new FlxSprite(0, 0);
		rightArrow.frames = Paths.getSparrowAtlas("arrows");
		rightArrow.setGraphicSize(Std.int(rightArrow.width * .7));
		rightArrow.updateHitbox();
		rightArrow.animation.addByPrefix("pressed", "arrow push right", 24, false);
		rightArrow.animation.addByPrefix("static", "arrow right", 24, false);
		rightArrow.animation.play("static");

		add(rightArrow);
		add(leftArrow);

		name = judgementNames[curValue];
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;
		if (PlayerSettings.player1.controls.UI_LEFT && isSelected)
		{
			leftArrow.animation.play("pressed");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = -3;
		}
		else
		{
			leftArrow.animation.play("static");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = 0;
		}

		if (PlayerSettings.player1.controls.UI_RIGHT && isSelected)
		{
			rightArrow.animation.play("pressed");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = -3;
		}
		else
		{
			rightArrow.animation.play("static");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = 0;
		}
		rightArrow.x = text.x + text.width + 10;
		leftArrow.x = text.x - 60;
		leftArrow.y = text.y - 10;
		rightArrow.y = text.y - 10;
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		if (labelAlphabet == null || text == null)
		{
			remove(text);
			remove(labelAlphabet);
			labelAlphabet = new Alphabet(0, (70 * curSelected), label, false, false);
			labelAlphabet.isMenuItem = true;

			text = new Alphabet(0, (70 * curSelected), name, false, false);
			text.isMenuItem = true;
			text.xAdd = labelAlphabet.width + 120;

			labelAlphabet.targetY = text.targetY;
			add(labelAlphabet);
			add(text);
		}
		else
		{
			labelAlphabet.changeText(label);
			text.changeText(name);
		}
		return text;
	}

	override public function left():Bool
	{
		var value:Int = curValue - 1;

		if (value < 0)
			value = judgementNames.length - 1;

		if (value > judgementNames.length - 1)
			value = 0;

		Reflect.setField(OptionUtils.options, property, judgementNames[value]);

		curValue = value;
		name = judgementNames[value];
		return true;
	}

	override public function right():Bool
	{
		var value:Int = curValue + 1;

		if (value < 0)
			value = judgementNames.length - 1;

		if (value > judgementNames.length - 1)
			value = 0;

		Reflect.setField(OptionUtils.options, property, judgementNames[value]);

		curValue = value;
		name = judgementNames[value];
		return true;
	}
}

/*class NoteskinOption extends Option
	{
	private var names:Array<String>;
	private var property:String = "dummyInt";
	private var label:String = '';
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var labelAlphabet:Alphabet;
	private var skinNames:Array<String> = [];
	private var curValue:Int = 0;
	private var defaultDesc:String = '';

	function updateDescription():Void
	{
		description = '${defaultDesc}.\nSkin description: ${Note.skinManifest.get(skinNames[curValue]).desc}';
	}

	public function new(property:String, label:String, description:String)
	{
		super();

		this.property = property;
		this.label = label;
		this.defaultDesc = description;
		var idx:Int = 0;
		var noteskinOrder:Array<String> = CoolUtil.coolTextFile(Paths.txtImages('skins/noteskinOrder'));
		for (i in 0...noteskinOrder.length)
		{
			var skin:String = noteskinOrder[i];
			if (OptionUtils.noteSkins.contains(skin) && skin != 'fallback')
				skinNames.push(skin);
		}
		for (skin in OptionUtils.noteSkins)
		{
			if (!skinNames.contains(skin) && skin != 'fallback')
			{
				skinNames.push(skin);
			}
		}
		idx = skinNames.indexOf(Reflect.field(OptionUtils.options, property));
		curValue = idx == -1 ? 0 : idx;
		updateDescription();
		leftArrow = new FlxSprite(0, 0);
		leftArrow.frames = Paths.getSparrowAtlas("arrows");
		leftArrow.setGraphicSize(Std.int(leftArrow.width * .7));
		leftArrow.updateHitbox();
		leftArrow.animation.addByPrefix("pressed", "arrow push left", 24, false);
		leftArrow.animation.addByPrefix("static", "arrow left", 24, false);
		leftArrow.animation.play("static");
		rightArrow = new FlxSprite(0, 0);
		rightArrow.frames = Paths.getSparrowAtlas("arrows");
		rightArrow.setGraphicSize(Std.int(rightArrow.width * .7));
		rightArrow.updateHitbox();
		rightArrow.animation.addByPrefix("pressed", "arrow push right", 24, false);
		rightArrow.animation.addByPrefix("static", "arrow right", 24, false);
		rightArrow.animation.play("static");
		add(rightArrow);
		add(leftArrow);
		name = Note.skinManifest.get(skinNames[curValue]).name;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;
		if (PlayerSettings.player1.controls.UI_LEFT && isSelected)
		{
			leftArrow.animation.play("pressed");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = -3;
		}
		else
		{
			leftArrow.animation.play("static");
			leftArrow.offset.x = 0;
			leftArrow.offset.y = 0;
		}
		if (PlayerSettings.player1.controls.UI_RIGHT && isSelected)
		{
			rightArrow.animation.play("pressed");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = -3;
		}
		else
		{
			rightArrow.animation.play("static");
			rightArrow.offset.x = 0;
			rightArrow.offset.y = 0;
		}
		rightArrow.x = text.x + text.width + 10;
		leftArrow.x = text.x - 60;
		leftArrow.y = text.y - 10;
		rightArrow.y = text.y - 10;
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		remove(text);
		remove(labelAlphabet);
		labelAlphabet = new Alphabet(0, (70 * curSelected), label, false, false);
		labelAlphabet.isMenuItem = true;
		text = new Alphabet(0, (70 * curSelected), name, false, false);
		text.isMenuItem = true;
		text.xAdd = labelAlphabet.width + 120;
		labelAlphabet.targetY = text.targetY;
		add(labelAlphabet);
		add(text);
		return text;
	}

	override public function left():Bool
	{
		var value:Int = curValue - 1;
		if (value < 0)
			value = skinNames.length - 1;
		if (value > skinNames.length - 1)
			value = 0;
		Reflect.setField(OptionUtils.options, property, skinNames[value]);
		curValue = value;
		name = Note.skinManifest.get(skinNames[value]).name;
		updateDescription();
		return true;
	}

	override public function right():Bool
	{
		var value:Int = curValue + 1;
		if (value < 0)
			value = skinNames.length - 1;
		if (value > skinNames.length - 1)
			value = 0;
		Reflect.setField(OptionUtils.options, property, skinNames[value]);
		curValue = value;
		name = Note.skinManifest.get(skinNames[value]).name;
		updateDescription();
		return true;
	}
}*/
class ControlOption extends Option
{
	private var controlType:String = 'ui_up';
	private var controls:Controls;
	private var keys:Array<FlxKey>;

	public var forceUpdate:Bool = false;

	public function new(controls:Controls, controlType:String, defaultValue:Array<FlxKey>)
	{
		super();

		this.controlType = controlType;
		this.controls = controls;

		if (OptionUtils.options.keyBinds == null)
			OptionUtils.options.keyBinds = new Map<String, Array<FlxKey>>();
		if (OptionUtils.options.keyBinds.get(controlType) == null)
			OptionUtils.options.keyBinds.set(controlType, defaultValue);

		keys = OptionUtils.getKey(controlType);
		name = '${controlType.toUpperCase()} : ${OptionUtils.getKey(controlType)[0].toString()}';
	}

	override public function keyPressed(pressed:FlxKey):Bool
	{
		for (k in OptionUtils.shit)
		{
			if (pressed == k)
			{
				pressed = -1;
				break;
			}
		}
		OptionUtils.options.keyBinds.get(controlType)[0] = pressed;
		keys[0] = pressed;
		name = '${controlType} : ${OptionUtils.getKey(controlType)[0].toString()}';
		if (pressed != -1)
		{
			Debug.logTrace("pressed: " + pressed);
			controls.setKeyboardScheme(CUSTOM, true);
			allowMultiKeyInput = false;
			return true;
		}
		return true;
	}

	override public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		if (text == null)
		{
			remove(text);
			text = new Alphabet(0, (70 * curSelected), name, true, false);
			text.isMenuItem = true;
			add(text);
		}
		else
		{
			text.changeText(name);
		}
		return text;
	}

	override public function accept():Bool
	{
		controls.setKeyboardScheme(NONE, true);
		allowMultiKeyInput = true;
		name = "<Press any key to rebind>";
		return true;
	}
}
