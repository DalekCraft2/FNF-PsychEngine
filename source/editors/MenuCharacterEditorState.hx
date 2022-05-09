package editors;

import MenuCharacter.MenuCharacterDef;
import flash.net.FileFilter;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import haxe.Json;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class MenuCharacterEditorState extends MusicBeatState
{
	private var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	private var characterFile:MenuCharacterDef;
	private var txtOffsets:FlxText;
	private var defaultCharacters:Array<String> = ['dad', 'bf', 'gf'];

	override public function create():Void
	{
		super.create();

		characterFile = {
			image: 'Menu_Dad',
			scale: 1,
			position: [0, 0],
			idleAnim: 'M Dad Idle',
			confirmAnim: 'M Dad Idle',
			flipX: false
		};

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Menu Character Editor', 'Editing: ${characterFile.image}');
		#end

		grpWeekCharacters = new FlxTypedGroup();
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, defaultCharacters[char]);
			weekCharacterThing.y += 70;
			weekCharacterThing.alpha = 0.2;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51));
		add(grpWeekCharacters);

		txtOffsets = new FlxText(20, 10, 0, '[0, 0]', 32);
		txtOffsets.setFormat(Paths.font('vcr.ttf'), txtOffsets.size, CENTER);
		txtOffsets.alpha = 0.7;
		add(txtOffsets);

		var tipText:FlxText = new FlxText(0, 540, FlxG.width,
			'Arrow Keys - Change Offset (Hold shift for 10x speed)\nSpace - Play "Start Press" animation (Boyfriend Character Type)', 16);
		tipText.setFormat(Paths.font('vcr.ttf'), tipText.size, CENTER);
		tipText.scrollFactor.set();
		add(tipText);

		addEditorBox();
		FlxG.mouse.visible = true;
		updateCharTypeBox();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn)
		{
			if (inputText.hasFocus)
			{
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;

				if (FlxG.keys.justPressed.ENTER)
					inputText.hasFocus = false;
				break;
			}
		}

		if (!blockInput)
		{
			FlxG.sound.muteKeys = InitState.muteKeys;
			FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;
			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.switchState(new MasterEditorMenu());
			}

			var shiftMult:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftMult = 10;

			if (FlxG.keys.justPressed.LEFT)
			{
				characterFile.position[0] += shiftMult;
				updateOffset();
			}
			if (FlxG.keys.justPressed.RIGHT)
			{
				characterFile.position[0] -= shiftMult;
				updateOffset();
			}
			if (FlxG.keys.justPressed.UP)
			{
				characterFile.position[1] += shiftMult;
				updateOffset();
			}
			if (FlxG.keys.justPressed.DOWN)
			{
				characterFile.position[1] -= shiftMult;
				updateOffset();
			}

			if (FlxG.keys.justPressed.SPACE && curTypeSelected == 1)
			{
				grpWeekCharacters.members[curTypeSelected].animation.play('confirm', true);
			}
		}

		var char:MenuCharacter = grpWeekCharacters.members[1];
		if (char.animation.curAnim != null && char.animation.curAnim.name == 'confirm' && char.animation.curAnim.finished)
		{
			char.animation.play('idle', true);
		}
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == imageInputText)
			{
				characterFile.image = imageInputText.text;
			}
			else if (sender == idleInputText)
			{
				characterFile.idleAnim = idleInputText.text;
			}
			else if (sender == confirmInputText)
			{
				characterFile.confirmAnim = confirmInputText.text;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			if (sender == scaleStepper)
			{
				characterFile.scale = scaleStepper.value;
				reloadCharacter();
			}
		}
	}

	private var UI_typebox:FlxUITabMenu;
	private var UI_mainbox:FlxUITabMenu;
	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];

	private function addEditorBox():Void
	{
		var tabs:Array<{name:String, label:String}> = [{name: 'Character Type', label: 'Character Type'},];
		UI_typebox = new FlxUITabMenu(null, tabs, true);
		UI_typebox.resize(120, 180);
		UI_typebox.x = 100;
		UI_typebox.y = FlxG.height - UI_typebox.height - 50;
		UI_typebox.scrollFactor.set();
		addTypeUI();
		add(UI_typebox);

		var tabs:Array<{name:String, label:String}> = [{name: 'Character', label: 'Character'},];
		UI_mainbox = new FlxUITabMenu(null, tabs, true);
		UI_mainbox.resize(240, 180);
		UI_mainbox.x = FlxG.width - UI_mainbox.width - 100;
		UI_mainbox.y = FlxG.height - UI_mainbox.height - 50;
		UI_mainbox.scrollFactor.set();
		addCharacterUI();
		add(UI_mainbox);

		var loadButton:FlxButton = new FlxButton(0, 480, 'Load Character', () ->
		{
			loadCharacter();
		});
		loadButton.screenCenter(X);
		loadButton.x -= 60;
		add(loadButton);

		var saveButton:FlxButton = new FlxButton(0, 480, 'Save Character', () ->
		{
			saveCharacter();
		});
		saveButton.screenCenter(X);
		saveButton.x += 60;
		add(saveButton);
	}

	private var opponentCheckbox:FlxUICheckBox;
	private var boyfriendCheckbox:FlxUICheckBox;
	private var girlfriendCheckbox:FlxUICheckBox;
	private var curTypeSelected:Int = 0; // 0 = Dad, 1 = BF, 2 = GF

	private function addTypeUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_typebox);
		tabGroup.name = 'Character Type';

		opponentCheckbox = new FlxUICheckBox(10, 20, null, null, 'Opponent', 100);
		opponentCheckbox.callback = () ->
		{
			curTypeSelected = 0;
			updateCharTypeBox();
		};

		boyfriendCheckbox = new FlxUICheckBox(opponentCheckbox.x, opponentCheckbox.y + 40, null, null, 'Boyfriend', 100);
		boyfriendCheckbox.callback = () ->
		{
			curTypeSelected = 1;
			updateCharTypeBox();
		};

		girlfriendCheckbox = new FlxUICheckBox(boyfriendCheckbox.x, boyfriendCheckbox.y + 40, null, null, 'Girlfriend', 100);
		girlfriendCheckbox.callback = () ->
		{
			curTypeSelected = 2;
			updateCharTypeBox();
		};

		tabGroup.add(opponentCheckbox);
		tabGroup.add(boyfriendCheckbox);
		tabGroup.add(girlfriendCheckbox);
		UI_typebox.addGroup(tabGroup);
	}

	private var imageInputText:FlxUIInputText;
	private var idleInputText:FlxUIInputText;
	private var confirmInputText:FlxUIInputText;
	private var confirmDescText:FlxText;
	private var scaleStepper:FlxUINumericStepper;
	private var flipXCheckbox:FlxUICheckBox;

	private function addCharacterUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_mainbox);
		tabGroup.name = 'Character';

		imageInputText = new FlxUIInputText(10, 20, 80, characterFile.image, 8);
		blockPressWhileTypingOn.push(imageInputText);
		idleInputText = new FlxUIInputText(10, imageInputText.y + 35, 100, characterFile.idleAnim, 8);
		blockPressWhileTypingOn.push(idleInputText);
		confirmInputText = new FlxUIInputText(10, idleInputText.y + 35, 100, characterFile.confirmAnim, 8);
		blockPressWhileTypingOn.push(confirmInputText);

		flipXCheckbox = new FlxUICheckBox(10, confirmInputText.y + 30, null, null, 'Flip X', 100);
		flipXCheckbox.callback = () ->
		{
			grpWeekCharacters.members[curTypeSelected].flipX = flipXCheckbox.checked;
			characterFile.flipX = flipXCheckbox.checked;
		};

		var reloadImageButton:FlxButton = new FlxButton(140, confirmInputText.y + 30, 'Reload Char', () ->
		{
			reloadCharacter();
		});

		scaleStepper = new FlxUINumericStepper(140, imageInputText.y, 0.05, 1, 0.1, 30, 2);

		confirmDescText = new FlxText(10, confirmInputText.y - 18, 0, 'Start Press animation on the .XML:');
		tabGroup.add(new FlxText(10, imageInputText.y - 18, 0, 'Image file name:'));
		tabGroup.add(new FlxText(10, idleInputText.y - 18, 0, 'Idle animation on the .XML:'));
		tabGroup.add(new FlxText(scaleStepper.x, scaleStepper.y - 18, 0, 'Scale:'));
		tabGroup.add(flipXCheckbox);
		tabGroup.add(reloadImageButton);
		tabGroup.add(confirmDescText);
		tabGroup.add(imageInputText);
		tabGroup.add(idleInputText);
		tabGroup.add(confirmInputText);
		tabGroup.add(scaleStepper);
		UI_mainbox.addGroup(tabGroup);
	}

	private function updateCharTypeBox():Void
	{
		opponentCheckbox.checked = false;
		boyfriendCheckbox.checked = false;
		girlfriendCheckbox.checked = false;

		switch (curTypeSelected)
		{
			case 0:
				opponentCheckbox.checked = true;
			case 1:
				boyfriendCheckbox.checked = true;
			case 2:
				girlfriendCheckbox.checked = true;
		}

		updateCharacters();
	}

	private function updateCharacters():Void
	{
		for (i in 0...grpWeekCharacters.length)
		{
			var char:MenuCharacter = grpWeekCharacters.members[i];
			char.alpha = 0.2;
			char.id = '';
			char.changeCharacter(defaultCharacters[i]);
		}
		reloadCharacter();
	}

	private function reloadCharacter():Void
	{
		var char:MenuCharacter = grpWeekCharacters.members[curTypeSelected];

		char.alpha = 1;
		char.frames = Paths.getSparrowAtlas(Path.join(['menucharacters', characterFile.image]));
		char.animation.addByPrefix('idle', characterFile.idleAnim, 24);
		if (curTypeSelected == 1)
			char.animation.addByPrefix('confirm', characterFile.confirmAnim, 24, false);
		char.flipX = characterFile.flipX;

		char.scale.set(characterFile.scale, characterFile.scale);
		char.updateHitbox();
		char.animation.play('idle');

		confirmDescText.visible = (curTypeSelected == 1);
		confirmInputText.visible = (curTypeSelected == 1);
		updateOffset();

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Menu Character Editor', 'Editing: ${characterFile.image}');
		#end
	}

	private function updateOffset():Void
	{
		var char:MenuCharacter = grpWeekCharacters.members[curTypeSelected];
		char.offset.set(characterFile.position[0], characterFile.position[1]);
		txtOffsets.text = Std.string(characterFile.position);
	}

	private var _file:FileReference;

	private function loadCharacter():Void
	{
		var jsonFilter:FileFilter = new FileFilter('JSON', Paths.JSON_EXT);
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse([jsonFilter]);
	}

	private function onLoadComplete(e:Event):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		var fullPath:Null<String> = null;
		@:privateAccess
		if (_file.__path != null)
			fullPath = _file.__path;

		if (fullPath != null)
		{
			var loadedChar:MenuCharacterDef = Paths.getJsonDirect(fullPath);
			if (loadedChar != null)
			{
				if (loadedChar.idleAnim != null && loadedChar.confirmAnim != null) // Make sure it's really a character
				{
					var cutName:String = Path.withoutExtension(_file.name);
					Debug.logTrace('Successfully loaded file: $cutName');
					characterFile = loadedChar;
					reloadCharacter();
					imageInputText.text = characterFile.image;
					idleInputText.text = characterFile.image;
					confirmInputText.text = characterFile.image;
					scaleStepper.value = characterFile.scale;
					updateOffset();
					_file = null;
					return;
				}
			}
		}
		_file = null;
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	private function onLoadCancel(e:Event):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		Debug.logTrace('Cancelled file loading.');
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	private function onLoadError(e:IOErrorEvent):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		Debug.logError('Problem loading file');
	}

	private function saveCharacter():Void
	{
		var data:String = Json.stringify(characterFile, '\t');
		if (data.length > 0)
		{
			var splitImage:Array<String> = imageInputText.text.trim().split('_');
			var characterName:String = splitImage[splitImage.length - 1].toLowerCase().replace(' ', '');

			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, Path.withExtension(characterName, Paths.JSON_EXT));
		}
	}

	private function onSaveComplete(e:Event):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		Debug.logInfo('Successfully saved file.');
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	private function onSaveCancel(e:Event):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	private function onSaveError(e:IOErrorEvent):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		Debug.logError('Problem saving file');
	}
}
