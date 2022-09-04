package states.editors;

import Week.WeekDef;
import chart.container.Song.SongMetadata;
import chart.container.Song.SongMetadataDef;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUITabMenu;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
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

	private var weekDef:WeekDef;

	public function new(?weekDef:WeekDef)
	{
		super();

		this.weekDef = Week.createTemplateWeekDef();
		if (weekDef != null)
			this.weekDef = weekDef;
		else
			weekDefName = 'week1';
	}

	override public function create():Void
	{
		super.create();

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, 32);
		txtWeekTitle.setFormat(Paths.font('vcr.ttf'), txtWeekTitle.size, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var uiTexture:FlxFramesCollection = Paths.getFrames(Path.join(['ui', 'story', 'campaign_menu_UI_assets']));
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = Options.save.data.globalAntialiasing;

		weekThing = new StoryMenuItem(0, bgSprite.y + 396, weekDefName);
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
		missingFileText.setFormat(Paths.font('vcr.ttf'), missingFileText.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		missingFileText.borderSize = 2;
		missingFileText.visible = false;
		add(missingFileText);

		var charArray:Array<String> = weekDef.weekCharacters;
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

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn)
		{
			if (inputText.hasFocus)
			{
				FlxG.sound.muteKeys = null;
				FlxG.sound.volumeDownKeys = null;
				FlxG.sound.volumeUpKeys = null;
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
				FlxG.switchState(new MasterEditorMenuState());
			}
		}

		lock.y = weekThing.y;
		missingFileText.y = weekThing.y + 36;
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == weekDefInputText)
			{
				weekDefName = weekDefInputText.text.trim();
				reloadWeekThing();
			}
			else if (sender == opponentInputText || sender == boyfriendInputText || sender == girlfriendInputText)
			{
				weekDef.weekCharacters[0] = opponentInputText.text.trim();
				weekDef.weekCharacters[1] = boyfriendInputText.text.trim();
				weekDef.weekCharacters[2] = girlfriendInputText.text.trim();
				updateText();
			}
			else if (sender == backgroundInputText)
			{
				weekDef.weekBackground = backgroundInputText.text.trim();
				reloadBG();
			}
			else if (sender == displayNameInputText)
			{
				weekDef.storyName = displayNameInputText.text.trim();
				updateText();
			}
			else if (sender == weekNameInputText)
			{
				weekDef.weekName = weekNameInputText.text.trim();
			}
			else if (sender == songsInputText)
			{
				var splitText:Array<String> = songsInputText.text.trim().split(',');
				for (i in 0...splitText.length)
				{
					splitText[i] = splitText[i].trim();
				}

				while (splitText.length < weekDef.songs.length)
				{
					weekDef.songs.pop();
				}

				for (i in 0...splitText.length)
				{
					if (i >= weekDef.songs.length)
					{ // Add new song
						weekDef.songs.push(splitText[i]);
					}
					else
					{ // Edit song
						weekDef.songs[i] = splitText[i];
						// if (weekDef.songs[i][1] == null || weekDef.songs[i][1])
						// {
						// 	weekDef.songs[i][1] = 'dad';
						// 	weekDef.songs[i][2] = [146, 113, 253];
						// }
					}
				}
				updateText();
			}
			else if (sender == weekBeforeInputText)
			{
				weekDef.weekBefore = weekBeforeInputText.text.trim();
			}
			else if (sender == difficultiesInputText)
			{
				var splitText:Array<String> = difficultiesInputText.text.trim().split(',');
				for (i in 0...splitText.length)
				{
					splitText[i] = splitText[i].trim();
				}

				while (splitText.length < weekDef.difficulties.length)
				{
					weekDef.difficulties.pop();
				}

				for (i in 0...splitText.length)
				{
					if (i >= weekDef.difficulties.length)
					{ // Add new difficulty
						weekDef.difficulties.push(splitText[i]);
					}
					else
					{ // Edit difficulty
						weekDef.difficulties[i] = splitText[i];
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
		var tabs:Array<{name:String, label:String}> = [{name: 'Week', label: 'Week'}, {name: 'Other', label: 'Other'}];
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
			fileBrowseDialog();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 60;
		add(loadWeekButton);

		var saveWeekButton:FlxButton = new FlxButton(0, 650, 'Save Week', () ->
		{
			fileSaveDialog();
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 60;
		add(saveWeekButton);
	}

	private var songsInputText:FlxUIInputText;
	private var backgroundInputText:FlxUIInputText;
	private var displayNameInputText:FlxUIInputText;
	private var weekNameInputText:FlxUIInputText;
	private var weekDefInputText:FlxUIInputText;

	private var opponentInputText:FlxUIInputText;
	private var boyfriendInputText:FlxUIInputText;
	private var girlfriendInputText:FlxUIInputText;

	private var hideCheckbox:FlxUICheckBox;

	public static var weekDefName:String = 'week1';

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

		weekDefInputText = new FlxUIInputText(10, weekNameInputText.y + 40, 100, 8);
		blockPressWhileTypingOn.push(weekDefInputText);
		reloadWeekThing();

		hideCheckbox = new FlxUICheckBox(10, weekDefInputText.y + 40, null, null, 'Hide Week from Story Mode?', 100);
		hideCheckbox.callback = () ->
		{
			weekDef.hideStoryMode = hideCheckbox.checked;
		};

		tabGroup.add(new FlxText(songsInputText.x, songsInputText.y - 18, 0, 'Songs:'));
		tabGroup.add(new FlxText(opponentInputText.x, opponentInputText.y - 18, 0, 'Characters:'));
		tabGroup.add(new FlxText(backgroundInputText.x, backgroundInputText.y - 18, 0, 'Background Asset:'));
		tabGroup.add(new FlxText(displayNameInputText.x, displayNameInputText.y - 18, 0, 'Display Name:'));
		tabGroup.add(new FlxText(weekNameInputText.x, weekNameInputText.y - 18, 0, 'Week Name (for Reset Score Menu):'));
		tabGroup.add(new FlxText(weekDefInputText.x, weekDefInputText.y - 18, 0, 'Week File:'));

		tabGroup.add(songsInputText);
		tabGroup.add(opponentInputText);
		tabGroup.add(boyfriendInputText);
		tabGroup.add(girlfriendInputText);
		tabGroup.add(backgroundInputText);

		tabGroup.add(displayNameInputText);
		tabGroup.add(weekNameInputText);
		tabGroup.add(weekDefInputText);
		tabGroup.add(hideCheckbox);
		UI_box.addGroup(tabGroup);
	}

	private var weekBeforeInputText:FlxUIInputText;
	private var difficultiesInputText:FlxUIInputText;
	private var lockedCheckbox:FlxUICheckBox;
	private var hiddenUntilUnlockCheckbox:FlxUICheckBox;
	private var hideFreeplayCheckbox:FlxUICheckBox;

	private function addOtherUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, UI_box);
		tabGroup.name = 'Other';

		hideFreeplayCheckbox = new FlxUICheckBox(10, 30, null, null, 'Hide Week from Freeplay', 100);
		hideFreeplayCheckbox.checked = weekDef.hideFreeplay;
		hideFreeplayCheckbox.callback = () ->
		{
			weekDef.hideFreeplay = hideFreeplayCheckbox.checked;
		};

		lockedCheckbox = new FlxUICheckBox(10, hideFreeplayCheckbox.y + 30, null, null, 'Week starts Locked', 100);
		lockedCheckbox.callback = () ->
		{
			weekDef.startUnlocked = !lockedCheckbox.checked;
			lock.visible = lockedCheckbox.checked;
			hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);
		};

		hiddenUntilUnlockCheckbox = new FlxUICheckBox(10, lockedCheckbox.y + 25, null, null, 'Hidden until Unlocked', 110);
		hiddenUntilUnlockCheckbox.callback = () ->
		{
			weekDef.hiddenUntilUnlocked = hiddenUntilUnlockCheckbox.checked;
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
		tabGroup.add(hideFreeplayCheckbox);
		UI_box.addGroup(tabGroup);
	}

	// Used in onCreate and when you load a week
	private function reloadAllShit():Void
	{
		var weekString:String = weekDef.songs[0];
		for (i in 1...weekDef.songs.length)
		{
			weekString += ', ${weekDef.songs[i]}';
		}
		songsInputText.text = weekString;
		backgroundInputText.text = weekDef.weekBackground;
		displayNameInputText.text = weekDef.storyName;
		weekNameInputText.text = weekDef.weekName;
		weekDefInputText.text = weekDefName;

		opponentInputText.text = weekDef.weekCharacters[0];
		boyfriendInputText.text = weekDef.weekCharacters[1];
		girlfriendInputText.text = weekDef.weekCharacters[2];

		hideCheckbox.checked = weekDef.hideStoryMode;

		weekBeforeInputText.text = weekDef.weekBefore;

		if (weekDef.difficulties != null && weekDef.difficulties.length > 0)
		{
			var difficultiesString:String = weekDef.difficulties[0];
			for (i in 1...weekDef.difficulties.length)
			{
				difficultiesString += ', ${weekDef.difficulties[i]}';
			}
			difficultiesInputText.text = difficultiesString;
		}
		else
		{
			difficultiesInputText.text = '';
		}

		lockedCheckbox.checked = !weekDef.startUnlocked;
		lock.visible = lockedCheckbox.checked;

		hiddenUntilUnlockCheckbox.checked = weekDef.hiddenUntilUnlocked;
		hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);

		reloadBG();
		reloadWeekThing();
		updateText();
	}

	private function updateText():Void
	{
		for (i => char in grpWeekCharacters.members)
		{
			char.changeCharacter(weekDef.weekCharacters[i]);
		}

		var stringThing:Array<String> = [];
		for (songId in weekDef.songs)
		{
			var songMetadataDef:SongMetadataDef = SongMetadata.getSongMetadata(songId);
			stringThing.push(songMetadataDef.name);
		}

		txtTracklist.text = '';
		for (song in stringThing)
		{
			txtTracklist.text += '$song\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		txtWeekTitle.text = weekDef.storyName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);
	}

	private function reloadBG():Void
	{
		bgSprite.visible = true;
		var assetName:String = weekDef.weekBackground;

		var isMissing:Bool = true;
		if (assetName != null && assetName.length > 0)
		{
			var bgPath:String = Path.join(['ui', 'story', 'backgrounds', assetName]);
			if (!Paths.exists(Paths.image(bgPath), IMAGE))
			{
				Debug.logError('Could not find story menu background with ID "$assetName"; using default');
				bgPath = Path.join(['ui', 'story', 'backgrounds', 'blank']); // Prevents crash from missing background
				isMissing = true;
			}
			var graphic:FlxGraphicAsset = Paths.getGraphic(bgPath);
			bgSprite.loadGraphic(graphic);
			if (bgPath != Path.join(['ui', 'story', 'backgrounds', 'blank']))
			{
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
		var assetName:String = weekDefInputText.text.trim();

		var isMissing:Bool = true;
		if (assetName != null && assetName.length > 0)
		{
			var graphic:FlxGraphicAsset = Paths.getGraphic(Path.join(['storymenu', assetName]));
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
			missingFileText.text = 'MISSING FILE: ${Path.join(['images', 'storymenu', Path.withExtension(assetName, Paths.IMAGE_EXT)])}';
		}
		recalculateStuffPosition();

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Week Editor', 'Editing: $weekDefName');
		#end
	}

	private function recalculateStuffPosition():Void
	{
		weekThing.screenCenter(X);
		lock.x = weekThing.width + 10 + weekThing.x;
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
		catch (ex:Exception)
		{
			removeLoadListeners();
			Debug.logError('Error loading file: ${ex.message}');
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
			var loadedWeek:WeekDef = Json.parse(jsonString);
			if (loadedWeek != null)
			{
				if (loadedWeek.weekCharacters != null && loadedWeek.weekName != null) // Make sure it's really a week
				{
					var cutName:String = Path.withoutExtension(_file.name);
					weekDefName = cutName;
					reloadAllShit();
					Debug.logTrace('Successfully loaded file: ${_file.name}');
					removeLoadListeners();
					return;
				}
			}
		}
		catch (ex:Exception)
		{
			Debug.logError('Error loading file: ${ex.message}');
			removeLoadListeners();
			return;
		}
		Debug.logError('Could not load file');
		removeLoadListeners();
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
		var data:String = Json.stringify(weekDef, Constants.JSON_SPACE);
		if (data.length > 0)
		{
			data += '\n'; // I like newlines at the ends of files.
			addSaveListeners();
			_file.save(data, Path.withExtension(weekDefName, Paths.JSON_EXT));
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
