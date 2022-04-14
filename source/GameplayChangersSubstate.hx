package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

using StringTools;

class GameplayChangersSubState extends MusicBeatSubState
{
	private var curOption:GameplayOption;
	private var curSelected:Int = 0;
	private var optionsArray:Array<GameplayOption> = [];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	override public function create():Void
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup();
		add(grpOptions);

		grpTexts = new FlxTypedGroup();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup();
		add(checkboxGroup);

		getOptions();

		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(0, 70 * i, optionsArray[i].name, true, false, 0.05, 0.8);
			optionText.isMenuItem = true;
			optionText.x += 300;
			/*optionText.forceX = 300;
				optionText.yMult = 90; */
			optionText.xAdd = 120;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if (optionsArray[i].type == 'bool')
			{
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue());
				checkbox.sprTracker = optionText;
				checkbox.offsetY = -60;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
				optionText.xAdd += 80;
			}
			else
			{
				var valueText:AttachedText = new AttachedText(Std.string(optionsArray[i].getValue()), optionText.width + 80, true, 0.8);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
	}

	private var nextAccept:Int = 5;
	private var holdTime:Float = 0;
	private var holdValue:Float = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK)
		{
			close();
			Options.flushSave();
			FlxG.sound.play(Paths.getSound('cancelMenu'));
		}

		if (nextAccept <= 0)
		{
			var usesCheckbox:Bool = true;
			if (curOption.type != 'bool')
			{
				usesCheckbox = false;
			}

			if (usesCheckbox)
			{
				if (controls.ACCEPT)
				{
					FlxG.sound.play(Paths.getSound('scrollMenu'));
					curOption.setValue(curOption.getValue() ? false : true);
					curOption.change();
					reloadCheckboxes();
				}
			}
			else
			{
				if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					var pressed:Bool = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
					if (holdTime > 0.5 || pressed)
					{
						if (pressed)
						{
							var add:Null<Float> = null;
							if (curOption.type != 'string')
							{
								add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
							}

							switch (curOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = curOption.getValue() + add;
									if (holdValue < curOption.minValue)
										holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue)
										holdValue = curOption.maxValue;

									switch (curOption.type)
									{
										case 'int':
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);

										case 'float' | 'percent':
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
									}

								case 'string':
									var num:Int = curOption.curOption; // lol
									if (controls.UI_LEFT_P)
										--num;
									else
										num++;

									if (num < 0)
									{
										num = curOption.options.length - 1;
									}
									else if (num >= curOption.options.length)
									{
										num = 0;
									}

									curOption.curOption = num;
									curOption.setValue(curOption.options[num]); // lol

									if (curOption.name == 'Scroll Type')
									{
										var oOption:GameplayOption = getOptionByName('Scroll Speed');
										if (oOption != null)
										{
											if (curOption.getValue() == 'constant')
											{
												oOption.displayFormat = '%v';
												oOption.maxValue = 6;
											}
											else
											{
												oOption.displayFormat = '%vX';
												oOption.maxValue = 3;
												if (oOption.getValue() > 3)
													oOption.setValue(3);
											}
											updateTextFrom(oOption);
										}
									}
									// Debug.logTrace(curOption.options[num]);
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.getSound('scrollMenu'));
						}
						else if (curOption.type != 'string')
						{
							holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
							if (holdValue < curOption.minValue)
								holdValue = curOption.minValue;
							else if (holdValue > curOption.maxValue)
								holdValue = curOption.maxValue;

							switch (curOption.type)
							{
								case 'int':
									curOption.setValue(Math.round(holdValue));

								case 'float' | 'percent':
									curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if (curOption.type != 'string')
					{
						holdTime += elapsed;
					}
				}
				else if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
				{
					clearHold();
				}
			}

			if (controls.RESET)
			{
				for (option in optionsArray)
				{
					option.setValue(option.defaultValue);
					if (option.type != 'bool')
					{
						if (option.type == 'string')
						{
							option.curOption = option.options.indexOf(option.getValue());
						}
						updateTextFrom(option);
					}

					if (option.name == 'Scroll Speed')
					{
						option.displayFormat = '%vX';
						option.maxValue = 3;
						if (option.getValue() > 3)
						{
							option.setValue(3);
						}
						updateTextFrom(option);
					}
					option.change();
				}
				FlxG.sound.play(Paths.getSound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if (nextAccept > 0)
		{
			nextAccept -= 1;
		}
	}

	private function getOptions():Void
	{
		var goption:GameplayOption = new GameplayOption('Scroll Type', 'scrollType', 'string', 'multiplicative', ['multiplicative', 'constant']);
		optionsArray.push(goption);

		var option:GameplayOption = new GameplayOption('Scroll Speed', 'scrollSpeed', 'float', 1);
		option.scrollSpeed = 1.5;
		option.minValue = 0.5;
		option.changeValue = 0.1;
		if (goption.getValue() != 'constant')
		{
			option.displayFormat = '%vX';
			option.maxValue = 3;
		}
		else
		{
			option.displayFormat = '%v';
			option.maxValue = 6;
		}
		optionsArray.push(option);

		/*var option:GameplayOption = new GameplayOption('Playback Rate', 'songSpeed', 'float', 1);
			option.scrollSpeed = 1;
			option.minValue = 0.5;
			option.maxValue = 2.5;
			option.changeValue = 0.1;
			option.displayFormat = '%vX';
			optionsArray.push(option); */

		var option:GameplayOption = new GameplayOption('Health Gain Multiplier', 'healthGain', 'float', 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Health Loss Multiplier', 'healthLoss', 'float', 1);
		option.scrollSpeed = 2.5;
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Instakill on Miss', 'instakillOnMiss', 'bool', false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('Practice Mode', 'practiceMode', 'bool', false);
		optionsArray.push(option);

		var option:GameplayOption = new GameplayOption('BotPlay', 'botPlay', 'bool', false);
		optionsArray.push(option);
	}

	public function getOptionByName(name:String):GameplayOption
	{
		for (opt in optionsArray)
		{
			if (opt.name == name)
				return opt;
		}
		return null;
	}

	private function updateTextFrom(option:GameplayOption):Void
	{
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if (option.type == 'percent')
			val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}

	private function clearHold():Void
	{
		if (holdTime > 0.5)
		{
			FlxG.sound.play(Paths.getSound('scrollMenu'));
		}
		holdTime = 0;
	}

	private function changeSelection(change:Int = 0):Void
	{
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionsArray.length - 1;
		if (curSelected >= optionsArray.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		for (text in grpTexts)
		{
			text.alpha = 0.6;
			if (text.ID == curSelected)
			{
				text.alpha = 1;
			}
		}
		curOption = optionsArray[curSelected]; // shorter lol
		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	private function reloadCheckboxes():Void
	{
		for (checkbox in checkboxGroup)
		{
			checkbox.daValue = optionsArray[checkbox.ID].getValue();
		}
	}
}

class GameplayOption
{
	private var child:Alphabet;

	public var text(get, set):String;
	public var onChange:() -> Void; // Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = 'bool'; // bool, int (or integer), float (or fl), percent, string (or str)

	// Bool will use checkboxes
	// Everything else will use a text
	public var showBoyfriend:Bool = false;
	public var scrollSpeed:Float = 50; // Only works on int/float, defines how fast it scrolls per second while holding left/right

	private var variable:String; // Variable from ClientPrefs.hx's gameplaySettings

	public var defaultValue:Dynamic;

	public var curOption:Int = 0; // Don't change this
	public var options:Array<String>; // Only used in string type
	public var changeValue:Float = 1; // Only used in int/float/percent type, how much is changed when you PRESS

	public var minValue:Null<Float>; // Only used in int/float/percent type
	public var maxValue:Null<Float>; // Only used in int/float/percent type

	public var decimals:Int = 1; // Only used in float/percent type

	public var displayFormat:String = '%v'; // How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var name:String = 'Unknown';

	public function new(name:String, variable:String, type:String = 'bool', defaultValue:Dynamic = 'null variable value', ?options:Array<String>)
	{
		this.name = name;
		this.variable = variable;
		this.type = type;
		this.defaultValue = defaultValue;
		this.options = options;

		if (defaultValue == 'null variable value')
		{
			switch (type)
			{
				case 'bool':
					defaultValue = false;
				case 'int' | 'float':
					defaultValue = 0;
				case 'percent':
					defaultValue = 1;
				case 'string':
					defaultValue = '';
					if (options.length > 0)
					{
						defaultValue = options[0];
					}
			}
		}

		if (getValue() == null)
		{
			setValue(defaultValue);
		}

		switch (type)
		{
			case 'string':
				var num:Int = options.indexOf(getValue());
				if (num > -1)
				{
					curOption = num;
				}

			case 'percent':
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
		}
	}

	public function change():Void
	{
		// nothing lol
		if (onChange != null)
		{
			onChange();
		}
	}

	public function getValue():Dynamic
	{
		return Reflect.field(Options.save.data, variable);
	}

	public function setValue(value:Dynamic):Void
	{
		Reflect.setField(Options.save.data, variable, value);
	}

	public function setChild(child:Alphabet):Void
	{
		this.child = child;
	}

	private function get_text():String
	{
		if (child != null)
		{
			return child.text;
		}
		return null;
	}

	private function set_text(newValue:String = ''):String
	{
		if (child != null)
		{
			child.changeText(newValue);
			return child.text;
		}
		return null;
	}

	private function get_type():String
	{
		var newValue:String = 'bool';
		switch (type.toLowerCase().trim())
		{
			case 'int' | 'float' | 'percent' | 'string':
				newValue = type;
			case 'integer':
				newValue = 'int';
			case 'str':
				newValue = 'string';
			case 'fl':
				newValue = 'float';
		}
		type = newValue;
		return type;
	}
}
