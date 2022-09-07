package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import funkin.NoteKey.NoteColor;
import funkin.shader.ColorSwap;
import funkin.states.substates.OptionsSubState;
import funkin.ui.Alphabet;
import haxe.io.Path;

class NoteColorState extends MusicBeatState
{
	private static var curSelected:Int = 0;
	private static var typeSelected:Int = 0;

	private var grpNumbers:FlxTypedGroup<Alphabet>;
	private var grpNotes:FlxTypedGroup<FlxSprite>;
	private var shaderArray:Array<ColorSwap> = [];
	private var curValue:Float = 0;
	private var holdTime:Float = 0;
	private var nextAccept:Int = 5;

	private var blackBG:FlxSprite;
	private var hsbText:Alphabet;

	private var posX:Float = 230;
	private var changingNote:Bool = false;

	private var goToOptions:Bool = false;

	override public function create():Void
	{
		super.create();

		if (OptionsSubState.isInPause)
		{
			var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			bg.alpha = 0.6;
			bg.scrollFactor.set();
			add(bg);

			cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		}
		// TODO I want to make this a substate so I don't have to have this "else" statement
		else
		{
			var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'main', 'backgrounds', 'menuDesat'])));
			bg.color = 0xFFEA71FD;
			bg.updateHitbox();
			bg.screenCenter();
			bg.antialiasing = Options.profile.globalAntialiasing;
			add(bg);
		}

		blackBG = new FlxSprite(posX - 25).makeGraphic(870, 200, FlxColor.BLACK);
		blackBG.alpha = 0.4;
		add(blackBG);

		grpNotes = new FlxTypedGroup();
		add(grpNotes);
		grpNumbers = new FlxTypedGroup();
		add(grpNumbers);

		if (Options.profile.arrowHSV == null)
			Options.profile.arrowHSV = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];

		for (i in 0...Options.profile.arrowHSV.length)
		{
			var yPos:Float = (165 * i) + 35;
			for (j in 0...3)
			{
				var optionText:Alphabet = new Alphabet(0, yPos + 60, Std.string(Options.profile.arrowHSV[i][j]), true);
				optionText.x = posX + (225 * j) + 250;
				grpNumbers.add(optionText);
			}

			var note:FlxSprite = new FlxSprite(posX, yPos);
			note.frames = Paths.getFrames(Path.join(['ui', 'notes', 'NOTE_assets']));
			note.animation.addByPrefix('idle', '${NoteColor.createByIndex(i)} alone');
			note.animation.play('idle');
			note.antialiasing = Options.profile.globalAntialiasing;
			grpNotes.add(note);

			var newShader:ColorSwap = new ColorSwap();
			note.shader = newShader.shader;
			newShader.hue = Options.profile.arrowHSV[i][0] / 360;
			newShader.saturation = Options.profile.arrowHSV[i][1] / 100;
			newShader.brightness = Options.profile.arrowHSV[i][2] / 100;
			shaderArray.push(newShader);
		}

		hsbText = new Alphabet(0, 0, 'Hue    Saturation  Brightness', false, false, 0, 0.65);
		hsbText.x = posX + 240;
		add(hsbText);

		changeSelection();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (changingNote)
		{
			if (holdTime < 0.5)
			{
				if (controls.UI_LEFT_P)
				{
					updateValue(-1);
					FlxG.sound.play(Paths.getSound('scrollMenu'));
				}
				else if (controls.UI_RIGHT_P)
				{
					updateValue(1);
					FlxG.sound.play(Paths.getSound('scrollMenu'));
				}
				else if (controls.RESET)
				{
					resetValue(curSelected, typeSelected);
					FlxG.sound.play(Paths.getSound('scrollMenu'));
				}
				if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
				{
					holdTime = 0;
				}
				else if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
				}
			}
			else
			{
				var add:Float = 90;
				switch (typeSelected)
				{
					case 1 | 2:
						add = 50;
				}
				if (controls.UI_LEFT)
				{
					updateValue(elapsed * -add);
				}
				else if (controls.UI_RIGHT)
				{
					updateValue(elapsed * add);
				}
				if (controls.UI_LEFT_R || controls.UI_RIGHT_R)
				{
					FlxG.sound.play(Paths.getSound('scrollMenu'));
					holdTime = 0;
				}
			}
		}
		else
		{
			if (controls.UI_UP_P)
			{
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P)
			{
				changeSelection(1);
			}
			if (FlxG.mouse.wheel != 0)
			{
				changeSelection(-FlxG.mouse.wheel);
			}
			if (controls.UI_LEFT_P)
			{
				changeType(-1);
			}
			if (controls.UI_RIGHT_P)
			{
				changeType(1);
			}
			if (controls.RESET)
			{
				for (i in 0...3)
				{
					resetValue(curSelected, i);
				}
				FlxG.sound.play(Paths.getSound('scrollMenu'));
			}
			if (controls.ACCEPT && nextAccept <= 0)
			{
				FlxG.sound.play(Paths.getSound('scrollMenu'));
				changingNote = true;
				holdTime = 0;
				for (i => item in grpNumbers.members)
				{
					item.alpha = 0;
					if ((curSelected * 3) + typeSelected == i)
					{
						item.alpha = 1;
					}
				}
				for (i => item in grpNotes.members)
				{
					item.alpha = 0;
					if (curSelected == i)
					{
						item.alpha = 1;
					}
				}
				return;
			}
		}

		if (controls.BACK || (changingNote && controls.ACCEPT))
		{
			if (!changingNote)
			{
				Options.flushSave();
				// TODO Switch to the substate if in PlayState
				FlxG.switchState(new OptionsState());
				// close();
			}
			else
			{
				changeSelection();
			}
			changingNote = false;
			FlxG.sound.play(Paths.getSound('cancelMenu'));
		}

		if (nextAccept > 0)
		{
			nextAccept -= 1;
		}
	}

	private function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, Std.int(Options.profile.arrowHSV.length) - 1);

		curValue = Options.profile.arrowHSV[curSelected][typeSelected];
		updateValue();

		for (i => item in grpNumbers.members)
		{
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i)
			{
				item.alpha = 1;
			}
		}
		for (i => item in grpNotes.members)
		{
			item.alpha = 0.6;
			item.scale.set(0.75, 0.75);
			if (curSelected == i)
			{
				item.alpha = 1;
				item.scale.set(1, 1);
				hsbText.y = item.y - 70;
				blackBG.y = item.y - 20;
			}
		}
		if (change != 0)
			FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	private function changeType(change:Int = 0):Void
	{
		typeSelected = FlxMath.wrap(typeSelected + change, 0, 2);

		curValue = Options.profile.arrowHSV[curSelected][typeSelected];
		updateValue();

		for (i => item in grpNumbers.members)
		{
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i)
			{
				item.alpha = 1;
			}
		}
		if (change != 0)
			FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	private function resetValue(selected:Int, type:Int):Void
	{
		curValue = 0;
		Options.profile.arrowHSV[selected][type] = 0;
		switch (type)
		{
			case 0:
				shaderArray[selected].hue = 0;
			case 1:
				shaderArray[selected].saturation = 0;
			case 2:
				shaderArray[selected].brightness = 0;
		}

		var item:Alphabet = grpNumbers.members[(selected * 3) + type];
		item.changeText('0');
		item.offset.x = (40 * (item.lettersArray.length - 1)) / 2;
	}

	private function updateValue(change:Float = 0):Void
	{
		curValue += change;
		var roundedValue:Int = Math.round(curValue);
		var max:Float = 180;
		switch (typeSelected)
		{
			case 1 | 2:
				max = 100;
		}

		if (roundedValue < -max)
		{
			curValue = -max;
		}
		else if (roundedValue > max)
		{
			curValue = max;
		}
		roundedValue = Math.round(curValue);
		Options.profile.arrowHSV[curSelected][typeSelected] = roundedValue;

		switch (typeSelected)
		{
			case 0:
				shaderArray[curSelected].hue = roundedValue / 360;
			case 1:
				shaderArray[curSelected].saturation = roundedValue / 100;
			case 2:
				shaderArray[curSelected].brightness = roundedValue / 100;
		}

		var item:Alphabet = grpNumbers.members[(curSelected * 3) + typeSelected];
		item.changeText(Std.string(roundedValue));
		item.offset.x = (40 * (item.lettersArray.length - 1)) / 2;
		if (roundedValue < 0)
			item.offset.x += 10;
	}
}
