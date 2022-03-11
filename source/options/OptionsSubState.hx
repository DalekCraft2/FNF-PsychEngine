package options;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.display.FPSMem;
import options.Options;

using StringTools;

class OptionsSubState extends MusicBeatSubState
{
	public static var instance:OptionsSubState;

	private var defCat:OptionCategory;

	private var optionText:FlxTypedGroup<Option>;
	private var optionDesc:FlxText;
	private var curSelected:Int = 0;

	public static var category:Dynamic;

	public static var isInPause = false;

	public function new(pauseMenu:Bool = false)
	{
		super();

		isInPause = pauseMenu;
	}

	// TODO Make some of these not changeable whilst in PlayState, like in Kade Engine
	public function createDefault()
	{
		defCat = new OptionCategory("Default", [
			new OptionCategory("Gameplay", [
				new OptionCategory("Controls",
					[
						// TODO: rewrite
						// TODO Reimplement the ability to change the second keybind
						new ControlOption(controls, 'note_left', [A, LEFT]),
						new ControlOption(controls, 'note_down', [S, DOWN]),
						new ControlOption(controls, 'note_up', [W, UP]),
						new ControlOption(controls, 'note_right', [D, RIGHT]),

						new ControlOption(controls, 'ui_left', [A, LEFT]),
						new ControlOption(controls, 'ui_down', [S, DOWN]),
						new ControlOption(controls, 'ui_up', [W, UP]),
						new ControlOption(controls, 'ui_right', [D, RIGHT]),

						new ControlOption(controls, 'accept', [SPACE, ENTER]),
						new ControlOption(controls, 'back', [BACKSPACE, ESCAPE]),
						new ControlOption(controls, 'pause', [ENTER, ESCAPE]),
						new ControlOption(controls, 'reset', [R, NONE]),

						new ControlOption(controls, 'volume_mute', [ZERO, NONE]),
						new ControlOption(controls, 'volume_up', [NUMPADPLUS, PLUS]),
						new ControlOption(controls, 'volume_down', [NUMPADMINUS, MINUS]),

						new ControlOption(controls, 'debug_1', [SEVEN, NONE]),
						new ControlOption(controls, 'debug_2', [EIGHT, NONE])
					]),
				new ToggleOption("controllerMode", false, "Controller Mode",
					"Check this if you want to play with a controller instead of using your Keyboard."),
				new ToggleOption("resetKey", true, "Reset Key", "Toggle pressing the bound key to instantly die"),
				#if !FORCE_LUA_MODCHARTS new ToggleOption("loadModcharts", true, "Load Lua modcharts", "Toggles lua modcharts"),
				#end
				new ToggleOption("ghostTapping", true, "Ghost-Tapping", "Allows you to press keys while no notes are able to be hit."),
				new ToggleOption("instakill", false, "Instakill on Miss", "FC or die"),
				#if !NO_BOTPLAY new ToggleOption("botPlay", false, "BotPlay", "Let a bot play for you"), #end
				// TODO Finish the description of this
				new ToggleOption("practice ", false, "Practice Mode", ""),
				// new StepOption("noteOffset", 0, "Note Delay", "Changes how late a note is spawned.\nUseful for preventing audio lag from wireless earphones.",
				// 	1, 0, 500, "ms", ""),
				new StepOption("ratingOffset", 0, "Rating Offset",
					"Changes how late/early you have to hit for a \"Sick!\" Higher values mean you have to hit later.", 1, -30, 30, "ms"),
				new StepOption("sickWindow", 45, "Sick! Hit Window", "Changes the amount of time you have for hitting a \"Sick!\" in milliseconds.", 1, 15,
					45, "ms"),
				new StepOption("goodWindow", 90, "Good Hit Window", "Changes the amount of time you have for hitting a \"Good\" in milliseconds.", 1, 15, 90,
					"ms"),
				new StepOption("badWindow", 135, "Bad Hit Window", "Changes the amount of time you have for hitting a \"Bad\" in milliseconds.", 1, 15, 135,
					"ms"),
				new StepOption("safeFrames", 10, "Safe Frames", "Changes how many frames you have for hitting a note earlier or later.", 0.1, 2, 10, "ms"),
				#if !NO_FREEPLAY_MODS
				new OptionCategory("Freeplay Modifiers", [
					new StepOption("cMod", 0, "Speed Constant", "A constant speed to override the scroll speed. 0 for chart-dependant speed", 0.1, 0, 10, "",
						"", true),
					new StepOption("xMod", 1, "Speed Mult", "A multiplier to a chart's scroll speed", 0.1, 0, 2, "", "x", true),
					new StepOption("mMod", 1, "Minimum Speed", "The minimum scroll speed a chart can have", 0.1, 0, 10, "", "", true),
					new ToggleOption("noFail", false, "No Fail", "You can't blueball, but there's an indicator that you failed and you don't save the score."),
				]), new StateOption("Delay and Combo Offset", new NoteOffsetState()),
				#end
				new OptionCategory("Advanced", [
					#if !FORCED_JUDGE new JudgementsOption("judgementWindow", "ITG", "Judgements",
						"The judgement windows to use"), new ToggleOption("useEpic", true, "Use Epics", "Allows the 'Epic' judgement to be used"),
					#end
					new ScrollOption("accuracySystem", "Basic", "Accuracy System", "How accuracy is determined", 0, 2, ["Basic", "Stepmania", "Wife3"]),
					// new ToggleOption("attemptToAdjust", false, "Better Sync", "Attempts to sync the song position to the instrumental better by using the average offset between the\ninstrumental and the visual pos")
				]
				),
				new StateOption("Calibrate Offset", new SoundOffsetState()) // TODO: make a better 'calibrate offset'
			]),
			new OptionCategory("Appearance", [
				new StateOption("Note Colors", new NotesState()),
				new ToggleOption("showComboCounter", true, "Show Combo", "Shows your combo when you hit a note"),
				new ToggleOption("showRatings", true, "Show Judgements", "Shows judgements when you hit a note"),
				new ToggleOption("showMS", false, "Show Hit MS", "Shows millisecond difference when you hit a note"),
				new ToggleOption("showCounters", true, "Show Judgement Counters", "Whether judgement counters get shown on the side"),
				new ToggleOption("downScroll", false, "Downscroll", "Arrows come from the top down instead of the bottom up."),
				new ToggleOption("middleScroll", false, "Centered Notes",
					"Places your notes in the center of the screen and hides the opponent's. \"Middlescroll\""),
				new ToggleOption("allowNoteModifiers", true, "Allow Note Modifiers", "Whether note modifiers (e.g pixel notes in week 6) get used"),
				new StepOption("backTrans", 0, "BG Darkness", "How dark the background is", 10, 0, 100, "%", "", true),
				new ScrollOption("staticCam", OptionUtils.camFocuses[0], "Camera Focus", "Who the camera should focus on", 0,
					OptionUtils.camFocuses.length - 1, OptionUtils.camFocuses),
				// new ToggleOption("oldMenus", false, "Vanilla Menus", "Forces the vanilla menus to be used"),
				// new ToggleOption("oldTitle", false, "Vanilla Title Screen", "Forces the vanilla title to be used"),
				new ToggleOption("healthBarColors", true, "Healthbar Colours", "Whether the healthbar colour changes with the character"),
				new ToggleOption("onlyScore", false, "Minimal Information", "Only shows your score below the hp bar"),
				new ToggleOption("smoothHPBar", false, "Smooth Healthbar", "Makes the HP Bar smoother"),
				new ToggleOption("fcBasedComboColor", false, "FC Combo Colouring", "Makes the combo's colour changes with type of FC you have"),
				new ToggleOption("holdsBehindReceptors", false, "Stepmania Clipping", "Makes holds clip behind the receptors"),
				// new NoteskinOption("noteSkin", "NoteSkin", "The noteskin to use"),
				new OptionCategory("Effects", [
					new ToggleOption("picoCamshake", true, "Train camera shake", "Whether the train in week 3's background shakes the camera"),
					// new ToggleOption("senpaiShaders", true, "Week 6 shaders","Is the CRT effect active in week 6"),
					new ScrollOption("senpaiShaderStrength", "All", "Week 6 shaders", "How strong the week 6 shaders are", 0, 2, ["Off", "CRT", "All"])
				])
			]),
			new OptionCategory("Preferences", [
				new ToggleOption("noteSplashes", true, "Show NoteSplashes", "Notesplashes showing up on sicks and above."),
				new ToggleOption("camFollowsAnims", false, "Directional Camera", "Camera moving depending on a character's animations"),
				new ToggleOption("hideHud", false, "Hide HUD", "If checked, hides most HUD elements."),
				new ScrollOption("timeBarType", "Time Left", "Time Bar", "What should the Time Bar display?", 0, 3,
					['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']),
				new ToggleOption("flashing", true, "Flashing Lights", "Uncheck this if you're sensitive to flashing lights!"),
				new ToggleOption("camZooms", true, "Camera Zooms", "If unchecked, the camera won't zoom in on a beat hit."),
				new ToggleOption("scoreZoom", true, "Score Text Zoom on Hit", "If unchecked, disables the Score text zooming\neverytime you hit a note."),
				new StepOption("healthBarAlpha", 1, "Health Bar Transparency", "How much transparent should the health bar and icons be.", 0.1, 0, 1, true),
				new ToggleOption("ratingInHUD", false, "Fixed Judgements", "Fixes judgements, milliseconds and combo to the screen"),
				new ToggleOption("ratingOverNotes", false, "Judgements over Notes", "Places judgements, milliseconds and combo above the playfield"),
				new ToggleOption("smJudges", false, "Simply Judgements", "Animates judgements like ITG's Simply Love theme"),
				new ToggleOption("persistentCombo", false, "Simply Combos", "Animates combos like ITG's Simply Love theme"),
				new ToggleOption("pauseHoldAnims", true, "Holds Pause Animations", "Whether to pause animations on their first frame"),
				new ToggleOption("menuFlash", true, "Flashing in Menus", "Whether buttons and the background should flash in menus"),
				new ToggleOption("hitSound", false, "Hit Sounds", "Play a click sound when you hit a note"),
				new ToggleOption("showFPS", false, "Show FPS", "Shows your FPS in the top left", function(state:Bool)
				{
					FPSMem.showFPS = state;
				}),
				new ToggleOption("showMem", false, "Show Memory", "Shows memory usage in the top left", function(state:Bool)
				{
					FPSMem.showMem = state;
				}),
				new ToggleOption("showMemPeak", false, "Show Memory Peak", "Shows peak memory usage in the top left",
					function(state:Bool)
					{
						FPSMem.showMemPeak = state;
					}),
				new ScrollOption("pauseMusic", "Tea Time", "Pause Screen Song", "What song do you prefer for the Pause Screen?", 0, 2,
					["None", "Breakfast", "Tea Time"],
					function(index:Int, name:String, indexAdd:Int)
					{
						if (name == 'None')
							FlxG.sound.music.volume = 0;
						else
							FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(name)));

						// changedMusic = true;
					}),
				new ToggleOption("ghosttapSounds", false, "Ghost-tap Hit Sounds", "Play a click sound when you ghost-tap"),
				new StepOption("hitsoundVol", 50, "Hit Sound Volume", "What volume the hitsound should be", 10, 0, 100, "%", "", true),
				// new ToggleOption("freeplayPreview", false, "Song Preview in Freeplay", "Whether songs get played as you hover over them in Freeplay"),
				new ToggleOption("fastTransitions", false, "Fast Transitions", "Makes transitions between states faster"),
				// new StateOption("Judgement Position", new JudgeCustomizationState())
			]),
			new OptionCategory("Performance", [
				new StepOption("framerate", 120, "FPS Cap", "The FPS the game tries to run at", 30, 30, 360, "", "", true,
					function(value:Float, step:Float)
					{
						Main.setFPSCap(Std.int(value));
					}),
				new ToggleOption("recycleComboJudges", false, "Recycling",
					"Instead of making a new sprite for each judgement and combo number, objects are reused when possible.\nMay cause layering issues."),
				new ToggleOption("lowQuality", false, "Low Quality",
					"If checked, disables some background details,\ndecreases loading times and improves performance."),
				new ToggleOption("noChars", false, "Hide Characters", "Hides characters ingame"),
				new ToggleOption("noStage", false, "Hide Background", "Hides stage ingame"),
				new ToggleOption("globalAntialiasing", true, "Antialiasing", "Toggles the ability for sprites to have antialiasing"),
				new ToggleOption("allowOrderSorting", true, "Sort notes by order",
					"Allows notes to go infront and behind other notes. May cause FPS drops on very high note-density charts."),
				new OptionCategory("Loading", [
					new ToggleOption("shouldCache", false, "Cache on startup", "Whether the engine caches stuff when the game starts"),
					new ToggleOption("cacheCharacters", false, "Cache characters", "Whether the engine caches characters if it caches on startup"),
					new ToggleOption("cacheSongs", false, "Cache songs", "Whether the engine caches songs if it caches on startup"),
					new ToggleOption("cacheSounds", false, "Cache sounds", "Whether the engine caches misc sounds if it caches on startup"),
					new ToggleOption("cachePreload", false, "Cache misc images", "Whether the engine caches misc images if it caches on startup"),
					new ToggleOption("cacheUsedImages", false, "Persistent Images", "Whether images should persist in memory", function(state:Bool)
					{
						FlxGraphic.defaultPersist = state;
					}),
				])
			])
		]);
	}

	override function create()
	{
		super.create();
		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Changing options", null);
		#end
		if (isInPause)
		{
			var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			bg.alpha = 0.6;
			bg.scrollFactor.set();
			add(bg);

			cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		}

		createDefault();
		category = defCat;

		optionText = new FlxTypedGroup<Option>();
		add(optionText);

		optionDesc = new FlxText(5, FlxG.height - 48, 0, "", 20);
		optionDesc.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		optionDesc.textField.background = true;
		optionDesc.textField.backgroundColor = FlxColor.BLACK;
		refresh();
		optionDesc.visible = false;
		add(optionDesc);
	}

	function refresh()
	{
		curSelected = category.curSelected;
		optionText.clear();
		for (i in 0...category.options.length)
		{
			optionText.add(category.options[i]);
			var text = category.options[i].createOptionText(curSelected, optionText);
			text.targetY = i;
		}

		changeSelection(0);
	}

	function changeSelection(?diff:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected += diff;

		if (curSelected < 0)
			curSelected = Std.int(category.options.length) - 1;
		if (curSelected >= Std.int(category.options.length))
			curSelected = 0;

		for (i in 0...optionText.length)
		{
			var item = optionText.members[i];
			item.text.targetY = i - curSelected;
			item.text.alpha = 0.6;
			var wasSelected = item.isSelected;
			item.isSelected = item.text.targetY == 0;
			if (item.isSelected)
			{
				item.text.alpha = 1;
				item.selected();
				if (item.description != null && item.description.replace(" ", "") != '')
				{
					optionDesc.visible = true;
					optionDesc.text = item.description;
				}
				else
				{
					optionDesc.visible = false;
				}
			}
			else if (wasSelected)
			{
				item.deselected();
			}
		}

		category.curSelected = curSelected;
	}

	override function update(elapsed:Float)
	{
		var upP = false;
		var downP = false;
		var leftP = false;
		var rightP = false;
		var accepted = false;
		var back = false;
		if (controls.keyboardScheme != None)
		{
			upP = controls.UI_UP_P;
			downP = controls.UI_DOWN_P;
			leftP = controls.UI_LEFT_P;
			rightP = controls.UI_RIGHT_P;

			accepted = controls.ACCEPT;
			back = controls.BACK;
		}

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		var option = category.options[curSelected];

		if (back)
		{
			if (category != defCat)
			{
				category.curSelected = 0;
				category = category.parent;
				refresh();
			}
			else
			{
				if (!isInPause)
					FlxG.switchState(new MainMenuState());
				else
				{
					PauseSubState.goBack = true;
					close();
				}
				Debug.logTrace("Save options");
				OptionUtils.saveOptions(OptionUtils.options);
			}
		}
		if (option.type != "Category")
		{
			if (leftP)
			{
				if (option.left())
				{
					option.createOptionText(curSelected, optionText);
					changeSelection();
				}
			}
			if (rightP)
			{
				if (option.right())
				{
					option.createOptionText(curSelected, optionText);
					changeSelection();
				}
			}
		}

		if (option.allowMultiKeyInput)
		{
			var pressed = FlxG.keys.firstJustPressed();
			var released = FlxG.keys.firstJustReleased();
			if (pressed != -1)
			{
				if (option.keyPressed(pressed))
				{
					option.createOptionText(curSelected, optionText);
					changeSelection();
				}
			}
			if (released != -1)
			{
				if (option.keyReleased(released))
				{
					option.createOptionText(curSelected, optionText);
					changeSelection();
				}
			}
		}

		if (accepted)
		{
			Debug.logTrace("shit");
			if (option.type == 'Category')
			{
				category = option;
				refresh();
			}
			else if (option.accept())
			{
				option.createOptionText(curSelected, optionText);
			}
			changeSelection();
			Debug.logTrace("cum");
		}

		if (option.forceupdate)
		{
			option.forceupdate = false;
			// optionText.remove(optionText.members[curSelected]);
			option.createOptionText(curSelected, optionText);
			changeSelection();
		}
		super.update(elapsed);
	}
}
