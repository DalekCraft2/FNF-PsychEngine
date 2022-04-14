package editors;

import Song.SongMetaData;
import Week.WeekData;
import flash.net.FileFilter;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Json;
import lime.system.Clipboard;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class WeekEditorState extends MusicBeatState
{
	private var txtWeekTitle:FlxText;
	private var bgSprite:FlxSprite;
	private var lock:FlxSprite;
	private var txtTracklist:FlxText;
	private var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	private var weekThing:StoryMenuItem;
	private var missingFileText:FlxText;

	private var weekData:WeekData;

	public function new(?weekData:WeekData)
	{
		super();

		this.weekData = Week.createTemplateWeekData();
		if (weekData != null)
			this.weekData = weekData;
		else
			weekDataName = 'week1';
	}

	override public function create():Void
	{
		super.create();

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, 32);
		txtWeekTitle.setFormat(Paths.font('vcr.ttf'), txtWeekTitle.size, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var uiTexture:FlxAtlasFrames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = Options.save.data.globalAntialiasing;

		weekThing = new StoryMenuItem(0, bgSprite.y + 396, weekDataName);
		weekThing.y += weekThing.height + 20;
		weekThing.antialiasing = Options.save.data.globalAntialiasing;
		add(weekThing);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup();

		lock = new FlxSprite();
		lock.frames = uiTexture;
		lock.animation.addByPrefix('lock', 'lock');
		lock.animation.play('lock');
		lock.antialiasing = Options.save.data.globalAntialiasing;
		add(lock);

		missingFileText = new FlxText(0, 0, FlxG.width, 24);
		missingFileText.setFormat(Paths.font('vcr.ttf'), missingFileText.size, CENTER, OUTLINE, FlxColor.BLACK);
		missingFileText.borderSize = 2;
		missingFileText.visible = false;
		add(missingFileText);

		var charArray:Array<String> = weekData.weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 435).loadGraphic(Paths.getGraphic('Menu_Tracks'));
		tracksSprite.antialiasing = Options.save.data.globalAntialiasing;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font('vcr.ttf');
		txtTracklist.color = 0xFFE55777;
		add(txtTracklist);
		add(txtWeekTitle);

		addEditorBox();
		reloadAllShit();

		FlxG.mouse.visible = true;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (loadedWeek != null)
		{
			weekData = loadedWeek;
			loadedWeek = null;

			reloadAllShit();
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
		}

		lock.y = weekThing.y;
		missingFileText.y = weekThing.y + 36;
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == weekDataInputText)
			{
				weekDataName = weekDataInputText.text.trim();
				reloadWeekThing();
			}
			else if (sender == opponentInputText || sender == boyfriendInputText || sender == girlfriendInputText)
			{
				weekData.weekCharacters[0] = opponentInputText.text.trim();
				weekData.weekCharacters[1] = boyfriendInputText.text.trim();
				weekData.weekCharacters[2] = girlfriendInputText.text.trim();
				updateText();
			}
			else if (sender == backgroundInputText)
			{
				weekData.weekBackground = backgroundInputText.text.trim();
				reloadBG();
			}
			else if (sender == displayNameInputText)
			{
				weekData.storyName = displayNameInputText.text.trim();
				updateText();
			}
			else if (sender == weekNameInputText)
			{
				weekData.weekName = weekNameInputText.text.trim();
			}
			else if (sender == songsInputText)
			{
				var splitText:Array<String> = songsInputText.text.trim().split(',');
				for (i in 0...splitText.length)
				{
					splitText[i] = splitText[i].trim();
				}

				while (splitText.length < weekData.songs.length)
				{
					weekData.songs.pop();
				}

				for (i in 0...splitText.length)
				{
					if (i >= weekData.songs.length)
					{ // Add new song
						weekData.songs.push(splitText[i]);
					}
					else
					{ // Edit song
						weekData.songs[i] = splitText[i];
						// if (weekData.songs[i][1] == null || weekData.songs[i][1])
						// {
						// 	weekData.songs[i][1] = 'dad';
						// 	weekData.songs[i][2] = [146, 113, 253];
						// }
					}
				}
				updateText();
			}
			else if (sender == weekBeforeInputText)
			{
				weekData.weekBefore = weekBeforeInputText.text.trim();
			}
			else if (sender == difficultiesInputText)
			{
				var splitText:Array<String> = difficultiesInputText.text.trim().split(',');
				for (i in 0...splitText.length)
				{
					splitText[i] = splitText[i].trim();
				}

				while (splitText.length < weekData.difficulties.length)
				{
					weekData.difficulties.pop();
				}

				for (i in 0...splitText.length)
				{
					if (i >= weekData.difficulties.length)
					{ // Add new difficulty
						weekData.difficulties.push(splitText[i]);
					}
					else
					{ // Edit difficulty
						weekData.difficulties[i] = splitText[i];
					}
				}
				updateText();
			}
		}
	}

	private var UI_box:FlxUITabMenu;
	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];

	private function addEditorBox():Void
	{
		var tabs:Array<{name:String, label:String}> = [{name: 'Week', label: 'Week'}, {name: 'Other', label: 'Other'},];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 375);
		UI_box.x = FlxG.width - UI_box.width;
		UI_box.y = FlxG.height - UI_box.height;
		UI_box.scrollFactor.set();
		addWeekUI();
		addOtherUI();

		UI_box.selected_tab_id = 'Week';
		add(UI_box);

		var loadWeekButton:FlxButton = new FlxButton(0, 650, 'Load Week', () ->
		{
			loadWeek();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);

		var freeplayButton:FlxButton = new FlxButton(0, 650, 'Freeplay', () ->
		{
			FlxG.switchState(new WeekEditorFreeplayState(weekData));
		});
		freeplayButton.screenCenter(X);
		add(freeplayButton);

		var saveWeekButton:FlxButton = new FlxButton(0, 650, 'Save Week', () ->
		{
			saveWeek(weekData);
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	private var songsInputText:FlxUIInputText;
	private var backgroundInputText:FlxUIInputText;
	private var displayNameInputText:FlxUIInputText;
	private var weekNameInputText:FlxUIInputText;
	private var weekDataInputText:FlxUIInputText;

	private var opponentInputText:FlxUIInputText;
	private var boyfriendInputText:FlxUIInputText;
	private var girlfriendInputText:FlxUIInputText;

	private var hideCheckbox:FlxUICheckBox;

	public static var weekDataName:String = 'week1';

	private function addWeekUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_box);
		tabGroup.name = 'Week';

		songsInputText = new FlxUIInputText(10, 30, 200, 8);
		blockPressWhileTypingOn.push(songsInputText);

		opponentInputText = new FlxUIInputText(10, songsInputText.y + 40, 70, 8);
		blockPressWhileTypingOn.push(opponentInputText);
		boyfriendInputText = new FlxUIInputText(opponentInputText.x + 75, opponentInputText.y, 70, 8);
		blockPressWhileTypingOn.push(boyfriendInputText);
		girlfriendInputText = new FlxUIInputText(boyfriendInputText.x + 75, opponentInputText.y, 70, 8);
		blockPressWhileTypingOn.push(girlfriendInputText);

		backgroundInputText = new FlxUIInputText(10, opponentInputText.y + 40, 120, 8);
		blockPressWhileTypingOn.push(backgroundInputText);

		displayNameInputText = new FlxUIInputText(10, backgroundInputText.y + 60, 200, 8);
		blockPressWhileTypingOn.push(backgroundInputText);

		weekNameInputText = new FlxUIInputText(10, displayNameInputText.y + 60, 150, 8);
		blockPressWhileTypingOn.push(weekNameInputText);

		weekDataInputText = new FlxUIInputText(10, weekNameInputText.y + 40, 100, 8);
		blockPressWhileTypingOn.push(weekDataInputText);
		reloadWeekThing();

		hideCheckbox = new FlxUICheckBox(10, weekDataInputText.y + 40, null, null, 'Hide Week from Story Mode?', 100);
		hideCheckbox.callback = () ->
		{
			weekData.hideStoryMode = hideCheckbox.checked;
		};

		tabGroup.add(new FlxText(songsInputText.x, songsInputText.y - 18, 0, 'Songs:'));
		tabGroup.add(new FlxText(opponentInputText.x, opponentInputText.y - 18, 0, 'Characters:'));
		tabGroup.add(new FlxText(backgroundInputText.x, backgroundInputText.y - 18, 0, 'Background Asset:'));
		tabGroup.add(new FlxText(displayNameInputText.x, displayNameInputText.y - 18, 0, 'Display Name:'));
		tabGroup.add(new FlxText(weekNameInputText.x, weekNameInputText.y - 18, 0, 'Week Name (for Reset Score Menu):'));
		tabGroup.add(new FlxText(weekDataInputText.x, weekDataInputText.y - 18, 0, 'Week File:'));

		tabGroup.add(songsInputText);
		tabGroup.add(opponentInputText);
		tabGroup.add(boyfriendInputText);
		tabGroup.add(girlfriendInputText);
		tabGroup.add(backgroundInputText);

		tabGroup.add(displayNameInputText);
		tabGroup.add(weekNameInputText);
		tabGroup.add(weekDataInputText);
		tabGroup.add(hideCheckbox);
		UI_box.addGroup(tabGroup);
	}

	private var weekBeforeInputText:FlxUIInputText;
	private var difficultiesInputText:FlxUIInputText;
	private var lockedCheckbox:FlxUICheckBox;
	private var hiddenUntilUnlockCheckbox:FlxUICheckBox;

	private function addOtherUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_box);
		tabGroup.name = 'Other';

		lockedCheckbox = new FlxUICheckBox(10, 30, null, null, 'Week starts Locked', 100);
		lockedCheckbox.callback = () ->
		{
			weekData.startUnlocked = !lockedCheckbox.checked;
			lock.visible = lockedCheckbox.checked;
			hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);
		};

		hiddenUntilUnlockCheckbox = new FlxUICheckBox(10, lockedCheckbox.y + 25, null, null, 'Hidden until Unlocked', 110);
		hiddenUntilUnlockCheckbox.callback = () ->
		{
			weekData.hiddenUntilUnlocked = hiddenUntilUnlockCheckbox.checked;
		};
		hiddenUntilUnlockCheckbox.alpha = 0.4;

		weekBeforeInputText = new FlxUIInputText(10, hiddenUntilUnlockCheckbox.y + 55, 100, 8);
		blockPressWhileTypingOn.push(weekBeforeInputText);

		difficultiesInputText = new FlxUIInputText(10, weekBeforeInputText.y + 60, 200, 8);
		blockPressWhileTypingOn.push(difficultiesInputText);

		tabGroup.add(new FlxText(weekBeforeInputText.x, weekBeforeInputText.y - 28, 0, 'Week File name of the Week you have\nto finish for Unlocking:'));
		tabGroup.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y - 20, 0, 'Difficulties:'));
		tabGroup.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y + 20, 0, 'Default difficulties are "Easy, Normal, Hard"\nwithout quotes.'));
		tabGroup.add(weekBeforeInputText);
		tabGroup.add(difficultiesInputText);
		tabGroup.add(hiddenUntilUnlockCheckbox);
		tabGroup.add(lockedCheckbox);
		UI_box.addGroup(tabGroup);
	}

	// Used on onCreate and when you load a week
	private function reloadAllShit():Void
	{
		var weekString:String = weekData.songs[0];
		for (i in 1...weekData.songs.length)
		{
			weekString += ', ${weekData.songs[i]}';
		}
		songsInputText.text = weekString;
		backgroundInputText.text = weekData.weekBackground;
		displayNameInputText.text = weekData.storyName;
		weekNameInputText.text = weekData.weekName;
		weekDataInputText.text = weekDataName;

		opponentInputText.text = weekData.weekCharacters[0];
		boyfriendInputText.text = weekData.weekCharacters[1];
		girlfriendInputText.text = weekData.weekCharacters[2];

		hideCheckbox.checked = weekData.hideStoryMode;

		weekBeforeInputText.text = weekData.weekBefore;

		if (weekData.difficulties != null && weekData.difficulties.length > 0)
		{
			var difficultiesString:String = weekData.difficulties[0];
			for (i in 1...weekData.difficulties.length)
			{
				difficultiesString += ', ${weekData.difficulties[i]}';
			}
			difficultiesInputText.text = difficultiesString;
		}
		else
		{
			difficultiesInputText.text = '';
		}

		lockedCheckbox.checked = !weekData.startUnlocked;
		lock.visible = lockedCheckbox.checked;

		hiddenUntilUnlockCheckbox.checked = weekData.hiddenUntilUnlocked;
		hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);

		reloadBG();
		reloadWeekThing();
		updateText();
	}

	private function updateText():Void
	{
		for (i in 0...grpWeekCharacters.length)
		{
			grpWeekCharacters.members[i].changeCharacter(weekData.weekCharacters[i]);
		}

		var stringThing:Array<String> = [];
		for (songId in weekData.songs)
		{
			var songMetaData:SongMetaData = Song.getSongMetaData(songId);
			stringThing.push(songMetaData.name);
		}

		txtTracklist.text = '';
		for (song in stringThing)
		{
			txtTracklist.text += '$song\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		txtWeekTitle.text = weekData.storyName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);
	}

	private function reloadBG():Void
	{
		bgSprite.visible = true;
		var assetName:String = weekData.weekBackground;

		var isMissing:Bool = true;
		if (assetName != null && assetName.length > 0)
		{
			var graphic:FlxGraphic = Paths.getGraphic('menubackgrounds/menu_$assetName');
			if (graphic != null)
			{
				bgSprite.loadGraphic(graphic);
				isMissing = false;
			}
		}

		if (isMissing)
		{
			bgSprite.visible = false;
		}
	}

	private function reloadWeekThing():Void
	{
		weekThing.visible = true;
		missingFileText.visible = false;
		var assetName:String = weekDataInputText.text.trim();

		var isMissing:Bool = true;
		if (assetName != null && assetName.length > 0)
		{
			var graphic:FlxGraphic = Paths.getGraphic('storymenu/$assetName');
			if (graphic != null)
			{
				weekThing.loadGraphic(graphic);
				isMissing = false;
			}
		}

		if (isMissing)
		{
			weekThing.visible = false;
			missingFileText.visible = true;
			missingFileText.text = 'MISSING FILE: images/storymenu/$assetName.png';
		}
		recalculateStuffPosition();

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Week Editor', 'Editing: $weekDataName');
		#end
	}

	private function recalculateStuffPosition():Void
	{
		weekThing.screenCenter(X);
		lock.x = weekThing.width + 10 + weekThing.x;
	}

	private static var _file:FileReference;
	public static var loadedWeek:WeekData;

	public static function loadWeek():Void
	{
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse([jsonFilter]);
	}

	private static function onLoadComplete(e:Event):Void
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
			loadedWeek = Paths.getJsonDirect(fullPath);
			if (loadedWeek != null)
			{
				if (loadedWeek.weekCharacters != null && loadedWeek.weekName != null) // Make sure it's really a week
				{
					var cutName:String = _file.name.substr(0, _file.name.length - 5);
					Debug.logTrace('Successfully loaded file: $cutName');

					weekDataName = cutName;
					_file = null;
					return;
				}
			}
		}
		loadedWeek = null;
		_file = null;
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	private static function onLoadCancel(e:Event):Void
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
	private static function onLoadError(e:IOErrorEvent):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		Debug.logError('Problem loading file');
	}

	public static function saveWeek(weekData:WeekData):Void
	{
		var data:String = Json.stringify(weekData, '\t');
		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, '$weekDataName.json');
		}
	}

	private static function onSaveComplete(e:Event):Void
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
	private static function onSaveCancel(e:Event):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	private static function onSaveError(e:IOErrorEvent):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		Debug.logError('Problem saving file');
	}
}

class WeekEditorFreeplayState extends MusicBeatState
{
	private var weekData:WeekData;

	public function new(?weekData:WeekData)
	{
		super();

		this.weekData = Week.createTemplateWeekData();
		if (weekData != null)
			this.weekData = weekData;
	}

	private var bg:FlxSprite;
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<HealthIcon> = [];

	private var curSelected:Int = 0;

	override public function create():Void
	{
		super.create();

		bg = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		bg.antialiasing = Options.save.data.globalAntialiasing;

		bg.color = FlxColor.WHITE;
		add(bg);

		grpSongs = new FlxTypedGroup();
		add(grpSongs);

		for (i in 0...weekData.songs.length)
		{
			var songMetaData:SongMetaData = Song.getSongMetaData(weekData.songs[i]);
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songMetaData.name, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(songMetaData.icon);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);
		}

		addEditorBox();
		changeSelection();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (WeekEditorState.loadedWeek != null)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new WeekEditorFreeplayState(WeekEditorState.loadedWeek));
			WeekEditorState.loadedWeek = null;
			return;
		}

		if (iconInputText.hasFocus)
		{
			FlxG.sound.muteKeys = [];
			FlxG.sound.volumeDownKeys = [];
			FlxG.sound.volumeUpKeys = [];
			if (FlxG.keys.justPressed.ENTER)
			{
				iconInputText.hasFocus = false;
			}
		}
		else
		{
			FlxG.sound.muteKeys = InitState.muteKeys;
			FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;
			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.switchState(new editors.MasterEditorMenu());
			}

			if (controls.UI_UP_P)
				changeSelection(-1);
			if (controls.UI_DOWN_P)
				changeSelection(1);
		}
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			var songMetaData:SongMetaData = Song.getSongMetaData(weekData.songs[curSelected]);
			songMetaData.icon = iconInputText.text;
			iconArray[curSelected].changeIcon(iconInputText.text);
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			if (sender == bgColorStepperR || sender == bgColorStepperG || sender == bgColorStepperB)
			{
				updateBG();
			}
		}
	}

	private var UI_box:FlxUITabMenu;
	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];

	private function addEditorBox():Void
	{
		var tabs:Array<{name:String, label:String}> = [{name: 'Freeplay', label: 'Freeplay'},];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 200);
		UI_box.x = FlxG.width - UI_box.width - 100;
		UI_box.y = FlxG.height - UI_box.height - 60;
		UI_box.scrollFactor.set();

		UI_box.selected_tab_id = 'Week';
		addFreeplayUI();
		add(UI_box);

		var blackBlack:FlxSprite = new FlxSprite(0, 670).makeGraphic(FlxG.width, 50, FlxColor.BLACK);
		blackBlack.alpha = 0.6;
		add(blackBlack);

		var loadWeekButton:FlxButton = new FlxButton(0, 685, 'Load Week', () ->
		{
			WeekEditorState.loadWeek();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);

		var storyModeButton:FlxButton = new FlxButton(0, 685, 'Story Mode', () ->
		{
			FlxG.switchState(new WeekEditorState(weekData));
		});
		storyModeButton.screenCenter(X);
		add(storyModeButton);

		var saveWeekButton:FlxButton = new FlxButton(0, 685, 'Save Week', () ->
		{
			WeekEditorState.saveWeek(weekData);
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	private var bgColorStepperR:FlxUINumericStepper;
	private var bgColorStepperG:FlxUINumericStepper;
	private var bgColorStepperB:FlxUINumericStepper;
	private var iconInputText:FlxUIInputText;

	private function addFreeplayUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_box);
		tabGroup.name = 'Freeplay';

		bgColorStepperR = new FlxUINumericStepper(10, 40, 20, 255, 0, 255, 0);
		bgColorStepperG = new FlxUINumericStepper(80, 40, 20, 255, 0, 255, 0);
		bgColorStepperB = new FlxUINumericStepper(150, 40, 20, 255, 0, 255, 0);

		var copyColor:FlxButton = new FlxButton(10, bgColorStepperR.y + 25, 'Copy Color', () ->
		{
			Clipboard.text = '${bg.color.red},${bg.color.green},${bg.color.blue}';
		});
		var pasteColor:FlxButton = new FlxButton(140, copyColor.y, 'Paste Color', () ->
		{
			if (Clipboard.text != null)
			{
				var leColor:Array<Int> = [];
				var splitStrings:Array<String> = Clipboard.text.trim().split(',');
				for (splitString in splitStrings)
				{
					var toPush:Int = Std.parseInt(splitString);
					if (!Math.isNaN(toPush))
					{
						if (toPush > 255)
							toPush = 255;
						else if (toPush < 0)
							toPush *= -1;
						leColor.push(toPush);
					}
				}

				if (leColor.length > 2)
				{
					bgColorStepperR.value = leColor[0];
					bgColorStepperG.value = leColor[1];
					bgColorStepperB.value = leColor[2];
					updateBG();
				}
			}
		});

		iconInputText = new FlxUIInputText(10, bgColorStepperR.y + 70, 100, 8);

		var hideFreeplayCheckbox:FlxUICheckBox = new FlxUICheckBox(10, iconInputText.y + 30, null, null, 'Hide Week from Freeplay?', 100);
		hideFreeplayCheckbox.checked = weekData.hideFreeplay;
		hideFreeplayCheckbox.callback = () ->
		{
			weekData.hideFreeplay = hideFreeplayCheckbox.checked;
		};

		tabGroup.add(new FlxText(10, bgColorStepperR.y - 18, 0, 'Selected background Color R/G/B:'));
		tabGroup.add(new FlxText(10, iconInputText.y - 18, 0, 'Selected icon:'));
		tabGroup.add(bgColorStepperR);
		tabGroup.add(bgColorStepperG);
		tabGroup.add(bgColorStepperB);
		tabGroup.add(copyColor);
		tabGroup.add(pasteColor);
		tabGroup.add(iconInputText);
		tabGroup.add(hideFreeplayCheckbox);
		UI_box.addGroup(tabGroup);
	}

	private function updateBG():Void
	{
		var red:Int = Math.round(bgColorStepperR.value);
		var green:Int = Math.round(bgColorStepperG.value);
		var blue:Int = Math.round(bgColorStepperB.value);
		var color:FlxColor = FlxColor.fromRGB(red, green, blue);
		// TODO Note that this actually does nothing to the meta yet, so I need to make an editor for it
		var songMetaData:SongMetaData = Song.getSongMetaData(weekData.songs[curSelected]);
		songMetaData.color[0] = red;
		songMetaData.color[1] = green;
		songMetaData.color[2] = blue;
		bg.color = color;
	}

	private function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = weekData.songs.length - 1;
		if (curSelected >= weekData.songs.length)
			curSelected = 0;

		var bullShit:Int = 0;
		for (icon in iconArray)
		{
			icon.alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		Debug.logTrace(weekData.songs[curSelected]);
		// TODO Try to minimize the usage of this method for performance
		var songMetaData:SongMetaData = Song.getSongMetaData(weekData.songs[curSelected]);
		iconInputText.text = songMetaData.icon;
		bgColorStepperR.value = Math.round(songMetaData.color[0]);
		bgColorStepperG.value = Math.round(songMetaData.color[1]);
		bgColorStepperB.value = Math.round(songMetaData.color[2]);
		updateBG();
	}
}
