package editors;

import Character.CharacterDef;
import chart.container.BasicNote;
import chart.container.Event;
import chart.container.Section;
import chart.container.Song;
import chart.io.MockChartReader;
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
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.util.FlxArrayUtil;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.typeLimit.OneOfTwo;
import haxe.Exception;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import lime.media.AudioBuffer;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import ui.AttachedSprite;
import ui.HealthIcon;
import util.CoolUtil;

using StringTools;

#if desktop
import haxe.io.Bytes;
import openfl.geom.Rectangle;
#end
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

typedef ChartSectionEntry = OneOfTwo<BasicNote, EventGroup>;

// TODO Fix the issues caused by switching from milliseconds to beats, specifically the issue that notes are rendered at incorrect Y values in the chart editor
// Note for implementing Kade's TimingStruct stuff: In Kade's ChartingState, every section is rendered at once, so the Y values increase with strum time; in Psych, each section is rendered at the same Y value
class ChartEditorState extends MusicBeatState
{
	// Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	public static final NOTE_TYPES:Array<String> = ['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation'];
	public static final GRID_SIZE:Int = 40;
	private static final GRID_MULT:Int = 2;
	private static final CAM_OFFSET:Int = 360;

	private static final TIP_TEXT:String = 'W/S or Mouse Wheel - Change Conductor\'s strum time\nPageUp/PageDown - Go to the previous/next section\nHold Shift to move 4x faster\nHold Control and click on a note to select it\nZ/X - Zoom Out/In\n\nEnter - Play your chart\nQ/E - Decrease/Increase Note Sustain Length\nSpace - Pause/Resume song';

	private var noteTypeIntMap:Map<Int, String> = [];
	private var noteTypeMap:Map<String, Null<Int>> = [];

	private var ignoreWarnings:Bool = false;

	private var undos:Array<Array<Section>> = [];
	private var redos:Array<Array<Section>> = [];
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
		],
		['Change BPM', 'Value 1: New BPM']
	];

	private var UI_box:FlxUITabMenu;

	private static var curSection:Int = 0;

	private static var lastSong:String = '';

	private var bpmTxt:FlxText;

	private var camPos:FlxObject;
	private var bullshitUI:FlxGroup;
	private var dummyArrow:FlxSprite;

	// Quant variables
	private static final QUANTS:Array<Float> = [
		4, // quarter
		2, // half
		4 / 3,
		1,
		4 / 8 // eight
	];
	private static var curQuant:Int = 0;

	private var quant:AttachedSprite;
	private var quantSpot:Int = 0;

	// Strum and Strum Note variables
	private static var vortex:Bool = false;

	private var strumLine:FlxSprite;
	private var strumLineNotes:FlxTypedGroup<StrumNote>;

	private var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	private var curRenderedNotes:FlxTypedGroup<Note>;
	private var curRenderedNoteType:FlxTypedGroup<FlxText>;

	private var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	private var nextRenderedNotes:FlxTypedGroup<Note>;

	private var gridBG:FlxSprite;

	private var curEventSelected:Int = 0;
	private var song:Song;

	/**
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	 */
	private var curSelectedNote:ChartSectionEntry;

	private var vocals:FlxSound;

	private var leftIcon:HealthIcon;
	private var rightIcon:HealthIcon;

	private var value1InputText:FlxUIInputText;
	private var value2InputText:FlxUIInputText;
	private var currentSongName:String;

	// Zoom variables
	private var zoomTxt:FlxText;
	private var curZoom:Int = 1;

	// TODO Figure out why this happens
	#if html5 // The grid gets all black when over 1/12 snap
	private static final ZOOMS:Array<Float> = [0.5, 1, 2, 4, 8, 12];
	#else
	private static final ZOOMS:Array<Float> = [0.5, 1, 2, 4, 8, 12, 16, 24];
	#end

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	private var waveformSprite:FlxSprite;
	private var gridLayer:FlxTypedGroup<FlxSprite>;

	override public function create():Void
	{
		super.create();

		if (PlayState.song != null)
		{
			song = PlayState.song;
		}
		else
		{
			song = Song.createTemplateSong();
			PlayState.song = song;
		}

		if (song.notes.length <= 0)
		{
			addSection();
		}

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Chart Editor', song.name);
		#end

		vortex = EngineData.save.data.chart_vortex;
		ignoreWarnings = EngineData.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuDesat'));
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

		if (curSection >= song.notes.length)
		{
			curSection = song.notes.length - 1;
			Debug.logTrace('Set curSection to $curSection');
		}

		FlxG.mouse.visible = true;

		currentSongName = song.id;
		loadAudioBuffer();

		Conductor.tempo = song.bpm;
		Conductor.mapTempoChanges(song);

		TimingStruct.generateTimings(song);

		song.recalculateAllSectionTimes();

		poggers();

		loadSong();

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
		for (i in 0...NoteKey.createAll().length * 2)
		{
			var note:StrumNote = new StrumNote(GRID_SIZE * (i + 1), strumLine.y, i % NoteKey.createAll().length, 0);
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
			{name: 'Event', label: 'Event'},
			{name: 'Charting', label: 'Charting'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 400);
		UI_box.x = 640 + GRID_SIZE / 2;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		var tipText:FlxText = new FlxText(UI_box.x, UI_box.y + UI_box.height + 8, 0, TIP_TEXT, 16);
		tipText.setFormat(Paths.font('vcr.ttf'), tipText.size, FlxColor.WHITE, LEFT);
		tipText.scrollFactor.set();
		add(tipText);

		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		updateHeads();
		reloadGridLayer();
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

	private var lastBeat:Float;
	private var colorSine:Float = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music.playing)
		{
			var timingSeg:TimingStruct = TimingStruct.getTimingAtBeat(curDecimalBeat);

			if (timingSeg != null)
			{
				var timingSegTempo:Float = timingSeg.tempo;

				if (timingSegTempo != Conductor.tempo)
				{
					Debug.logTrace('Setting tempo from ${Conductor.tempo} to $timingSegTempo');
					Conductor.tempo = timingSegTempo;
				}
			}
		}

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
		song.id = UI_songTitle.text;

		FlxG.mouse.visible = true; // cause reasons. trust me
		camPos.y = strumLine.y;
		if (!disableAutoScrolling.checked)
		{
			if (Math.ceil(strumLine.y) >= (gridBG.height / 2))
			{
				if (song.notes[curSection + 1] == null)
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

		var section:Section = getSectionByBeat(curDecimalBeat);

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
							var curSelectedNote:BasicNote = curSelectedNote;
							curSelectedNote.type = noteTypeIntMap.get(currentType);
							updateGrid();
						}
						else
						{
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
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * section.lengthInSteps) * ZOOMS[curZoom])
				{
					addNote();
				}
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * section.lengthInSteps) * ZOOMS[curZoom])
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
				FlxG.sound.muteKeys = null;
				FlxG.sound.volumeDownKeys = null;
				FlxG.sound.volumeUpKeys = null;
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
					FlxG.sound.muteKeys = null;
					FlxG.sound.volumeDownKeys = null;
					FlxG.sound.volumeUpKeys = null;
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
			if (FlxG.keys.justPressed.ENTER)
			{
				autosaveSong();
				FlxG.mouse.visible = false;
				PlayState.song = song;
				FlxG.sound.music.stop();
				if (vocals != null)
					vocals.stop();

				LoadingState.loadAndSwitchState(new PlayState());
			}

			if (curSelectedNote != null && curSelectedNote is BasicNote)
			{
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.semiquaverLength);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.semiquaverLength);
				}
			}

			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.sound.music.stop();
				FlxG.mouse.visible = false;
				FlxG.switchState(new MasterEditorMenuState());
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
				curZoom--;
				updateZoom();
			}
			if (FlxG.keys.justPressed.X && curZoom < ZOOMS.length - 1)
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
				FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.semiquaverLength * 0.8);
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

				var time:Float = 700 * elapsed * holdingShift;

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

			// AWW YOU MADE IT SEXY <3333 THX SHADMAR
			if (vortex && !blockInput)
			{
				// TODO Somehow make this stuff not dependent on there being 4 strum notes
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
							doANoteThing(curDecimalBeat, i, style);
					}
				}

				var daTimes:Array<Float> = [];

				var time:Float = Conductor.semiquaverLength * QUANTS[curQuant];
				var cuquant:Int = Std.int(32 / QUANTS[curQuant]);
				for (i in 0...cuquant)
				{
					daTimes.push(section.startTime + time * i);
				}

				if (FlxG.keys.justPressed.LEFT)
				{
					--curQuant;
					if (curQuant < 0)
						curQuant = 0;

					quantSpot *= Std.int(32 / QUANTS[curQuant]);
				}
				if (FlxG.keys.justPressed.RIGHT)
				{
					curQuant++;
					if (curQuant > QUANTS.length - 1)
						curQuant = QUANTS.length - 1;
					quantSpot *= Std.int(32 / QUANTS[curQuant]);
				}
				quant.animation.play('q', true, false, curQuant);
				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();

					if (FlxG.keys.pressed.UP)
					{
						var foundASpot:Bool = false;
						var i:Int = daTimes.length - 1; // backwards for loop
						while (i >= 0)
						{
							if (Math.ceil(FlxG.sound.music.time) >= Math.ceil(daTimes[i]) && !foundASpot)
							{
								foundASpot = true;
								FlxG.sound.music.time = daTimes[i];
							}
							i--;
						}
						feces = FlxG.sound.music.time - time;
					}
					else
					{
						var foundASpot:Bool = false;
						for (i in daTimes)
						{
							if (Math.floor(FlxG.sound.music.time) <= Math.floor(i) && !foundASpot)
							{
								foundASpot = true;
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

					var strum:Float = 0;

					if (curSelectedNote != null && curSelectedNote is BasicNote)
					{
						var curSelectedNote:BasicNote = curSelectedNote;
						// TODO Strum beat thing
						// strum = curSelectedNote.strumTime;
						strum = TimingStruct.getTimeFromBeat(curSelectedNote.beat);
					}

					var secStart:Float = section.startTime;
					// TODO figure out what this issue is
					var time:Float = (feces - secStart) - (strum - secStart); // idk math find out why it doesn't work on any other section other than 0
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
								{
									var curSelectedNote:BasicNote = curSelectedNote;
									if (curSelectedNote.data == i)
										curSelectedNote.sustainLength += time - curSelectedNote.sustainLength - Conductor.semiquaverLength;
								}
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

			// TODO Implement a way to go to any section by typing its number into something, because that would make things *SO* much easier

			if (FlxG.keys.justPressed.PAGEUP)
			{
				changeSection(curSection - shiftThing);
			}
			else if (FlxG.keys.justPressed.PAGEDOWN)
			{
				changeSection(curSection + shiftThing);
			}

			if (FlxG.keys.justPressed.HOME)
				changeSection(0);
			else if (FlxG.keys.justPressed.END)
			{
				changeSection(song.notes.length - 1);
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

		strumLine.y = getYFromBeat((curDecimalBeat - section.startBeat) / ZOOMS[curZoom]);

		camPos.y = strumLine.y;
		for (strumNote in strumLineNotes)
		{
			strumNote.y = strumLine.y;
			strumNote.alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		bpmTxt.text = '${FlxMath.roundDecimal(Conductor.songPosition / TimingConstants.MILLISECONDS_PER_SECOND, 2)} / ${FlxMath.roundDecimal(FlxG.sound.music.length / TimingConstants.MILLISECONDS_PER_SECOND, 2)}\n\nSection: $curSection\n\nBeat: ${FlxMath.roundDecimal(curDecimalBeat, 3)}\n\nStep: $curStep\n\nTempo: ${Conductor.tempo}';

		var playedSound:Array<Bool> = [false, false, false, false]; // Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive((note:Note) ->
		{
			note.alpha = 1;
			if (curSelectedNote != null && curSelectedNote is BasicNote)
			{
				var curSelectedNote:BasicNote = curSelectedNote;

				var noteDataToCheck:Int = note.noteData;
				if (noteDataToCheck > -1 && note.mustPress != section.mustHitSection)
					noteDataToCheck += NoteKey.createAll().length;

				if (curSelectedNote.beat == note.beat
					&& ((curSelectedNote.sustainLength == null && noteDataToCheck < 0)
						|| (curSelectedNote.sustainLength != null && curSelectedNote.data == noteDataToCheck)))
				{
					colorSine += elapsed;
					var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal);
				}
			}

			if (note.beat <= curDecimalBeat)
			{
				note.alpha = 0.4;
				// FIXME Notes on the very first beat of a measure most of the time don't light the Vortex strums
				if (note.beat >= lastBeat && FlxG.sound.music.playing && note.noteData > -1)
				{
					var data:Int = note.noteDataModulo;
					var noteDataToCheck:Int = note.noteData;
					if (noteDataToCheck > -1 && note.mustPress != section.mustHitSection)
						noteDataToCheck += NoteKey.createAll().length;

					var strumNote:StrumNote = strumLineNotes.members[noteDataToCheck];
					strumNote.playAnim('confirm', true);
					strumNote.resetAnim = (note.sustainLength / TimingConstants.MILLISECONDS_PER_SECOND) + 0.15;

					if (!playedSound[data])
					{
						if ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress))
						{
							var soundToPlay:String = 'hitsound';
							if (song.player1 == 'gf')
							{ // Easter egg
								soundToPlay = 'GF_${data + 1}';
							}

							FlxG.sound.play(Paths.getSound(soundToPlay)).pan = note.noteData < NoteKey.createAll().length ? -0.3 : 0.3; // would be coolio
							playedSound[data] = true;
						}

						data = note.noteData;
						if (note.mustPress != section.mustHitSection)
						{
							data += NoteKey.createAll().length;
						}
					}
				}
			}
		});

		if (metronome.checked && lastBeat != curDecimalBeat)
		{
			// var metroInterval:Float = TimingConstants.SECONDS_PER_MINUTE / metronomeStepper.value;
			// var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / TimingConstants.MILLISECONDS_PER_SECOND);
			// var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / TimingConstants.MILLISECONDS_PER_SECOND);
			var metroStep = Math.floor(curDecimalBeat);
			var lastMetroStep = Math.floor(lastBeat);
			if (metroStep != lastMetroStep)
			{
				FlxG.sound.play(Paths.getSound('Metronome_Tick'));
			}
		}
		lastBeat = curDecimalBeat;
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var section:Section = getSectionByBeat(curDecimalBeat);
			var check:FlxUICheckBox = sender;
			var name:String = check.name;
			switch (name)
			{
				case 'check_mustHit':
					section.mustHitSection = check.checked;

					updateGrid();
					updateHeads();

				case 'check_gf':
					section.gfSection = check.checked;

					updateGrid();
					updateHeads();

				case 'check_altAnim':
					section.altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var section:Section = getSectionByBeat(curDecimalBeat);
			var nums:FlxUINumericStepper = sender;
			var wname:String = nums.name;
			switch (wname)
			{
				case 'section_length':
					section.lengthInSteps = Std.int(nums.value);
					updateGrid();
				case 'song_speed':
					song.speed = nums.value;
				case 'song_bpm':
					song.bpm = nums.value;

					if (song.events[0].events[0].type != "Change BPM")
						Lib.application.window.alert("i'm crying, first event isn't a bpm change. fuck you");
					else
					{
						song.events[0].events[0].value1 = nums.value;
						updateGrid();
					}

					TimingStruct.generateTimings(song);

					song.recalculateAllSectionTimes();

					poggers();
				case 'note_susLength':
					if (curSelectedNote != null && curSelectedNote is BasicNote)
					{
						var curSelectedNote:BasicNote = curSelectedNote;
						curSelectedNote.sustainLength = nums.value;
						updateGrid();
					}
					else
					{
						sender.value = 0;
					}
				case 'note_beat':
					if (curSelectedNote != null && curSelectedNote is BasicNote)
					{
						var curSelectedNote:BasicNote = curSelectedNote;
						curSelectedNote.beat = nums.value;
						updateGrid();
					}
				case 'inst_volume':
					FlxG.sound.music.volume = nums.value;
				case 'voices_volume':
					vocals.volume = nums.value;
			}
		}
		else if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == noteSplashesInputText)
			{
				song.splashSkin = noteSplashesInputText.text;
			}
			else if (curSelectedNote != null)
			{
				var curSelectedNote:EventGroup = curSelectedNote;

				if (sender == value1InputText)
				{
					curSelectedNote.events[curEventSelected].value1 = value1InputText.text;
					updateGrid();
				}
				else if (sender == value2InputText)
				{
					curSelectedNote.events[curEventSelected].value2 = value2InputText.text;
					updateGrid();
				}
			}
		}
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
		UI_songTitle = new FlxUIInputText(10, 10, 70, song.id, 8);
		blockPressWhileTypingOn.push(UI_songTitle);

		var voicesCheckBox:FlxUICheckBox = new FlxUICheckBox(10, 25, null, null, 'Has voice track', 100);
		voicesCheckBox.checked = song.needsVoices;
		voicesCheckBox.callback = () ->
		{
			song.needsVoices = voicesCheckBox.checked;
		};

		var saveButton:FlxButton = new FlxButton(110, 8, 'Save', () ->
		{
			fileSaveDialog();
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
				loadJson(song.id);
			}, null, ignoreWarnings));
		});

		var loadAutosaveButton:FlxButton = new FlxButton(reloadSongJsonButton.x, reloadSongJsonButton.y + 30, 'Load Autosave', () ->
		{
			var song:Song = Unserializer.run(EngineData.save.data.autosave);
			PlayState.song = song;
			FlxG.resetState();
		});

		var loadEventsButton:FlxButton = new FlxButton(loadAutosaveButton.x, loadAutosaveButton.y + 30, 'Load Events', () ->
		{
			var file:String = Paths.json(Path.join(['songs', song.id, 'events']));
			if (Paths.exists(file))
			{
				clearEvents();
				var events:Song = Song.loadSong('events', '', song.id);
				song.events = events.events;
				changeSection(curSection);
				TimingStruct.generateTimings(song);
			}
		});

		var saveEventsButton:FlxButton = new FlxButton(110, reloadSongJsonButton.y, 'Save Events', () ->
		{
			eventsFileSaveDialog();
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
				for (section in song.notes)
				{
					FlxArrayUtil.clearArray(section.sectionNotes);
				}
				updateGrid();
			}, null, ignoreWarnings));
		});
		clearNotesButton.color = FlxColor.RED;
		clearNotesButton.label.color = FlxColor.WHITE;

		var bpmStepper:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 339, 1);
		bpmStepper.value = Conductor.tempo;
		bpmStepper.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(bpmStepper);

		var speedStepper:FlxUINumericStepper = new FlxUINumericStepper(10, bpmStepper.y + 35, 0.1, 1, 0.1, 10, 1);
		speedStepper.value = song.speed;
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
				song.player1 = characterList[Std.parseInt(character)];
				updateHeads();
			});
		player1DropDown.selectedLabel = song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown:FlxUIDropDownMenu = new FlxUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40,
			FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true), (character:String) ->
			{
				song.gfVersion = characterList[Std.parseInt(character)];
				updateHeads();
			});
		gfVersionDropDown.selectedLabel = song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown:FlxUIDropDownMenu = new FlxUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40,
			FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true), (character:String) ->
			{
				song.player2 = characterList[Std.parseInt(character)];
				updateHeads();
			});
		player2DropDown.selectedLabel = song.player2;
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
				song.stage = stageList[Std.parseInt(character)];
			});
		stageDropDown.selectedLabel = song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		var skin:String = PlayState.song.noteSkin;
		if (skin == null)
			skin = '';
		noteSkinInputText = new FlxUIInputText(player2DropDown.x, player2DropDown.y + 50, 150, skin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, song.splashSkin, 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', () ->
		{
			song.noteSkin = noteSkinInputText.text;
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
	private var check_altAnim:FlxUICheckBox;

	private var sectionToCopy:Int = 0;
	private var notesCopied:Array<ChartSectionEntry>;

	private function addSectionUI():Void
	{
		var sectionTabGroup:FlxUI = new FlxUI(null, UI_box);
		sectionTabGroup.name = 'Section';

		var section:Section = getSectionByBeat(curDecimalBeat);

		stepperLength = new FlxUINumericStepper(10, 10, 4, 0, 0, 999, 0);
		stepperLength.value = section.lengthInSteps;
		blockPressWhileTypingOnStepper.push(stepperLength);
		stepperLength.name = 'section_length';

		check_mustHitSection = new FlxUICheckBox(10, 30, null, null, 'Must hit section', 100);
		check_mustHitSection.checked = section.mustHitSection;
		check_mustHitSection.name = 'check_mustHit';

		check_gfSection = new FlxUICheckBox(130, 30, null, null, 'GF section', 100);
		check_gfSection.checked = section.gfSection;
		check_gfSection.name = 'check_gf';

		check_altAnim = new FlxUICheckBox(10, 60, null, null, 'Alt Animation', 100);
		check_altAnim.checked = section.altAnim;
		check_altAnim.name = 'check_altAnim';

		var copyButton:FlxButton = new FlxButton(10, 150, 'Copy Section', () ->
		{
			var section:Section = getSectionByBeat(curDecimalBeat);

			FlxArrayUtil.clearArray(notesCopied);
			sectionToCopy = curSection;
			for (note in section.sectionNotes)
			{
				notesCopied.push(note);
			}

			for (event in song.events)
			{
				if (event.beat >= section.startBeat && section.endBeat > event.beat)
				{
					var copiedEventArray:Array<EventEntry> = Reflect.copy(event.events);
					notesCopied.push({beat: event.beat, events: copiedEventArray});
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(10, 180, 'Paste Section', () ->
		{
			if (notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var section:Section = getSectionByBeat(curDecimalBeat);

			var addToTime:Float = Conductor.semiquaverLength * (section.lengthInSteps * (curSection - sectionToCopy));

			for (note in notesCopied)
			{
				if (note is BasicNote)
				{
					var note:BasicNote = note;
					var newStrumTime:Float = TimingStruct.getTimeFromBeat(note.beat) + addToTime;
					var copiedNote:BasicNote = new BasicNote(newStrumTime, note.data, note.sustainLength, note.type,
						TimingStruct.getBeatFromTime(newStrumTime));
					section.sectionNotes.push(copiedNote);
				}
				else
				{
					var note:EventGroup = note;
					var newStrumTime:Float = TimingStruct.getTimeFromBeat(note.beat) + addToTime;
					var copiedEventArray:Array<EventEntry> = Reflect.copy(note.events);
					song.events.push({beat: TimingStruct.getBeatFromTime(newStrumTime), events: copiedEventArray});
				}
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(10, 210, 'Clear', () ->
		{
			var section:Section = getSectionByBeat(curDecimalBeat);
			FlxArrayUtil.clearArray(section.sectionNotes);

			var i:Int = song.events.length - 1;
			while (i >= 0)
			{
				var event:EventGroup = song.events[i];
				if (event != null && event.beat >= section.startBeat && section.endBeat > event.beat)
				{
					song.events.remove(event);
				}
				i--;
			}
			updateGrid();
			updateNoteUI();
		});

		var swapSection:FlxButton = new FlxButton(10, 240, 'Swap section', () ->
		{
			var section:Section = getSectionByBeat(curDecimalBeat);
			for (note in section.sectionNotes)
			{
				note.data = (note.data + NoteKey.createAll().length) % (NoteKey.createAll().length * 2);
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

			for (note in song.notes[sectionIndex - value].sectionNotes)
			{
				var strum:Float = TimingStruct.getTimeFromBeat(note.beat) + Conductor.semiquaverLength * (song.notes[sectionIndex].lengthInSteps * value);

				var copiedNote:BasicNote = new BasicNote(strum, note.data, note.sustainLength, note.type, TimingStruct.getBeatFromTime(strum));
				song.notes[sectionIndex].sectionNotes.push(copiedNote);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in song.events)
			{
				// TODO Convert this to work with beats
				var strumTime:Float = TimingStruct.getTimeFromBeat(event.beat);
				if (endThing > strumTime && strumTime >= startThing)
				{
					strumTime += Conductor.semiquaverLength * (song.notes[sectionIndex].lengthInSteps * value);
					var copiedEventArray:Array<EventEntry> = Reflect.copy(event.events);
					song.events.push({beat: event.beat, events: copiedEventArray});
				}
			}
			updateGrid();
		});
		var duetButton:FlxButton = new FlxButton(10, 320, 'Duet Notes', () ->
		{
			var section:Section = getSectionByBeat(curDecimalBeat);

			var duetNotes:Array<BasicNote> = [];
			for (note in section.sectionNotes)
			{
				var noteData:Int = note.data;
				if (noteData >= NoteKey.createAll().length)
				{
					noteData -= NoteKey.createAll().length;
				}
				else
				{
					noteData += NoteKey.createAll().length;
				}

				var copiedNote:BasicNote = new BasicNote(TimingStruct.getTimeFromBeat(note.beat), noteData, note.sustainLength, note.type, note.beat);
				duetNotes.push(copiedNote);
			}

			for (note in duetNotes)
			{
				section.sectionNotes.push(note);
			}

			updateGrid();
		});
		var mirrorButton:FlxButton = new FlxButton(10, 350, 'Mirror Notes', () ->
		{
			var section:Section = getSectionByBeat(curDecimalBeat);

			for (note in section.sectionNotes)
			{
				var noteData:Int = Std.int(note.data % NoteKey.createAll().length);
				noteData = NoteKey.createAll().length - 1 - noteData;
				if (note.data >= NoteKey.createAll().length)
					noteData += NoteKey.createAll().length;

				note.data = noteData;
			}

			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();

		var startSectionButton:FlxButton = new FlxButton(10, 380, "Play Here", () ->
		{
			PlayState.song = song;
			FlxG.sound.music.stop();
			if (!PlayState.isSM)
				vocals.stop();
			PlayState.startTime = getSectionByBeat(curDecimalBeat).startTime;
			for (note in curRenderedNotes)
			{
				note.kill();
				note.destroy();
			}
			curRenderedNotes.clear();

			for (sustain in curRenderedSustains)
			{
				sustain.kill();
				sustain.destroy();
			}
			curRenderedSustains.clear();

			LoadingState.loadAndSwitchState(new PlayState());
		});

		sectionTabGroup.add(stepperLength);
		sectionTabGroup.add(check_mustHitSection);
		sectionTabGroup.add(check_gfSection);
		sectionTabGroup.add(check_altAnim);
		sectionTabGroup.add(copyButton);
		sectionTabGroup.add(pasteButton);
		sectionTabGroup.add(clearSectionButton);
		sectionTabGroup.add(swapSection);
		sectionTabGroup.add(copyLastStepper);
		sectionTabGroup.add(copyLastButton);
		sectionTabGroup.add(duetButton);
		sectionTabGroup.add(mirrorButton);
		sectionTabGroup.add(startSectionButton);

		UI_box.addGroup(sectionTabGroup);
	}

	private var stepperSusLength:FlxUINumericStepper;
	// TODO Find a way to scale steppers
	private var stepperBeat:FlxUINumericStepper;
	private var noteTypeDropDown:FlxUIDropDownMenu;
	private var currentType:Int = 0;

	private function addNoteUI():Void
	{
		var noteTabGroup:FlxUI = new FlxUI(null, UI_box);
		noteTabGroup.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.semiquaverLength / 2, 0, 0, Math.POSITIVE_INFINITY, 3);
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		stepperBeat = new FlxUINumericStepper(10, 65, 1, 0, 0, Math.POSITIVE_INFINITY, 3);
		stepperBeat.name = 'note_beat';
		blockPressWhileTypingOnStepper.push(stepperBeat);

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
			if (curSelectedNote != null && curSelectedNote is BasicNote)
			{
				var curSelectedNote:BasicNote = curSelectedNote;
				curSelectedNote.type = noteTypeIntMap.get(currentType);
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		noteTabGroup.add(new FlxText(10, 10, 0, 'Sustain length:'));
		noteTabGroup.add(new FlxText(10, 50, 0, 'Beat:'));
		noteTabGroup.add(new FlxText(10, 90, 0, 'Type:'));
		noteTabGroup.add(stepperSusLength);
		noteTabGroup.add(stepperBeat);
		noteTabGroup.add(noteTypeDropDown);

		UI_box.addGroup(noteTabGroup);
	}

	private var eventDropDown:FlxUIDropDownMenu;
	private var descText:FlxText;
	private var selectedEventText:FlxText;

	private function addEventsUI():Void
	{
		var eventTabGroup:FlxUI = new FlxUI(null, UI_box);
		eventTabGroup.name = 'Event';

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

		var events:Array<String> = eventList.map((array:Array<String>) -> array[0]);

		var text:FlxText = new FlxText(20, 30, 0, 'Event:');
		eventTabGroup.add(text);
		eventDropDown = new FlxUIDropDownMenu(20, 50, FlxUIDropDownMenu.makeStrIdLabelArray(events, true), (pressed:String) ->
		{
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventList[selectedEvent][1];
			if (curSelectedNote != null && eventList != null)
			{
				if (curSelectedNote != null && !(curSelectedNote is BasicNote))
				{
					var curSelectedNote:EventGroup = curSelectedNote;
					curSelectedNote.events[curEventSelected].type = eventList[selectedEvent][0];
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
			if (curSelectedNote != null && !(curSelectedNote is BasicNote)) // Is event note
			{
				var curSelectedNote:EventGroup = curSelectedNote;
				if (curSelectedNote.events.length < 2)
				{
					song.events.remove(curSelectedNote);
					this.curSelectedNote = null;
				}
				else
				{
					curSelectedNote.events.remove(curSelectedNote.events[curEventSelected]);
				}

				// TODO Use FlxMath.wrap here
				var eventArray:Array<EventEntry>;
				--curEventSelected;
				if (curEventSelected < 0)
					curEventSelected = 0;
				else if (curSelectedNote != null)
				{
					eventArray = curSelectedNote.events;
					if (curEventSelected >= eventArray.length)
						curEventSelected = eventArray.length - 1;
				}

				changeEventSelected();

				TimingStruct.generateTimings(song);
				song.recalculateAllSectionTimes();
				poggers();

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
			if (curSelectedNote != null && !(curSelectedNote is BasicNote)) // Is event note
			{
				var curSelectedNote:EventGroup = curSelectedNote;
				var eventsGroup:Array<EventEntry> = curSelectedNote.events;
				eventsGroup.push({type: '', value1: '', value2: ''});

				changeEventSelected(1);

				TimingStruct.generateTimings(song);
				song.recalculateAllSectionTimes();
				poggers();

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
		if (curSelectedNote != null && !(curSelectedNote is BasicNote)) // Is event note
		{
			var curSelectedNote:EventGroup = curSelectedNote;
			curEventSelected += change;
			if (curEventSelected < 0)
				curEventSelected = Std.int(curSelectedNote.events.length) - 1;
			else if (curEventSelected >= curSelectedNote.events.length)
				curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ${curEventSelected + 1} / ${curSelectedNote.events.length}';
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

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, song.bpm, 1, 1500, 1);
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
			if (vocals != null)
			{
				vocals.stop();
			}
		}

		vocals = new FlxSound();
		if (song.needsVoices)
		{
			vocals.loadEmbedded(Paths.getVoices(currentSongName));
			FlxG.sound.list.add(vocals);
		}
		generateSong();
		FlxG.sound.music.pause();

		var section:Section = getSectionByBeat(curDecimalBeat);

		Conductor.songPosition = section.startTime;
		FlxG.sound.music.time = Conductor.songPosition;
	}

	private function generateSong():Void
	{
		FlxG.sound.playMusic(Paths.getInst(currentSongName));
		if (song.needsVoices)
		{
			FlxG.sound.music.volume = 0.6;
		}

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
			vocals.play();
			updateGrid();
			updateSectionUI();
		};
	}

	private function generateUI():Void
	{
		for (item in bullshitUI)
		{
			item.kill();
			item.destroy();
		}
		bullshitUI.clear();

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	private function sectionStartTime(add:Int = 0):Float
	{
		var section:Section = song.notes[curSection + add];
		if (section != null)
			return section.startTime;
		return 0;
	}

	private function sectionStartBeat(add:Int = 0):Float
	{
		var section:Section = song.notes[curSection + add];
		if (section != null)
			return section.startBeat;
		return 0;
	}

	private function updateZoom():Void
	{
		zoomTxt.text = 'Zoom: ${ZOOMS[curZoom]}x';
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
		}
	}

	private function reloadGridLayer():Void
	{
		var noteKeyCount:Int = NoteKey.createAll().length;
		var gridColumnCount:Int = noteKeyCount * 2 + 1; // +1 for the event row

		gridLayer.clear();
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * gridColumnCount, Std.int(GRID_SIZE * 32 * ZOOMS[curZoom]));
		gridLayer.add(gridBG);

		#if desktop
		if (waveformEnabled != null)
		{
			updateWaveform();
		}
		#end

		var gridBlack:FlxSprite = new FlxSprite(0,
			gridBG.height / 2).makeGraphic(Std.int(GRID_SIZE * gridColumnCount), Std.int(gridBG.height / 2), FlxColor.BLACK);
		gridBlack.alpha = 0.4;
		gridLayer.add(gridBlack);

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * noteKeyCount)).makeGraphic(2, Std.int(gridBG.height),
			FlxColor.BLACK);
		gridLayer.add(gridBlackLine);

		for (i in 1...4)
		{
			var beatsep1:FlxSprite = new FlxSprite(gridBG.x, (GRID_SIZE * (noteKeyCount * curZoom)) * i).makeGraphic(Std.int(gridBG.width), 1, 0x44FF0000);
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
			return;
		}

		var section:Section = getSectionByBeat(curDecimalBeat);

		var sampleMult:Float = audioBuffers[checkForVoices].sampleRate / 44100;
		var index:Int = Std.int(section.startTime * 44.0875 * sampleMult);
		var drawIndex:Int = 0;

		var steps:Int = section.lengthInSteps;
		if (Math.isNaN(steps) || steps < 1)
			steps = Conductor.SEMIQUAVERS_PER_MEASURE;
		var samplesPerRow:Int = Std.int(((Conductor.semiquaverLength * steps * 1.1 * sampleMult) / Conductor.SEMIQUAVERS_PER_MEASURE) / ZOOMS[curZoom]);
		if (samplesPerRow < 1)
			samplesPerRow = 1;
		var waveBytes:Bytes = audioBuffers[checkForVoices].data.toBytes();

		var min:Float = 0;
		var max:Float = 0;
		while (index < waveBytes.length)
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
			if (curSelectedNote is BasicNote)
			{
				var curSelectedNote:BasicNote = curSelectedNote;
				curSelectedNote.sustainLength += value;
				curSelectedNote.sustainLength = Math.max(curSelectedNote.sustainLength, 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	private function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		var section:Section = getSectionByBeat(curDecimalBeat);

		FlxG.sound.music.pause();
		FlxG.sound.music.time = section.startTime;

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSection = 0;
			Debug.logTrace('Set curSection to $curSection');
		}

		if (vocals != null)
		{
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	private function changeSection(sec:Int = 0, updateMusic:Bool = true):Void
	{
		// TODO Find a way to add another "if" condition for whether FlxG.sound.music.time will be larger than FlxG.sound.music.length
		// TODO Also, use FlxMath more for these sorts of min/max things
		sec = FlxMath.wrap(sec, 0, song.notes.length - 1);

		curSection = sec;
		Debug.logTrace('Set curSection to $curSection');

		if (updateMusic)
		{
			var section:Section = getSectionByBeat(curDecimalBeat);

			FlxG.sound.music.pause();
			FlxG.sound.music.time = section.startTime;
			if (vocals != null)
			{
				vocals.pause();
				vocals.time = FlxG.sound.music.time;
			}
		}
		Conductor.songPosition = FlxG.sound.music.time;

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	private function updateSectionUI():Void
	{
		var section:Section = getSectionByBeat(curDecimalBeat);

		stepperLength.value = section.lengthInSteps;
		check_mustHitSection.checked = section.mustHitSection;
		check_gfSection.checked = section.gfSection;
		check_altAnim.checked = section.altAnim;

		updateHeads();
	}

	private function updateHeads():Void
	{
		var healthIconP1:String = loadHealthIconFromCharacter(song.player1);
		var healthIconP2:String = loadHealthIconFromCharacter(song.player2);

		var section:Section = getSectionByBeat(curDecimalBeat);

		if (section.mustHitSection)
		{
			leftIcon.changeIcon(healthIconP1);
			rightIcon.changeIcon(healthIconP2);
			if (section.gfSection)
				leftIcon.changeIcon('gf');
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(healthIconP1);
			if (section.gfSection)
				leftIcon.changeIcon('gf');
		}
	}

	private function loadHealthIconFromCharacter(char:String):String
	{
		// FIXME This crashes the game if the save window is open
		var path:String = Paths.json(Path.join(['characters', char]));
		var characterDef:CharacterDef = null;
		if (Paths.exists(path))
		{
			characterDef = Paths.getJsonDirect(path);
		}
		else
		{
			characterDef = Paths.getJson(Path.join(['characters', Character.DEFAULT_CHARACTER]));
		}

		return characterDef.healthIcon;
	}

	private function updateNoteUI():Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote is BasicNote)
			{
				var curSelectedNote:BasicNote = curSelectedNote;
				stepperSusLength.value = curSelectedNote.sustainLength;
				if (curSelectedNote.type != null)
				{
					currentType = noteTypeMap.get(curSelectedNote.type);
					if (currentType <= 0)
					{
						noteTypeDropDown.selectedLabel = '';
					}
					else
					{
						noteTypeDropDown.selectedLabel = '$currentType. ${curSelectedNote.type}';
					}
				}
				stepperBeat.value = curSelectedNote.beat;
			}
			else
			{
				var curSelectedNote:EventGroup = curSelectedNote;
				eventDropDown.selectedLabel = curSelectedNote.events[curEventSelected].type;
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if (selected > 0 && selected < eventList.length)
				{
					descText.text = eventList[selected][1];
				}
				value1InputText.text = curSelectedNote.events[curEventSelected].value1;
				value2InputText.text = curSelectedNote.events[curEventSelected].value2;

				stepperBeat.value = curSelectedNote.beat;
			}
		}
	}

	private function updateGrid():Void
	{
		curRenderedNotes.clear();
		curRenderedSustains.clear();
		curRenderedNoteType.clear();
		nextRenderedNotes.clear();
		nextRenderedSustains.clear();

		var section:Section = getSectionByBeat(curDecimalBeat);

		// CURRENT SECTION
		for (noteDef in section.sectionNotes)
		{
			var note:Note = setupNoteData(noteDef, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note));
			}

			if (noteDef.type != null && note.noteType != null && note.noteType.length > 0)
			{
				var typeInt:Null<Int> = noteTypeMap.get(noteDef.type);
				var theType:String = Std.string(typeInt);
				if (typeInt == null)
					theType = '?';

				var text:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				text.setFormat(Paths.font('vcr.ttf'), text.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				text.xAdd = -32;
				text.yAdd = 6;
				text.borderSize = 1;
				curRenderedNoteType.add(text);
				text.sprTracker = note;
			}
			note.mustPress = section.mustHitSection;
			if (noteDef.data >= NoteKey.createAll().length)
				note.mustPress = !note.mustPress;
		}

		// CURRENT EVENTS
		for (eventGroup in song.events)
		{
			if (eventGroup.beat >= section.startBeat && section.endBeat > eventGroup.beat)
			{
				var note:Note = setupNoteData(eventGroup, false);
				curRenderedNotes.add(note);

				var textString:String = 'Event: ${note.eventName} (Beat ${Math.floor(note.beat)})\nValue 1: ${note.eventVal1}\nValue 2: ${note.eventVal2}';
				if (note.eventLength > 1)
					textString = '${note.eventLength} Events:\n${note.eventName}';

				var text:AttachedFlxText = new AttachedFlxText(0, 0, 400, textString, 12);
				text.setFormat(Paths.font('vcr.ttf'), text.size, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
				text.xAdd = -410;
				text.borderSize = 1;
				if (note.eventLength > 1)
					text.yAdd += 8;
				curRenderedNoteType.add(text);
				text.sprTracker = note;
			}
		}

		// NEXT SECTION
		if (curSection < song.notes.length - 1)
		{
			for (noteDef in song.notes[curSection + 1].sectionNotes)
			{
				var note:Note = setupNoteData(noteDef, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note));
				}
			}
		}

		// NEXT EVENTS
		var startBeat:Float = sectionStartBeat(1);
		var endBeat:Float = sectionStartBeat(2);
		for (eventGroup in song.events)
		{
			if (eventGroup.beat >= startBeat && endBeat > eventGroup.beat)
			{
				var note:Note = setupNoteData(eventGroup, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	private function setupNoteData(entry:ChartSectionEntry, isNextSection:Bool):Note
	{
		var beat:Float = 0;
		if (entry is BasicNote)
		{
			var entry:BasicNote = entry;
			beat = entry.beat;
		}
		else
		{
			var entry:EventGroup = entry;
			beat = entry.beat;
		}

		var strumTime:Float = TimingStruct.getTimeFromBeat(beat);

		var noteData:Int = entry is BasicNote ? cast(entry, BasicNote).data : -1;

		var note:Note = new Note(strumTime, noteData % NoteKey.createAll().length, null, false, true, beat);
		if (entry is BasicNote)
		{ // Common note
			var entry:BasicNote = entry;

			var sustainLength:Null<Float> = entry.sustainLength;
			var noteType:String = entry.type;
			note.sustainLength = sustainLength;
			note.noteType = noteType;
		}
		else
		{ // Event note
			var entry:EventGroup = entry;

			note.loadGraphic(Paths.getGraphic('eventArrow'));
			note.eventName = getEventName(entry.events);
			note.eventLength = entry.events.length;
			if (entry.events.length < 2)
			{
				note.eventVal1 = entry.events[0].value1;
				note.eventVal2 = entry.events[0].value2;
			}
			note.noteData = -1;
			noteData = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(noteData * GRID_SIZE) + GRID_SIZE;

		var section:Section = getSectionByBeat(beat);
		if (isNextSection && section.mustHitSection != song.notes[curSection + 1].mustHitSection)
		{
			if (noteData >= NoteKey.createAll().length)
			{
				note.x -= GRID_SIZE * NoteKey.createAll().length;
			}
			else if (entry is BasicNote)
			{
				note.x += GRID_SIZE * NoteKey.createAll().length;
			}
		}

		note.y = (GRID_SIZE * (isNextSection ? Conductor.SEMIQUAVERS_PER_MEASURE : 0)) * ZOOMS[curZoom]
			+ getYFromBeat(note.beat - sectionStartBeat(isNextSection ? 1 : 0), false);
		return note;
	}

	private function getEventName(names:Array<EventEntry>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (name in names)
		{
			if (addedOne)
				retStr += ', ';
			retStr += name.type;
			addedOne = true;
		}
		return retStr;
	}

	private function setupSusNote(note:Note):FlxSprite
	{
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.semiquaverLength * Conductor.SEMIQUAVERS_PER_MEASURE, 0,
			(gridBG.height / GRID_MULT))
			+ (GRID_SIZE * ZOOMS[curZoom])
			- GRID_SIZE / 2);
		var minHeight:Int = Std.int((GRID_SIZE * ZOOMS[curZoom] / 2) + GRID_SIZE / 2);
		if (height < minHeight)
			height = minHeight;
		if (height < 1)
			height = 1; // Prevents error of invalid height

		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, height);
		return spr;
	}

	private function addSection(lengthInSteps:Int = Conductor.SEMIQUAVERS_PER_MEASURE):Void
	{
		var daPos:Float = 0;
		var start:Float = 0;

		var bpm:Float = song.bpm;
		for (i in 0...curSection)
		{
			for (ii in TimingStruct.allTimings)
			{
				var data:TimingStruct = TimingStruct.getTimingAtTimestamp(start);
				if ((data != null ? data.tempo : song.bpm) != bpm && bpm != ii.tempo)
					bpm = ii.tempo;
			}
			start += Conductor.calculateCrotchetLength(bpm) * 4;
		}

		var section:Section = new Section();
		section.startTime = daPos;
		section.endTime = Math.POSITIVE_INFINITY;
		section.lengthInSteps = lengthInSteps;

		song.notes.push(section);
	}

	private function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;

		if (noteDataToCheck > -1)
		{
			var section:Section = getSectionByBeat(note.beat);
			if (note.mustPress != section.mustHitSection)
				noteDataToCheck += NoteKey.createAll().length;
			for (noteDef in section.sectionNotes)
			{
				if (noteDef != curSelectedNote && noteDef.beat == note.beat && noteDef.data == noteDataToCheck)
				{
					curSelectedNote = noteDef;
					break;
				}
			}
		}
		else
		{
			for (eventGroup in song.events)
			{
				if (eventGroup != curSelectedNote && eventGroup.beat == note.beat)
				{
					curSelectedNote = eventGroup;
					var curSelectedNote:EventGroup = curSelectedNote;
					curEventSelected = Std.int(curSelectedNote.events.length) - 1;
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
		var section:Section = getSectionByBeat(note.beat);
		if (noteDataToCheck > -1 && note.mustPress != section.mustHitSection)
			noteDataToCheck += NoteKey.createAll().length;

		if (note.noteData > -1) // Normal Notes
		{
			for (noteDef in section.sectionNotes)
			{
				if (noteDef.beat == note.beat && noteDef.data == noteDataToCheck)
				{
					if (noteDef == curSelectedNote)
						curSelectedNote = null;
					section.sectionNotes.remove(noteDef);
					break;
				}
			}
		}
		else // Events
		{
			for (eventGroup in song.events)
			{
				if (eventGroup.beat == note.beat)
				{
					if (eventGroup == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					song.events.remove(eventGroup);
					break;
				}
			}
		}

		updateGrid();
	}

	private function doANoteThing(beat:Float, noteData:Int, noteType:Int):Void
	{
		var delNote:Bool = false;
		var strumNote:StrumNote = strumLineNotes.members[noteData];
		if (strumNote.overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive((note:Note) ->
			{
				if (note.overlapsPoint(new FlxPoint(strumNote.x + 1, strumLine.y + 1))
					&& note.noteData == noteData % NoteKey.createAll().length)
				{
					if (!delNote)
						deleteNote(note);
					delNote = true;
				}
			});
		}

		if (!delNote)
		{
			addNote(beat, noteData, noteType);
		}
	}

	private function clearSong():Void
	{
		for (section in song.notes)
		{
			FlxArrayUtil.clearArray(section.sectionNotes);
		}

		updateGrid();
	}

	private function poggers():Void
	{
		/*
			var notes:Array<BasicNote> = [];

			for (section in song.notes)
			{
				var removed:Array<BasicNote> = [];

				for (note in section.sectionNotes)
				{
					note.strumTime = TimingStruct.getTimeFromBeat(note.beat);
					note.sustainLength = TimingStruct.getTimeFromBeat(TimingStruct.getBeatFromTime(note.sustainLength));
					if (note.strumTime < section.startTime)
					{
						notes.push(note);
						removed.push(note);
					}
					if (note.strumTime > section.endTime)
					{
						notes.push(note);
						removed.push(note);
					}
				}

				for (i in removed)
				{
					section.sectionNotes.remove(i);
				}
			}

			for (section in song.notes)
			{
				var saveRemove:Array<BasicNote> = [];

				for (i in notes)
				{
					if (i.strumTime >= section.startTime && i.strumTime < section.endTime)
					{
						saveRemove.push(i);
						section.sectionNotes.push(i);
					}
				}

				for (i in saveRemove)
					notes.remove(i);
			}
		 */
		/*
			for (note in curRenderedNotes)
			{
				note.strumTime = TimingStruct.getTimeFromBeat(note.beat);
				note.y = Math.floor(getYFromStrumTime(note.strumTime) * ZOOMS[curZoom]);
				note.sustainLength = TimingStruct.getTimeFromBeat(TimingStruct.getBeatFromTime(note.sustainLength));
				// if (note.noteCharterObject != null)
				// {
				// 	note.noteCharterObject.y = note.y + 40;
				// 	note.noteCharterObject.makeGraphic(8, Math.floor((getYFromStrumTime(note.strumTime + note.sustainLength) * ZOOMS[curZoom]) - note.y), FlxColor.WHITE);
				// }
			}
		 */
	}

	public function getSectionByTime(ms:Float, changeCurSectionIndex:Bool = false):Section
	{
		/*
			for (index => section in song.notes)
			{
				var startTime:Float = section.startTime;
				var endTime:Float = section.endTime;

				if (ms >= startTime && ms < endTime)
				{
					if (changeCurSectionIndex)
					{
						curSection = index;
					}
					return section;
				}
			}

			return null;
		 */

		return song.notes[curSection]; // This will have to do until I figure out how to make this work
	}

	public function getSectionByBeat(beat:Float, changeCurSectionIndex:Bool = false):Section
	{
		/*
			for (index => section in song.notes)
			{
				var startBeat:Float = section.startBeat;
				var endBeat:Float = section.endBeat;

				if (beat >= startBeat && beat < endBeat)
				{
					if (changeCurSectionIndex)
					{
						curSection = index;
					}
					return section;
				}
			}

			return null;
		 */

		return song.notes[curSection]; // This will have to do until I figure out how to make this work
	}

	private function addNote(?beat:Float, ?noteData:Int, ?noteType:Int):Void
	{
		undos.push(Reflect.copy(song.notes));

		var section:Section = getSectionByBeat(beat);
		if (beat == null)
		{
			section = getSectionByBeat(curDecimalBeat);
			beat = getBeatFromY(dummyArrow.y, false) + section.startBeat;
		}
		if (noteData == null)
		{
			noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		}

		var strumTime:Float = TimingStruct.getTimeFromBeat(beat);

		if (noteData > -1)
		{
			var sustainLength:Float = 0;
			if (noteType == null)
			{
				noteType = currentType;
			}
			var noteTypeString:String = noteTypeIntMap.get(noteType);

			var newNote:BasicNote = new BasicNote(strumTime, noteData, sustainLength, noteTypeString, beat);
			section.sectionNotes.push(newNote);
			curSelectedNote = newNote;

			if (FlxG.keys.pressed.CONTROL) // Copies the note to both players' strums
			{
				section.sectionNotes.push(new BasicNote(strumTime, (noteData + NoteKey.createAll().length) % (NoteKey.createAll().length * 2), sustainLength,
					noteTypeString, beat));
			}
		}
		else
		{
			var type:String = eventList[Std.parseInt(eventDropDown.selectedId)][0];
			var value1:String = value1InputText.text;
			var value2:String = value2InputText.text;
			song.events.push({beat: beat, events: [{type: type, value1: value1, value2: value2}]});
			curSelectedNote = song.events[song.events.length - 1];
			curEventSelected = 0;
			changeEventSelected();
		}

		stepperBeat.value = beat;

		updateGrid();
		updateNoteUI();
	}

	// TODO Undos and redos
	// I theorize that these methods do not work because, instead of cloning the sections, they are just getting a reference to them
	private function undo():Void
	{
		if (undos.length > 0)
		{
			var copiedNotes:Array<Section> = Reflect.copy(song.notes);
			redos.push(copiedNotes);
			song.notes = undos.pop();
			updateGrid();
		}
	}

	private function redo():Void
	{
		if (redos.length > 0)
		{
			var copiedNotes:Array<Section> = Reflect.copy(song.notes);
			undos.push(copiedNotes);
			song.notes = redos.pop();
			updateGrid();
		}
	}

	private function getStrumTimeFromY(y:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = doZoomCalc ? ZOOMS[curZoom] : 1;
		return FlxMath.remapToRange(y, gridBG.y, gridBG.y + (gridBG.height / GRID_MULT) * zoom, 0,
			Conductor.SEMIQUAVERS_PER_MEASURE * Conductor.semiquaverLength);
	}

	private function getYFromStrumTime(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = doZoomCalc ? ZOOMS[curZoom] : 1;
		return FlxMath.remapToRange(strumTime, 0, Conductor.SEMIQUAVERS_PER_MEASURE, gridBG.y, gridBG.y + (gridBG.height / GRID_MULT) * zoom);
	}

	private function getBeatFromY(y:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = doZoomCalc ? ZOOMS[curZoom] : 1;
		return FlxMath.remapToRange(y, gridBG.y, gridBG.y + (gridBG.height / GRID_MULT) * zoom, 0, Conductor.CROTCHETS_PER_MEASURE);
	}

	private function getYFromBeat(beat:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = doZoomCalc ? ZOOMS[curZoom] : 1;
		return FlxMath.remapToRange(beat, 0, Conductor.CROTCHETS_PER_MEASURE, gridBG.y, gridBG.y + (gridBG.height / GRID_MULT) * zoom);
	}

	private function loadJson(songId:String):Void
	{
		var difficulty:String = Difficulty.getDifficultyFilePath(PlayState.storyDifficulty);
		PlayState.song = Song.loadSong(songId, difficulty);
		FlxG.resetState();
	}

	private function autosaveSong():Void
	{
		EngineData.save.data.autosave = Serializer.run(song);
		EngineData.flushSave();
	}

	private function clearEvents():Void
	{
		FlxArrayUtil.clearArray(song.events);
		updateGrid();
	}

	private var _file:FileReference;

	private function fileBrowseDialog():Void
	{
		// This is to fix the crash caused by the chart editor loading a new section whilst the file dialog is opened
		if (FlxG.sound.music.playing)
		{
			FlxG.sound.music.pause();
			if (vocals != null)
				vocals.pause();
		}

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
			var loadedSong:Song = Json.parse(jsonString);
			if (loadedSong != null)
			{
				if (loadedSong.notes != null) // Make sure it's really a dialogue character
				{
					var cutName:String = Path.withoutExtension(_file.name);
					loadJson(cutName);
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

	// TODO Learn how to save things with tags in a specific order
	private function fileSaveDialog():Void
	{
		// This is to fix the crash caused by the chart editor loading a new section whilst the file dialog is opened
		if (FlxG.sound.music.playing)
		{
			FlxG.sound.music.pause();
			if (vocals != null)
				vocals.pause();
		}

		song.events.sort(sortByTime);
		var json:MockSongWrapper = {
			song: Song.toSongDef(song)
		};

		var data:String = Json.stringify(json, '\t');

		if (data != null && data.length > 0)
		{
			data += '\n'; // I like newlines at the ends of files.
			addSaveListeners();
			_file.save(data, Path.withExtension('${song.id}${Difficulty.getDifficultyFilePath(PlayState.storyDifficulty)}', Paths.JSON_EXT));
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

	private function sortByTime(obj1:ChartSectionEntry, obj2:ChartSectionEntry):Int
	{
		var beat1:Float;
		if (obj1 is BasicNote)
		{
			var obj1:BasicNote = obj1;
			beat1 = obj1.beat;
		}
		else
		{
			var obj1:EventGroup = obj1;
			beat1 = obj1.beat;
		}

		var beat2:Float;
		if (obj2 is BasicNote)
		{
			var obj2:BasicNote = obj2;
			beat2 = obj2.beat;
		}
		else
		{
			var obj2:EventGroup = obj2;
			beat2 = obj2.beat;
		}

		return FlxSort.byValues(FlxSort.ASCENDING, beat1, beat2);
	}

	private function eventsFileSaveDialog():Void
	{
		// This is to fix the crash caused by the chart editor loading a new section whilst the file dialog is opened
		if (FlxG.sound.music.playing)
		{
			FlxG.sound.music.pause();
			if (vocals != null)
				vocals.pause();
		}

		song.events.sort(sortByTime);
		var eventsSong:MockSong = {
			player1: song.player1,
			player2: song.player2,
			gfVersion: song.gfVersion,
			stage: song.stage,
			noteSkin: song.noteSkin,
			splashSkin: song.splashSkin,
			bpm: song.bpm,
			speed: song.speed,
			needsVoices: song.needsVoices,
			validScore: false,
			notes: [],
			events: song.events,
			chartVersion: Song.LATEST_CHART
		};
		var json:MockSongWrapper = {
			song: eventsSong
		}

		var data:String = Json.stringify(json, '\t');

		if ((data != null) && (data.length > 0))
		{
			data += '\n'; // I like newlines at the ends of files.
			addSaveListeners();
			_file.save(data.trim(), Path.withExtension('events', Paths.JSON_EXT));
		}
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
