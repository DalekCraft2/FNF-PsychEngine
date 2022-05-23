package editors;

import DialogueBoxPsych.DialogueAnimationDef;
import DialogueBoxPsych.DialogueCharacter;
import DialogueBoxPsych.DialogueDef;
import DialogueBoxPsych.DialogueLineDef;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
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

class DialogueEditorState extends MusicBeatState
{
	private static inline final DEFAULT_TEXT:String = 'Lorem ipsum dolor sit amet';
	private static inline final DEFAULT_BOXSTATE:String = 'normal';
	private static inline final DEFAULT_SPEED:Float = 0.05;

	private var character:DialogueCharacter;
	private var box:FlxSprite;
	private var text:Alphabet;

	private var selectedText:FlxText;
	private var animText:FlxText;

	private var dialogueFile:DialogueDef;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		FlxG.camera.bgColor = FlxColor.fromHSL(0, 0, 0.5);

		dialogueFile = {
			dialogue: [createTemplateDialogueLine()]
		};

		character = new DialogueCharacter();
		character.scrollFactor.set();
		add(character);

		box = new FlxSprite(70, 370);
		box.frames = Paths.getSparrowAtlas('speech_bubble');
		box.scrollFactor.set();
		box.antialiasing = Options.save.data.globalAntialiasing;
		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('angry', 'AHH speech bubble', 24);
		box.animation.addByPrefix('center', 'speech bubble middle', 24);
		box.animation.addByPrefix('center-angry', 'AHH Speech Bubble middle', 24);
		box.animation.play('normal', true);
		box.setGraphicSize(Std.int(box.width * 0.9));
		box.updateHitbox();
		add(box);

		addEditorBox();
		FlxG.mouse.visible = true;

		var addLineText:FlxText = new FlxText(10, 10, FlxG.width - 20,
			'Press O to remove the current dialogue line, Press P to add another line after the current one.', 16);
		addLineText.setFormat(Paths.font('vcr.ttf'), addLineText.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		addLineText.scrollFactor.set();
		add(addLineText);

		selectedText = new FlxText(10, 32, FlxG.width - 20, 24);
		selectedText.setFormat(Paths.font('vcr.ttf'), selectedText.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		selectedText.scrollFactor.set();
		add(selectedText);

		animText = new FlxText(10, 62, FlxG.width - 20, 24);
		animText.setFormat(Paths.font('vcr.ttf'), animText.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		animText.scrollFactor.set();
		add(animText);
		changeText();
	}

	private var curSelected:Int = 0;
	private var curAnim:Int = 0;
	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
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
				if (character.animationIsLoop() && character.animation.curAnim.finished)
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
				{
					if (inputText == lineInputText)
					{
						inputText.text += '\\n';
						inputText.caretIndex += 2;
					}
					else
					{
						inputText.hasFocus = false;
					}
				}
				break;
			}
		}

		if (!blockInput)
		{
			FlxG.sound.muteKeys = InitState.muteKeys;
			FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;
			if (FlxG.keys.justPressed.SPACE)
			{
				reloadText(speedStepper.value);
			}
			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.switchState(new MasterEditorMenuState());
				transitioning = true;
			}
			var negaMult:Array<Int> = [1, -1];
			var controlAnim:Array<Bool> = [FlxG.keys.justPressed.W, FlxG.keys.justPressed.S];
			var controlText:Array<Bool> = [FlxG.keys.justPressed.D, FlxG.keys.justPressed.A];
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
						dialogueFile.dialogue[curSelected].expression = animToPlay;
					}
					animText.text = 'Animation: $animToPlay (${(curAnim + 1)} / ${character.jsonFile.animations.length}) - Press W or S to scroll';
				}
				if (controlText[i])
				{
					changeText(negaMult[i]);
				}
			}

			if (FlxG.keys.justPressed.O)
			{
				dialogueFile.dialogue.remove(dialogueFile.dialogue[curSelected]);
				if (dialogueFile.dialogue.length < 1) // You deleted everything, dumbo!
				{
					dialogueFile.dialogue = [createTemplateDialogueLine()];
				}
				changeText();
			}
			else if (FlxG.keys.justPressed.P)
			{
				dialogueFile.dialogue.insert(curSelected + 1, createTemplateDialogueLine());
				changeText(1);
			}
		}
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == characterInputText)
			{
				character.reloadCharacterJson(characterInputText.text);
				reloadCharacter();
				updateTextBox();

				if (character.jsonFile.animations.length > 0)
				{
					curAnim = 0;
					if (character.jsonFile.animations.length > curAnim && character.jsonFile.animations[curAnim] != null)
					{
						character.playAnim(character.jsonFile.animations[curAnim].anim, text.finishedText);
						animText.text = 'Animation: ${character.jsonFile.animations[curAnim].anim} (${curAnim + 1} / ${character.jsonFile.animations.length}) - Press W or S to scroll';
					}
					else
					{
						animText.text = 'ERROR! NO ANIMATIONS FOUND';
					}
					characterAnimSpeed();
				}
				dialogueFile.dialogue[curSelected].portrait = characterInputText.text;
			}
			else if (sender == lineInputText)
			{
				reloadText(0);
				dialogueFile.dialogue[curSelected].text = lineInputText.text;
			}
			else if (sender == soundInputText)
			{
				dialogueFile.dialogue[curSelected].sound = soundInputText.text;
				reloadText(0);
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender == speedStepper))
		{
			reloadText(speedStepper.value);
			dialogueFile.dialogue[curSelected].speed = speedStepper.value;
			if (Math.isNaN(dialogueFile.dialogue[curSelected].speed)
				|| dialogueFile.dialogue[curSelected].speed == null
				|| dialogueFile.dialogue[curSelected].speed < 0.001)
			{
				dialogueFile.dialogue[curSelected].speed = 0.0;
			}
		}
	}

	private var UI_box:FlxUITabMenu;

	private function addEditorBox():Void
	{
		var tabs:Array<{name:String, label:String}> = [{name: 'Dialogue Line', label: 'Dialogue Line'}];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 210);
		UI_box.x = FlxG.width - UI_box.width - 10;
		UI_box.y = 10;
		UI_box.scrollFactor.set();
		// FIXME There's some bug here where clicking a not-fully-opaque UI Tab will make its members become more transparent
		// UI_box.alpha = 0.8;
		addDialogueLineUI();
		add(UI_box);
	}

	private var characterInputText:FlxUIInputText;
	private var lineInputText:FlxUIInputText;
	private var angryCheckbox:FlxUICheckBox;
	private var speedStepper:FlxUINumericStepper;
	private var soundInputText:FlxUIInputText;

	private function addDialogueLineUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_box);
		tabGroup.name = 'Dialogue Line';

		characterInputText = new FlxUIInputText(10, 20, 80, DialogueCharacter.DEFAULT_CHARACTER, 8);
		blockPressWhileTypingOn.push(characterInputText);

		speedStepper = new FlxUINumericStepper(10, characterInputText.y + 40, 0.005, DEFAULT_SPEED, 0, 0.5, 3);

		angryCheckbox = new FlxUICheckBox(speedStepper.x + 120, speedStepper.y, null, null, 'Angry Textbox', 200);
		angryCheckbox.callback = () ->
		{
			updateTextBox();
			dialogueFile.dialogue[curSelected].boxState = (angryCheckbox.checked ? 'angry' : 'normal');
		};

		soundInputText = new FlxUIInputText(10, speedStepper.y + 40, 150, 8);
		blockPressWhileTypingOn.push(soundInputText);

		lineInputText = new FlxUIInputText(10, soundInputText.y + 35, 200, DEFAULT_TEXT, 8);
		blockPressWhileTypingOn.push(lineInputText);

		var loadButton:FlxButton = new FlxButton(20, lineInputText.y + 25, 'Load Dialogue', () ->
		{
			fileBrowseDialog();
		});
		var saveButton:FlxButton = new FlxButton(loadButton.x + 120, loadButton.y, 'Save Dialogue', () ->
		{
			fileSaveDialog();
		});

		tabGroup.add(new FlxText(10, speedStepper.y - 18, 0, 'Interval/Speed (ms):'));
		tabGroup.add(new FlxText(10, characterInputText.y - 18, 0, 'Character:'));
		tabGroup.add(new FlxText(10, soundInputText.y - 18, 0, 'Sound file name:'));
		tabGroup.add(new FlxText(10, lineInputText.y - 18, 0, 'Text:'));
		tabGroup.add(characterInputText);
		tabGroup.add(angryCheckbox);
		tabGroup.add(speedStepper);
		tabGroup.add(soundInputText);
		tabGroup.add(lineInputText);
		tabGroup.add(loadButton);
		tabGroup.add(saveButton);
		UI_box.addGroup(tabGroup);
	}

	private static function createTemplateDialogueLine():DialogueLineDef
	{
		var dialogueLine:DialogueLineDef = {
			portrait: DialogueCharacter.DEFAULT_CHARACTER,
			expression: 'talk',
			text: DEFAULT_TEXT,
			boxState: DEFAULT_BOXSTATE,
			speed: DEFAULT_SPEED,
			sound: ''
		};
		return dialogueLine;
	}

	private function updateTextBox():Void
	{
		box.flipX = false;
		var isAngry:Bool = angryCheckbox.checked;
		var anim:String = isAngry ? 'angry' : 'normal';

		switch (character.jsonFile.dialoguePos)
		{
			case 'left':
				box.flipX = true;
			case 'center':
				if (isAngry)
				{
					anim = 'center-angry';
				}
				else
				{
					anim = 'center';
				}
		}
		box.animation.play(anim, true);
		DialogueBoxPsych.updateBoxOffsets(box);
	}

	private function reloadCharacter():Void
	{
		character.frames = Paths.getSparrowAtlas(Path.join(['dialogue', character.jsonFile.image]));
		character.jsonFile = character.jsonFile;
		character.reloadAnimations();
		character.setGraphicSize(Std.int(character.width * DialogueCharacter.DEFAULT_SCALE * character.jsonFile.scale));
		character.updateHitbox();
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
		character.x += character.jsonFile.position[0];
		character.y += character.jsonFile.position[1];
		character.playAnim(); // Plays random animation
		characterAnimSpeed();

		if (character.animation.curAnim != null)
		{
			animText.text = 'Animation: ${character.jsonFile.animations[curAnim].anim} (${curAnim + 1} / ${character.jsonFile.animations.length}) - Press W or S to scroll';
		}
		else
		{
			animText.text = 'ERROR! NO ANIMATIONS FOUND';
		}
	}

	private function reloadText(speed:Float = DEFAULT_SPEED):Void
	{
		if (text != null)
		{
			text.killTheTimer();
			text.kill();
			remove(text);
			text.destroy();
		}

		if (Math.isNaN(speed) || speed < 0.001)
			speed = 0.0;

		var textToType:String = lineInputText.text;
		if (textToType == null || textToType.length < 1)
			textToType = ' ';

		Alphabet.setDialogueSound(soundInputText.text);
		text = new Alphabet(DialogueBoxPsych.DEFAULT_TEXT_X, DialogueBoxPsych.DEFAULT_TEXT_Y, textToType, false, true, speed, 0.7);
		add(text);

		if (speed > 0)
		{
			if (character.jsonFile.animations.length > curAnim && character.jsonFile.animations[curAnim] != null)
			{
				character.playAnim(character.jsonFile.animations[curAnim].anim);
			}
			characterAnimSpeed();
		}

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		var rpcText:String = lineInputText.text;
		if (rpcText == null || rpcText.length < 1)
			rpcText = '(Empty)';
		// TODO This is still an error, and the Discord RPC Haxe library is sort of old, so maybe I should switch to Haxicord
		if (rpcText.length < 3)
			rpcText += '  '; // Fixes a bug on RPC that triggers an error when the text is too short
		DiscordClient.changePresence('Dialogue Editor', rpcText);
		#end
	}

	private function changeText(add:Int = 0):Void
	{
		curSelected += add;
		if (curSelected < 0)
			curSelected = dialogueFile.dialogue.length - 1;
		else if (curSelected >= dialogueFile.dialogue.length)
			curSelected = 0;

		var curDialogue:DialogueLineDef = dialogueFile.dialogue[curSelected];
		characterInputText.text = curDialogue.portrait;
		lineInputText.text = curDialogue.text;
		angryCheckbox.checked = (curDialogue.boxState == 'angry');
		speedStepper.value = curDialogue.speed;

		curAnim = 0;
		character.reloadCharacterJson(characterInputText.text);
		reloadCharacter();
		updateTextBox();
		reloadText(curDialogue.speed);

		var animsLength:Int = character.jsonFile.animations.length;
		if (animsLength > 0)
		{
			for (i in 0...animsLength)
			{
				var animation:DialogueAnimationDef = character.jsonFile.animations[i];
				if (animation != null && animation.anim == curDialogue.expression)
				{
					curAnim = i;
					break;
				}
			}
			character.playAnim(character.jsonFile.animations[curAnim].anim, text.finishedText);
			animText.text = 'Animation: ${character.jsonFile.animations[curAnim].anim} (${(curAnim + 1)} / $animsLength) - Press W or S to scroll';
		}
		else
		{
			animText.text = 'ERROR! NO ANIMATIONS FOUND';
		}
		characterAnimSpeed();

		selectedText.text = 'Line: (${curSelected + 1} / ${dialogueFile.dialogue.length}) - Press A or D to scroll';
	}

	private function characterAnimSpeed():Void
	{
		if (character.animation.curAnim != null)
		{
			var speed:Float = speedStepper.value;
			var rate:Float = 24 - (((speed - DEFAULT_SPEED) / 5) * 480);
			if (rate < 12)
				rate = 12;
			else if (rate > 48)
				rate = 48;
			character.animation.curAnim.frameRate = rate;
		}
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
			var loadedDialog:DialogueDef = Json.parse(jsonString);
			if (loadedDialog != null)
			{
				if (loadedDialog.dialogue != null && loadedDialog.dialogue.length > 0) // Make sure it's really a dialogue file
				{
					dialogueFile = loadedDialog;
					changeText();
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
		var data:String = Json.stringify(dialogueFile, '\t');
		if (data.length > 0)
		{
			data += '\n'; // I like newlines at the ends of files.
			addSaveListeners();
			_file.save(data, Path.withExtension('dialogue', Paths.JSON_EXT));
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
