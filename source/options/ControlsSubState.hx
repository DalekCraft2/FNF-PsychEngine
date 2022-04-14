package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import options.Options.OptionDefaults;

class ControlsSubState extends MusicBeatSubState
{
	private static var curSelected:Int = -1;
	private static var curAlt:Bool = false;

	private static final RESET_BUTTON_TEXT:String = 'Reset to Default Keys';

	private var bindLength:Int = 0;

	private var optionShit:Array<Array<String>> = [
		['NOTES'], ['Left', 'note_left'], ['Down', 'note_down'], ['Up', 'note_up'], ['Right', 'note_right'], [''], ['UI'], ['Left', 'ui_left'],
		['Down', 'ui_down'], ['Up', 'ui_up'], ['Right', 'ui_right'], [''], ['Reset', 'reset'], ['Accept', 'accept'], ['Back', 'back'], ['Pause', 'pause'],
		[''], ['VOLUME'], ['Mute', 'volume_mute'], ['Up', 'volume_up'], ['Down', 'volume_down'], [''], ['DEBUG'], ['Key 1', 'debug_1'], ['Key 2', 'debug_2']];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var grpInputs:Array<AttachedText> = [];
	private var grpInputsAlt:Array<AttachedText> = [];
	private var rebindingKey:Bool = false;
	private var nextAccept:Int = 5;

	override public function create():Void
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.screenCenter();
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);

		grpOptions = new FlxTypedGroup();
		add(grpOptions);

		optionShit.push(['']);
		optionShit.push([RESET_BUTTON_TEXT]);

		for (i in 0...optionShit.length)
		{
			var isCentered:Bool = false;
			var isDefaultKey:Bool = (optionShit[i][0] == RESET_BUTTON_TEXT);
			if (unselectableCheck(i, true))
			{
				isCentered = true;
			}

			var optionText:Alphabet = new Alphabet(0, (10 * i), optionShit[i][0], (!isCentered || isDefaultKey), false);
			optionText.isMenuItem = true;
			if (isCentered)
			{
				optionText.screenCenter(X);
				optionText.forceX = optionText.x;
				optionText.yAdd = -55;
			}
			else
			{
				optionText.forceX = 200;
			}
			optionText.yMult = 60;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if (!isCentered)
			{
				addBindTexts(optionText, i);
				bindLength++;
				if (curSelected < 0)
					curSelected = i;
			}
		}
		changeSelection();
	}

	private var leaving:Bool = false;
	private var bindingTime:Float = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!rebindingKey)
		{
			if (controls.UI_UP_P)
			{
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P)
			{
				changeSelection(1);
			}
			if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
			{
				changeAlt();
			}

			if (controls.BACK)
			{
				ClientPrefs.reloadControls();
				close();
				FlxG.sound.play(Paths.getSound('cancelMenu'));
			}

			if (controls.ACCEPT && nextAccept <= 0)
			{
				if (optionShit[curSelected][0] == RESET_BUTTON_TEXT)
				{
					Options.save.data.keyBinds = OptionDefaults.keyBinds.copy();
					reloadKeys();
					changeSelection();
					FlxG.sound.play(Paths.getSound('confirmMenu'));
				}
				else if (!unselectableCheck(curSelected))
				{
					bindingTime = 0;
					rebindingKey = true;
					if (curAlt)
					{
						grpInputsAlt[getInputTextNum()].alpha = 0;
					}
					else
					{
						grpInputs[getInputTextNum()].alpha = 0;
					}
					FlxG.sound.play(Paths.getSound('scrollMenu'));
				}
			}
		}
		else
		{
			var keyPressed:Int = FlxG.keys.firstJustPressed();
			if (keyPressed > -1)
			{
				var keysArray:Array<FlxKey> = Options.save.data.keyBinds.get(optionShit[curSelected][1]);
				keysArray[curAlt ? 1 : 0] = keyPressed;

				var opposite:Int = (curAlt ? 0 : 1);
				if (keysArray[opposite] == keysArray[1 - opposite])
				{
					keysArray[opposite] = NONE;
				}
				Options.save.data.keyBinds.set(optionShit[curSelected][1], keysArray);

				reloadKeys();
				FlxG.sound.play(Paths.getSound('confirmMenu'));
				rebindingKey = false;
			}

			bindingTime += elapsed;
			if (bindingTime > 5)
			{
				if (curAlt)
				{
					grpInputsAlt[curSelected].alpha = 1;
				}
				else
				{
					grpInputs[curSelected].alpha = 1;
				}
				FlxG.sound.play(Paths.getSound('scrollMenu'));
				rebindingKey = false;
				bindingTime = 0;
			}
		}

		if (nextAccept > 0)
		{
			nextAccept -= 1;
		}
	}

	private function getInputTextNum():Int
	{
		var num:Int = 0;
		for (i in 0...curSelected)
		{
			if (optionShit[i].length > 1)
			{
				num++;
			}
		}
		return num;
	}

	private function changeSelection(change:Int = 0):Void
	{
		do
		{
			curSelected += change;
			if (curSelected < 0)
				curSelected = optionShit.length - 1;
			if (curSelected >= optionShit.length)
				curSelected = 0;
		}
		while (unselectableCheck(curSelected));

		var bullShit:Int = 0;

		for (input in grpInputs)
		{
			input.alpha = 0.6;
		}
		for (inputAlt in grpInputsAlt)
		{
			inputAlt.alpha = 0.6;
		}

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			if (!unselectableCheck(bullShit - 1))
			{
				item.alpha = 0.6;
				if (item.targetY == 0)
				{
					item.alpha = 1;
					if (curAlt)
					{
						for (inputAlt in grpInputsAlt)
						{
							if (inputAlt.sprTracker == item)
							{
								inputAlt.alpha = 1;
								break;
							}
						}
					}
					else
					{
						for (input in grpInputs)
						{
							if (input.sprTracker == item)
							{
								input.alpha = 1;
								break;
							}
						}
					}
				}
			}
		}
		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	private function changeAlt():Void
	{
		curAlt = !curAlt;
		for (input in grpInputs)
		{
			if (input.sprTracker == grpOptions.members[curSelected])
			{
				input.alpha = 0.6;
				if (!curAlt)
				{
					input.alpha = 1;
				}
				break;
			}
		}
		for (inputAlt in grpInputsAlt)
		{
			if (inputAlt.sprTracker == grpOptions.members[curSelected])
			{
				inputAlt.alpha = 0.6;
				if (curAlt)
				{
					inputAlt.alpha = 1;
				}
				break;
			}
		}
		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	private function unselectableCheck(num:Int, ?checkDefaultKey:Bool = false):Bool
	{
		if (optionShit[num][0] == RESET_BUTTON_TEXT)
		{
			return checkDefaultKey;
		}
		return optionShit[num].length < 2 && optionShit[num][0] != RESET_BUTTON_TEXT;
	}

	private function addBindTexts(optionText:Alphabet, num:Int):Void
	{
		var keys:Array<FlxKey> = Options.save.data.keyBinds.get(optionShit[num][1]);
		var text1:AttachedText = new AttachedText(InputFormatter.getKeyName(keys[0]), 400, -55);
		text1.setPosition(optionText.x + 400, optionText.y - 55);
		text1.sprTracker = optionText;
		grpInputs.push(text1);
		add(text1);

		var text2:AttachedText = new AttachedText(InputFormatter.getKeyName(keys[1]), 650, -55);
		text2.setPosition(optionText.x + 650, optionText.y - 55);
		text2.sprTracker = optionText;
		grpInputsAlt.push(text2);
		add(text2);
	}

	private function reloadKeys():Void
	{
		while (grpInputs.length > 0)
		{
			var item:AttachedText = grpInputs[0];
			item.kill();
			grpInputs.remove(item);
			item.destroy();
		}
		while (grpInputsAlt.length > 0)
		{
			var item:AttachedText = grpInputsAlt[0];
			item.kill();
			grpInputsAlt.remove(item);
			item.destroy();
		}

		Debug.logTrace('Reloaded keys: ${Options.save.data.keyBinds}');

		for (i in 0...grpOptions.length)
		{
			if (!unselectableCheck(i, true))
			{
				addBindTexts(grpOptions.members[i], i);
			}
		}

		var bullShit:Int = 0;
		for (input in grpInputs)
		{
			input.alpha = 0.6;
		}
		for (inputAlt in grpInputsAlt)
		{
			inputAlt.alpha = 0.6;
		}

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			if (!unselectableCheck(bullShit - 1))
			{
				item.alpha = 0.6;
				if (item.targetY == 0)
				{
					item.alpha = 1;
					if (curAlt)
					{
						for (inputAlt in grpInputsAlt)
						{
							if (inputAlt.sprTracker == item)
							{
								inputAlt.alpha = 1;
							}
						}
					}
					else
					{
						for (input in grpInputs)
						{
							if (input.sprTracker == item)
							{
								input.alpha = 1;
							}
						}
					}
				}
			}
		}
	}
}
