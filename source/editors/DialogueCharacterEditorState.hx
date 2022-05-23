package editors;

import DialogueBoxPsych.DialogueAnimationDef;
import DialogueBoxPsych.DialogueCharacter;
import DialogueBoxPsych.DialogueCharacterDef;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class DialogueCharacterEditorState extends MusicBeatState
{
	private static final TIP_TEXT_MAIN:String = 'JKLI - Move camera (Hold Shift to move 4x faster)\nQ/E - Zoom out/in\nR - Reset Camera\nH - Toggle Speech Bubble\nSpace - Reset text';

	private static final TIP_TEXT_OFFSET:String = 'JKLI - Move camera (Hold Shift to move 4x faster)\nQ/E - Zoom out/in\nR - Reset Camera\nH - Toggle Ghosts\nWASD - Move Looping animation offset (Red)\nArrow Keys - Move Idle/Finished animation offset (Blue)\nHold Shift to move offsets 10x faster';

	private static final DEFAULT_TEXT:String = 'Lorem ipsum dolor sit amet';

	private var box:FlxSprite;
	private var text:Alphabet;
	private var tipText:FlxText;
	private var offsetLoopText:FlxText;
	private var offsetIdleText:FlxText;
	private var animText:FlxText;

	private var camGame:FlxCamera;
	private var camOther:FlxCamera;

	private var mainGroup:FlxSpriteGroup;
	private var hudGroup:FlxSpriteGroup;

	private var character:DialogueCharacter;
	private var ghostLoop:DialogueCharacter;
	private var ghostIdle:DialogueCharacter;

	private var curAnim:Int = 0;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		Alphabet.setDialogueSound();

		camGame = new FlxCamera();
		camOther = new FlxCamera();
		camGame.bgColor = FlxColor.fromHSL(0, 0, 0.5);
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camOther, false);

		mainGroup = new FlxSpriteGroup();
		mainGroup.cameras = [camGame];
		hudGroup = new FlxSpriteGroup();
		hudGroup.cameras = [camGame];
		add(mainGroup);
		add(hudGroup);

		character = new DialogueCharacter();
		character.scrollFactor.set();
		mainGroup.add(character);

		ghostLoop = new DialogueCharacter();
		ghostLoop.alpha = 0;
		ghostLoop.color = FlxColor.RED;
		ghostLoop.isGhost = true;
		ghostLoop.jsonFile = character.jsonFile;
		ghostLoop.cameras = [camGame];
		add(ghostLoop);

		ghostIdle = new DialogueCharacter();
		ghostIdle.alpha = 0;
		ghostIdle.color = FlxColor.BLUE;
		ghostIdle.isGhost = true;
		ghostIdle.jsonFile = character.jsonFile;
		ghostIdle.cameras = [camGame];
		add(ghostIdle);

		box = new FlxSprite(70, 370);
		box.frames = Paths.getSparrowAtlas('speech_bubble');
		box.scrollFactor.set();
		box.antialiasing = Options.save.data.globalAntialiasing;
		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('center', 'speech bubble middle', 24);
		box.animation.play('normal', true);
		box.setGraphicSize(Std.int(box.width * 0.9));
		box.updateHitbox();
		hudGroup.add(box);

		tipText = new FlxText(10, 10, FlxG.width - 20, TIP_TEXT_MAIN, 16);
		tipText.setFormat(Paths.font('vcr.ttf'), tipText.size, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		tipText.cameras = [camOther];
		tipText.scrollFactor.set();
		add(tipText);

		offsetLoopText = new FlxText(10, 10, 0, 32);
		offsetLoopText.setFormat(Paths.font('vcr.ttf'), offsetLoopText.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		offsetLoopText.cameras = [camOther];
		offsetLoopText.scrollFactor.set();
		offsetLoopText.visible = false;
		add(offsetLoopText);

		offsetIdleText = new FlxText(10, 46, 0, 32);
		offsetIdleText.setFormat(Paths.font('vcr.ttf'), offsetIdleText.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		offsetIdleText.cameras = [camOther];
		offsetIdleText.scrollFactor.set();
		offsetIdleText.visible = false;
		add(offsetIdleText);

		animText = new FlxText(10, 22, FlxG.width - 20, 24);
		animText.setFormat(Paths.font('vcr.ttf'), animText.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		animText.scrollFactor.set();
		add(animText);

		reloadCharacter();
		updateTextBox();
		reloadText();

		addEditorBox();
		FlxG.mouse.visible = true;
		updateCharTypeBox();
	}

	private var currentGhosts:Int = 0;
	private var lastTab:String = 'Character';
	private var transitioning:Bool = false;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (transitioning)
		{
			return;
		}

		if (character.animation.curAnim != null)
		{
			if (text.finishedText)
			{
				if (character.animationIsLoop())
				{
					character.playAnim(character.animation.curAnim.name, true);
				}
			}
			else if (character.animation.curAnim.finished)
			{
				character.animation.curAnim.restart();
			}
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn)
		{
			if (inputText.hasFocus)
			{
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;

				if (FlxG.keys.pressed.CONTROL
					&& FlxG.keys.justPressed.V
					&& Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT) != null)
				{ // Copy paste
					inputText.text = clipboardAdd(inputText.text);
					inputText.caretIndex = inputText.text.length;
					getEvent(FlxUIInputText.CHANGE_EVENT, inputText, null, []);
				}
				if (FlxG.keys.justPressed.ENTER)
					inputText.hasFocus = false;
				break;
			}
		}

		if (!blockInput && !animationDropDown.dropPanel.visible)
		{
			FlxG.sound.muteKeys = InitState.muteKeys;
			FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;
			if (FlxG.keys.justPressed.SPACE && UI_mainbox.selected_tab_id == 'Character')
			{
				character.playAnim(character.jsonFile.animations[curAnim].anim);
				updateTextBox();
				reloadText();
			}

			// lots of Ifs lol get trolled
			var offsetAdd:Int = 1;
			var speed:Float = 300;
			if (FlxG.keys.pressed.SHIFT)
			{
				speed = 1200;
				offsetAdd = 10;
			}

			var negaMult:Array<Int> = [1, 1, -1, -1];
			var controlArray:Array<Bool> = [
				FlxG.keys.pressed.J,
				FlxG.keys.pressed.I,
				FlxG.keys.pressed.L,
				FlxG.keys.pressed.K
			];
			for (i in 0...controlArray.length)
			{
				if (controlArray[i])
				{
					if (i % 2 == 1)
					{
						mainGroup.y += speed * elapsed * negaMult[i];
					}
					else
					{
						mainGroup.x += speed * elapsed * negaMult[i];
					}
				}
			}

			if (UI_mainbox.selected_tab_id == 'Animations'
				&& curSelectedAnim != null
				&& character.dialogueAnimations.exists(curSelectedAnim))
			{
				var moved:Bool = false;
				var animShit:DialogueAnimationDef = character.dialogueAnimations.get(curSelectedAnim);
				var controlArrayLoop:Array<Bool> = [
					FlxG.keys.justPressed.A,
					FlxG.keys.justPressed.W,
					FlxG.keys.justPressed.D,
					FlxG.keys.justPressed.S
				];
				var controlArrayIdle:Array<Bool> = [
					FlxG.keys.justPressed.LEFT,
					FlxG.keys.justPressed.UP,
					FlxG.keys.justPressed.RIGHT,
					FlxG.keys.justPressed.DOWN
				];
				for (i in 0...controlArrayLoop.length)
				{
					if (controlArrayLoop[i])
					{
						if (i % 2 == 1)
						{
							animShit.loopOffsets[1] += offsetAdd * negaMult[i];
						}
						else
						{
							animShit.loopOffsets[0] += offsetAdd * negaMult[i];
						}
						moved = true;
					}
				}
				for (i in 0...controlArrayIdle.length)
				{
					if (controlArrayIdle[i])
					{
						if (i % 2 == 1)
						{
							animShit.idleOffsets[1] += offsetAdd * negaMult[i];
						}
						else
						{
							animShit.idleOffsets[0] += offsetAdd * negaMult[i];
						}
						moved = true;
					}
				}

				if (moved)
				{
					offsetLoopText.text = 'Loop: ${animShit.loopOffsets}';
					offsetIdleText.text = 'Idle: ${animShit.idleOffsets}';
					ghostLoop.offset.set(animShit.loopOffsets[0], animShit.loopOffsets[1]);
					ghostIdle.offset.set(animShit.idleOffsets[0], animShit.idleOffsets[1]);
				}
			}

			if (FlxG.keys.pressed.Q && camGame.zoom > 0.1)
			{
				camGame.zoom -= elapsed * camGame.zoom;
				if (camGame.zoom < 0.1)
					camGame.zoom = 0.1;
			}
			if (FlxG.keys.pressed.E && camGame.zoom < 1)
			{
				camGame.zoom += elapsed * camGame.zoom;
				if (camGame.zoom > 1)
					camGame.zoom = 1;
			}
			if (FlxG.keys.justPressed.H)
			{
				if (UI_mainbox.selected_tab_id == 'Animations')
				{
					currentGhosts++;
					if (currentGhosts > 2)
						currentGhosts = 0;

					ghostLoop.visible = (currentGhosts != 1);
					ghostIdle.visible = (currentGhosts != 2);
					ghostLoop.alpha = (currentGhosts == 2 ? 1 : 0.6);
					ghostIdle.alpha = (currentGhosts == 1 ? 1 : 0.6);
				}
				else
				{
					hudGroup.visible = !hudGroup.visible;
				}
			}
			if (FlxG.keys.justPressed.R)
			{
				camGame.zoom = 1;
				mainGroup.setPosition(0, 0);
				hudGroup.visible = true;
			}

			if (UI_mainbox.selected_tab_id != lastTab)
			{
				if (UI_mainbox.selected_tab_id == 'Animations')
				{
					hudGroup.alpha = 0;
					mainGroup.alpha = 0;
					ghostLoop.alpha = 0.6;
					ghostIdle.alpha = 0.6;
					tipText.text = TIP_TEXT_OFFSET;
					offsetLoopText.visible = true;
					offsetIdleText.visible = true;
					animText.visible = false;
					currentGhosts = 0;
				}
				else
				{
					hudGroup.alpha = 1;
					mainGroup.alpha = 1;
					ghostLoop.alpha = 0;
					ghostIdle.alpha = 0;
					tipText.text = TIP_TEXT_MAIN;
					offsetLoopText.visible = false;
					offsetIdleText.visible = false;
					animText.visible = true;
					updateTextBox();
					reloadText();

					if (curAnim < 0)
						curAnim = character.jsonFile.animations.length - 1;
					else if (curAnim >= character.jsonFile.animations.length)
						curAnim = 0;

					character.playAnim(character.jsonFile.animations[curAnim].anim);
					animText.text = 'Animation: ${character.jsonFile.animations[curAnim].anim} (${curAnim + 1} / ${character.jsonFile.animations.length}) - Press W or S to scroll';
				}
				lastTab = UI_mainbox.selected_tab_id;
				currentGhosts = 0;
			}

			if (UI_mainbox.selected_tab_id == 'Character')
			{
				var negaMult:Array<Int> = [1, -1];
				var controlAnim:Array<Bool> = [FlxG.keys.justPressed.W, FlxG.keys.justPressed.S];

				if (controlAnim.contains(true))
				{
					for (i in 0...controlAnim.length)
					{
						if (controlAnim[i] && character.jsonFile.animations.length > 0)
						{
							curAnim -= negaMult[i];
							if (curAnim < 0)
								curAnim = character.jsonFile.animations.length - 1;
							else if (curAnim >= character.jsonFile.animations.length)
								curAnim = 0;

							var animToPlay:String = character.jsonFile.animations[curAnim].anim;
							if (character.dialogueAnimations.exists(animToPlay))
							{
								character.playAnim(animToPlay, text.finishedText);
							}
						}
					}
					animText.text = 'Animation: ${character.jsonFile.animations[curAnim].anim} (${curAnim + 1} / ${character.jsonFile.animations.length}) - Press W or S to scroll';
				}
			}

			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.switchState(new MasterEditorMenuState());
				transitioning = true;
			}

			ghostLoop.setPosition(character.x, character.y);
			ghostIdle.setPosition(character.x, character.y);
			hudGroup.x = mainGroup.x;
			hudGroup.y = mainGroup.y;
		}
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && sender == imageInputText)
		{
			character.jsonFile.image = imageInputText.text;
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			if (sender == scaleStepper)
			{
				character.jsonFile.scale = scaleStepper.value;
				reloadCharacter();
			}
			else if (sender == xStepper)
			{
				character.jsonFile.position[0] = xStepper.value;
				reloadCharacter();
			}
			else if (sender == yStepper)
			{
				character.jsonFile.position[1] = yStepper.value;
				reloadCharacter();
			}
		}
	}

	private var UI_typebox:FlxUITabMenu;
	private var UI_mainbox:FlxUITabMenu;

	private function addEditorBox():Void
	{
		var tabs:Array<{name:String, label:String}> = [{name: 'Character Type', label: 'Character Type'},];
		UI_typebox = new FlxUITabMenu(null, tabs, true);
		UI_typebox.resize(120, 180);
		UI_typebox.x = 900;
		UI_typebox.y = FlxG.height - UI_typebox.height - 50;
		UI_typebox.scrollFactor.set();
		UI_typebox.camera = camGame;
		addTypeUI();
		add(UI_typebox);

		var tabs:Array<{name:String, label:String}> = [
			{name: 'Animations', label: 'Animations'},
			{name: 'Character', label: 'Character'},
		];
		UI_mainbox = new FlxUITabMenu(null, tabs, true);
		UI_mainbox.resize(200, 250);
		UI_mainbox.x = UI_typebox.x + UI_typebox.width;
		UI_mainbox.y = FlxG.height - UI_mainbox.height - 50;
		UI_mainbox.scrollFactor.set();
		UI_mainbox.camera = camGame;
		addAnimationsUI();
		addCharacterUI();
		add(UI_mainbox);
		UI_mainbox.selected_tab_id = 'Character';
		lastTab = UI_mainbox.selected_tab_id;
	}

	private var leftCheckbox:FlxUICheckBox;
	private var centerCheckbox:FlxUICheckBox;
	private var rightCheckbox:FlxUICheckBox;

	private function addTypeUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_typebox);
		tabGroup.name = 'Character Type';

		leftCheckbox = new FlxUICheckBox(10, 20, null, null, 'Left', 100);
		leftCheckbox.callback = () ->
		{
			character.jsonFile.dialoguePos = 'left';
			updateCharTypeBox();
		};

		centerCheckbox = new FlxUICheckBox(leftCheckbox.x, leftCheckbox.y + 40, null, null, 'Center', 100);
		centerCheckbox.callback = () ->
		{
			character.jsonFile.dialoguePos = 'center';
			updateCharTypeBox();
		};

		rightCheckbox = new FlxUICheckBox(centerCheckbox.x, centerCheckbox.y + 40, null, null, 'Right', 100);
		rightCheckbox.callback = () ->
		{
			character.jsonFile.dialoguePos = 'right';
			updateCharTypeBox();
		};

		tabGroup.add(leftCheckbox);
		tabGroup.add(centerCheckbox);
		tabGroup.add(rightCheckbox);
		UI_typebox.addGroup(tabGroup);
	}

	private var curSelectedAnim:String;
	private var animationArray:Array<String> = [];
	private var animationDropDown:FlxUIDropDownMenu;
	private var animationInputText:FlxUIInputText;
	private var loopInputText:FlxUIInputText;
	private var idleInputText:FlxUIInputText;

	private function addAnimationsUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_mainbox);
		tabGroup.name = 'Animations';

		animationDropDown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), (animation:String) ->
		{
			var anim:String = animationArray[Std.parseInt(animation)];
			if (character.dialogueAnimations.exists(anim))
			{
				ghostLoop.playAnim(anim);
				ghostIdle.playAnim(anim, true);

				curSelectedAnim = anim;
				var animShit:DialogueAnimationDef = character.dialogueAnimations.get(curSelectedAnim);
				offsetLoopText.text = 'Loop: ${animShit.loopOffsets}';
				offsetIdleText.text = 'Idle: ${animShit.idleOffsets}';

				animationInputText.text = animShit.anim;
				loopInputText.text = animShit.loopName;
				idleInputText.text = animShit.idleName;
			}
		});

		animationInputText = new FlxUIInputText(15, 85, 80, 8);
		blockPressWhileTypingOn.push(animationInputText);
		loopInputText = new FlxUIInputText(animationInputText.x, animationInputText.y + 35, 150, 8);
		blockPressWhileTypingOn.push(loopInputText);
		idleInputText = new FlxUIInputText(loopInputText.x, loopInputText.y + 40, 150, 8);
		blockPressWhileTypingOn.push(idleInputText);

		var addUpdateButton:FlxButton = new FlxButton(10, idleInputText.y + 30, 'Add/Update', () ->
		{
			var theAnim:String = animationInputText.text.trim();
			if (character.dialogueAnimations.exists(theAnim)) // Update
			{
				for (animArray in character.jsonFile.animations)
				{
					if (animArray.anim.trim() == theAnim)
					{
						animArray.loopName = loopInputText.text;
						animArray.idleName = idleInputText.text;
						break;
					}
				}

				character.reloadAnimations();
				ghostLoop.reloadAnimations();
				ghostIdle.reloadAnimations();
				if (curSelectedAnim == theAnim)
				{
					ghostLoop.playAnim(theAnim);
					ghostIdle.playAnim(theAnim, true);
				}
			}
			else // Add
			{
				var newAnim:DialogueAnimationDef = {
					anim: theAnim,
					loopName: loopInputText.text,
					loopOffsets: [0, 0],
					idleName: idleInputText.text,
					idleOffsets: [0, 0]
				}
				character.jsonFile.animations.push(newAnim);

				var lastSelected:String = animationDropDown.selectedLabel;
				character.reloadAnimations();
				ghostLoop.reloadAnimations();
				ghostIdle.reloadAnimations();
				reloadAnimationsDropDown();
				animationDropDown.selectedLabel = lastSelected;
			}
		});

		var removeUpdateButton:FlxButton = new FlxButton(100, addUpdateButton.y, 'Remove', () ->
		{
			for (animArray in character.jsonFile.animations)
			{
				if (animArray != null && animArray.anim.trim() == animationInputText.text.trim())
				{
					var lastSelected:String = animationDropDown.selectedLabel;
					character.jsonFile.animations.remove(animArray);
					character.reloadAnimations();
					ghostLoop.reloadAnimations();
					ghostIdle.reloadAnimations();
					reloadAnimationsDropDown();
					if (character.jsonFile.animations.length > 0 && lastSelected == animArray.anim.trim())
					{
						var animToPlay:String = character.jsonFile.animations[0].anim;
						ghostLoop.playAnim(animToPlay);
						ghostIdle.playAnim(animToPlay, true);
					}
					animationDropDown.selectedLabel = lastSelected;
					animationInputText.text = '';
					loopInputText.text = '';
					idleInputText.text = '';
					break;
				}
			}
		});

		tabGroup.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tabGroup.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tabGroup.add(new FlxText(loopInputText.x, loopInputText.y - 18, 0, 'Loop name on .XML file:'));
		tabGroup.add(new FlxText(idleInputText.x, idleInputText.y - 18, 0, 'Idle/Finished name on .XML file:'));
		tabGroup.add(animationInputText);
		tabGroup.add(loopInputText);
		tabGroup.add(idleInputText);
		tabGroup.add(addUpdateButton);
		tabGroup.add(removeUpdateButton);
		tabGroup.add(animationDropDown);
		UI_mainbox.addGroup(tabGroup);
		reloadAnimationsDropDown();
	}

	private function reloadAnimationsDropDown():Void
	{
		animationArray = [];
		for (anim in character.jsonFile.animations)
		{
			animationArray.push(anim.anim);
		}

		if (animationArray.length < 1)
			animationArray = [''];
		animationDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(animationArray, true));
	}

	private var imageInputText:FlxUIInputText;
	private var scaleStepper:FlxUINumericStepper;
	private var xStepper:FlxUINumericStepper;
	private var yStepper:FlxUINumericStepper;
	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];

	private function addCharacterUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_mainbox);
		tabGroup.name = 'Character';

		imageInputText = new FlxUIInputText(10, 30, 80, character.jsonFile.image, 8);
		blockPressWhileTypingOn.push(imageInputText);
		xStepper = new FlxUINumericStepper(imageInputText.x, imageInputText.y + 50, 10, character.jsonFile.position[0], -2000, 2000, 0);
		yStepper = new FlxUINumericStepper(imageInputText.x + 80, xStepper.y, 10, character.jsonFile.position[1], -2000, 2000, 0);
		scaleStepper = new FlxUINumericStepper(imageInputText.x, xStepper.y + 50, 0.05, character.jsonFile.scale, 0.1, 10, 2);

		var noAntialiasingCheckbox:FlxUICheckBox = new FlxUICheckBox(scaleStepper.x + 80, scaleStepper.y, null, null, 'No Antialiasing', 100);
		noAntialiasingCheckbox.checked = character.jsonFile.noAntialiasing;
		noAntialiasingCheckbox.callback = () ->
		{
			character.jsonFile.noAntialiasing = noAntialiasingCheckbox.checked;
			character.antialiasing = !character.jsonFile.noAntialiasing;
		};

		tabGroup.add(new FlxText(10, imageInputText.y - 18, 0, 'Image file name:'));
		tabGroup.add(new FlxText(10, xStepper.y - 18, 0, 'Position Offset:'));
		tabGroup.add(new FlxText(10, scaleStepper.y - 18, 0, 'Scale:'));
		tabGroup.add(imageInputText);
		tabGroup.add(xStepper);
		tabGroup.add(yStepper);
		tabGroup.add(scaleStepper);
		tabGroup.add(noAntialiasingCheckbox);

		var reloadImageButton:FlxButton = new FlxButton(10, scaleStepper.y + 60, 'Reload Image', () ->
		{
			reloadCharacter();
		});

		var loadButton:FlxButton = new FlxButton(reloadImageButton.x + 100, reloadImageButton.y, 'Load Character', () ->
		{
			fileBrowseDialog();
		});
		var saveButton:FlxButton = new FlxButton(loadButton.x, reloadImageButton.y - 25, 'Save Character', () ->
		{
			fileSaveDialog();
		});
		tabGroup.add(reloadImageButton);
		tabGroup.add(loadButton);
		tabGroup.add(saveButton);
		UI_mainbox.addGroup(tabGroup);
	}

	private function updateCharTypeBox():Void
	{
		leftCheckbox.checked = false;
		centerCheckbox.checked = false;
		rightCheckbox.checked = false;

		switch (character.jsonFile.dialoguePos)
		{
			case 'left':
				leftCheckbox.checked = true;
			case 'center':
				centerCheckbox.checked = true;
			case 'right':
				rightCheckbox.checked = true;
		}
		reloadCharacter();
		updateTextBox();
	}

	private function reloadText():Void
	{
		if (text != null)
		{
			text.killTheTimer();
			text.kill();
			hudGroup.remove(text);
			text.destroy();
		}
		text = new Alphabet(0, 0, DEFAULT_TEXT, false, true, 0.05, 0.7);
		text.x = DialogueBoxPsych.DEFAULT_TEXT_X;
		text.y = DialogueBoxPsych.DEFAULT_TEXT_Y;
		hudGroup.add(text);
	}

	private function reloadCharacter():Void
	{
		var charsArray:Array<DialogueCharacter> = [character, ghostLoop, ghostIdle];
		for (char in charsArray)
		{
			char.frames = Paths.getSparrowAtlas(Path.join(['dialogue', character.jsonFile.image]));
			char.jsonFile = character.jsonFile;
			char.reloadAnimations();
			char.setGraphicSize(Std.int(char.width * DialogueCharacter.DEFAULT_SCALE * character.jsonFile.scale));
			char.updateHitbox();
		}
		character.x = DialogueBoxPsych.LEFT_CHAR_X;
		character.y = DialogueBoxPsych.DEFAULT_CHAR_Y;

		switch (character.jsonFile.dialoguePos)
		{
			case 'right':
				character.x = FlxG.width - character.width + DialogueBoxPsych.RIGHT_CHAR_X;

			case 'center':
				character.x = FlxG.width / 2;
				character.x -= character.width / 2;
		}
		character.x += character.jsonFile.position[0] + mainGroup.x;
		character.y += character.jsonFile.position[1] + mainGroup.y;
		character.playAnim(character.jsonFile.animations[0].anim);
		if (character.jsonFile.animations.length > 0)
		{
			curSelectedAnim = character.jsonFile.animations[0].anim;
			var animShit:DialogueAnimationDef = character.dialogueAnimations.get(curSelectedAnim);
			ghostLoop.playAnim(animShit.anim);
			ghostIdle.playAnim(animShit.anim, true);
			offsetLoopText.text = 'Loop: ${animShit.loopOffsets}';
			offsetIdleText.text = 'Idle: ${animShit.idleOffsets}';
		}

		curAnim = 0;
		animText.text = 'Animation: ${character.jsonFile.animations[curAnim].anim} (${curAnim + 1} / ${character.jsonFile.animations.length}) - Press W or S to scroll';

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Dialogue Character Editor', 'Editing: ${character.jsonFile.image}');
		#end
	}

	private function updateTextBox():Void
	{
		box.flipX = false;
		var anim:String = 'normal';
		switch (character.jsonFile.dialoguePos)
		{
			case 'left':
				box.flipX = true;
			case 'center':
				anim = 'center';
		}
		box.animation.play(anim, true);
		DialogueBoxPsych.updateBoxOffsets(box);
	}

	private function clipboardAdd(prefix:String = ''):String
	{
		if (prefix.toLowerCase().endsWith('v')) // probably copy paste attempt
		{
			prefix = prefix.substring(0, prefix.length - 1);
		}

		return prefix + Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT).replace('\n', '');
	}

	private var _file:FileReference;

	private function fileBrowseDialog():Void
	{
		var jsonFilter:FileFilter = new FileFilter('JSON', Paths.JSON_EXT);
		addLoadListeners();
		_file.browse([jsonFilter]);
	}

	private function addLoadListeners():Void
	{
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadSelect);
		_file.addEventListener(Event.COMPLETE, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
	}

	private function removeLoadListeners():Void
	{
		_file.removeEventListener(Event.SELECT, onLoadSelect);
		_file.removeEventListener(Event.COMPLETE, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
	}

	/**
	 * Called when a file has been selected.
	 */
	private function onLoadSelect(e:Event):Void
	{
		try
		{
			_file.load();
		}
		catch (e:Exception)
		{
			removeLoadListeners();
			Debug.logError('Error loading file:\n${e.message}');
		}
	}

	/**
	 * Called when the file has finished loading.
	 */
	private function onLoadComplete(e:Event):Void
	{
		try
		{
			var jsonString:String = _file.data.toString();
			var loadedChar:DialogueCharacterDef = Json.parse(jsonString);
			if (loadedChar != null)
			{
				if (loadedChar.dialoguePos != null) // Make sure it's really a dialogue character
				{
					character.jsonFile = loadedChar;
					reloadCharacter();
					reloadAnimationsDropDown();
					updateCharTypeBox();
					updateTextBox();
					reloadText();
					imageInputText.text = character.jsonFile.image;
					scaleStepper.value = character.jsonFile.scale;
					xStepper.value = character.jsonFile.position[0];
					yStepper.value = character.jsonFile.position[1];
					Debug.logTrace('Successfully loaded file: ${_file.name}');
					removeLoadListeners();
					return;
				}
			}
		}
		catch (e:Exception)
		{
			removeLoadListeners();
			Debug.logError('Error loading file:\n${e.message}');
			return;
		}
		removeLoadListeners();
		Debug.logError('Could not load file');
	}

	/**
	 * Called when the load file dialog is cancelled.
	 */
	private function onLoadCancel(e:Event):Void
	{
		removeLoadListeners();
		Debug.logTrace('Cancelled file loading.');
	}

	/**
	 * Called if there is an error while loading the file.
	 */
	private function onLoadError(e:IOErrorEvent):Void
	{
		removeLoadListeners();
		Debug.logError('Error loading file: ${e.text}');
	}

	private function fileSaveDialog():Void
	{
		var data:String = Json.stringify(character.jsonFile, '\t');
		if (data.length > 0)
		{
			data += '\n'; // I like newlines at the ends of files.

			var splitImage:Array<String> = imageInputText.text.trim().split('_');
			var characterName:String = splitImage[0].toLowerCase().replace(' ', '');

			addSaveListeners();
			_file.save(data, Path.withExtension(characterName, Paths.JSON_EXT));
		}
	}

	private function addSaveListeners():Void
	{
		_file = new FileReference();
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
	}

	private function removeSaveListeners():Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called when the file has finished saving.
	 */
	private function onSaveComplete(e:Event):Void
	{
		removeSaveListeners();
		Debug.logTrace('Successfully saved file.');
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	private function onSaveCancel(e:Event):Void
	{
		removeSaveListeners();
		Debug.logTrace('Cancelled file saving.');
	}

	/**
	 * Called if there is an error while saving the file.
	 */
	private function onSaveError(e:IOErrorEvent):Void
	{
		removeSaveListeners();
		Debug.logError('Error saving file: ${e.text}');
	}
}
