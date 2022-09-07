package funkin.states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import funkin.chart.container.SongMetadata.SongMetadataDef;
import funkin.chart.container.SongMetadata;
import funkin.ui.Alphabet;
import funkin.ui.HealthIcon;
import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;

// TODO Make sure this actually works
class SongMetadataEditorState extends MusicBeatState
{
	private var songMetadata:SongMetadata;
	private var songId:String;

	public function new(?songMetadata:SongMetadata)
	{
		super();

		if (songMetadata != null)
			this.songMetadata = songMetadata;
		else
			this.songMetadata = new SongMetadata();
	}

	private var bg:FlxSprite;
	private var icon:HealthIcon;

	override public function create():Void
	{
		super.create();

		bg = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'main', 'backgrounds', 'menuDesat'])));
		bg.antialiasing = Options.profile.globalAntialiasing;

		bg.color = FlxColor.WHITE;
		add(bg);

		var songText:Alphabet = new Alphabet(0, (70 * 0) + 30, songMetadata.name, true, false);
		songText.isMenuItem = true;
		songText.targetY = 0;

		icon = new HealthIcon(songMetadata.icon);
		icon.sprTracker = songText;

		add(icon);

		addEditorBox();
		reloadAll();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (iconInputText.hasFocus)
		{
			FlxG.sound.muteKeys = null;
			FlxG.sound.volumeDownKeys = null;
			FlxG.sound.volumeUpKeys = null;
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
				FlxG.switchState(new MasterEditorMenuState());
			}
		}
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			songMetadata.icon = iconInputText.text;
			icon.changeIcon(iconInputText.text);
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
		var tabs:Array<{name:String, label:String}> = [{name: 'Freeplay', label: 'Freeplay'}];
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
			fileBrowseDialog();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 60;
		add(loadWeekButton);

		var saveWeekButton:FlxButton = new FlxButton(0, 685, 'Save Week', () ->
		{
			fileSaveDialog();
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 60;
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
			Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, '${bg.color.red},${bg.color.green},${bg.color.blue}');
		});
		var pasteColor:FlxButton = new FlxButton(140, copyColor.y, 'Paste Color', () ->
		{
			if (Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT) != null)
			{
				var colors:Array<Int> = [];
				var splitStrings:Array<String> = Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT).trim().split(',');
				for (splitString in splitStrings)
				{
					var toPush:Int = Std.parseInt(splitString);
					if (!Math.isNaN(toPush))
					{
						if (toPush > 255)
							toPush = 255;
						else if (toPush < 0)
							toPush *= -1;
						colors.push(toPush);
					}
				}

				if (colors.length > 2)
				{
					bgColorStepperR.value = colors[0];
					bgColorStepperG.value = colors[1];
					bgColorStepperB.value = colors[2];
					updateBG();
				}
			}
		});

		iconInputText = new FlxUIInputText(10, bgColorStepperR.y + 70, 100, 8);

		tabGroup.add(new FlxText(10, bgColorStepperR.y - 18, 0, 'Selected background Color R/G/B:'));
		tabGroup.add(new FlxText(10, iconInputText.y - 18, 0, 'Selected icon:'));
		tabGroup.add(bgColorStepperR);
		tabGroup.add(bgColorStepperG);
		tabGroup.add(bgColorStepperB);
		tabGroup.add(copyColor);
		tabGroup.add(pasteColor);
		tabGroup.add(iconInputText);
		UI_box.addGroup(tabGroup);
	}

	private function updateBG():Void
	{
		var color:FlxColor = FlxColor.fromRGBFloat(bgColorStepperR.value, bgColorStepperG.value, bgColorStepperB.value);
		// TODO Make this able to edit all of the colors in the color array
		songMetadata.colors[0].red = color.red;
		songMetadata.colors[0].green = color.green;
		songMetadata.colors[0].blue = color.blue;
		bg.color = color;
	}

	private function reloadAll():Void
	{
		iconInputText.text = songMetadata.icon;
		bgColorStepperR.value = songMetadata.colors[0].red;
		bgColorStepperG.value = songMetadata.colors[0].green;
		bgColorStepperB.value = songMetadata.colors[0].blue;
		updateBG();
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
			var loadedMeta:SongMetadataDef = Json.parse(jsonString);
			if (loadedMeta != null)
			{
				if (loadedMeta.name != null && loadedMeta.icon != null) // Make sure it's really a week
				{
					var cutName:String = Path.withoutExtension(_file.name);
					songId = cutName;
					reloadAll();
					Debug.logTrace('Successfully loaded file: ${_file.name}');
					removeLoadListeners();
					return;
				}
			}
		}
		catch (ex:Exception)
		{
			removeLoadListeners();
			Debug.logError('Error loading file: ${ex.message}');
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
		var data:String = Json.stringify(songMetadata, Constants.JSON_SPACE);
		if (data.length > 0)
		{
			data += '\n'; // I like newlines at the ends of files.
			addSaveListeners();
			_file.save(data, Path.withExtension(songId, Paths.JSON_EXT));
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
