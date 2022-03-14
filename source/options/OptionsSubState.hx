package options;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
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

	public static var category:OptionCategory;

	public static var isInPause:Bool = false;

	public function new(isInPause:Bool = false)
	{
		super();

		OptionsSubState.isInPause = isInPause;
	}

	// TODO Make some of these not changeable whilst in PlayState, like in Kade Engine
	public function createDefault():Void
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
				new BooleanOption("controllerMode", false, "Controller Mode",
					"Check this if you want to play with a controller instead of using your Keyboard."),
				new BooleanOption("resetKey", true, "Reset Key", "Toggle pressing the bound key to instantly die"),
				#if !FORCE_LUA_MODCHARTS new BooleanOption("loadModcharts", true, "Load Lua modcharts", "Toggles lua modcharts"),
				#end
				new BooleanOption("ghostTapping", true, "Ghost-Tapping", "Allows you to press keys while no notes are able to be hit."),
				// TODO Finish the descriptions of these
				// TODO Make this option change the suffix of the scrollSpeed option when changed
				new StringOption("scrollType", 'multiplicative', "Scroll Type", "", 0, 1,
					["multiplicative", "constant"] /*,
						(i1, s, i2) ->
						{
							if (defCat != null)
							{
								var gameplayCategory:OptionCategory = defCat.options[0];

							}
					}*/),

				new FloatOption("scrollSpeed", 1, "Scroll Speed", 0.1, 0.5, (OptionUtils.options.scrollType == 'multiplicative' ? 3 : 6),
					(OptionUtils.options.scrollType == 'multiplicative' ? "X" : "")),
				new FloatOption("healthGain", 1, "Health Gain Multiplier", 0.1, 0, 5, "X"),
				new FloatOption("healthLoss", 1, "Health Loss Multiplier", 0.1, 0.5, 5, "X"),
				new BooleanOption("instakill", false, "Instakill on Miss", "FC or die"),
				new BooleanOption("practice ", false, "Practice Mode", ""),
				#if !NO_BOTPLAY new BooleanOption("botPlay", false, "BotPlay", "Let a bot play for you"), #end
				// new FloatOption("noteOffset", 0, "Note Delay", "Changes how late a note is spawned.\nUseful for preventing audio lag from wireless earphones.",
				// 	1, 0, 500, "ms", ""),
				new FloatOption("ratingOffset", 0, "Rating Offset",
					"Changes how late/early you have to hit for a \"Sick!\" Higher values mean you have to hit later.", 1, -30, 30, "ms"),
				new FloatOption("sickWindow", 45, "Sick! Hit Window", "Changes the amount of time you have for hitting a \"Sick!\" in milliseconds.", 1, 15,
					45, "ms"),
				new FloatOption("goodWindow", 90, "Good Hit Window", "Changes the amount of time you have for hitting a \"Good\" in milliseconds.", 1, 15, 90,
					"ms"),
				new FloatOption("badWindow", 135, "Bad Hit Window", "Changes the amount of time you have for hitting a \"Bad\" in milliseconds.", 1, 15, 135,
					"ms"),
				new FloatOption("safeFrames", 10, "Safe Frames", "Changes how many frames you have for hitting a note earlier or later.", 0.1, 2, 10, "ms"),
				#if !NO_FREEPLAY_MODS
				/*new OptionCategory("Freeplay Modifiers", [
						new FloatOption("cMod", 0, "Speed Constant", "A constant speed to override the scroll speed. 0 for chart-dependant speed", 0.1, 0,
							10, "", "", true),
						new FloatOption("xMod", 1, "Speed Mult", "A multiplier to a chart's scroll speed", 0.1, 0, 2, "", "x", true),
						new FloatOption("mMod", 1, "Minimum Speed", "The minimum scroll speed a chart can have", 0.1, 0, 10, "", "", true),
						new BooleanOption("noFail", false, "No Fail", "You can't blueball, but there's an indicator that you failed and you don't save the score."),
					]), */
				new StateOption("Delay and Combo Offset", new NoteOffsetState()),
				#end
				/*new OptionCategory("Advanced", [
						#if !FORCED_JUDGE new JudgementsOption("judgementWindow", "ITG", "Judgements",
							"The judgement windows to use"), new BooleanOption("useEpic", true, "Use Epics", "Allows the 'Epic' judgement to be used"),
						#end
						new StringOption("accuracySystem", "Basic", "Accuracy System", "How accuracy is determined", 0, 2, ["Basic", "Stepmania", "Wife3"]),
						// new BooleanOption("attemptToAdjust", false, "Better Sync", "Attempts to sync the song position to the instrumental better by using the average offset between the\ninstrumental and the visual pos")
					]
					), */
				new StateOption("Calibrate Offset", new SoundOffsetState()) // TODO: make a better 'calibrate offset'
			]),
			new OptionCategory("Appearance", [
				new StateOption("Note Colors", new NotesState()),
				new BooleanOption("showComboCounter", true, "Show Combo", "Shows your combo when you hit a note"),
				new BooleanOption("showRatings", true, "Show Judgements", "Shows judgements when you hit a note"),
				new BooleanOption("showMS", false, "Show Hit MS", "Shows millisecond difference when you hit a note"),
				new BooleanOption("showCounters", true, "Show Judgement Counters", "Whether judgement counters get shown on the side"),
				new BooleanOption("downScroll", false, "Downscroll", "Arrows come from the top down instead of the bottom up."),
				new BooleanOption("middleScroll", false, "Centered Notes",
					"Places your notes in the center of the screen and hides the opponent's. \"Middlescroll\""),
				new BooleanOption("allowNoteModifiers", true, "Allow Note Modifiers", "Whether note modifiers (e.g pixel notes in week 6) get used"),
				new FloatOption("backTrans", 0, "BG Darkness", "How dark the background is", 10, 0, 100, "%", "", true),
				new StringOption("staticCam", "Default", "Camera Focus", "Who the camera should focus on", 0, 3, ["Default", "BF", "Dad", "Center"]),
				// new BooleanOption("oldMenus", false, "Vanilla Menus", "Forces the vanilla menus to be used"),
				// new BooleanOption("oldTitle", false, "Vanilla Title Screen", "Forces the vanilla title to be used"),
				new BooleanOption("healthBarColors", true, "Healthbar Colours", "Whether the healthbar colour changes with the character"),
				new BooleanOption("onlyScore", false, "Minimal Information", "Only shows your score below the hp bar"),
				new BooleanOption("smoothHPBar", false, "Smooth Healthbar", "Makes the HP Bar smoother"),
				new BooleanOption("fcBasedComboColor", false, "FC Combo Colouring", "Makes the combo's colour changes with type of FC you have"),
				new BooleanOption("holdsBehindReceptors", false, "Stepmania Clipping", "Makes holds clip behind the receptors"),
				// new NoteskinOption("noteSkin", "NoteSkin", "The noteskin to use"),
				new OptionCategory("Effects", [
					new BooleanOption("picoCamshake", true, "Train camera shake", "Whether the train in week 3's background shakes the camera"),
					// new BooleanOption("senpaiShaders", true, "Week 6 shaders","Is the CRT effect active in week 6"),
					new StringOption("senpaiShaderStrength", "All", "Week 6 shaders", "How strong the week 6 shaders are", 0, 2, ["Off", "CRT", "All"])
				])
			]),
			new OptionCategory("Preferences", [
				new BooleanOption("noteSplashes", true, "Show NoteSplashes", "Notesplashes showing up on sicks and above."),
				new BooleanOption("camFollowsAnims", false, "Directional Camera", "Camera moving depending on a character's animations"),
				new BooleanOption("hideHud", false, "Hide HUD", "If checked, hides most HUD elements."),
				new StringOption("timeBarType", "Time Left", "Time Bar", "What should the Time Bar display?", 0, 3,
					['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']),
				new BooleanOption("scoreScreen", false, "Score Screen", "Show the score screen after the end of a song"),
				new BooleanOption("inputShow", false, "Score Screen Debug", "Display every single input on the score screen."),
				new BooleanOption("accuracyDisplay", true, "Accuracy Display", "Display accuracy information on the info bar."),
				new BooleanOption("npsDisplay", false, "NPS Display", "Shows your current Notes Per Second on the info bar."),
				new BooleanOption("flashing", true, "Flashing Lights", "Uncheck this if you're sensitive to flashing lights!"),
				new BooleanOption("camZooms", true, "Camera Zooms", "If unchecked, the camera won't zoom in on a beat hit."),
				new BooleanOption("scoreZoom", true, "Score Text Zoom on Hit", "If unchecked, disables the Score text zooming\neverytime you hit a note."),
				new FloatOption("healthBarAlpha", 1, "Health Bar Transparency", "How much transparent should the health bar and icons be.", 0.1, 0, 1, true),
				new BooleanOption("ratingInHUD", false, "Fixed Judgements", "Fixes judgements, milliseconds and combo to the screen"),
				new BooleanOption("ratingOverNotes", false, "Judgements over Notes", "Places judgements, milliseconds and combo above the playfield"),
				new BooleanOption("smJudges", false, "Simply Judgements", "Animates judgements like ITG's Simply Love theme"),
				new BooleanOption("persistentCombo", false, "Simply Combos", "Animates combos like ITG's Simply Love theme"),
				new BooleanOption("pauseHoldAnims", true, "Holds Pause Animations", "Whether to pause animations on their first frame"),
				new BooleanOption("menuFlash", true, "Flashing in Menus", "Whether buttons and the background should flash in menus"),
				new BooleanOption("hitSound", false, "Hit Sounds", "Play a click sound when you hit a note"),
				new BooleanOption("showFPS", false, "Show FPS", "Shows your FPS in the top left", (state:Bool) ->
				{
					FPSMem.showFPS = state;
				}),
				new BooleanOption("showMem", false, "Show Memory", "Shows memory usage in the top left", (state:Bool) ->
				{
					FPSMem.showMem = state;
				}),
				new BooleanOption("showMemPeak", false, "Show Memory Peak", "Shows peak memory usage in the top left",
					(state:Bool) ->
					{
						FPSMem.showMemPeak = state;
					}),
				new StringOption("pauseMusic", "Tea Time", "Pause Screen Song", "What song do you prefer for the Pause Screen?", 0, 2,
					["None", "Breakfast", "Tea Time"],
					(index:Int, name:String, indexAdd:Int) ->
					{
						if (name == 'None')
							FlxG.sound.music.volume = 0;
						else
							FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(name)));

						// changedMusic = true;
					}),
				new BooleanOption("ghosttapSounds", false, "Ghost-tap Hit Sounds", "Play a click sound when you ghost-tap"),
				new FloatOption("hitsoundVol", 50, "Hit Sound Volume", "What volume the hitsound should be", 10, 0, 100, "%", "", true),
				// new BooleanOption("freeplayPreview", false, "Song Preview in Freeplay", "Whether songs get played as you hover over them in Freeplay"),
				new BooleanOption("fastTransitions", false, "Fast Transitions", "Makes transitions between states faster"),
				// new StateOption("Judgement Position", new JudgeCustomizationState())
			]),
			new OptionCategory("Performance", [
				new FloatOption("framerate", 120, "FPS Cap", "The FPS the game tries to run at", 30, 30, 360, "", "", true, (value:Float, step:Float) ->
				{
					Main.setFPSCap(Std.int(value));
				}),
				new BooleanOption("recycleComboJudges", false, "Recycling",
					"Instead of making a new sprite for each judgement and combo number, objects are reused when possible.\nMay cause layering issues."),
				new BooleanOption("lowQuality", false, "Low Quality",
					"If checked, disables some background details,\ndecreases loading times and improves performance."),
				new BooleanOption("noChars", false, "Hide Characters", "Hides characters ingame"),
				new BooleanOption("noStage", false, "Hide Background", "Hides stage ingame"),
				new BooleanOption("globalAntialiasing", true, "Antialiasing", "Toggles the ability for sprites to have antialiasing"),
				new BooleanOption("allowOrderSorting", true, "Sort notes by order",
					"Allows notes to go infront and behind other notes. May cause FPS drops on very high note-density charts."),
				/*new OptionCategory("Caching", [
						new BooleanOption("shouldCache", false, "Cache on startup", "Whether the engine caches stuff when the game starts"),
						new BooleanOption("cacheSongs", false, "Cache songs", "Whether the engine caches songs if it caches on startup"),
						new BooleanOption("cacheSounds", false, "Cache sounds", "Whether the engine caches misc sounds if it caches on startup"),
						new BooleanOption("cacheImages", false, "Cache images", "Whether the engine caches misc images if it caches on startup"),
						new BooleanOption("persistentImages", false, "Persistent Images", "Whether images should persist in memory", (state:Bool) ->
						{
							FlxGraphic.defaultPersist = state;
						})
					]) */
			])
		]);
	}

	override function create():Void
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

		optionText = new FlxTypedGroup();
		add(optionText);

		optionDesc = new FlxText(5, FlxG.height - 48, 0, "", 20);
		optionDesc.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		optionDesc.textField.background = true;
		optionDesc.textField.backgroundColor = FlxColor.BLACK;
		refresh();
		optionDesc.visible = false;
		add(optionDesc);
	}

	function refresh():Void
	{
		curSelected = category.curSelected;
		optionText.clear();
		for (i in 0...category.options.length)
		{
			optionText.add(category.options[i]);
			var text:Alphabet = category.options[i].createOptionText(curSelected, optionText);
			text.targetY = i;
		}

		changeSelection(0);
	}

	function changeSelection(?diff:Int = 0):Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected += diff;

		if (curSelected < 0)
			curSelected = Std.int(category.options.length) - 1;
		if (curSelected >= Std.int(category.options.length))
			curSelected = 0;

		for (i in 0...optionText.length)
		{
			var item:Option = optionText.members[i];
			item.text.targetY = i - curSelected;
			item.text.alpha = 0.6;
			var wasSelected:Bool = item.isSelected;
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

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var upP:Bool = false;
		var downP:Bool = false;
		var leftP:Bool = false;
		var rightP:Bool = false;
		var accepted:Bool = false;
		var back:Bool = false;
		if (controls.keyboardScheme != NONE)
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

		var option:Option = category.options[curSelected];

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
			var pressed:FlxKey = FlxG.keys.firstJustPressed();
			var released:FlxKey = FlxG.keys.firstJustReleased();
			if (pressed != NONE)
			{
				if (option.keyPressed(pressed))
				{
					option.createOptionText(curSelected, optionText);
					changeSelection();
				}
			}
			if (released != NONE)
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
				category = cast(option, OptionCategory);
				refresh();
			}
			else if (option.accept())
			{
				option.createOptionText(curSelected, optionText);
			}
			changeSelection();
			Debug.logTrace("cum");
		}

		if (Std.isOfType(option, ControlOption))
		{
			var controlOption:ControlOption = cast(option, ControlOption);
			if (controlOption.forceUpdate)
			{
				controlOption.forceUpdate = false;
				// optionText.remove(optionText.members[curSelected]);
				controlOption.createOptionText(curSelected, optionText);
				changeSelection();
			}
		}
	}
}
