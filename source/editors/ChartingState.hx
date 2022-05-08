package editors;

import Character.CharacterDef;
import Conductor.BPMChangeEvent;
import Section.SectionDef;
import Song.SongDef;
import Song.SongMetadataDef;
import Song.SongWrapper;
import flash.geom.Rectangle;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import lime.media.AudioBuffer;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class ChartingState extends MusicBeatState
{
	// Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	public static final NOTE_TYPES:Array<String> = ['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation'];
	public static final GRID_SIZE:Int = 40;

	private static final CAM_OFFSET:Int = 360;

	private static final TIP_TEXT:String = 'W/S or Mouse Wheel - Change Conductor\'s strum time\nA or Left/D or Right - Go to the previous/next section\nHold Shift to move 4x faster\nHold Control and click on an arrow to select it\nZ/X - Zoom in/out\n\nEsc - Test your chart inside Chart Editor\nEnter - Play your chart\nQ/E - Decrease/Increase Note Sustain Length\nSpace - Stop/Resume song';

	private var noteTypeIntMap:Map<Int, String> = [];
	private var noteTypeMap:Map<String, Null<Int>> = [];

	private var ignoreWarnings:Bool = false;

	private var undos:Array<Array<SectionDef>> = [];
	private var redos:Array<Array<SectionDef>> = [];
	private var eventList:Array<Array<String>> = [
		['', 'Nothing. Yep, that\'s right.'],
		[
			'Hey!',
			'Plays the "Hey!" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s'
		],
		[
			'Set GF Speed',
			'Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!'
		],
		[
			'Blammed Lights',
			'Value 1: 0 = Turn off, 1 = Blue, 2 = Green,\n3 = Pink, 4 = Red, 5 = Orange, Anything else = Random.\n\nNote to modders: This effect is starting to get \nREEEEALLY overused, this isn\'t very creative bro smh.'
		],
		['Kill Henchmen', 'For Mom\'s songs, don\'t use this please, i love them :('],
		[
			'Add Camera Zoom',
			'Used on MILF on that one "hard" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default.'
		],
		['BG Freaks Expression', 'Should be used only in "school" Stage!'],
		['Trigger BG Ghouls', 'Should be used only in "schoolEvil" Stage!'],
		[
			'Play Animation',
			'Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)'
		],
		[
			'Camera Follow Pos',
			'Value 1: X\nValue 2: Y\n\nThe camera won\'t change the follow point\nafter using this, for getting it back\nto normal, leave both values blank.'
		],
		[
			'Alt Idle Animation',
			'Sets a specified suffix after the idle animation name.\nYou can use this to trigger "idle-alt" if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)'
		],
		[
			'Screen Shake',
			'Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: "1, 0.05".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity.'
		],
		[
			'Change Character',
			'Value 1: Character to change (Dad, BF, GF)\nValue 2: New character\'s name'
		],
		[
			'Change Scroll Speed',
			'Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds.'
		]
	];

	private var _file:FileReference;

	private var UI_box:FlxUITabMenu;

	// TODO I am pretty sure this comment is misplaced

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	private static var curSection:Int = 0;

	private static var lastSong:String = '';

	private var bpmTxt:FlxText;

	private var camPos:FlxObject;
	private var strumLine:FlxSprite;
	private var quant:AttachedSprite;
	private var strumLineNotes:FlxTypedGroup<StrumNote>;
	private var bullshitUI:FlxGroup;

	private var dummyArrow:FlxSprite;

	private var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	private var curRenderedNotes:FlxTypedGroup<Note>;
	private var curRenderedNoteType:FlxTypedGroup<FlxText>;

	private var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	private var nextRenderedNotes:FlxTypedGroup<Note>;

	private var gridBG:FlxSprite;
	private var gridMult:Int = 2;

	private var daquantspot:Int = 0;
	private var curEventSelected:Int = 0;
	private var _song:SongDef;

	/**
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	 */
	private var curSelectedNote:Array<Dynamic>;

	private var tempBpm:Float = 0;

	private var vocals:FlxSound;

	private var leftIcon:HealthIcon;
	private var rightIcon:HealthIcon;

	private var value1InputText:FlxUIInputText;
	private var value2InputText:FlxUIInputText;
	private var currentSongName:String;

	private var zoomTxt:FlxText;
	private var curZoom:Int = 1;

	// TODO Is this even necessary? The chart editor is not accessible on HTML5, because file writing is not possible.
	#if !html5
	private var zoomList:Array<Float> = [0.5, 1, 2, 4, 8, 12, 16, 24];
	#else // The grid gets all black when over 1/12 snap
	private var zoomList:Array<Float> = [0.5, 1, 2, 4, 8, 12];
	#end

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	private var waveformSprite:FlxSprite;
	private var gridLayer:FlxTypedGroup<FlxSprite>;

	private var quants:Array<Float> = [
		4, // quarter
		2, // half
		4 / 3,
		1,
		4 / 8 // eight
	];

	private static var curQuant:Int = 0;

	private static var vortex:Bool = false;

	override public function create():Void
	{
		super.create();

		TimingStruct.clearTimings();

		if (PlayState.song != null)
			_song = PlayState.song;
		else
		{
			_song = Song.createTemplateSongDef();
			addSection();
			PlayState.song = _song;
		}

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Chart Editor', _song.songName);
		#end

		vortex = EngineData.save.data.chart_vortex;
		ignoreWarnings = EngineData.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		gridLayer = new FlxTypedGroup();
		add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.getGraphic('eventArrow'));
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		eventIcon.scrollFactor.set(1, 1);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(GRID_SIZE + 10, -100);
		rightIcon.setPosition(GRID_SIZE * 5.2, -100);

		curRenderedSustains = new FlxTypedGroup();
		curRenderedNotes = new FlxTypedGroup();
		curRenderedNoteType = new FlxTypedGroup();

		nextRenderedSustains = new FlxTypedGroup();
		nextRenderedNotes = new FlxTypedGroup();

		if (curSection >= _song.notes.length)
			curSection = _song.notes.length - 1;

		FlxG.mouse.visible = true;

		tempBpm = _song.bpm;

		addSection();

		currentSongName = _song.songId;
		loadAudioBuffer();
		reloadGridLayer();
		loadSong();
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		bpmTxt = new FlxText(1000, 50, 0, 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		add(strumLine);

		quant = new AttachedSprite('chart_quant', 'chart_quant');
		quant.animation.addByPrefix('q', 'chart_quant', 0, false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);

		strumLineNotes = new FlxTypedGroup();
		for (i in 0...8)
		{
			var note:StrumNote = new StrumNote(GRID_SIZE * (i + 1), strumLine.y, i % 4, 0);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		var tabs:Array<{name:String, label:String}> = [
			{name: 'Song', label: 'Song'},
			{name: 'Section', label: 'Section'},
			{name: 'Note', label: 'Note'},
			{name: 'Events', label: 'Events'},
			{name: 'Charting', label: 'Charting'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 400);
		UI_box.x = 640 + GRID_SIZE / 2;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		var tipText:FlxText = new FlxText(UI_box.x, UI_box.y + UI_box.height + 8, 0, TIP_TEXT, 16);
		tipText.setFormat(Paths.font('vcr.ttf'), tipText.size, LEFT);
		tipText.scrollFactor.set();
		add(tipText);

		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		updateHeads();
		updateWaveform();

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		if (lastSong != currentSongName)
		{
			changeSection();
		}
		lastSong = currentSongName;

		zoomTxt = new FlxText(10, 10, 0, 'Zoom: 1x', 16);
		zoomTxt.scrollFactor.set();
		add(zoomTxt);

		updateGrid();
	}

	private var lastConductorPos:Float;
	private var colorSine:Float = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		curStep = recalculateSteps();

		if (FlxG.sound.music.time < 0)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		_song.songId = UI_songTitle.text;

		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * _song.notes[curSection].lengthInSteps));
		for (strumNote in strumLineNotes.members)
		{
			strumNote.y = strumLine.y;
		}

		FlxG.mouse.visible = true; // cause reasons. trust me
		camPos.y = strumLine.y;
		if (!disableAutoScrolling.checked)
		{
			if (Math.ceil(strumLine.y) >= (gridBG.height / 2))
			{
				// Debug.logTrace(curStep);
				// Debug.logTrace((_song.notes[curSection].lengthInSteps) * (curSection + 1));

				if (_song.notes[curSection + 1] == null)
				{
					addSection();
				}

				changeSection(curSection + 1, false);
			}
			else if (strumLine.y < -10)
			{
				changeSection(curSection - 1, false);
			}
		}
		// Debug.quickWatch('Song Speed', songSpeed);
		Debug.quickWatch('BPM', Conductor.bpm);
		Debug.quickWatch('Beat', curBeat);
		Debug.quickWatch('Step', curStep);
		Debug.quickWatch('Section', curSection);

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEachAlive((note:Note) ->
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note);
							curSelectedNote[3] = noteTypeIntMap.get(currentType);
							updateGrid();
						}
						else
						{
							// Debug.logTrace('Trying to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps) * zoomList[curZoom])
				{
					addNote();
					Debug.logTrace('Added note');
				}
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps) * zoomList[curZoom])
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
				dummyArrow.y = Math.floor(FlxG.mouse.y / GRID_SIZE) * GRID_SIZE;
		}
		else
		{
			dummyArrow.visible = false;
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
				break;
			}
		}

		if (!blockInput)
		{
			for (stepper in blockPressWhileTypingOnStepper)
			{
				@:privateAccess
				var text:FlxUIInputText = cast stepper.text_field;
				if (text.hasFocus)
				{
					FlxG.sound.muteKeys = [];
					FlxG.sound.volumeDownKeys = [];
					FlxG.sound.volumeUpKeys = [];
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			FlxG.sound.muteKeys = InitState.muteKeys;
			FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;
			for (dropDownMenu in blockPressWhileScrolling)
			{
				if (dropDownMenu.dropPanel.visible)
				{
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.ESCAPE)
			{
				autosaveSong();
				LoadingState.loadAndSwitchState(new EditorPlayState(sectionStartTime()));
			}
			if (FlxG.keys.justPressed.ENTER)
			{
				autosaveSong();
				FlxG.mouse.visible = false;
				PlayState.song = _song;
				FlxG.sound.music.stop();
				if (vocals != null)
					vocals.stop();

				Stage.loadDirectory(_song);
				LoadingState.loadAndSwitchState(new PlayState());
			}

			if (curSelectedNote != null && curSelectedNote[1] > -1)
			{
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}

			if (FlxG.keys.justPressed.BACKSPACE)
			{
				FlxG.switchState(new MasterEditorMenu());
				FlxG.mouse.visible = false;
				return;
			}

			if (FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL)
			{
				undo();
			}

			if (FlxG.keys.justPressed.Y && FlxG.keys.pressed.CONTROL)
			{
				redo();
			}

			if (FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL)
			{
				--curZoom;
				updateZoom();
			}
			if (FlxG.keys.justPressed.X && curZoom < zoomList.length - 1)
			{
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					UI_box.selected_tab -= 1;
					if (UI_box.selected_tab < 0)
						UI_box.selected_tab = 2;
				}
				else
				{
					UI_box.selected_tab += 1;
					if (UI_box.selected_tab >= 3)
						UI_box.selected_tab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if (vocals != null)
						vocals.pause();
				}
				else
				{
					if (vocals != null)
					{
						vocals.play();
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
						vocals.play();
					}
					FlxG.sound.music.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.8);
				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
			}

			// ARROW VORTEX SHIT NO DEADASS

			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL)
					holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT)
					holdingShift = 4;

				var time:Float = 700 * FlxG.elapsed * holdingShift;

				if (FlxG.keys.pressed.W)
				{
					FlxG.sound.music.time -= time;
				}
				else
					FlxG.sound.music.time += time;

				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
			}

			var style:Int = currentType;

			if (FlxG.keys.pressed.SHIFT)
			{
				style = 3;
			}

			var conductorTime:Float = Conductor.songPosition; // + sectionStartTime();Conductor.songPosition / Conductor.stepCrochet;

			// AWW YOU MADE IT SEXY <3333 THX SHADMAR
			if (vortex && !blockInput)
			{
				var controlArray:Array<Bool> = [
					FlxG.keys.justPressed.ONE,
					FlxG.keys.justPressed.TWO,
					FlxG.keys.justPressed.THREE,
					FlxG.keys.justPressed.FOUR,
					FlxG.keys.justPressed.FIVE,
					FlxG.keys.justPressed.SIX,
					FlxG.keys.justPressed.SEVEN,
					FlxG.keys.justPressed.EIGHT
				];

				if (controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if (controlArray[i])
							doANoteThing(conductorTime, i, style);
					}
				}

				var datimess:Array<Float> = [];

				var time:Float = Conductor.stepCrochet * quants[curQuant]; // WHY DID I ROUND BEFORE THIS IS A FLOAT???
				var cuquant:Int = Std.int(32 / quants[curQuant]);
				for (i in 0...cuquant)
				{
					datimess.push(sectionStartTime() + time * i);
				}

				if (FlxG.keys.justPressed.LEFT)
				{
					--curQuant;
					if (curQuant < 0)
						curQuant = 0;

					daquantspot *= Std.int(32 / quants[curQuant]);
				}
				if (FlxG.keys.justPressed.RIGHT)
				{
					curQuant++;
					if (curQuant > quants.length - 1)
						curQuant = quants.length - 1;
					daquantspot *= Std.int(32 / quants[curQuant]);
				}
				quant.animation.play('q', true, false, curQuant);
				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();

					updateStep();

					if (FlxG.keys.pressed.UP)
					{
						var foundaspot:Bool = false;
						var i:Int = datimess.length - 1; // backwards for loop
						while (i > -1)
						{
							if (Math.ceil(FlxG.sound.music.time) >= Math.ceil(datimess[i]) && !foundaspot)
							{
								foundaspot = true;
								FlxG.sound.music.time = datimess[i];
							}
							--i;
						}
						feces = FlxG.sound.music.time - time;
					}
					else
					{
						var foundaspot:Bool = false;
						for (i in datimess)
						{
							if (Math.floor(FlxG.sound.music.time) <= Math.floor(i) && !foundaspot)
							{
								foundaspot = true;
								FlxG.sound.music.time = i;
							}
						}

						feces = FlxG.sound.music.time + time;
					}
					FlxTween.tween(FlxG.sound.music, {time: feces}, 0.1, {ease: FlxEase.circOut});
					if (vocals != null)
					{
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
					}

					var dastrum:Int = 0;

					if (curSelectedNote != null)
					{
						dastrum = curSelectedNote[0];
					}

					var secStart:Float = sectionStartTime();
					var datime:Float = (feces - secStart) - (dastrum - secStart); // idk math find out why it doesn't work on any other section other than 0
					if (curSelectedNote != null)
					{
						var controlArray:Array<Bool> = [
							FlxG.keys.pressed.ONE,
							FlxG.keys.pressed.TWO,
							FlxG.keys.pressed.THREE,
							FlxG.keys.pressed.FOUR,
							FlxG.keys.pressed.FIVE,
							FlxG.keys.pressed.SIX,
							FlxG.keys.pressed.SEVEN,
							FlxG.keys.pressed.EIGHT
						];

						if (controlArray.contains(true))
						{
							for (i in 0...controlArray.length)
							{
								if (controlArray[i])
									if (curSelectedNote[1] == i)
										curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;
							}
							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;

			if (FlxG.keys.justPressed.RIGHT && !vortex || FlxG.keys.justPressed.D)
				changeSection(curSection + shiftThing);
			if (FlxG.keys.justPressed.LEFT && !vortex || FlxG.keys.justPressed.A)
			{
				if (curSection <= 0)
				{
					changeSection(_song.notes.length - 1);
				}
				else
				{
					changeSection(curSection - shiftThing);
				}
			}
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			for (inputText in blockPressWhileTypingOn)
			{
				if (inputText.hasFocus)
				{
					inputText.hasFocus = false;
				}
			}
		}

		_song.bpm = tempBpm;

		strumLineNotes.visible = quant.visible = vortex;

		if (FlxG.sound.music.time < 0)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if (FlxG.sound.music.time > FlxG.sound.music.length)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * _song.notes[curSection].lengthInSteps));
		camPos.y = strumLine.y;
		for (strumNote in strumLineNotes.members)
		{
			strumNote.y = strumLine.y;
			strumNote.alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		bpmTxt.text = '${FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)} / ${FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2)}\nSection: $curSection\n\nBeat: $curBeat\n\nStep: $curStep';

		var playedSound:Array<Bool> = [false, false, false, false]; // Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive((note:Note) ->
		{
			note.alpha = 1;
			if (curSelectedNote != null)
			{
				var noteDataToCheck:Int = note.noteData;
				if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSection].mustHitSection)
					noteDataToCheck += 4;

				if (curSelectedNote[0] == note.strumTime
					&& ((curSelectedNote[2] == null && noteDataToCheck < 0)
						|| (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
				{
					colorSine += elapsed;
					var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal,
						0.999); // Alpha can't be 100% or the color won't be updated for some reason, guess i will die
				}
			}

			if (note.strumTime <= Conductor.songPosition)
			{
				note.alpha = 0.4;
				if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1)
				{
					var data:Int = note.noteData % 4;
					var noteDataToCheck:Int = note.noteData;
					if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSection].mustHitSection)
						noteDataToCheck += 4;
					strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
					strumLineNotes.members[noteDataToCheck].resetAnim = (note.sustainLength / 1000) + 0.15;
					if (!playedSound[data])
					{
						if ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress))
						{
							var soundToPlay:String = 'hitsound';
							if (_song.player1 == 'gf')
							{ // Easter egg
								soundToPlay = 'GF_${data + 1}';
							}

							FlxG.sound.play(Paths.getSound(soundToPlay)).pan = note.noteData < 4 ? -0.3 : 0.3; // would be coolio
							playedSound[data] = true;
						}

						data = note.noteData;
						if (note.mustPress != _song.notes[curSection].mustHitSection)
						{
							data += 4;
						}
					}
				}
			}
		});

		if (metronome.checked && lastConductorPos != Conductor.songPosition)
		{
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if (metroStep != lastMetroStep)
			{
				FlxG.sound.play(Paths.getSound('Metronome_Tick'));
				// Debug.logTrace('Ticked');
			}
		}
		lastConductorPos = Conductor.songPosition;
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = sender;
			var label:String = check.getLabel().text;
			var section:SectionDef = _song.notes[curSection];
			switch (label)
			{
				case 'Must hit section':
					section.mustHitSection = check.checked;

					updateGrid();
					updateHeads();

				case 'GF section':
					section.gfSection = check.checked;

					updateGrid();
					updateHeads();

				case 'Change BPM':
					section.changeBPM = check.checked;
					Debug.logTrace('Set changeBPM for section $curSection to ${section.changeBPM}');
				case 'Alt Animation':
					section.altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = sender;
			var wname:String = nums.name;
			// Debug.logTrace(wname);
			if (wname == 'section_length')
			{
				_song.notes[curSection].lengthInSteps = Std.int(nums.value);
				updateGrid();
			}
			else if (wname == 'song_speed')
			{
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				tempBpm = nums.value;
				Conductor.mapBPMChanges(_song);
				Conductor.changeBPM(nums.value);
			}
			else if (wname == 'note_susLength')
			{
				if (curSelectedNote != null && curSelectedNote[1] > -1)
				{
					curSelectedNote[2] = nums.value;
					updateGrid();
				}
				else
				{
					sender.value = 0;
				}
			}
			else if (wname == 'section_bpm')
			{
				_song.notes[curSection].bpm = nums.value;
				updateGrid();
			}
			else if (wname == 'inst_volume')
			{
				FlxG.sound.music.volume = nums.value;
			}
			else if (wname == 'voices_volume')
			{
				vocals.volume = nums.value;
			}
		}
		else if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == noteSplashesInputText)
			{
				_song.splashSkin = noteSplashesInputText.text;
			}
			else if (curSelectedNote != null)
			{
				if (sender == value1InputText)
				{
					curSelectedNote[1][curEventSelected][1] = value1InputText.text;
					updateGrid();
				}
				else if (sender == value2InputText)
				{
					curSelectedNote[1][curEventSelected][2] = value2InputText.text;
					updateGrid();
				}
				else if (sender == strumTimeInputText)
				{
					var value:Float = Std.parseFloat(strumTimeInputText.text);
					if (Math.isNaN(value))
						value = 0;
					curSelectedNote[0] = value;
					updateGrid();
				}
			}
		}

		// Debug.logTrace('ID: $id, Sender: $sender, Data: $data, Params: $params');
	}

	private var check_mute_inst:FlxUICheckBox;
	private var check_vortex:FlxUICheckBox;
	private var check_warnings:FlxUICheckBox;
	private var playSoundBf:FlxUICheckBox;
	private var playSoundDad:FlxUICheckBox;
	private var UI_songTitle:FlxUIInputText;
	private var noteSkinInputText:FlxUIInputText;
	private var noteSplashesInputText:FlxUIInputText;
	private var stageDropDown:FlxUIDropDownMenu;

	private function addSongUI():Void
	{
		UI_songTitle = new FlxUIInputText(10, 10, 70, _song.songId, 8);
		blockPressWhileTypingOn.push(UI_songTitle);

		var voicesCheckBox:FlxUICheckBox = new FlxUICheckBox(10, 25, null, null, 'Has voice track', 100);
		voicesCheckBox.checked = _song.needsVoices;
		voicesCheckBox.callback = () ->
		{
			_song.needsVoices = voicesCheckBox.checked;
			// Debug.logTrace('CHECKED!');
		};

		var saveButton:FlxButton = new FlxButton(110, 8, 'Save', () ->
		{
			saveLevel();
		});

		var reloadSongButton:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, 'Reload Audio', () ->
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			loadSong();
			loadAudioBuffer();
			updateWaveform();
		});

		var reloadSongJsonButton:FlxButton = new FlxButton(reloadSongButton.x, saveButton.y + 30, 'Reload JSON', () ->
		{
			openSubState(new PromptSubState('This action will clear current progress.\n\nProceed?', 0, () ->
			{
				loadJson(_song.songId);
			}, null, ignoreWarnings));
		});

		var loadAutosaveButton:FlxButton = new FlxButton(reloadSongJsonButton.x, reloadSongJsonButton.y + 30, 'Load Autosave', () ->
		{
			var autoSaveData:SongWrapper = Json.parse(EngineData.save.data.autosave);
			var songDef:SongDef = autoSaveData.song;
			var name:String = songDef.songId;
			var songMetadataDef:SongMetadataDef = {};
			PlayState.song = Song.parseJson(name, autoSaveData, songMetadataDef);
			FlxG.resetState();
		});

		var loadEventsButton:FlxButton = new FlxButton(loadAutosaveButton.x, loadAutosaveButton.y + 30, 'Load Events', () ->
		{
			var file:String = Paths.json(Path.join(['songs', _song.songId, 'events']));
			if (Paths.exists(file))
			{
				clearEvents();
				var events:SongDef = Song.getSongDef('events', '', _song.songId);
				_song.events = events.events;
				changeSection(curSection);
			}
		});

		var saveEventsButton:FlxButton = new FlxButton(110, reloadSongJsonButton.y, 'Save Events', () ->
		{
			saveEvents();
		});

		var clearEventsButton:FlxButton = new FlxButton(320, 310, 'Clear events', () ->
		{
			openSubState(new PromptSubState('This action will clear current progress.\n\nProceed?', 0, clearEvents, null, ignoreWarnings));
		});
		clearEventsButton.color = FlxColor.RED;
		clearEventsButton.label.color = FlxColor.WHITE;

		var clearNotesButton:FlxButton = new FlxButton(320, clearEventsButton.y + 30, 'Clear notes', () ->
		{
			openSubState(new PromptSubState('This action will clear current progress.\n\nProceed?', 0, () ->
			{
				for (section in _song.notes)
				{
					section.sectionNotes = [];
				}
				updateGrid();
			}, null, ignoreWarnings));
		});
		clearNotesButton.color = FlxColor.RED;
		clearNotesButton.label.color = FlxColor.WHITE;

		var bpmStepper:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 339, 1);
		bpmStepper.value = Conductor.bpm;
		bpmStepper.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(bpmStepper);

		var speedStepper:FlxUINumericStepper = new FlxUINumericStepper(10, bpmStepper.y + 35, 0.1, 1, 0.1, 10, 1);
		speedStepper.value = _song.speed;
		speedStepper.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(speedStepper);

		var characterList:Array<String> = [];
		var charsLoaded:Map<String, Bool> = [];

		var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

		for (directory in directories)
		{
			var characterDirectory:String = Path.join([directory, 'data/characters']);
			var characterListPath:String = Path.join([characterDirectory, Path.withExtension('characterList', Paths.TEXT_EXT)]);
			if (Paths.exists(characterListPath))
			{
				// Add characters from characterList.txt first
				var characterListFromDir:Array<String> = CoolUtil.listFromTextFile(characterListPath);
				for (characterId in characterListFromDir)
				{
					var path:String = Path.join([characterDirectory, Path.withExtension(characterId, Paths.JSON_EXT)]);
					if (Paths.exists(path))
					{
						if (!charsLoaded.exists(characterId))
						{
							characterList.push(characterId);
							charsLoaded.set(characterId, true);
						}
					}
				}
			}

			if (Paths.fileSystem.exists(characterDirectory))
			{
				// Add any characters what were not included in the list but were in the directory
				for (file in Paths.fileSystem.readDirectory(characterDirectory))
				{
					var path:String = Path.join([characterDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.JSON_EXT)
					{
						var characterId:String = Path.withoutExtension(file);
						if (!charsLoaded.exists(characterId))
						{
							characterList.push(characterId);
							charsLoaded.set(characterId, true);
						}
					}
				}
			}
		}

		var player1DropDown:FlxUIDropDownMenu = new FlxUIDropDownMenu(10, speedStepper.y + 45, FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true),
			(character:String) ->
			{
				_song.player1 = characterList[Std.parseInt(character)];
				updateHeads();
			});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown:FlxUIDropDownMenu = new FlxUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40,
			FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true), (character:String) ->
			{
				_song.gfVersion = characterList[Std.parseInt(character)];
				updateHeads();
			});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown:FlxUIDropDownMenu = new FlxUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40,
			FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true), (character:String) ->
			{
				_song.player2 = characterList[Std.parseInt(character)];
				updateHeads();
			});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);

		var stageList:Array<String> = [];
		var stagesLoaded:Map<String, Bool> = [];

		for (directory in directories)
		{
			var stageDirectory:String = Path.join([directory, 'data/stages']);
			var stageListPath:String = Path.join([stageDirectory, Path.withExtension('stageList', Paths.TEXT_EXT)]);
			if (Paths.exists(stageListPath))
			{
				// Add stages from stageList.txt first
				var stageListFromDir:Array<String> = CoolUtil.listFromTextFile(stageListPath);
				for (stageId in stageListFromDir)
				{
					var path:String = Path.join([stageDirectory, Path.withExtension(stageId, Paths.JSON_EXT)]);
					if (Paths.exists(path))
					{
						if (!stagesLoaded.exists(stageId))
						{
							stageList.push(stageId);
							stagesLoaded.set(stageId, true);
						}
					}
				}
			}

			if (Paths.fileSystem.exists(stageDirectory))
			{
				// Add any stages what were not included in the list but were in the directory
				for (file in Paths.fileSystem.readDirectory(stageDirectory))
				{
					var path:String = Path.join([stageDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.JSON_EXT)
					{
						var stageId:String = Path.withoutExtension(file);
						if (!stagesLoaded.exists(stageId))
						{
							stageList.push(stageId);
							stagesLoaded.set(stageId, true);
						}
					}
				}
			}
		}

		if (stageList.length < 1)
			stageList.push('stage');

		stageDropDown = new FlxUIDropDownMenu(player1DropDown.x + 140, player1DropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray(stageList, true),
			(character:String) ->
			{
				_song.stage = stageList[Std.parseInt(character)];
			});
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		var skin:String = PlayState.song.arrowSkin;
		if (skin == null)
			skin = '';
		noteSkinInputText = new FlxUIInputText(player2DropDown.x, player2DropDown.y + 50, 150, skin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, _song.splashSkin, 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', () ->
		{
			_song.arrowSkin = noteSkinInputText.text;
			updateGrid();
		});

		var songTabGroup:FlxUI = new FlxUI(null, UI_box);
		songTabGroup.name = 'Song';
		songTabGroup.add(UI_songTitle);

		songTabGroup.add(voicesCheckBox);
		songTabGroup.add(clearEventsButton);
		songTabGroup.add(clearNotesButton);
		songTabGroup.add(saveButton);
		songTabGroup.add(saveEventsButton);
		songTabGroup.add(reloadSongButton);
		songTabGroup.add(reloadSongJsonButton);
		songTabGroup.add(loadAutosaveButton);
		songTabGroup.add(loadEventsButton);
		songTabGroup.add(bpmStepper);
		songTabGroup.add(speedStepper);
		songTabGroup.add(reloadNotesButton);
		songTabGroup.add(noteSkinInputText);
		songTabGroup.add(noteSplashesInputText);
		songTabGroup.add(new FlxText(bpmStepper.x, bpmStepper.y - 15, 0, 'Song BPM:'));
		songTabGroup.add(new FlxText(speedStepper.x, speedStepper.y - 15, 0, 'Song Speed:'));
		songTabGroup.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		songTabGroup.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		songTabGroup.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
		songTabGroup.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		songTabGroup.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		songTabGroup.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		songTabGroup.add(player2DropDown);
		songTabGroup.add(gfVersionDropDown);
		songTabGroup.add(player1DropDown);
		songTabGroup.add(stageDropDown);

		UI_box.addGroup(songTabGroup);

		FlxG.camera.follow(camPos);
	}

	private var stepperLength:FlxUINumericStepper;
	private var check_mustHitSection:FlxUICheckBox;
	private var check_gfSection:FlxUICheckBox;
	private var check_changeBPM:FlxUICheckBox;
	private var stepperSectionBPM:FlxUINumericStepper;
	private var check_altAnim:FlxUICheckBox;

	private var sectionToCopy:Int = 0;
	private var notesCopied:Array<Array<Dynamic>>;

	private function addSectionUI():Void
	{
		var sectionTabGroup:FlxUI = new FlxUI(null, UI_box);
		sectionTabGroup.name = 'Section';

		stepperLength = new FlxUINumericStepper(10, 10, 4, 0, 0, 999, 0);
		stepperLength.value = _song.notes[curSection].lengthInSteps;
		stepperLength.name = 'section_length';
		blockPressWhileTypingOnStepper.push(stepperLength);

		check_mustHitSection = new FlxUICheckBox(10, 30, null, null, 'Must hit section', 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSection].mustHitSection;

		check_gfSection = new FlxUICheckBox(130, 30, null, null, 'GF section', 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSection].gfSection;

		check_altAnim = new FlxUICheckBox(10, 60, null, null, 'Alt Animation', 100);
		check_altAnim.checked = _song.notes[curSection].altAnim;
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, 90, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSection].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, 110, 1, Conductor.bpm, 0, 999, 1);
		if (check_changeBPM.checked)
		{
			stepperSectionBPM.value = _song.notes[curSection].bpm;
		}
		else
		{
			stepperSectionBPM.value = Conductor.bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		var copyButton:FlxButton = new FlxButton(10, 150, 'Copy Section', () ->
		{
			notesCopied = [];
			sectionToCopy = curSection;
			for (note in _song.notes[curSection].sectionNotes)
			{
				notesCopied.push(note);
			}

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(10, 180, 'Paste Section', () ->
		{
			if (notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var addToTime:Float = Conductor.stepCrochet * (_song.notes[curSection].lengthInSteps * (curSection - sectionToCopy));
			// Debug.logTrace('Time to add: $addToTime');

			for (note in notesCopied)
			{
				var copiedNote:Array<Dynamic> = [];
				var newStrumTime:Float = note[0] + addToTime;
				if (note[1] < 0)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...note[2].length)
					{
						var eventToPush:Array<Dynamic> = note[2][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					_song.events.push([newStrumTime, copiedEventArray]);
				}
				else
				{
					if (note[4] != null)
					{
						copiedNote = [newStrumTime, note[1], note[2], note[3], note[4]];
					}
					else
					{
						copiedNote = [newStrumTime, note[1], note[2], note[3]];
					}
					_song.notes[curSection].sectionNotes.push(copiedNote);
				}
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(10, 210, 'Clear', () ->
		{
			_song.notes[curSection].sectionNotes = [];

			var i:Int = _song.events.length - 1;

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			while (i > -1)
			{
				var event:Array<Dynamic> = _song.events[i];
				if (event != null && endThing > event[0] && event[0] >= startThing)
				{
					_song.events.remove(event);
				}
				--i;
			}
			updateGrid();
			updateNoteUI();
		});

		var swapSection:FlxButton = new FlxButton(10, 240, 'Swap section', () ->
		{
			for (i in 0..._song.notes[curSection].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSection].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSection].sectionNotes[i] = note;
			}
			updateGrid();
		});

		var copyLastStepper:FlxUINumericStepper = new FlxUINumericStepper(110, 276, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(copyLastStepper);

		var copyLastButton:FlxButton = new FlxButton(10, 270, 'Copy last section', () ->
		{
			var value:Int = Std.int(copyLastStepper.value);
			if (value == 0)
				return;

			var sectionIndex:Int = FlxMath.maxInt(curSection, value);

			for (note in _song.notes[sectionIndex - value].sectionNotes)
			{
				var strum:Float = note[0] + Conductor.stepCrochet * (_song.notes[sectionIndex].lengthInSteps * value);

				var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3]];
				_song.notes[sectionIndex].sectionNotes.push(copiedNote);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if (endThing > event[0] && event[0] >= startThing)
				{
					strumTime += Conductor.stepCrochet * (_song.notes[sectionIndex].lengthInSteps * value);
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					_song.events.push([strumTime, copiedEventArray]);
				}
			}
			updateGrid();
		});
		var duetButton:FlxButton = new FlxButton(10, 320, 'Duet Notes', () ->
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSection].sectionNotes)
			{
				var noteData:Int = note[1];
				if (noteData > 3)
				{
					noteData -= 4;
				}
				else
				{
					noteData += 4;
				}

				var copiedNote:Array<Dynamic> = [note[0], noteData, note[2], note[3]];
				duetNotes.push(copiedNote);
			}

			for (i in duetNotes)
			{
				_song.notes[curSection].sectionNotes.push(i);
			}

			updateGrid();
		});
		var mirrorButton:FlxButton = new FlxButton(10, 350, 'Mirror Notes', () ->
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSection].sectionNotes)
			{
				var noteData:Int = Std.int(note[1] % 4);
				noteData = 3 - noteData;
				if (note[1] > 3)
					noteData += 4;

				note[1] = noteData;
			}

			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();

		sectionTabGroup.add(stepperLength);
		sectionTabGroup.add(stepperSectionBPM);
		sectionTabGroup.add(check_mustHitSection);
		sectionTabGroup.add(check_gfSection);
		sectionTabGroup.add(check_altAnim);
		sectionTabGroup.add(check_changeBPM);
		sectionTabGroup.add(copyButton);
		sectionTabGroup.add(pasteButton);
		sectionTabGroup.add(clearSectionButton);
		sectionTabGroup.add(swapSection);
		sectionTabGroup.add(copyLastStepper);
		sectionTabGroup.add(copyLastButton);
		sectionTabGroup.add(duetButton);
		sectionTabGroup.add(mirrorButton);

		UI_box.addGroup(sectionTabGroup);
	}

	private var stepperSusLength:FlxUINumericStepper;
	// TODO Find a way to scale steppers?
	private var strumTimeInputText:FlxUIInputText; // I wanted to use a stepper but we can't scale these as far as i know :(
	private var noteTypeDropDown:FlxUIDropDownMenu;
	private var currentType:Int = 0;

	private function addNoteUI():Void
	{
		var noteTabGroup:FlxUI = new FlxUI(null, UI_box);
		noteTabGroup.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 32);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new FlxUIInputText(10, 65, 180, '0');
		noteTabGroup.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		var noteTypeList:Array<String> = [];
		while (key < NOTE_TYPES.length)
		{
			noteTypeList.push(NOTE_TYPES[key]);
			noteTypeMap.set(NOTE_TYPES[key], key);
			noteTypeIntMap.set(key, NOTE_TYPES[key]);
			key++;
		}

		#if FEATURE_SCRIPTS
		var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

		for (directory in directories)
		{
			var noteTypeDirectory:String = Path.join([directory, 'data/notetypes']);
			if (Paths.fileSystem.exists(noteTypeDirectory))
			{
				for (file in Paths.fileSystem.readDirectory(noteTypeDirectory))
				{
					var path:String = Path.join([noteTypeDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.SCRIPT_EXT)
					{
						var noteTypeId:String = Path.withoutExtension(file);
						if (!noteTypeMap.exists(noteTypeId))
						{
							noteTypeList.push(noteTypeId);
							noteTypeMap.set(noteTypeId, key);
							noteTypeIntMap.set(key, noteTypeId);
							key++;
						}
					}
				}
			}
		}
		#end

		for (i in 1...noteTypeList.length)
		{
			noteTypeList[i] = '$i. ${noteTypeList[i]}';
		}

		noteTypeDropDown = new FlxUIDropDownMenu(10, 105, FlxUIDropDownMenu.makeStrIdLabelArray(noteTypeList, true), (character:String) ->
		{
			currentType = Std.parseInt(character);
			if (curSelectedNote != null && curSelectedNote[1] > -1)
			{
				curSelectedNote[3] = noteTypeIntMap.get(currentType);
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		noteTabGroup.add(new FlxText(10, 10, 0, 'Sustain length:'));
		noteTabGroup.add(new FlxText(10, 50, 0, 'Strum time (in milliseconds):'));
		noteTabGroup.add(new FlxText(10, 90, 0, 'Note type:'));
		noteTabGroup.add(stepperSusLength);
		noteTabGroup.add(strumTimeInputText);
		noteTabGroup.add(noteTypeDropDown);

		UI_box.addGroup(noteTabGroup);
	}

	private var eventDropDown:FlxUIDropDownMenu;
	private var descText:FlxText;
	private var selectedEventText:FlxText;

	private function addEventsUI():Void
	{
		var eventTabGroup:FlxUI = new FlxUI(null, UI_box);
		eventTabGroup.name = 'Events';

		var eventMap:Map<String, Bool> = [];
		#if FEATURE_SCRIPTS
		var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

		for (directory in directories)
		{
			var eventDirectory:String = Path.join([directory, 'data/events']);
			if (Paths.fileSystem.exists(eventDirectory))
			{
				for (file in Paths.fileSystem.readDirectory(eventDirectory))
				{
					var path:String = Path.join([eventDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path)
						&& Path.extension(path) == Paths.TEXT_EXT
						&& file != Path.withExtension('readme', Paths.TEXT_EXT))
					{
						var eventId:String = Path.withoutExtension(file);
						if (!eventMap.exists(eventId))
						{
							eventList.push([eventId, Paths.getTextDirect(path)]);
							eventMap.set(eventId, true);
						}
					}
				}
			}
		}
		#end

		descText = new FlxText(20, 200, 0, eventList[0][0]);

		var events:Array<String> = [];
		for (i in 0...eventList.length)
		{
			events.push(eventList[i][0]);
		}

		var text:FlxText = new FlxText(20, 30, 0, 'Event:');
		eventTabGroup.add(text);
		eventDropDown = new FlxUIDropDownMenu(20, 50, FlxUIDropDownMenu.makeStrIdLabelArray(events, true), (pressed:String) ->
		{
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventList[selectedEvent][1];
			if (curSelectedNote != null && eventList != null)
			{
				if (curSelectedNote != null && curSelectedNote[2] == null)
				{
					curSelectedNote[1][curEventSelected][0] = eventList[selectedEvent][0];
				}
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(eventDropDown);

		var text:FlxText = new FlxText(20, 90, 0, 'Value 1:');
		eventTabGroup.add(text);
		value1InputText = new FlxUIInputText(20, 110, 100);
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, 'Value 2:');
		eventTabGroup.add(text);
		value2InputText = new FlxUIInputText(20, 150, 100);
		blockPressWhileTypingOn.push(value2InputText);

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', () ->
		{
			if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
			{
				if (curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if (curEventSelected < 0)
					curEventSelected = 0;
				else if (curSelectedNote != null)
				{
					eventsGroup = curSelectedNote[1];
					if (curEventSelected >= eventsGroup.length)
						curEventSelected = eventsGroup.length - 1;
				}

				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		eventTabGroup.add(removeButton);

		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', () ->
		{
			if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		eventTabGroup.add(addButton);

		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', () ->
		{
			changeEventSelected(-1);
		});
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		eventTabGroup.add(moveLeftButton);

		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', () ->
		{
			changeEventSelected(1);
		});
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		eventTabGroup.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186,
			'Selected Event: None');
		selectedEventText.alignment = CENTER;
		eventTabGroup.add(selectedEventText);

		eventTabGroup.add(descText);
		eventTabGroup.add(value1InputText);
		eventTabGroup.add(value2InputText);
		eventTabGroup.add(eventDropDown);

		UI_box.addGroup(eventTabGroup);
	}

	private function changeEventSelected(change:Int = 0):Void
	{
		if (curSelectedNote != null && curSelectedNote[2] == null) // Is event note
		{
			curEventSelected += change;
			if (curEventSelected < 0)
				curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if (curEventSelected >= curSelectedNote[1].length)
				curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ${curEventSelected + 1} / ${curSelectedNote[1].length}';
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	private function setAllLabelsOffset(button:FlxButton, x:Float, y:Float):Void
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	private var metronome:FlxUICheckBox;
	private var metronomeStepper:FlxUINumericStepper;
	private var metronomeOffsetStepper:FlxUINumericStepper;
	private var disableAutoScrolling:FlxUICheckBox;
	#if desktop
	private var waveformEnabled:FlxUICheckBox;
	private var waveformUseInstrumental:FlxUICheckBox;
	#end
	private var instVolume:FlxUINumericStepper;
	private var voicesVolume:FlxUINumericStepper;

	private function addChartingUI():Void
	{
		var chartTabGroup:FlxUI = new FlxUI(null, UI_box);
		chartTabGroup.name = 'Charting';

		#if desktop
		waveformEnabled = new FlxUICheckBox(10, 90, null, null, 'Visible Waveform', 100);
		if (EngineData.save.data.chart_waveform == null)
			EngineData.save.data.chart_waveform = false;
		waveformEnabled.checked = EngineData.save.data.chart_waveform;
		waveformEnabled.callback = () ->
		{
			EngineData.save.data.chart_waveform = waveformEnabled.checked;
			updateWaveform();
		};

		waveformUseInstrumental = new FlxUICheckBox(waveformEnabled.x + 120, waveformEnabled.y, null, null, 'Waveform for Instrumental', 100);
		waveformUseInstrumental.checked = false;
		waveformUseInstrumental.callback = () ->
		{
			updateWaveform();
		};
		#end

		check_mute_inst = new FlxUICheckBox(10, 310, null, null, 'Mute Instrumental (in editor)', 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = () ->
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};
		check_vortex = new FlxUICheckBox(10, 160, null, null, 'Vortex Editor (BETA)', 100);
		if (EngineData.save.data.chart_vortex == null)
			EngineData.save.data.chart_vortex = false;
		check_vortex.checked = EngineData.save.data.chart_vortex;

		check_vortex.callback = () ->
		{
			EngineData.save.data.chart_vortex = check_vortex.checked;
			vortex = EngineData.save.data.chart_vortex;
			reloadGridLayer();
		};

		check_warnings = new FlxUICheckBox(10, 120, null, null, 'Ignore Progress Warnings', 100);
		if (EngineData.save.data.ignoreWarnings == null)
			EngineData.save.data.ignoreWarnings = false;
		check_warnings.checked = EngineData.save.data.ignoreWarnings;

		check_warnings.callback = () ->
		{
			EngineData.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = EngineData.save.data.ignoreWarnings;
		};

		var muteVocalsCheckBox:FlxUICheckBox = new FlxUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, null, null, 'Mute Vocals (in editor)', 100);
		muteVocalsCheckBox.checked = false;
		muteVocalsCheckBox.callback = () ->
		{
			if (vocals != null)
			{
				var vol:Float = 1;

				if (muteVocalsCheckBox.checked)
					vol = 0;

				vocals.volume = vol;
			}
		};

		playSoundBf = new FlxUICheckBox(check_mute_inst.x, muteVocalsCheckBox.y + 30, null, null, 'Play Sound (Boyfriend notes)', 100, () ->
		{
			EngineData.save.data.chart_playSoundBf = playSoundBf.checked;
		});
		if (EngineData.save.data.chart_playSoundBf == null)
			EngineData.save.data.chart_playSoundBf = false;
		playSoundBf.checked = EngineData.save.data.chart_playSoundBf;

		playSoundDad = new FlxUICheckBox(check_mute_inst.x + 120, playSoundBf.y, null, null, 'Play Sound (Opponent notes)', 100, () ->
		{
			EngineData.save.data.chart_playSoundDad = playSoundDad.checked;
		});
		if (EngineData.save.data.chart_playSoundDad == null)
			EngineData.save.data.chart_playSoundDad = false;
		playSoundDad.checked = EngineData.save.data.chart_playSoundDad;

		metronome = new FlxUICheckBox(10, 15, null, null, 'Metronome Enabled', 100, () ->
		{
			EngineData.save.data.chart_metronome = metronome.checked;
		});
		if (EngineData.save.data.chart_metronome == null)
			EngineData.save.data.chart_metronome = false;
		metronome.checked = EngineData.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, _song.bpm, 1, 1500, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 120, metronome.y, null, null, 'Disable Autoscroll (Not Recommended)', 120, () ->
		{
			EngineData.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
		});
		if (EngineData.save.data.chart_noAutoScroll == null)
			EngineData.save.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = EngineData.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(metronomeStepper.x, 270, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		voicesVolume = new FlxUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';
		blockPressWhileTypingOnStepper.push(voicesVolume);

		chartTabGroup.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'BPM:'));
		chartTabGroup.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):'));
		chartTabGroup.add(new FlxText(instVolume.x, instVolume.y - 15, 0, 'Inst Volume'));
		chartTabGroup.add(new FlxText(voicesVolume.x, voicesVolume.y - 15, 0, 'Voices Volume'));
		chartTabGroup.add(metronome);
		chartTabGroup.add(disableAutoScrolling);
		chartTabGroup.add(metronomeStepper);
		chartTabGroup.add(metronomeOffsetStepper);
		#if desktop
		chartTabGroup.add(waveformEnabled);
		chartTabGroup.add(waveformUseInstrumental);
		#end
		chartTabGroup.add(instVolume);
		chartTabGroup.add(voicesVolume);
		chartTabGroup.add(check_mute_inst);
		chartTabGroup.add(muteVocalsCheckBox);
		chartTabGroup.add(check_vortex);
		chartTabGroup.add(check_warnings);
		chartTabGroup.add(playSoundBf);
		chartTabGroup.add(playSoundDad);
		UI_box.addGroup(chartTabGroup);
	}

	private function loadSong():Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			// vocals.stop();
		}

		var file:FlxSoundAsset = Paths.getVoices(currentSongName);
		vocals = new FlxSound();
		if (file != null)
		{
			vocals.loadEmbedded(file);
			FlxG.sound.list.add(vocals);
		}
		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;
	}

	private function generateSong():Void
	{
		FlxG.sound.playMusic(Paths.getInst(currentSongName), 0.6 /*, false*/);
		if (instVolume != null)
			FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked)
			FlxG.sound.music.volume = 0;

		FlxG.sound.music.onComplete = () ->
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			if (vocals != null)
			{
				vocals.pause();
				vocals.time = 0;
			}
			changeSection();
			curSection = 0;
			updateGrid();
			updateSectionUI();
			vocals.play();
		};
	}

	private function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	private function sectionStartTime(add:Int = 0):Float
	{
		var bpm:Float = _song.bpm;
		var position:Float = 0;
		for (i in 0...curSection + add)
		{
			if (_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					bpm = _song.notes[i].bpm;
				}
				position += 4 * (1000 * 60 / bpm);
			}
		}
		return position;
	}

	private function updateZoom():Void
	{
		zoomTxt.text = 'Zoom: ${zoomList[curZoom]}x';
		reloadGridLayer();
	}

	private function loadAudioBuffer():Void
	{
		if (audioBuffers[0] != null)
		{
			audioBuffers[0].dispose();
		}
		audioBuffers[0] = null;
		var inst:String = Paths.inst(currentSongName);
		if (Paths.exists(inst, SOUND))
		{
			audioBuffers[0] = AudioBuffer.fromFile(inst);
			// Debug.logTrace('Inst found');
		}

		if (audioBuffers[1] != null)
		{
			audioBuffers[1].dispose();
		}
		audioBuffers[1] = null;
		var voices:String = Paths.voices(currentSongName);
		if (Paths.exists(voices, SOUND))
		{
			audioBuffers[1] = AudioBuffer.fromFile(voices);
			// Debug.logTrace('Voices found');
		}
	}

	private function reloadGridLayer():Void
	{
		gridLayer.clear();
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, Std.int(GRID_SIZE * 32 * zoomList[curZoom]));
		gridLayer.add(gridBG);

		#if desktop
		if (waveformEnabled != null)
		{
			updateWaveform();
		}
		#end

		var gridBlack:FlxSprite = new FlxSprite(0, gridBG.height / 2).makeGraphic(Std.int(GRID_SIZE * 9), Std.int(gridBG.height / 2), FlxColor.BLACK);
		gridBlack.alpha = 0.4;
		gridLayer.add(gridBlack);

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * 4)).makeGraphic(2, Std.int(gridBG.height), FlxColor.BLACK);
		gridLayer.add(gridBlackLine);

		for (i in 1...4)
		{
			var beatsep1:FlxSprite = new FlxSprite(gridBG.x, (GRID_SIZE * (4 * curZoom)) * i).makeGraphic(Std.int(gridBG.width), 1, 0x44FF0000);
			if (vortex)
				gridLayer.add(beatsep1);
		}

		gridBlackLine = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(2, Std.int(gridBG.height), FlxColor.BLACK);
		gridLayer.add(gridBlackLine);
		updateGrid();
	}

	private var waveformPrinted:Bool = true;
	private var audioBuffers:Array<AudioBuffer> = [null, null];

	private function updateWaveform():Void
	{
		#if desktop
		if (waveformPrinted)
		{
			waveformSprite.makeGraphic(Std.int(GRID_SIZE * 8), Std.int(gridBG.height), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridBG.height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		var checkForVoices:Int = 1;
		if (waveformUseInstrumental.checked)
			checkForVoices = 0;

		if (!waveformEnabled.checked || audioBuffers[checkForVoices] == null)
		{
			// Debug.logTrace('Epic fail on the waveform lol');
			return;
		}

		var sampleMult:Float = audioBuffers[checkForVoices].sampleRate / 44100;
		var index:Int = Std.int(sectionStartTime() * 44.0875 * sampleMult);
		var drawIndex:Int = 0;

		var steps:Int = _song.notes[curSection].lengthInSteps;
		if (Math.isNaN(steps) || steps < 1)
			steps = 16;
		var samplesPerRow:Int = Std.int(((Conductor.stepCrochet * steps * 1.1 * sampleMult) / 16) / zoomList[curZoom]);
		if (samplesPerRow < 1)
			samplesPerRow = 1;
		var waveBytes:Bytes = audioBuffers[checkForVoices].data.toBytes();

		var min:Float = 0;
		var max:Float = 0;
		while (index < (waveBytes.length - 1))
		{
			var byte:Int = waveBytes.getUInt16(index * 4);

			if (byte > 65535 / 2)
				byte -= 65535;

			var sample:Float = (byte / 65535);

			if (sample > 0)
			{
				if (sample > max)
					max = sample;
			}
			else if (sample < 0)
			{
				if (sample < min)
					min = sample;
			}

			if ((index % samplesPerRow) == 0)
			{
				Debug.logTrace('Min: $min, Max: $max');

				/*
					if (drawIndex > gridBG.height)
					{
						drawIndex = 0;
					}
				 */

				var pixelsMin:Float = Math.abs(min * (GRID_SIZE * 8));
				var pixelsMax:Float = max * (GRID_SIZE * 8);
				waveformSprite.pixels.fillRect(new Rectangle((GRID_SIZE * 4) - pixelsMin, drawIndex, pixelsMin + pixelsMax, 1), FlxColor.BLUE);
				drawIndex++;

				min = 0;
				max = 0;

				if (drawIndex > gridBG.height)
					break;
			}

			index++;
		}
		waveformPrinted = true;
		#end
	}

	private function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += value;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	private function recalculateSteps(add:Float = 0):Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (bpmChange in Conductor.bpmChangeMap)
		{
			if (FlxG.sound.music.time > bpmChange.songTime)
				lastChange = bpmChange;
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime + add) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	private function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSection = 0;
		}

		if (vocals != null)
		{
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}
		updateStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	private function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		// Debug.logTrace('Changing to section $sec');

		if (_song.notes[sec] != null)
		{
			curSection = sec;

			updateGrid();

			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = sectionStartTime();
				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				updateStep();
			}

			updateGrid();
			updateSectionUI();
		}
		else
		{
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		updateWaveform();
	}

	private function updateSectionUI():Void
	{
		var sec:SectionDef = _song.notes[curSection];

		stepperLength.value = sec.lengthInSteps;
		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		updateHeads();
	}

	private function updateHeads():Void
	{
		var healthIconP1:String = loadHealthIconFromCharacter(_song.player1);
		var healthIconP2:String = loadHealthIconFromCharacter(_song.player2);

		if (_song.notes[curSection].mustHitSection)
		{
			leftIcon.changeIcon(healthIconP1);
			rightIcon.changeIcon(healthIconP2);
			if (_song.notes[curSection].gfSection)
				leftIcon.changeIcon('gf');
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(healthIconP1);
			if (_song.notes[curSection].gfSection)
				leftIcon.changeIcon('gf');
		}
	}

	private function loadHealthIconFromCharacter(char:String):String
	{
		// FIXME This crashes the game if the save window is open
		var characterDef:CharacterDef = Paths.getJson(Path.join(['characters', char]));
		if (characterDef == null)
		{
			characterDef = Paths.getJson(Path.join(['characters', Character.DEFAULT_CHARACTER]));
		}
		return characterDef.healthIcon;
	}

	private function updateNoteUI():Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				stepperSusLength.value = curSelectedNote[2];
				if (curSelectedNote[3] != null)
				{
					currentType = noteTypeMap.get(curSelectedNote[3]);
					if (currentType <= 0)
					{
						noteTypeDropDown.selectedLabel = '';
					}
					else
					{
						noteTypeDropDown.selectedLabel = '$currentType. ${curSelectedNote[3]}';
					}
				}
			}
			else
			{
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if (selected > 0 && selected < eventList.length)
				{
					descText.text = eventList[selected][1];
				}
				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
			}
			strumTimeInputText.text = curSelectedNote[0];
		}
	}

	private function updateGrid():Void
	{
		curRenderedNotes.clear();
		curRenderedSustains.clear();
		curRenderedNoteType.clear();
		nextRenderedNotes.clear();
		nextRenderedSustains.clear();

		var section:SectionDef = _song.notes[curSection];

		if (section.changeBPM && section.bpm > 0)
		{
			Conductor.changeBPM(section.bpm);
			// Debug.logTrace('BPM of this section: ${section.bpm}');
		}
		else
		{
			// get last bpm
			var bpm:Float = _song.bpm;
			for (i in 0...curSection)
				if (_song.notes[i].changeBPM)
					bpm = _song.notes[i].bpm;
			Conductor.changeBPM(bpm);
		}

		// CURRENT SECTION
		for (i in section.sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note));
			}

			if (note.y < -150)
				note.y = -150;

			if (i[3] != null && note.noteType != null && note.noteType.length > 0)
			{
				var typeInt:Null<Int> = noteTypeMap.get(i[3]);
				var theType:String = Std.string(typeInt);
				if (typeInt == null)
					theType = '?';

				var text:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				text.setFormat(Paths.font('vcr.ttf'), text.size, CENTER, OUTLINE, FlxColor.BLACK);
				text.xAdd = -32;
				text.yAdd = 6;
				text.borderSize = 1;
				curRenderedNoteType.add(text);
				text.sprTracker = note;
			}
			note.mustPress = _song.notes[curSection].mustHitSection;
			if (i[1] > 3)
				note.mustPress = !note.mustPress;
		}

		// CURRENT EVENTS
		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);

				if (note.y < -150)
					note.y = -150;

				var textString:String = 'Event: ${note.eventName} (${Math.floor(note.strumTime)} ms)\nValue 1: ${note.eventVal1}\nValue 2: ${note.eventVal2}';
				if (note.eventLength > 1)
					textString = '${note.eventLength} Events:\n${note.eventName}';

				var text:AttachedFlxText = new AttachedFlxText(0, 0, 400, textString, 12);
				text.setFormat(Paths.font('vcr.ttf'), text.size, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
				text.xAdd = -410;
				text.borderSize = 1;
				if (note.eventLength > 1)
					text.yAdd += 8;
				curRenderedNoteType.add(text);
				text.sprTracker = note;
				// Debug.logTrace('Test: ${i[0]}, startThing: $startThing, endThing: $endThing);
			}
		}

		// NEXT SECTION
		if (curSection < _song.notes.length - 1)
		{
			for (i in _song.notes[curSection + 1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note));
				}
			}
		}

		// NEXT EVENTS
		var startThing:Float = sectionStartTime(1);
		var endThing:Float = sectionStartTime(2);
		for (i in _song.events)
		{
			if (endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	private function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var strumTime:Float = i[0];
		var noteData:Int = i[1];
		var sustainLength:Null<Float> = i[2];
		var noteType:String = i[3];

		var note:Note = new Note(strumTime, noteData % 4, null, null, true);
		if (sustainLength != null)
		{ // Common note
			if (!Std.isOfType(i[3], String)) // Convert old note type to new note type format
			{
				noteType = noteTypeIntMap.get(i[3]);
			}
			if (i.length > 3 && (noteType == null || noteType.length < 1))
			{
				i.remove(noteType);
			}
			note.sustainLength = sustainLength;
			note.noteType = noteType;
		}
		else
		{ // Event note
			note.loadGraphic(Paths.getGraphic('eventArrow'));
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if (i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.noteData = -1;
			noteData = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(noteData * GRID_SIZE) + GRID_SIZE;
		if (isNextSection && _song.notes[curSection].mustHitSection != _song.notes[curSection + 1].mustHitSection)
		{
			if (noteData > 3)
			{
				note.x -= GRID_SIZE * 4;
			}
			else if (sustainLength != null)
			{
				note.x += GRID_SIZE * 4;
			}
		}

		note.y = (GRID_SIZE * (isNextSection ? 16 : 0)) * zoomList[curZoom]
			+ Math.floor(getYfromStrum((strumTime - sectionStartTime(isNextSection ? 1 : 0)) % (Conductor.stepCrochet * _song.notes[curSection].lengthInSteps),
				false));
		return note;
	}

	private function getEventName(names:Array<Dynamic>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (name in names)
		{
			if (addedOne)
				retStr += ', ';
			retStr += name[0];
			addedOne = true;
		}
		return retStr;
	}

	private function setupSusNote(note:Note):FlxSprite
	{
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, (gridBG.height / gridMult))
			+ (GRID_SIZE * zoomList[curZoom])
			- GRID_SIZE / 2);
		var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if (height < minHeight)
			height = minHeight;
		if (height < 1)
			height = 1; // Prevents error of invalid height

		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, height);
		return spr;
	}

	private function addSection(lengthInSteps:Int = 16):Void
	{
		var section:SectionDef = {
			sectionNotes: [],
			lengthInSteps: lengthInSteps,
			typeOfSection: 0,
			mustHitSection: true,
			gfSection: false,
			bpm: _song.bpm,
			changeBPM: false,
			altAnim: false
		};

		_song.notes.push(section);
	}

	private function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;

		if (noteDataToCheck > -1)
		{
			if (note.mustPress != _song.notes[curSection].mustHitSection)
				noteDataToCheck += 4;
			for (i in _song.notes[curSection].sectionNotes)
			{
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in _song.events)
			{
				if (i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
					changeEventSelected();
					break;
				}
			}
		}

		updateGrid();
		updateNoteUI();
	}

	private function deleteNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;
		if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSection].mustHitSection)
			noteDataToCheck += 4;

		if (note.noteData > -1) // Normal Notes
		{
			for (i in _song.notes[curSection].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					if (i == curSelectedNote)
						curSelectedNote = null;
					// Debug.logTrace('FOUND EVIL NOTE');
					_song.notes[curSection].sectionNotes.remove(i);
					break;
				}
			}
		}
		else // Events
		{
			for (i in _song.events)
			{
				if (i[0] == note.strumTime)
				{
					if (i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					// Debug.logTrace('FOUND EVIL EVENT');
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	private function doANoteThing(cs:Float, d:Int, style:Int):Void
	{
		var delnote:Bool = false;
		if (strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive((note:Note) ->
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1, strumLine.y + 1)) && note.noteData == d % 4)
				{
					// Debug.logTrace('Trying to delete note...');
					if (!delnote)
						deleteNote(note);
					delnote = true;
				}
			});
		}

		if (!delnote)
		{
			addNote(cs, d, style);
		}
	}

	private function clearSong():Void
	{
		for (section in _song.notes)
		{
			section.sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(?strum:Float, ?data:Int, ?type:Int):Void
	{
		// undos.push(_song.notes);
		var noteStrum:Float = getStrumTime(dummyArrow.y, false) + sectionStartTime();
		var noteData:Int = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var noteSus:Float = 0;
		var noteType:Int = currentType;

		if (strum != null)
			noteStrum = strum;
		if (data != null)
			noteData = data;
		if (type != null)
			noteType = type;

		if (noteData > -1)
		{
			_song.notes[curSection].sectionNotes.push([noteStrum, noteData, noteSus, noteTypeIntMap.get(noteType)]);
			curSelectedNote = _song.notes[curSection].sectionNotes[_song.notes[curSection].sectionNotes.length - 1];
		}
		else
		{
			var event:String = eventList[Std.parseInt(eventDropDown.selectedId)][0];
			var text1:String = value1InputText.text;
			var text2:String = value2InputText.text;
			_song.events.push([noteStrum, [[event, text1, text2]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
			changeEventSelected();
		}

		if (FlxG.keys.pressed.CONTROL && noteData > -1)
		{
			_song.notes[curSection].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, noteTypeIntMap.get(noteType)]);
		}

		// Debug.logTrace('$noteData, $noteStrum, $curSection');
		strumTimeInputText.text = Std.string(curSelectedNote[0]);

		updateGrid();
		updateNoteUI();
	}

	// TODO Undos and redos
	// I theorize that these methods do not work because, instead of cloning the sections, they are just getting a reference to them
	private function undo():Void
	{
		// if (undos.length > 0)
		// {
		// 	redos.push(_song.notes);
		// 	_song.notes = undos.pop();
		// 	Debug.logTrace(_song.notes);
		// 	updateGrid();
		// }
	}

	private function redo():Void
	{
		// if (redos.length > 0)
		// {
		// 	undos.push(_song.notes);
		// 	_song.notes = redos.pop();
		// 	Debug.logTrace(_song.notes);
		// 	updateGrid();
		// }
	}

	private function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = zoomList[curZoom];
		if (!doZoomCalc)
			zoom = 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + (gridBG.height / gridMult) * zoom, 0, 16 * Conductor.stepCrochet);
	}

	private function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = zoomList[curZoom];
		if (!doZoomCalc)
			zoom = 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + (gridBG.height / gridMult) * zoom);
	}

	// TODO Finish the sectionLength feature so we can have 3/4 time signature and such

	/*
		private function calculateSectionLengths(?sec:SectionDef):Int
		{
			var sectionLengthSum:Int = 0;

			for (i in _song.notes)
			{
				var sectionLength:Int = i.lengthInSteps;

				if (i.typeOfSection == Section.COPYCAT)
					sectionLength * 2;

				sectionLengthSum += sectionLength;

				if (sec != null && sec == i)
				{
					break;
				}
			}

			return sectionLengthSum;
		}
	 */
	private function getNotes():Array<Array<Dynamic>>
	{
		var noteData:Array<Array<Dynamic>> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	private function loadJson(songId:String):Void
	{
		var difficulty:String = Difficulty.getDifficultyFilePath(PlayState.storyDifficulty);
		PlayState.song = Song.loadSong(songId, difficulty);
		FlxG.resetState();
	}

	private function autosaveSong():Void
	{
		EngineData.save.data.autosave = Json.stringify({
			song: _song
		});
		EngineData.flushSave();
	}

	private function clearEvents():Void
	{
		_song.events = [];
		updateGrid();
	}

	// TODO Learn how to save things with tags in a specific order
	private function saveLevel():Void
	{
		_song.events.sort(sortByTime);
		var json:SongWrapper = {
			song: _song
		};

		var data:String = Json.stringify(json, '\t');

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Path.withExtension('${_song.songId}${Difficulty.getDifficultyFilePath(PlayState.storyDifficulty)}', Paths.JSON_EXT));
		}
	}

	private function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveEvents():Void
	{
		_song.events.sort(sortByTime);
		var eventsSong:SongDef = {
			songId: _song.songId,
			songName: _song.songName,
			player1: _song.player1,
			player2: _song.player2,
			gfVersion: _song.gfVersion,
			stage: _song.stage,
			arrowSkin: _song.arrowSkin,
			splashSkin: _song.splashSkin,
			bpm: _song.bpm,
			speed: _song.speed,
			needsVoices: _song.needsVoices,
			validScore: false,
			notes: [],
			events: _song.events
		};
		var json:SongWrapper = {
			song: eventsSong
		}

		var data:String = Json.stringify(json, '\t');

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Path.withExtension('events', Paths.JSON_EXT));
		}
	}

	private function onSaveComplete(e:Event):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		Debug.logInfo('Successfully saved LEVEL DATA.');
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
		Debug.logError('Problem saving Level data');
	}
}

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, ?text:String, size:Int = 8, embeddedFont:Bool = true)
	{
		super(x, y, fieldWidth, text, size, embeddedFont);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}
