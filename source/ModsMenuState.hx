package;

import ui.Alphabet;
import ui.AttachedSprite;
#if FEATURE_MODS
import Mod.ModEnableState;
import Mod.ModMetadata;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
#if sys
import haxe.Exception;
import haxe.io.Bytes;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Uncompress;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
#end
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
#if polymod
import polymod.PolymodConfig;
#end

class ModsMenuState extends MusicBeatState
{
	private static var curSelected:Int = 0;

	private var mods:Array<ModMetadata> = [];

	private var bg:FlxSprite;
	private var intendedColor:Int;
	private var colorTween:FlxTween;

	private var noModsTxt:FlxText;
	private var selector:AttachedSprite;
	private var descriptionTxt:FlxText;
	private var needaReset:Bool = false;

	private var buttonDown:FlxButton;
	private var buttonTop:FlxButton;
	private var buttonDisableAll:FlxButton;
	private var buttonEnableAll:FlxButton;
	private var buttonUp:FlxButton;
	private var buttonToggle:FlxButton;
	private var buttonsArray:Array<FlxButton> = [];

	private var installButton:FlxButton;
	private var uninstallButton:FlxButton;

	private var modList:Array<ModEnableState> = [];

	private var visibleWhenNoMods:Array<FlxBasic> = [];
	private var visibleWhenHasMods:Array<FlxBasic> = [];

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('In the Menus');
		#end

		Week.setDirectoryFromWeek();

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.tempo = TitleState.titleDef.bpm;
		}

		bg = new FlxSprite().loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuDesat'));
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		noModsTxt = new FlxText(0, 0, FlxG.width, 'NO MODS INSTALLED\nPRESS BACK TO EXIT AND INSTALL A MOD', 32);
		if (FlxG.random.bool(0.1))
			noModsTxt.text += '\nBITCH.'; // meanie
		noModsTxt.setFormat(Paths.font('vcr.ttf'), noModsTxt.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		noModsTxt.scrollFactor.set();
		noModsTxt.borderSize = 2;
		noModsTxt.screenCenter();
		add(noModsTxt);
		visibleWhenNoMods.push(noModsTxt);

		for (modEnableState in Paths.getSortedModEnableStates())
		{
			addToModList(modEnableState);
		}

		saveTxt();

		selector = new AttachedSprite();
		selector.xAdd = -205;
		selector.yAdd = -68;
		selector.alphaMult = 0.5;
		makeSelectorGraphic();
		add(selector);
		visibleWhenHasMods.push(selector);

		// attached buttons
		var startX:Int = 1120;

		buttonToggle = new FlxButton(startX, 0, 'ON', () ->
		{
			if (mods[curSelected].restart)
			{
				needaReset = true;
			}
			modList[curSelected].enabled = !modList[curSelected].enabled;
			updateButtonToggle();
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
		});
		buttonToggle.setGraphicSize(50, 50);
		buttonToggle.updateHitbox();
		add(buttonToggle);
		buttonsArray.push(buttonToggle);
		visibleWhenHasMods.push(buttonToggle);

		buttonToggle.label.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
		setAllLabelsOffset(buttonToggle, -15, 10);
		startX -= 70;

		buttonUp = new FlxButton(startX, 0, '/\\', () ->
		{
			moveMod(-1);
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
		});
		buttonUp.setGraphicSize(50, 50);
		buttonUp.updateHitbox();
		add(buttonUp);
		buttonsArray.push(buttonUp);
		visibleWhenHasMods.push(buttonUp);
		buttonUp.label.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.BLACK, CENTER);
		setAllLabelsOffset(buttonUp, -15, 10);
		startX -= 70;

		buttonDown = new FlxButton(startX, 0, '\\/', () ->
		{
			moveMod(1);
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
		});
		buttonDown.setGraphicSize(50, 50);
		buttonDown.updateHitbox();
		add(buttonDown);
		buttonsArray.push(buttonDown);
		visibleWhenHasMods.push(buttonDown);
		buttonDown.label.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.BLACK, CENTER);
		setAllLabelsOffset(buttonDown, -15, 10);

		startX -= 100;
		buttonTop = new FlxButton(startX, 0, 'TOP', () ->
		{
			var doRestart:Bool = (mods[0].restart || mods[curSelected].restart);
			for (i in 0...curSelected) // so it shifts to the top instead of replacing the top one
			{
				moveMod(-1, true);
			}

			if (doRestart)
			{
				needaReset = true;
			}
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
		});
		buttonTop.setGraphicSize(80, 50);
		buttonTop.updateHitbox();
		buttonTop.label.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.BLACK, CENTER);
		setAllLabelsOffset(buttonTop, 0, 10);
		add(buttonTop);
		buttonsArray.push(buttonTop);
		visibleWhenHasMods.push(buttonTop);

		// TODO Make the "Disable/Enable all" buttons part of the menu itself and not part of each mod entry
		startX -= 190;
		buttonDisableAll = new FlxButton(startX, 0, 'DISABLE ALL', () ->
		{
			for (modEnableState in modList)
			{
				modEnableState.enabled = false;
			}
			for (mod in mods)
			{
				if (mod.restart)
				{
					needaReset = true;
					break;
				}
			}
			updateButtonToggle();
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
		});
		buttonDisableAll.setGraphicSize(170, 50);
		buttonDisableAll.updateHitbox();
		buttonDisableAll.label.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.BLACK, CENTER);
		buttonDisableAll.label.fieldWidth = 170;
		setAllLabelsOffset(buttonDisableAll, 0, 10);
		add(buttonDisableAll);
		buttonsArray.push(buttonDisableAll);
		visibleWhenHasMods.push(buttonDisableAll);

		startX -= 190;
		buttonEnableAll = new FlxButton(startX, 0, 'ENABLE ALL', () ->
		{
			for (modEnableState in modList)
			{
				modEnableState.enabled = true;
			}
			for (mod in mods)
			{
				if (mod.restart)
				{
					needaReset = true;
					break;
				}
			}
			updateButtonToggle();
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
		});
		buttonEnableAll.setGraphicSize(170, 50);
		buttonEnableAll.updateHitbox();
		buttonEnableAll.label.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.BLACK, CENTER);
		buttonEnableAll.label.fieldWidth = 170;
		setAllLabelsOffset(buttonEnableAll, 0, 10);
		add(buttonEnableAll);
		buttonsArray.push(buttonEnableAll);
		visibleWhenHasMods.push(buttonEnableAll);

		// more buttons
		var startX:Int = 1100;

		#if sys
		installButton = new FlxButton(startX, 620, 'Install Mod', () ->
		{
			fileBrowseDialog();
		});
		installButton.setGraphicSize(150, 70);
		installButton.updateHitbox();
		installButton.color = FlxColor.GREEN;
		installButton.label.fieldWidth = 135;
		installButton.label.setFormat(Paths.font('vcr.ttf'), 16, CENTER);
		setAllLabelsOffset(installButton, 2, 24);
		add(installButton);
		startX -= 180;

		uninstallButton = new FlxButton(startX, 620, 'Uninstall Selected Mod', () ->
		{
			uninstallMod();
		});
		uninstallButton.setGraphicSize(150, 70);
		uninstallButton.updateHitbox();
		uninstallButton.color = FlxColor.RED;
		uninstallButton.label.fieldWidth = 135;
		uninstallButton.label.setFormat(Paths.font('vcr.ttf'), 16, CENTER);
		setAllLabelsOffset(uninstallButton, 2, 15);
		add(uninstallButton);
		visibleWhenHasMods.push(uninstallButton);
		#end

		descriptionTxt = new FlxText(148, 0, FlxG.width - 216, 32);
		descriptionTxt.setFormat(Paths.font('vcr.ttf'), descriptionTxt.size, FlxColor.WHITE, LEFT);
		descriptionTxt.scrollFactor.set();
		add(descriptionTxt);
		visibleWhenHasMods.push(descriptionTxt);

		for (i => enableState in modList)
		{
			if (!Paths.fileSystem.exists(Path.join([Paths.MOD_DIRECTORY, enableState.title])))
			{
				modList.remove(enableState);
				continue;
			}

			var newMod:ModMetadata = new ModMetadata(enableState.title);
			mods.push(newMod);

			newMod.alphabet = new Alphabet(0, 0, mods[i].title, true, false, 0.05);
			var scale:Float = Math.min(840 / newMod.alphabet.width, 1);
			newMod.alphabet = new Alphabet(0, 0, mods[i].title, true, false, 0.05, scale);
			newMod.alphabet.y = i * 150;
			newMod.alphabet.x = 310;
			add(newMod.alphabet);
			// Don't ever cache the icons, it's a waste of loaded memory
			var loadedIcon:Null<BitmapData> = null;
			#if polymod
			var iconToUse:String = Path.join([Paths.MOD_DIRECTORY, enableState.title, PolymodConfig.modIconFile]);
			#else
			var iconToUse:String = Path.join([
				Paths.MOD_DIRECTORY,
				enableState.title,
				Path.withExtension('_icon', Paths.IMAGE_EXT)
			]);
			#end
			if (Paths.exists(iconToUse, IMAGE))
			{
				loadedIcon = BitmapData.fromFile(iconToUse);
			}

			newMod.icon = new AttachedSprite();
			if (loadedIcon != null)
			{
				newMod.icon.loadGraphic(loadedIcon, true, 150, 150); // animated icon support
				var totalFrames:Int = Math.floor(loadedIcon.width / 150) * Math.floor(loadedIcon.height / 150);
				newMod.icon.animation.add('icon', [for (i in 0...totalFrames) i], 10);
				newMod.icon.animation.play('icon');
			}
			else
			{
				newMod.icon.loadGraphic(Paths.getGraphic('unknownMod'));
			}
			newMod.icon.sprTracker = newMod.alphabet;
			newMod.icon.xAdd = -newMod.icon.width - 30;
			newMod.icon.yAdd = -45;
			add(newMod.icon);
		}

		if (curSelected >= mods.length)
			curSelected = 0;

		if (mods.length < 1)
			bg.color = FreeplayState.DEFAULT_COLOR;
		else
			bg.color = mods[curSelected].color;

		intendedColor = bg.color;
		changeSelection();
		updatePosition();
		FlxG.sound.play(Paths.getSound('scrollMenu'));

		FlxG.mouse.visible = true;
	}

	private var noModsSine:Float = 0;
	private var canExit:Bool = true;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (noModsTxt.visible)
		{
			noModsSine += 180 * elapsed;
			noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);
		}

		if (canExit && controls.BACK)
		{
			if (colorTween != null)
			{
				colorTween.cancel();
			}
			FlxG.sound.play(Paths.getSound('cancelMenu'));
			FlxG.mouse.visible = false;
			persistentUpdate = false;
			saveTxt();
			if (needaReset)
			{
				TitleState.initialized = false;
				TitleState.closedState = false;
				FlxG.sound.music.fadeOut(0.3);
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			}
			else
			{
				FlxG.switchState(new MainMenuState());
			}
		}

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
			FlxG.sound.play(Paths.getSound('scrollMenu'));
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
			FlxG.sound.play(Paths.getSound('scrollMenu'));
		}
		updatePosition(elapsed);
	}

	private function addToModList(newMod:ModEnableState):Void
	{
		for (mod in modList)
		{
			if (mod.title == newMod.title)
			{
				return;
			}
		}
		modList.push(newMod);
	}

	private function updateButtonToggle():Void
	{
		if (modList[curSelected].enabled)
		{
			buttonToggle.label.text = 'ON';
			buttonToggle.color = FlxColor.GREEN;
		}
		else
		{
			buttonToggle.label.text = 'OFF';
			buttonToggle.color = FlxColor.RED;
		}
	}

	private function moveMod(change:Int, skipResetCheck:Bool = false):Void
	{
		if (mods.length > 1)
		{
			var doRestart:Bool = (mods[0].restart);

			var newPos:Int = curSelected + change;
			if (newPos < 0)
			{
				modList.push(modList.shift());
				mods.push(mods.shift());
			}
			else if (newPos >= mods.length)
			{
				modList.unshift(modList.pop());
				mods.unshift(mods.pop());
			}
			else
			{
				var lastModEnableState:ModEnableState = modList[curSelected];
				modList[curSelected] = modList[newPos];
				modList[newPos] = lastModEnableState;

				var lastMod:ModMetadata = mods[curSelected];
				mods[curSelected] = mods[newPos];
				mods[newPos] = lastMod;
			}
			changeSelection(change);

			if (!doRestart)
				doRestart = mods[curSelected].restart;
			if (!skipResetCheck && doRestart)
				needaReset = true;
		}
	}

	private function saveTxt():Void
	{
		#if sys
		var fileStr:String = '';
		for (mod in modList)
		{
			if (fileStr.length > 0)
				fileStr += '\n';
			fileStr += '${mod.title}|${mod.enabled ? '1' : '0'}';
		}

		var path:String = Path.withExtension('modList', Paths.TEXT_EXT);
		File.saveContent(path, fileStr);
		#end
	}

	private function setAllLabelsOffset(button:FlxButton, x:Float, y:Float):Void
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	private function changeSelection(change:Int = 0):Void
	{
		if (mods.length < 1)
		{
			for (obj in visibleWhenHasMods)
			{
				obj.visible = false;
			}
			for (obj in visibleWhenNoMods)
			{
				obj.visible = true;
			}
			return;
		}

		for (obj in visibleWhenHasMods)
		{
			obj.visible = true;
		}
		for (obj in visibleWhenNoMods)
		{
			obj.visible = false;
		}

		curSelected += change;
		if (curSelected < 0)
			curSelected = mods.length - 1;
		else if (curSelected >= mods.length)
			curSelected = 0;

		var newColor:Int = mods[curSelected].color;
		if (newColor != intendedColor)
		{
			if (colorTween != null)
			{
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: (twn:FlxTween) ->
				{
					colorTween = null;
				}
			});
		}

		var i:Int = 0;
		for (mod in mods)
		{
			mod.alphabet.alpha = 0.6;
			if (i == curSelected)
			{
				mod.alphabet.alpha = 1;
				selector.sprTracker = mod.alphabet;
				descriptionTxt.text = mod.description;
				if (mod.restart)
				{ // finna make it to where if nothing changed then it won't reset
					descriptionTxt.text += ' (This Mod will restart the game!)';
				}

				// correct layering
				var stuffArray:Array<FlxSprite> = [uninstallButton, installButton, selector, descriptionTxt, mod.alphabet, mod.icon];
				for (obj in stuffArray)
				{
					remove(obj, true);
					add(obj);
				}
				for (obj in buttonsArray)
				{
					remove(obj, true);
					add(obj);
				}
			}
			i++;
		}
		updateButtonToggle();
	}

	private function updatePosition(elapsed:Float = -1):Void
	{
		var i:Int = 0;
		for (mod in mods)
		{
			var intendedPos:Float = (i - curSelected) * 225 + 200;
			if (i > curSelected)
				intendedPos += 225;
			if (elapsed == -1)
			{
				mod.alphabet.y = intendedPos;
			}
			else
			{
				mod.alphabet.y = FlxMath.lerp(mod.alphabet.y, intendedPos, FlxMath.bound(elapsed * 12, 0, 1));
			}

			if (i == curSelected)
			{
				descriptionTxt.y = mod.alphabet.y + 160;
				for (button in buttonsArray)
				{
					button.y = mod.alphabet.y + 320;
				}
			}
			i++;
		}
	}

	private static final cornerSize:Int = 11;

	private function makeSelectorGraphic():Void
	{
		selector.makeGraphic(1100, 450, FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle(0, 190, selector.width, 5), FlxColor.BLACK);

		// Why did i do this? Because i'm a lmao stupid, of course
		// also i wanted to understand better how fillRect works so i did this shit lol???
		selector.pixels.fillRect(new Rectangle(0, 0, cornerSize, cornerSize), FlxColor.BLACK); // top left
		drawCircleCornerOnSelector(false, false);
		selector.pixels.fillRect(new Rectangle(selector.width - cornerSize, 0, cornerSize, cornerSize), FlxColor.BLACK); // top right
		drawCircleCornerOnSelector(true, false);
		selector.pixels.fillRect(new Rectangle(0, selector.height - cornerSize, cornerSize, cornerSize), FlxColor.BLACK); // bottom left
		drawCircleCornerOnSelector(false, true);
		selector.pixels.fillRect(new Rectangle(selector.width - cornerSize, selector.height - cornerSize, cornerSize, cornerSize),
			FlxColor.BLACK); // bottom right
		drawCircleCornerOnSelector(true, true);
	}

	private function drawCircleCornerOnSelector(flipX:Bool, flipY:Bool):Void
	{
		var antiX:Float = (selector.width - cornerSize);
		var antiY:Float = flipY ? (selector.height - 1) : 0;
		if (flipY)
			antiY -= 2;
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 1), Math.abs(antiY - 8), 10, 3), FlxColor.BLACK);
		if (flipY)
			antiY += 1;
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 2), Math.abs(antiY - 6), 9, 2), FlxColor.BLACK);
		if (flipY)
			antiY += 1;
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 3), Math.abs(antiY - 5), 8, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 4), Math.abs(antiY - 4), 7, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 5), Math.abs(antiY - 3), 6, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 6), Math.abs(antiY - 2), 5, 1), FlxColor.BLACK);
		selector.pixels.fillRect(new Rectangle((flipX ? antiX : 8), Math.abs(antiY - 1), 3, 1), FlxColor.BLACK);
	}

	#if sys
	private var _file:FileReference;

	private function fileBrowseDialog():Void
	{
		var zipFilter:FileFilter = new FileFilter('ZIP', 'zip');
		addLoadListeners();
		_file.browse([zipFilter]);
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
		// TODO Load from the _file.data field instead of getting the private path field from it
		// Do that with the editors, too, because some of them load from paths (like the chart editor) instead of from the file data
		var fullPath:Null<String> = null;
		@:privateAccess
		if (_file.__path != null)
			fullPath = _file.__path;

		if (Paths.exists(fullPath))
		{
			FlxG.resetState();

			unzip(fullPath, Paths.MOD_DIRECTORY);
			Debug.logTrace('Successfully loaded file: ${_file.name}');
			removeLoadListeners();
			return;
		}
		removeLoadListeners();
		canExit = true;
		Debug.logError('Could not load file');
	}

	/**
	 * Called when the load file dialog is cancelled.
	 */
	private function onLoadCancel(e:Event):Void
	{
		removeLoadListeners();
		canExit = true;
		Debug.logTrace('Cancelled file loading.');
	}

	/**
	 * Called if there is an error while loading the file.
	 */
	private function onLoadError(e:IOErrorEvent):Void
	{
		removeLoadListeners();
		canExit = true;
		Debug.logError('Error loading file: ${e.text}');
	}

	private function uninstallMod():Void
	{
		var path:String = Path.join([Paths.MOD_DIRECTORY, modList[curSelected].title]);

		if (Paths.fileSystem.exists(path) && Paths.fileSystem.isDirectory(path))
		{
			Debug.logTrace('Trying to delete directory $path');
			try
			{
				deleteDirRecursively(path);
				var icon:AttachedSprite = mods[curSelected].icon;
				var alphabet:Alphabet = mods[curSelected].alphabet;

				remove(icon);
				remove(alphabet);
				icon.destroy();
				alphabet.destroy();
				modList.remove(modList[curSelected]);
				mods.remove(mods[curSelected]);
				if (curSelected >= mods.length)
					--curSelected;
				changeSelection();
				Debug.logTrace('Successfully deleted directory $path');
			}
			catch (ex:Exception)
			{
				Debug.logError('Error deleting directory "$path": ${ex.message}');
			}
		}
	}

	/**
	 * https://ashes999.github.io/learnhaxe/recursively-delete-a-directory-in-haxe.html
	 */
	private function deleteDirRecursively(path:String):Void
	{
		if (Paths.fileSystem.exists(path) && Paths.fileSystem.isDirectory(path))
		{
			var entries:Array<String> = Paths.fileSystem.readDirectory(path);
			for (entry in entries)
			{
				var entryPath:String = Path.join([path, entry]);
				if (Paths.fileSystem.isDirectory(entryPath))
				{
					deleteDirRecursively(entryPath);
					FileSystem.deleteDirectory(entryPath);
				}
				else
				{
					FileSystem.deleteFile(entryPath);
				}
			}
		}
	}

	/**
	 * https://gist.github.com/ruby0x1/8dc3a206c325fbc9a97e
	 */
	public static function unzip(path:String, dest:String, ignoreRootFolder:Bool = false):Void
	{
		var fileInput:FileInput = File.read(path);
		var entries:List<Entry> = Reader.readZip(fileInput);

		fileInput.close();

		for (entry in entries)
		{
			var fileName:String = entry.fileName;
			if (fileName.charAt(0) != '/' && fileName.charAt(0) != '\\' && fileName.split('..').length <= 1)
			{
				var directories:Array<String> = ~/[\/\\]/g.split(fileName);
				if ((ignoreRootFolder && directories.length > 1) || !ignoreRootFolder)
				{
					if (ignoreRootFolder)
					{
						directories.shift();
					}

					var file:String = directories.pop();
					var entryDirectory:String = Path.join(directories);
					// createDirectory does not throw an exception if a parent directory does not exist, so we are able to not use a loop to create the directories
					FileSystem.createDirectory(Path.join([dest, entryDirectory]));

					if (file == '')
					{
						if (entryDirectory != '')
							Debug.logTrace('Created $entryDirectory');
						continue; // was just a directory
					}
					var entryPath:String = Path.join([entryDirectory, file]);
					Debug.logTrace('Unzipped $entryPath');

					try
					{
						// Reader.unzip() will cause an exception on anything other than Neko if the entry is compressed
						// Because of that, I have to just copy the Neko segment of code from Reader.unzip() into my own custom method
						// I should probably make an issue for that on the Haxe GitHub...
						// Update: It's actually caused by Lime, which overrides the Reader class. I'll have to report it on that repository eventually.
						// var data:Bytes = Reader.unzip(entry);
						var data:Bytes = unzipWorkaround(entry);
						var fileOutput:FileOutput = File.write(Path.join([dest, entryPath]));
						fileOutput.write(data);
						fileOutput.close();
					}
					catch (e:Exception)
					{
						Debug.logError(e);
					}
				}
			}
		}
		Debug.logTrace('Successfully unzipped $path to $dest');
	}

	// Trying to work around the platform limitations for zip support by just copying a segment from Reader.unzip()
	private static function unzipWorkaround(f:Entry):Bytes
	{
		if (!f.compressed)
		{
			return f.data;
		}
		var c:Uncompress = new Uncompress(-15);
		var s:Bytes = Bytes.alloc(f.fileSize);
		var r:{done:Bool, read:Int, write:Int} = c.execute(f.data, 0, s, 0);
		c.close();
		if (!r.done || r.read != f.data.length || r.write != f.fileSize)
		{
			throw new Exception('Invalid compressed data for ${f.fileName}');
		}
		f.compressed = false;
		f.dataSize = f.fileSize;
		f.data = s;
		return f.data;
	}
	#end
}
#end
