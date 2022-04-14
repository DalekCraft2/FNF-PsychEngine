package options;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import options.Options;

using StringTools;

class OptionsSubState extends MusicBeatSubState
{
	public static var instance:OptionsSubState;
	public static var isInPause:Bool;
	private static var category:OptionCategory;

	private var defCat:OptionCategory;
	private var optionText:FlxTypedGroup<Option>;
	private var optionDesc:FlxText;
	private var curSelected:Int = 0;

	public function new(isInPause:Bool = false)
	{
		super();

		OptionsSubState.isInPause = isInPause;
	}

	// TODO Make some of these not changeable whilst in PlayState, like in Kade Engine
	// TODO Also, try to sort these a bit, maybe?
	public function createDefault():Void
	{
		defCat = new OptionCategory('Default', [
			new OptionCategory('Gameplay', [
				new OptionCategory('Controls',
					[
						// TODO Reimplement the ability to change the second keybind
						// TODO Make option categories for these five control groups? (Notes, UI, Misc., Volume, Debug)
						new ControlOption('note_left', controls),
						new ControlOption('note_down', controls),
						new ControlOption('note_up', controls),
						new ControlOption('note_right', controls),

						new ControlOption('ui_left', controls),
						new ControlOption('ui_down', controls),
						new ControlOption('ui_up', controls),
						new ControlOption('ui_right', controls),

						new ControlOption('accept', controls),
						new ControlOption('back', controls),
						new ControlOption('pause', controls),
						new ControlOption('reset', controls),

						new ControlOption('volume_mute', controls, (keys:Array<FlxKey>) ->
						{
							InitState.muteKeys = Options.copyKey(Options.save.data.keyBinds.get('volume_mute'));
							FlxG.sound.muteKeys = InitState.muteKeys;
						}),
						new ControlOption('volume_up', controls, (keys:Array<FlxKey>) ->
						{
							InitState.volumeUpKeys = Options.copyKey(Options.save.data.keyBinds.get('volume_up'));
							FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;
						}),
						new ControlOption('volume_down', controls,
							(keys:Array<FlxKey>) ->
							{
								InitState.volumeDownKeys = Options.copyKey(Options.save.data.keyBinds.get('volume_down'));
								FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
							}),

						new ControlOption('debug_1', controls),
						new ControlOption('debug_2', controls)
					]),
				new BooleanOption('controllerMode', 'Controller Mode', 'Toggle playing with a controller instead of a keyboard.'),
				new BooleanOption('resetKey', 'Reset Key', 'Toggle pressing the Reset keybind to game-over.'),
				#if FEATURE_LUA new BooleanOption('loadLuaScripts', 'Load Lua Scripts', 'Toggle lua scripts.'),
				#end
				new BooleanOption('ghostTapping', 'Ghost-Tapping', 'Toggle being able to pressing keys while no notes are able to be hit.'),
				// TODO Finish the descriptions of these
				// TODO Make this option change the suffix of the scrollSpeed option when changed
				new StringOption('scrollType', 'Scroll Type', 0, 1, ['multiplicative', 'constant']),
				new FloatOption('scrollSpeed', 'Scroll Speed', 0.1, 0.5, (Options.save.data.scrollType == 'multiplicative' ? 3 : 6),
					(Options.save.data.scrollType == 'multiplicative' ? 'X' : '')),
				new FloatOption('healthGain', 'Health Gain Multiplier', 0.1, 0, 5, 'X'),
				new FloatOption('healthLoss', 'Health Loss Multiplier', 0.1, 0.5, 5, 'X'),
				new BooleanOption('instakillOnMiss', 'Instakill on Miss', 'Toggle instantly getting a game over after a miss.'),
				new BooleanOption('practiceMode', 'Practice Mode'),
				new BooleanOption('botPlay', 'BotPlay', 'Let a bot play for you.'),
				// TODO Try to rename this and change the description because it looks like the same thing as sickWindow
				new IntegerOption('ratingOffset', 'Rating Offset',
					'Change how late/early a note must be hit for a "Sick!". Higher values mean notes must be hit later.', 1, -30, 30, 'ms'),
				new IntegerOption('sickWindow', 'Sick! Hit Window', 'Change the hit window for hitting a "Sick!", in milliseconds.', 1, 15, 45, 'ms'),
				new IntegerOption('goodWindow', 'Good Hit Window', 'Change the hit window for hitting a "Good", in milliseconds.', 1, 15, 90, 'ms'),
				new IntegerOption('badWindow', 'Bad Hit Window', 'Change the hit window for hitting a "Bad", in milliseconds.', 1, 15, 135, 'ms'),
				new FloatOption('safeFrames', 'Safe Frames', 'Changes how many frames you have for hitting a note earlier or later.', 0.1, 2, 10, 'ms'),
				// new IntegerOption('noteOffset', 'Note Delay', 'Change how late a note is spawned.\nUseful for preventing audio lag from wireless earphones.',
				// 	1, 0, 500, 'ms'),
				// new StateOption('Delay and Combo Offset', new NoteOffsetState()),
				// new StringOption('accuracySystem', 'Accuracy System', 'How accuracy is calculated.', 0, 2, ['Basic', 'Stepmania', 'Wife3']),
				// new BooleanOption('attemptToAdjust', 'Better Sync',
				// 	'Have the game attempt to sync the song position to the instrumental better by using the average offset between the\ninstrumental and the visual position.'),
				// new StateOption('Calibrate Offset', new SoundOffsetState()) // TODO: make a better 'calibrate offset'
			]),
			new OptionCategory('Appearance', [
				new StateOption('Note Colors', new NoteColorState()),
				new BooleanOption('showComboCounter', 'Show Combo', 'Show the combo pop-up when a note is hit.'),
				new BooleanOption('showRatings', 'Show Judgements', 'Show judgements when a note is hit.'),
				new BooleanOption('showHitMS', 'Show Hit MS', 'Show millisecond difference when a note is hit.'),
				new BooleanOption('showCounters', 'Show Judgement Counters', 'Toggle the judgement counters on the side of the screen.'),
				new BooleanOption('downScroll', 'DownScroll', 'Arrows come from the top down instead of the bottom up.'),
				new BooleanOption('middleScroll', 'MiddleScroll', 'Place your notes in the center of the screen and hides the opponent\'s.'),
				new BooleanOption('allowNoteModifiers', 'Allow Note Modifiers', 'Toggle whether note modifiers (e.g pixel notes in week 6) get used.'),
				new FloatOption('bgAlpha', 'BG Opacity', 'How opaque the background is.', 10, 0, 100, '%', '', true),
				new StringOption('cameraFocus', 'Camera Focus', 'Who the camera should focus on.', 0, 3, ['Default', 'BF', 'Dad', 'Center']),
				new BooleanOption('healthBarColors', 'Healthbar Colors', 'Whether the healthbar color changes with the character.'),
				new BooleanOption('onlyScore', 'Minimal Information', 'Only show the score below the HP Bar'),
				new BooleanOption('smoothHPBar', 'Smooth Healthbar', 'Make the HP Bar smoother.'),
				new BooleanOption('fcBasedComboColor', 'FC Combo Coloring', 'Make the combo\'s color change depending on the combo rank.'),
				new BooleanOption('holdsBehindStrums', 'Stepmania Clipping', 'Make note holds clip behind the strums.'),
				// new NoteskinOption('noteSkin', 'NoteSkin', 'The noteskin to use.'),
				new OptionCategory('Effects', [
					new BooleanOption('picoCameraShake', 'Train Camera Shake', 'Whether the train in week 3\'s background shakes the camera.'),
					new StringOption('senpaiShaderStrength', 'Week 6 Shaders', 'How strong the week 6 shaders are.', 0, 2, ['Off', 'CRT', 'All'])
				])
			]),
			new OptionCategory('Preferences', [
				new BooleanOption('noteSplashes', 'Show NoteSplashes', 'Whether notesplashes show up on Sicks and above.'),
				new BooleanOption('camFollowsAnims', 'Directional Camera', 'Toggle moving the camera when a note is hit.'),
				new BooleanOption('hideHUD', 'Hide HUD', 'Hide most HUD elements.'),
				new StringOption('timeBarType', 'Time Bar', 'Change what is displayed on the Time Bar.', 0, 3,
					['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']),
				new BooleanOption('scoreScreen', 'Score Screen', 'Show the score screen after the end of a song.'),
				new BooleanOption('inputShow', 'Score Screen Debug', 'Display every input on the score screen.'),
				new BooleanOption('accuracyDisplay', 'Accuracy Display', 'Display accuracy information on the info bar.'),
				new BooleanOption('npsDisplay', 'NPS Display', 'Shows your current Notes Per Second on the info bar.'),
				new BooleanOption('flashing', 'Flashing Lights', 'Uncheck this if you\'re sensitive to flashing lights!'),
				new BooleanOption('camZooms', 'Camera Zooms', 'Whether the camera zooms on each beat hit.'),
				new BooleanOption('scoreZoom', 'Score Text Zoom on Hit', 'Whether the Score text should zoom everytime a note is hit.'),
				new FloatOption('healthBarAlpha', 'Health Bar Opacity', 'How opaque the health bar and icons should be.', 0.1, 0, 1, true),
				new BooleanOption('ratingInHUD', 'Fixed Judgements', 'Fix judgements, milliseconds, and combo to the screen.'),
				new BooleanOption('ratingOverNotes', 'Judgements over Notes', 'Place judgements, milliseconds and combo above the playfield.'),
				new BooleanOption('smJudges', 'Simply Judgements', 'Use judgement animated like ITG\'s Simply Love theme.'),
				new BooleanOption('persistentCombo', 'Simply Combos', 'Use combos animated like ITG\'s Simply Love theme.'),
				new BooleanOption('pauseHoldAnims', 'Holds Pause Animations', 'Whether to pause animations on their first frame.'),
				new BooleanOption('menuFlash', 'Flashing in Menus', 'Whether buttons and the background should flash in menus.'),
				new BooleanOption('hitSound', 'Hit Sounds', 'Play a click sound when a note is hit.'),
				new BooleanOption('showFPS', 'Show FPS', 'Show the current FPS in the top left.'),
				new BooleanOption('showMem', 'Show Memory', 'Show the memory usage in the top left.'),
				new BooleanOption('showMemPeak', 'Show Memory Peak', 'Show the peak memory usage in the top left.'),
				new StringOption('pauseMusic', 'Pause Screen Song', 'The song which plays in the pause menu.', 0, 2, ['None', 'Breakfast', 'Tea Time'],
					(index:Int, name:String, indexAdd:Int) ->
					{
						if (name == 'None')
							FlxG.sound.music.volume = 0;
						else
							FlxG.sound.playMusic(Paths.getMusic(Paths.formatToSongPath(name)));

						// changedMusic = true;
					}),
				new BooleanOption('ghostTapSounds', 'Ghost-Tap Hit Sounds', 'Play a click sound for each ghost-tap.'),
				new FloatOption('hitSoundVolume', 'Hit Sound Volume', 'The volume used for the hit sounds.', 10, 0, 100, '%', '', true),
				new BooleanOption('fastTransitions', 'Fast Transitions', 'Makes transitions between states faster.'),
				// new StateOption('Judgement Position', new JudgeCustomizationState())
			]),
			new OptionCategory('Performance', [
				new IntegerOption('frameRate', 'FPS Cap', 'The FPS the game tries to run at.', 30, 30, 360, '', '', (value:Float, step:Float) ->
				{
					Main.setFPSCap(value);
				}),
				new BooleanOption('recycleComboJudges', 'Recycling',
					'Instead of making a new sprite for each judgement and combo number, objects are reused when possible.\nMay cause layering issues.'),
				new BooleanOption('lowQuality', 'Low Quality', 'Disables some background details,\ndecreases loading times, and improves performance.'),
				new BooleanOption('noChars', 'Hide Characters', 'Hide characters in-game.'),
				new BooleanOption('noStage', 'Hide Background', 'Hide stages in-game.'),
				new BooleanOption('globalAntialiasing', 'Antialiasing', 'Toggle the ability for sprites to have antialiasing.'),
				new BooleanOption('allowOrderSorting', 'Sort Notes by Order',
					'Allows notes to go infront and behind other notes. May cause FPS drops on very high note-density charts.'),
				/*new OptionCategory('Caching', [
						new BooleanOption('shouldCache', 'Cache on Startup', 'Whether the engine caches assets when the game starts.'),
						new BooleanOption('cacheSongs', 'Cache Songs', 'Whether the engine caches songs if it caches on startup.'),
						new BooleanOption('cacheSounds', 'Cache Sounds', 'Whether the engine caches misc sounds if it caches on startup.'),
						new BooleanOption('cacheImages', 'Cache Images', 'Whether the engine caches misc images if it caches on startup.'),
						new BooleanOption('persistentImages', 'Persistent Images', 'Whether images should persist in memory.', (state:Bool) ->
						{
							FlxGraphic.defaultPersist = state;
						})
					]) */
			]),
			// TODO Get replays to work (First issue: sustains crash the game)
			// new StateOption('Replays', new LoadReplayState())
		]);
	}

	override public function create():Void
	{
		super.create();

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Changing options', null);
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

		optionDesc = new FlxText(5, FlxG.height - 48, 0, 20);
		optionDesc.setFormat(Paths.font('vcr.ttf'), optionDesc.size, LEFT, OUTLINE, FlxColor.BLACK);
		optionDesc.textField.background = true;
		optionDesc.textField.backgroundColor = FlxColor.BLACK;
		refresh();
		optionDesc.visible = false;
		add(optionDesc);
	}

	private function refresh():Void
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

	private function changeSelection(?diff:Int = 0):Void
	{
		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
		curSelected += diff;

		if (curSelected < 0)
			curSelected = category.options.length - 1;
		if (curSelected >= category.options.length)
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
				if (item.description != null && item.description.replace(' ', '') != '')
				{
					optionDesc.visible = true;
					optionDesc.text = item.description;
					optionDesc.updateHitbox();
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

	override public function update(elapsed:Float):Void
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
				Debug.logTrace('Save options');
				Options.flushSave();
			}
		}
		if (!Std.isOfType(option, OptionCategory))
		{
			if (leftP)
			{
				if (option.left())
				{
					option.updateOptionText();
					changeSelection();
				}
			}
			if (rightP)
			{
				if (option.right())
				{
					option.updateOptionText();
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
					option.updateOptionText();
					changeSelection();
				}
			}
			if (released != NONE)
			{
				if (option.keyReleased(released))
				{
					option.updateOptionText();
					changeSelection();
				}
			}
		}

		if (accepted)
		{
			if (Std.isOfType(option, OptionCategory))
			{
				category = cast option;
				refresh();
			}
			else if (option.accept())
			{
				option.updateOptionText();
			}
			changeSelection();
		}

		if (Std.isOfType(option, ControlOption))
		{
			var controlOption:ControlOption = cast option;
			if (controlOption.forceUpdate)
			{
				controlOption.forceUpdate = false;
				// optionText.remove(optionText.members[curSelected]);
				controlOption.updateOptionText();
				changeSelection();
			}
		}
	}
}
