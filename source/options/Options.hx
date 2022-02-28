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

	public static var camFocuses:Array<String> = ["Default", "BF", "Dad", "Center"];

	public static var shit:Array<FlxKey> = [ALT, SHIFT, TAB, CAPSLOCK, CONTROL, ENTER];
	public static var options:Dynamic = {};

	public static function bindSave(?saveName:String = "mockEngineOptions")
	{
		save.bind(saveName);
		options = save.data;
	}

	public static function saveOptions(options:Dynamic)
	{
		var fields = Reflect.fields(options);
		for (f in fields)
		{
			var shit = Reflect.field(options, f);
			trace(f, shit);
			Reflect.setField(save.data, f, shit);
		}
		save.flush();
		trace("Settings saved!");
	}

	public static function loadOptions(options:Dynamic)
	{
		var fields = Reflect.fields(save.data);
		for (f in fields)
		{
			trace(f, Reflect.getProperty(options, f));
			if (Reflect.getProperty(options, f) != null)
				Reflect.setField(options, f, Reflect.field(save.data, f));
		}
	}

	public static function getKey(control:String)
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

	public override function accept()
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
		frames = Paths.getSparrowAtlas('checkboxanim');
		animation.addByPrefix("unchecked", "checkbox0", 24, false);
		animation.addByPrefix("unchecking", "checkbox anim reverse", 24, false);
		animation.addByPrefix("checking", "checkbox anim0", 24, false);
		animation.addByPrefix("checked", "checkbox finish", 24, false);

		antialiasing = OptionUtils.options.globalAntialiasing;
		setGraphicSize(Std.int(0.9 * width));
		updateHitbox();

		animationFinished(state ? 'checking' : 'unchecking');
		animation.finishCallback = animationFinished;
	}

	public function changeState(state:Bool)
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

	override function update(elapsed:Float)
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

	private function animationFinished(name:String)
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

class ToggleOption extends Option
{
	private var property = "dummy";
	private var checkbox:OptionCheckbox;
	private var callback:Bool->Void;

	public function new(property:String, defaultValue:Bool, ?name:String, ?description:String = '', ?callback:Bool->Void)
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

	public override function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Dynamic
	{
		if (text == null)
		{
			remove(text);
			text = new Alphabet(0, (70 * curSelected), name, true, false);
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

	public override function accept():Bool
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

class StepOption extends Option
{
	private var names:Array<String>;
	private var property = "dummyInt";
	private var max:Float = -1;
	private var min:Float = 0;
	private var step:Float = 1;
	private var scrollSpeed:Float = 50;
	private var label:String = '';
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var labelAlphabet:Alphabet;
	private var callback:Float->Float->Void;
	private var suffix:String = '';
	private var prefix:String = '';
	private var truncFloat:Bool = false;

	private var decimals:Int = 1;

	public function new(property:String, defaultValue:Float, label:String, ?desc:String = '', ?step:Float = 1, ?min:Float = 0, ?max:Float = 100,
			?suffix:String = '', ?prefix:String = '', ?truncateFloat = false, ?callback:Float->Float->Void)
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
		var value = Reflect.field(OptionUtils.options, property);
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

		truncFloat = truncateFloat;
		if (truncFloat)
			value = CoolUtil.truncateFloat(value, 2);

		name = '${prefix}${Std.string(value)}${suffix}';
	}

	var holdTime:Float = 0;
	var holdValue:Float = 0;

	override function update(elapsed:Float)
	{
		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;

		super.update(elapsed);
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

		// if (PlayerSettings.player1.controls.UI_LEFT || PlayerSettings.player1.controls.UI_RIGHT)
		// {
		// 	var pressed = (PlayerSettings.player1.controls.UI_LEFT_P || PlayerSettings.player1.controls.UI_RIGHT_P);
		// 	if (holdTime > 0.5 || pressed)
		// 	{
		// 		if (pressed)
		// 		{
		// 			var add:Dynamic = PlayerSettings.player1.controls.UI_LEFT ? -step : step;

		// 			holdValue = getValue() + add;
		// 			if (holdValue < min)
		// 				holdValue = min;
		// 			else if (holdValue > max)
		// 				holdValue = max;

		// 			holdValue = FlxMath.roundDecimal(holdValue, decimals);
		// 			setValue(holdValue);

		// 			updateOptionText();
		// 			// if (callback != null)
		// 			// 	callback(value, add);
		// 			FlxG.sound.play(Paths.sound('scrollMenu'));
		// 		}
		// 		else
		// 		{
		// 			holdValue += scrollSpeed * elapsed * (PlayerSettings.player1.controls.UI_LEFT ? -1 : 1);
		// 			if (holdValue < min)
		// 				holdValue = min;
		// 			else if (holdValue > max)
		// 				holdValue = max;

		// 			holdValue = FlxMath.roundDecimal(holdValue, decimals);
		// 			setValue(holdValue);

		// 			updateOptionText();
		// 			// if (callback != null)
		// 			// 	callback(value, add);
		// 		}
		// 	}
		// 	holdTime += elapsed;
		// }
		// else if (PlayerSettings.player1.controls.UI_LEFT_R || PlayerSettings.player1.controls.UI_RIGHT_R)
		// {
		// 	clearHold();
		// }
	}

	function clearHold()
	{
		if (holdTime > 0.5)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		holdTime = 0;
	}

	function getValue()
	{
		return Reflect.field(OptionUtils.options, property);
	}

	function setValue(value:Float)
	{
		Reflect.setField(OptionUtils.options, property, value);
	}

	public override function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Dynamic
	{
		if (labelAlphabet == null || text == null)
		{
			remove(text);
			remove(labelAlphabet);
			labelAlphabet = new Alphabet(0, (70 * curSelected), label, true, false);
			labelAlphabet.isMenuItem = true;

			text = new Alphabet(0, (70 * curSelected), name, true, false);
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

	public function updateOptionText()
	{
		labelAlphabet.changeText(label);
		text.changeText(name);
	}

	public override function left():Bool
	{
		var value:Float = Reflect.field(OptionUtils.options, property) - step;

		if (value < min)
			value = max;

		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);

		if (truncFloat)
			value = CoolUtil.truncateFloat(value, 2);
		name = '${prefix}${Std.string(value)}${suffix}';
		if (callback != null)
			callback(value, -step);

		return true;
	}

	public override function right():Bool
	{
		var value:Float = Reflect.field(OptionUtils.options, property) + step;

		if (value < min)
			value = max;
		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);

		if (truncFloat)
			value = CoolUtil.truncateFloat(value, 2);
		name = '${prefix}${Std.string(value)}${suffix}';
		if (callback != null)
			callback(value, step);

		return true;
	}
}

class ScrollOption extends Option
{
	private var names:Array<String>;
	private var property = "dummyInt";
	private var max:Int = -1;
	private var min:Int = 0;
	private var label:String = '';
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;
	private var labelAlphabet:Alphabet;
	private var callback:Int->String->Int->Void;

	// i wish there was a better way to do this ^
	// if there is and you're reading this and know a better way, PR please!

	public function new(property:String, defaultValue:Int, label:String, description:String, ?min:Int = 0, ?max:Int = -1, ?names:Array<String>,
			?callback:Int->String->Int->Void)
	{
		super();
		this.property = property;
		this.label = label;
		this.description = description;
		this.names = names;
		this.callback = callback;
		if (Reflect.field(OptionUtils.options, property) == null)
			Reflect.setField(OptionUtils.options, property, defaultValue);
		var value = Reflect.field(OptionUtils.options, property);
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
		if (names != null)
		{
			name = names[value];
		}
		else
		{
			name = Std.string(value);
		}
	}

	override function update(elapsed:Float)
	{
		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;
		super.update(elapsed);
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

	public override function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Dynamic
	{
		if (labelAlphabet == null || text == null)
		{
			remove(text);
			remove(labelAlphabet);
			labelAlphabet = new Alphabet(0, (70 * curSelected), label, true, false);
			labelAlphabet.isMenuItem = true;

			text = new Alphabet(0, (70 * curSelected), name, true, false);
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

	public override function left():Bool
	{
		var value:Int = Std.int(Reflect.field(OptionUtils.options, property) - 1);

		if (value < min)
			value = max;

		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);

		if (names != null)
		{
			name = names[value];
		}
		else
		{
			name = Std.string(value);
		}

		if (callback != null)
		{
			callback(value, name, -1);
		}
		return true;
	}

	public override function right():Bool
	{
		var value:Int = Std.int(Reflect.field(OptionUtils.options, property) + 1);

		if (value < min)
			value = max;
		if (value > max)
			value = min;

		Reflect.setField(OptionUtils.options, property, value);

		if (names != null)
		{
			name = names[value];
		}
		else
		{
			name = Std.string(value);
		}

		if (callback != null)
		{
			callback(value, name, 1);
		}
		return true;
	}
}

class JudgementsOption extends Option
{
	private var names:Array<String>;
	private var property = "dummyInt";
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
		var idx = 0;

		if (Reflect.field(OptionUtils.options, property) == null)
			Reflect.setField(OptionUtils.options, property, defaultValue);

		var judgementOrder = CoolUtil.coolTextFile(Paths.txt('judgementOrder'));

		for (i in 0...judgementOrder.length)
		{
			var judge = judgementOrder[i];
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

	override function update(elapsed:Float)
	{
		labelAlphabet.targetY = text.targetY;
		labelAlphabet.alpha = text.alpha;
		leftArrow.alpha = text.alpha;
		rightArrow.alpha = text.alpha;
		super.update(elapsed);
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

	public override function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Dynamic
	{
		if (labelAlphabet == null || text == null)
		{
			remove(text);
			remove(labelAlphabet);
			labelAlphabet = new Alphabet(0, (70 * curSelected), label, true, false);
			labelAlphabet.isMenuItem = true;

			text = new Alphabet(0, (70 * curSelected), name, true, false);
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

	public override function left():Bool
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

	public override function right():Bool
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

// class NoteskinOption extends Option
// {
// 	private var names:Array<String>;
// 	private var property = "dummyInt";
// 	private var label:String = '';
// 	private var leftArrow:FlxSprite;
// 	private var rightArrow:FlxSprite;
// 	private var labelAlphabet:Alphabet;
// 	private var skinNames:Array<String> = [];
// 	private var curValue:Int = 0;
// 	private var defaultDesc:String = '';
// 	function updateDescription()
// 	{
// 		description = '${defaultDesc}.\nSkin description: ${Note.skinManifest.get(skinNames[curValue]).desc}';
// 	}
// 	public function new(property:String, label:String, description:String)
// 	{
// 		super();
// 		this.property = property;
// 		this.label = label;
// 		this.defaultDesc = description;
// 		var idx = 0;
// 		var noteskinOrder = CoolUtil.coolTextFile(Paths.txtImages('skins/noteskinOrder'));
// 		for (i in 0...noteskinOrder.length)
// 		{
// 			var skin = noteskinOrder[i];
// 			if (OptionUtils.noteSkins.contains(skin) && skin != 'fallback')
// 				skinNames.push(skin);
// 		}
// 		for (skin in OptionUtils.noteSkins)
// 		{
// 			if (!skinNames.contains(skin) && skin != 'fallback')
// 			{
// 				skinNames.push(skin);
// 			}
// 		}
// 		var idx = skinNames.indexOf(Reflect.field(OptionUtils.options, property));
// 		curValue = idx == -1 ? 0 : idx;
// 		updateDescription();
// 		leftArrow = new FlxSprite(0, 0);
// 		leftArrow.frames = Paths.getSparrowAtlas("arrows");
// 		leftArrow.setGraphicSize(Std.int(leftArrow.width * .7));
// 		leftArrow.updateHitbox();
// 		leftArrow.animation.addByPrefix("pressed", "arrow push left", 24, false);
// 		leftArrow.animation.addByPrefix("static", "arrow left", 24, false);
// 		leftArrow.animation.play("static");
// 		rightArrow = new FlxSprite(0, 0);
// 		rightArrow.frames = Paths.getSparrowAtlas("arrows");
// 		rightArrow.setGraphicSize(Std.int(rightArrow.width * .7));
// 		rightArrow.updateHitbox();
// 		rightArrow.animation.addByPrefix("pressed", "arrow push right", 24, false);
// 		rightArrow.animation.addByPrefix("static", "arrow right", 24, false);
// 		rightArrow.animation.play("static");
// 		add(rightArrow);
// 		add(leftArrow);
// 		name = Note.skinManifest.get(skinNames[curValue]).name;
// 	}
// 	override function update(elapsed:Float)
// 	{
// 		labelAlphabet.targetY = text.targetY;
// 		labelAlphabet.alpha = text.alpha;
// 		leftArrow.alpha = text.alpha;
// 		rightArrow.alpha = text.alpha;
// 		super.update(elapsed);
// 		if (PlayerSettings.player1.controls.UI_LEFT && isSelected)
// 		{
// 			leftArrow.animation.play("pressed");
// 			leftArrow.offset.x = 0;
// 			leftArrow.offset.y = -3;
// 		}
// 		else
// 		{
// 			leftArrow.animation.play("static");
// 			leftArrow.offset.x = 0;
// 			leftArrow.offset.y = 0;
// 		}
// 		if (PlayerSettings.player1.controls.UI_RIGHT && isSelected)
// 		{
// 			rightArrow.animation.play("pressed");
// 			rightArrow.offset.x = 0;
// 			rightArrow.offset.y = -3;
// 		}
// 		else
// 		{
// 			rightArrow.animation.play("static");
// 			rightArrow.offset.x = 0;
// 			rightArrow.offset.y = 0;
// 		}
// 		rightArrow.x = text.x + text.width + 10;
// 		leftArrow.x = text.x - 60;
// 		leftArrow.y = text.y - 10;
// 		rightArrow.y = text.y - 10;
// 	}
// 	public override function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Dynamic
// 	{
// 		remove(text);
// 		remove(labelAlphabet);
// 		labelAlphabet = new Alphabet(0, (70 * curSelected), label, true, false);
// 		labelAlphabet.isMenuItem = true;
// 		text = new Alphabet(0, (70 * curSelected), name, true, false);
// 		text.isMenuItem = true;
// 		text.xAdd = labelAlphabet.width + 120;
// 		labelAlphabet.targetY = text.targetY;
// 		add(labelAlphabet);
// 		add(text);
// 		return text;
// 	}
// 	public override function left():Bool
// 	{
// 		var value:Int = curValue - 1;
// 		if (value < 0)
// 			value = skinNames.length - 1;
// 		if (value > skinNames.length - 1)
// 			value = 0;
// 		Reflect.setField(OptionUtils.options, property, skinNames[value]);
// 		curValue = value;
// 		name = Note.skinManifest.get(skinNames[value]).name;
// 		updateDescription();
// 		return true;
// 	}
// 	public override function right():Bool
// 	{
// 		var value:Int = curValue + 1;
// 		if (value < 0)
// 			value = skinNames.length - 1;
// 		if (value > skinNames.length - 1)
// 			value = 0;
// 		Reflect.setField(OptionUtils.options, property, skinNames[value]);
// 		curValue = value;
// 		name = Note.skinManifest.get(skinNames[value]).name;
// 		updateDescription();
// 		return true;
// 	}
// }

class CountOption extends Option
{
	private var prefix:String = '';
	private var suffix:String = '';
	private var property = "dummyInt";
	private var max:Int = -1;
	private var min:Int = 0;

	public function new(property:String, ?min:Int = 0, ?max:Int = -1, ?prefix:String = '', ?suffix:String = '')
	{
		super();
		this.property = property;
		this.min = min;
		this.max = max;
		var value = Reflect.field(OptionUtils.options, property);
		this.prefix = prefix;
		this.suffix = suffix;

		name = prefix + " " + Std.string(value) + " " + suffix;
	}

	public override function left():Bool
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

	public override function right():Bool
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

class ControlOption extends Option
{
	private var controlType:String = 'ui_up';
	private var controls:Controls;
	private var keys:Array<FlxKey>;

	public var forceUpdate = false;

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
		name = '${controlType} : ${OptionUtils.getKey(controlType)[0].toString()}';
	}

	public override function keyPressed(pressed:FlxKey)
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
			trace("epic style " + pressed.toString());
			controls.setKeyboardScheme(Custom, true);
			allowMultiKeyInput = false;
			return true;
		}
		return true;
	}

	public override function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Dynamic
	{
		if (text == null)
		{
			remove(text);
			text = new Alphabet(0, (70 * curSelected), name, false, false);
			text.isMenuItem = true;
			add(text);
		}
		else
		{
			text.changeText(name);
		}
		return text;
	}

	public override function accept():Bool
	{
		controls.setKeyboardScheme(None, true);
		allowMultiKeyInput = true;
		name = "<Press any key to rebind>";
		return true;
	}
}
