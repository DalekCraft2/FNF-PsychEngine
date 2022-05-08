package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import options.Options;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class BaseOptionsMenu extends MusicBeatSubState
{
	private var curOption:Option;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var boyfriend:Character;
	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	override public function create():Void
	{
		super.create();

		if (title == null)
			title = 'Options';
		if (rpcTitle == null)
			rpcTitle = 'Options Menu';

		#if FEATURE_DISCORD
		DiscordClient.changePresence(rpcTitle, null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.screenCenter();
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup();
		add(grpOptions);

		grpTexts = new FlxTypedGroup();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		var titleText:Alphabet = new Alphabet(0, 0, title, true, false, 0, 0.6);
		titleText.x += 60;
		titleText.y += 40;
		titleText.alpha = 0.4;
		add(titleText);

		descText = new FlxText(50, 600, 1180, 32);
		descText.setFormat(Paths.font('vcr.ttf'), descText.size, CENTER, OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...optionsArray.length)
		{
			var option:Option = optionsArray[i];

			var optionText:Alphabet = new Alphabet(0, 70 * i, option.name, false, false);
			optionText.isMenuItem = true;
			optionText.x += 300;
			optionText.xAdd = 200;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if (option is ValueOption)
			{
				var valueOption:ValueOption<Any> = cast option;
				if (valueOption is BooleanOption)
				{
					var booleanOption:BooleanOption = cast valueOption;
					var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, booleanOption.value);
					checkbox.sprTracker = optionText;
					checkbox.ID = i;
					checkboxGroup.add(checkbox);
				}
				else
				{
					optionText.x -= 80;
					optionText.xAdd -= 80;
					var valueText:AttachedText = new AttachedText(Std.string(valueOption.value), optionText.width + 80);
					valueText.sprTracker = optionText;
					valueText.copyAlpha = true;
					valueText.ID = i;
					grpTexts.add(valueText);
					optionsArray[i].text = valueText;
				}
			}

			if (option.showBoyfriend && boyfriend == null)
			{
				reloadBoyfriend();
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
	}

	public function addOption(option:Option):Void
	{
		if (optionsArray == null || optionsArray.length < 1)
			optionsArray = [];
		optionsArray.push(option);
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

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
			FlxG.sound.play(Paths.getSound('cancelMenu'));
		}

		if (nextAccept <= 0)
		{
			var usesCheckbox:Bool = true;
			if (!(curOption is BooleanOption))
			{
				usesCheckbox = false;
			}

			if (usesCheckbox)
			{
				if (controls.ACCEPT)
				{
					FlxG.sound.play(Paths.getSound('scrollMenu'));
					curOption.value = curOption.value ? false : true;
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
							var add:Null<Float>;
							if (!(curOption is StringOption))
							{
								add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
							}

							if (curOption is IntegerOption || curOption is FloatOption)
							{
								holdValue = curOption.value + add;
								if (holdValue < curOption.min)
									holdValue = curOption.min;
								else if (holdValue > curOption.max)
									holdValue = curOption.max;

								if (curOption is IntegerOption)
								{
									holdValue = Math.round(holdValue);
									curOption.value = holdValue;
								}
								else if (curOption is FloatOption)
								{
									holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
									curOption.value = holdValue;
								}
							}
							else if (curOption is StringOption)
							{
								var num:Int = curOption.curOption;
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
								curOption.value = curOption.options[num]; // lol
								// Debug.logTrace(curOption.options[num]);
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.getSound('scrollMenu'));
						}
						else if (!(curOption is StringOption))
						{
							holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
							if (holdValue < curOption.minValue)
								holdValue = curOption.minValue;
							else if (holdValue > curOption.maxValue)
								holdValue = curOption.maxValue;

							if (curOption is IntegerOption)
							{
								holdValue = Math.round(holdValue);
								curOption.value = holdValue;
							}
							else if (curOption is FloatOption)
							{
								holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
								curOption.value = holdValue;
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if (!(curOption is StringOption))
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
					option.value = option.defaultValue;
					if (!(option is BooleanOption))
					{
						if (option is StringOption)
						{
							option.curOption = option.options.indexOf(option.value);
						}
						updateTextFrom(option);
					}
					option.change();
				}
				FlxG.sound.play(Paths.getSound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if (boyfriend != null && boyfriend.animation.curAnim.finished)
		{
			boyfriend.dance();
		}

		if (nextAccept > 0)
		{
			nextAccept -= 1;
		}
	}

	private function updateTextFrom(option:Option):Void
	{
		var text:String = option.displayFormat;
		var val:Any = option.value;
		if (option.type == 'percent')
			val *= 100;
		var def:Any = option.defaultValue;
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

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		for (i in 0...grpOptions.members.length)
		{
			var item:Alphabet = grpOptions.members[i];
			item.targetY = i - curSelected;

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

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		if (boyfriend != null)
		{
			boyfriend.visible = optionsArray[curSelected].showBoyfriend;
		}
		curOption = optionsArray[curSelected]; // shorter lol
		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	public function reloadBoyfriend():Void
	{
		var wasVisible:Bool = false;
		if (boyfriend != null)
		{
			wasVisible = boyfriend.visible;
			boyfriend.kill();
			remove(boyfriend);
			boyfriend.destroy();
		}

		boyfriend = new Character(840, 170, true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		insert(1, boyfriend);
		boyfriend.visible = wasVisible;
	}

	private function reloadCheckboxes():Void
	{
		for (checkbox in checkboxGroup)
		{
			checkbox.value = (optionsArray[checkbox.ID].value);
		}
	}
}
