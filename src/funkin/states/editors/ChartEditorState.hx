package funkin.states.editors;

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
import funkin.Character.CharacterDef;
import funkin.EventType.EditorEventType;
import funkin.chart.container.Bar;
import funkin.chart.container.BasicNote;
import funkin.chart.container.Event;
import funkin.chart.container.Song;
import funkin.states.substates.PromptSubState;
import funkin.ui.AttachedSprite;
import funkin.ui.HealthIcon;
import funkin.ui.Waveform;
import funkin.util.CoolUtil;
import haxe.Exception;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;

using StringTools;

#if FEATURE_DISCORD
import funkin.Discord.DiscordClient;
#end

typedef ChartBarEntry = OneOfTwo<BasicNote, EventGroup>;

// FIXME Possible memory leak after opening this; it persists after closing the editor
class ChartEditorState extends MusicBeatState
{
	public static final GRID_SIZE:Int = 40;
	private static final GRID_MULT:Int = 2;
	private static final CAM_OFFSET:Int = 360;

	private static final TIP_TEXT:String = 'W/S or Mouse Wheel - Change Conductor\'s strum time\nPageUp/PageDown - Go to the previous/next bar\nHold Shift to move 4x faster\nHold Control and click on a note to select it\nZ/X - Zoom Out/In\n\nEnter - Play your chart\nQ/E - Decrease/Increase Note Sustain Length\nSpace - Pause/Resume song';

	private var noteTypeIntMap:Map<Int, String> = [];
	private var noteTypeMap:Map<String, Null<Int>> = [];

	private var undos:Array<Array<Bar>> = [];
	private var redos:Array<Array<Bar>> = [];

	/**
	 * Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	 */
	// TODO Push note types into this array like what is done with eventTypeList, maybe
	private var noteTypeList:Array<String> = ['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation'];

	private var eventTypeList:Array<EditorEventType> = [
		{
			name: '',
			description: 'Nothing. Yep, that\'s right.'
		},
		{
			name: 'Hey!',
			description: 'Plays the "Hey!" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s'
		},
		{
			name: 'Set GF Speed',
			description: 'Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!'
		},
		{
			name: 'Philly Glow',
			description: 'Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, I won\'t add it to other weeks.'
		},
		{
			name: 'Kill Henchmen',
			description: 'For Mom\'s songs, don\'t use this please, i love them :('
		},
		{
			name: 'Add Camera Zoom',
			description: 'Used on MILF on that one "hard" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default.'
		},
		{
			name: 'BG Freaks Expression',
			description: 'Should be used only in "school" Stage!'
		},
		{
			name: 'Trigger BG Ghouls',
			description: 'Should be used only in "schoolEvil" Stage!'
		},
		{
			name: 'Play Animation',
			description: 'Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)'
		},
		{
			name: 'Camera Follow Pos',
			description: 'Value 1: X\nValue 2: Y\n\nThe camera won\'t change the follow point\nafter using this, for getting it back\nto normal, leave both values blank.'
		},
		{
			name: 'Alt Idle Animation',
			description: 'Sets a specified suffix after the idle animation name.\nYou can use this to trigger "idle-alt" if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)'
		},
		{
			name: 'Screen Shake',
			description: 'Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: "1, 0.05".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity.'
		},
		{
			name: 'Change Character',
			description: 'Value 1: Character to change (Dad, BF, GF)\nValue 2: New character\'s name'
		},
		{
			name: 'Change Scroll Speed',
			description: 'Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds.'
		},
		{
			name: 'Change Tempo',
			description: 'Value 1: New tempo'
		},
		{
			name: 'Set Property',
			description: 'Value 1: Variable name\nValue 2: New value'
		}
	];

	private var UI_box:FlxUITabMenu;

	private static var currentBar:Int = 0;

	private static var lastSong:String = '';

	private var tempoTxt:FlxText;

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
	private var curSelectedNote:ChartBarEntry;

	private var leftIcon:HealthIcon;
	private var rightIcon:HealthIcon;

	#if CHART_FLIPPING
	private var leftIconBG:FlxSprite;
	private var rightIconBG:FlxSprite;
	#end

	private var value1InputText:FlxUIInputText;
	private var value2InputText:FlxUIInputText;
	private var currentSongName:String;

	// Zoom variables
	// TODO Figure out why this happens
	#if html5 // The grid gets all black when over 1/12 snap
	private static final ZOOMS:Array<Float> = [0.5, 1, 2, 4, 8, 12];
	#else
	private static final ZOOMS:Array<Float> = [0.5, 1, 2, 4, 8, 12, 16, 24];
	#end

	private var curZoom:Int = 1;
	private var zoomTxt:FlxText;

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	private var waveformInstrumental:Waveform;
	private var waveformVocals:Waveform;

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

		if (song.bars.length <= 0)
		{
			addBar();
		}

		if (song.bars[currentBar] == null)
		{
			currentBar = 0;
		}

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Chart Editor', song.name);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'main', 'backgrounds', 'menuDesat'])));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		gridLayer = new FlxTypedGroup();
		add(gridLayer);

		waveformInstrumental = new Waveform(GRID_SIZE, 0);
		waveformInstrumental.color = FlxColor.BLUE;
		waveformInstrumental.alpha = 0.5;
		add(waveformInstrumental);
		waveformVocals = new Waveform(GRID_SIZE, 0);
		waveformVocals.color = FlxColor.RED;
		waveformVocals.alpha = 0.5;
		add(waveformVocals);

		Debug.trackObject(waveformInstrumental);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.getGraphic('eventArrow'));
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		eventIcon.scrollFactor.set(1, 1);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		#if CHART_FLIPPING
		leftIconBG = new FlxSprite(GRID_SIZE).makeGraphic(Std.int(GRID_SIZE * NoteKey.createAll().length), GRID_SIZE, FlxColor.CYAN);
		leftIconBG.y -= leftIconBG.height;
		leftIconBG.visible = false;
		rightIconBG = new FlxSprite(leftIconBG.x + leftIconBG.width,
			leftIconBG.y).makeGraphic(Std.int(GRID_SIZE * NoteKey.createAll().length), GRID_SIZE, FlxColor.CYAN);
		rightIconBG.visible = false;
		add(leftIconBG);
		add(rightIconBG);
		#end

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

		FlxG.mouse.visible = true;

		currentSongName = song.id;

		song.generateTimings();
		song.recalculateAllBarTimes();
		Conductor.prepareFromSong(song);

		loadSong();

		tempoTxt = new FlxText(1000, 50, 0, 16);
		tempoTxt.scrollFactor.set();
		add(tempoTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * (NoteKey.createAll().length * 2 + 1)), 4);
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
			{name: 'Bar', label: 'Bar'},
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
		addBarUI();
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
			setBar(0);
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

		if (song.inst.playing)
		{
			var timingSeg:TimingSegment = song.getTimingAtBeat(curDecimalBeat);

			if (timingSeg != null)
			{
				var timingSegTempo:Float = timingSeg.tempo;

				if (timingSegTempo != Conductor.tempo)
				{
					Conductor.tempo = timingSegTempo;
				}
			}
		}

		if (song.inst.time < 0)
		{
			song.inst.pause();
			song.inst.time = 0;
		}
		else if (song.inst.time > song.inst.length)
		{
			setBar(0);
		}
		Conductor.songPosition = song.inst.time;
		song.id = UI_songTitle.text;

		// Reason for this: When the mouse is over the Flixel debugger UI while FlxG.mouse.visible is being set to true, it get sets to false afterward by the debugger
		// Maybe I'll try making a GitHub issue for it
		FlxG.mouse.visible = true;
		camPos.y = strumLine.y;
		if (!disableAutoScrolling.checked)
		{
			if (Math.ceil(strumLine.y) >= (gridBG.height / GRID_MULT))
			{
				if (song.bars[currentBar + 1] == null)
				{
					addBar();
				}

				changeBar(1, false);
			}
			else if (strumLine.y < -10)
			{
				changeBar(-1, false);
			}
		}

		var bar:Bar = song.bars[currentBar];

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
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * bar.lengthInSteps) * ZOOMS[curZoom])
				{
					addNote();
				}
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * bar.lengthInSteps) * ZOOMS[curZoom])
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
				song.inst.stop();
				if (song.vocals != null)
					song.vocals.stop();

				LoadingState.loadAndSwitchState(new PlayState());
			}

			if (curSelectedNote != null && curSelectedNote is BasicNote)
			{
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(1 / Conductor.STEPS_PER_BEAT);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-1 / Conductor.STEPS_PER_BEAT);
				}
			}

			if (FlxG.keys.justPressed.ESCAPE)
			{
				song.inst.stop();
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
				if (song.inst.playing)
				{
					song.inst.pause();
					if (song.vocals != null)
						song.vocals.pause();
				}
				else
				{
					if (song.vocals != null)
					{
						song.vocals.play();
						song.vocals.pause();
						song.vocals.time = song.inst.time;
						song.vocals.play();
					}
					song.inst.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetBar(true);
				else
					resetBar();
			}

			if (FlxG.mouse.wheel != 0)
			{
				// FIXME Scrolling with a mouse is WAY too fast on HTML
				var stepAfterScroll:Float = Math.round(curDecimalStep * ZOOMS[curZoom] - FlxG.mouse.wheel) / ZOOMS[curZoom];
				var timeAfterScroll:Float = song.getTimeFromBeat(stepAfterScroll / Conductor.STEPS_PER_BEAT);

				song.inst.pause();
				song.inst.time = timeAfterScroll;
				if (song.vocals != null)
				{
					song.vocals.pause();
					song.vocals.time = song.inst.time;
				}
			}

			// ARROW VORTEX SHIT NO DEADASS

			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				song.inst.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL)
					holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT)
					holdingShift = 4;

				var time:Float = 700 * elapsed * holdingShift;

				if (FlxG.keys.pressed.W)
				{
					song.inst.time -= time;
				}
				else
					song.inst.time += time;

				if (song.vocals != null)
				{
					song.vocals.pause();
					song.vocals.time = song.inst.time;
				}
			}

			var style:Int = currentType;

			if (FlxG.keys.pressed.SHIFT)
			{
				style = 3;
			}

			// AWW YOU MADE IT SEXY <3333 THX SHADMAR
			if (check_vortex.checked && !blockInput)
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

				var time:Float = Conductor.stepLength * QUANTS[curQuant];
				var cuquant:Int = Std.int(32 / QUANTS[curQuant]);
				for (i in 0...cuquant)
				{
					daTimes.push(bar.startTime + time * i);
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
					song.inst.pause();

					if (FlxG.keys.pressed.UP)
					{
						var foundASpot:Bool = false;
						var i:Int = daTimes.length - 1; // backwards for loop
						while (i >= 0)
						{
							if (Math.ceil(song.inst.time) >= Math.ceil(daTimes[i]) && !foundASpot)
							{
								foundASpot = true;
								song.inst.time = daTimes[i];
							}
							i--;
						}
						feces = song.inst.time - time;
					}
					else
					{
						var foundASpot:Bool = false;
						for (i in daTimes)
						{
							if (Math.floor(song.inst.time) <= Math.floor(i) && !foundASpot)
							{
								foundASpot = true;
								song.inst.time = i;
							}
						}

						feces = song.inst.time + time;
					}
					FlxTween.tween(song.inst, {time: feces}, 0.1, {ease: FlxEase.circOut});
					if (song.vocals != null)
					{
						song.vocals.pause();
						song.vocals.time = song.inst.time;
					}

					var strum:Float = 0;

					if (curSelectedNote != null && curSelectedNote is BasicNote)
					{
						var curSelectedNote:BasicNote = curSelectedNote;
						strum = song.getTimeFromBeat(curSelectedNote.beat);
					}

					var barStart:Float = bar.startTime;
					// TODO figure out what this issue is
					var time:Float = (feces - barStart) - (strum - barStart); // idk math find out why it doesn't work on any other bar other than 0
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
							var beat:Float = song.getBeatFromTime(time);

							for (i in 0...controlArray.length)
							{
								if (controlArray[i])
								{
									var curSelectedNote:BasicNote = curSelectedNote;
									if (curSelectedNote.data == i)
										curSelectedNote.sustainLength += beat - curSelectedNote.sustainLength - 1 / Conductor.STEPS_PER_BEAT;
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

			// TODO Implement a way to go to any bar by typing its number into something, because that would make things *SO* much easier

			if (FlxG.keys.justPressed.PAGEUP)
			{
				changeBar(-shiftThing);
			}
			else if (FlxG.keys.justPressed.PAGEDOWN)
			{
				changeBar(shiftThing);
			}

			if (FlxG.keys.justPressed.HOME)
			{
				setBar(0);
			}
			else if (FlxG.keys.justPressed.END)
			{
				setBar(song.bars.length - 1);
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

		strumLineNotes.visible = quant.visible = check_vortex.checked;

		if (song.inst.time < 0)
		{
			song.inst.pause();
			song.inst.time = 0;
		}
		else if (song.inst.time > song.inst.length)
		{
			song.inst.pause();
			song.inst.time = 0;
			setBar(0);
		}
		Conductor.songPosition = song.inst.time;

		strumLine.y = getYFromBeat((curDecimalBeat - bar.startBeat) / ZOOMS[curZoom]);

		camPos.y = strumLine.y;
		for (strumNote in strumLineNotes)
		{
			strumNote.y = strumLine.y;
			strumNote.alpha = song.inst.playing ? 1 : 0.35;
		}

		tempoTxt.text = '${FlxMath.roundDecimal(Conductor.songPosition / TimingConstants.MILLISECONDS_PER_SECOND, 2)} / ${FlxMath.roundDecimal(song.inst.length / TimingConstants.MILLISECONDS_PER_SECOND, 2)}\n\nBar: $currentBar\n\nBeat: ${FlxMath.roundDecimal(curDecimalBeat, 3)}\n\nStep: ${FlxMath.roundDecimal(curDecimalStep, 3)}\n\nTempo: ${Conductor.tempo}';

		var playedSound:Array<Bool> = [false, false, false, false]; // Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive((note:Note) ->
		{
			note.alpha = 1;
			// FIXME This code from a Psych commit just fucks up the rendered note positions a lot
			// note.strumTime = note.unModifiedStrumTime - song.offset; // make it change mid time lol

			// // TODO This is from a Psych commit; replace the strumTime usage with beat usage (also figure out what this is for)
			// note.y = (GRID_SIZE) * ZOOMS[curZoom]
			// 	+ Math.floor(getYFromStrumTime((note.strumTime) % (Conductor.stepLength * song.bars[currentBar].lengthInSteps), false));
			// note.y = (GRID_SIZE) * ZOOMS[curZoom]
			// 	+ Math.floor(getYFromBeat((note.beat) % (song.bars[currentBar].lengthInSteps / Conductor.STEPS_PER_BEAT), false));
			if (curSelectedNote != null && curSelectedNote is BasicNote)
			{
				var curSelectedNote:BasicNote = curSelectedNote;

				var noteDataToCheck:Int = note.noteData;
				if (noteDataToCheck > -1 && note.mustPress != bar.mustHit)
					noteDataToCheck += NoteKey.createAll().length;

				if (curSelectedNote.beat == note.beat && (noteDataToCheck < 0 || curSelectedNote.data == noteDataToCheck))
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
				// Potential solution: Keep the "preview" of the next bar instead of reloading the entire UI when the bar changes, so the notes near the beginning will always light the strums
				if (note.beat >= lastBeat && song.inst.playing && note.noteData > -1)
				{
					var data:Int = note.noteDataModulo;
					var noteDataToCheck:Int = note.noteData;
					if (noteDataToCheck > -1 && note.mustPress != bar.mustHit)
						noteDataToCheck += NoteKey.createAll().length;
					#if CHART_FLIPPING
					if (bar.mustHit)
					{
						if (note.mustPress)
						{
							noteDataToCheck += NoteKey.createAll().length;
						}
						else
						{
							noteDataToCheck -= NoteKey.createAll().length;
						}
					}
					#end

					var strumNote:StrumNote = strumLineNotes.members[noteDataToCheck];
					strumNote.playAnim('confirm', true);

					strumNote.resetAnim = ((song.getTimeFromBeat(note.beat +
						note.sustainLength) - song.getTimeFromBeat(note.beat)) / TimingConstants.MILLISECONDS_PER_SECOND)
						+ 0.15;

					if (!playedSound[data])
					{
						if ((playSoundBf.checked && note.mustPress) || (playSoundOpponent.checked && !note.mustPress))
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
						if (note.mustPress != bar.mustHit)
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
			var metroStep:Int = Math.floor(curDecimalBeat);
			var lastMetroStep:Int = Math.floor(lastBeat);
			if (metroStep != lastMetroStep)
			{
				FlxG.sound.play(Paths.getSound('Metronome_Tick'));
			}
		}
		lastBeat = curDecimalBeat;
	}

	override public function destroy():Void
	{
		FlxG.cameras.reset();
		song = null;
		Conductor.song = null;
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var bar:Bar = song.bars[currentBar];
			var check:FlxUICheckBox = sender;
			var name:String = check.name;
			switch (name)
			{
				case 'check_bar_mustHit':
					bar.mustHit = check.checked;

					updateGrid();
					updateHeads();

				case 'check_bar_gfSings':
					bar.gfSings = check.checked;

					updateGrid();
					updateHeads();

				case 'check_bar_altAnim':
					bar.altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var bar:Bar = song.bars[currentBar];
			var nums:FlxUINumericStepper = sender;
			var wname:String = nums.name;
			switch (wname)
			{
				case 'stepper_bar_length':
					bar.lengthInSteps = Std.int(nums.value);
					updateGrid();
				case 'stepper_song_scrollSpeed':
					song.scrollSpeed = nums.value;
				case 'stepper_song_offset':
					song.offset = nums.value;
				case 'stepper_song_tempo':
					song.tempo = nums.value;
					updateGrid();
					song.generateTimings();
					song.recalculateAllBarTimes();
				case 'stepper_note_beat':
					if (curSelectedNote != null && curSelectedNote is BasicNote)
					{
						var curSelectedNote:BasicNote = curSelectedNote;
						curSelectedNote.beat = nums.value;
						updateGrid();
					}
				case 'stepper_note_sustainLength':
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
				case 'stepper_inst_volume':
					song.inst.volume = nums.value;
				case 'stepper_vocals_volume':
					song.vocals.volume = nums.value;
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
					curSelectedNote.events[curEventSelected].args[0] = value1InputText.text;
					updateGrid();
				}
				else if (sender == value2InputText)
				{
					curSelectedNote.events[curEventSelected].args[1] = value2InputText.text;
					updateGrid();
				}
			}
		}
	}

	private var check_mute_inst:FlxUICheckBox;
	private var check_vortex:FlxUICheckBox;
	private var check_ignoreWarnings:FlxUICheckBox;
	private var playSoundBf:FlxUICheckBox;
	private var playSoundOpponent:FlxUICheckBox;
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
			updateWaveform();
		});

		var reloadSongJsonButton:FlxButton = new FlxButton(reloadSongButton.x, saveButton.y + 30, 'Reload JSON', () ->
		{
			openSubState(new PromptSubState('This action will clear current progress.\n\nProceed?', 0, () ->
			{
				loadJson(song.id);
			}, null, check_ignoreWarnings.checked));
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
				changeBar();
				song.generateTimings();
			}
		});

		var saveEventsButton:FlxButton = new FlxButton(110, reloadSongJsonButton.y, 'Save Events', () ->
		{
			eventsFileSaveDialog();
		});

		var clearEventsButton:FlxButton = new FlxButton(320, 310, 'Clear events', () ->
		{
			openSubState(new PromptSubState('This action will clear current progress.\n\nProceed?', 0, clearEvents, null, check_ignoreWarnings.checked));
		});
		clearEventsButton.color = FlxColor.RED;
		clearEventsButton.label.color = FlxColor.WHITE;

		var clearNotesButton:FlxButton = new FlxButton(320, clearEventsButton.y + 30, 'Clear notes', () ->
		{
			openSubState(new PromptSubState('This action will clear current progress.\n\nProceed?', 0, () ->
			{
				for (bar in song.bars)
				{
					FlxArrayUtil.clearArray(bar.notes);
				}
				updateGrid();
			}, null, check_ignoreWarnings.checked));
		});
		clearNotesButton.color = FlxColor.RED;
		clearNotesButton.label.color = FlxColor.WHITE;

		var tempoStepper:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 339, 1);
		tempoStepper.value = Conductor.tempo;
		tempoStepper.name = 'stepper_song_tempo';
		blockPressWhileTypingOnStepper.push(tempoStepper);

		var scrollSpeedStepper:FlxUINumericStepper = new FlxUINumericStepper(10, tempoStepper.y + 35, 0.1, 1, 0.1, 10, 1);
		scrollSpeedStepper.value = song.scrollSpeed;
		scrollSpeedStepper.name = 'stepper_song_scrollSpeed';
		blockPressWhileTypingOnStepper.push(scrollSpeedStepper);

		var stepperOffset:FlxUINumericStepper = new FlxUINumericStepper(tempoStepper.x + 100, 70, 1, 0, -2000, 2000, 0);
		stepperOffset.value = song.offset;
		stepperOffset.name = 'stepper_song_offset';
		blockPressWhileTypingOnStepper.push(stepperOffset);

		var characterList:Array<String> = [];
		var charsLoaded:Map<String, Bool> = [];

		var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

		for (directory in directories)
		{
			var characterDirectory:String = Path.join([directory, 'data', 'characters']);
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

		var player1DropDown:FlxUIDropDownMenu = new FlxUIDropDownMenu(10, scrollSpeedStepper.y + 45,
			FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true), (character:String) ->
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
			var stageDirectory:String = Path.join([directory, 'data', 'stages']);
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
		songTabGroup.add(tempoStepper);
		songTabGroup.add(stepperOffset);
		songTabGroup.add(scrollSpeedStepper);
		songTabGroup.add(reloadNotesButton);
		songTabGroup.add(noteSkinInputText);
		songTabGroup.add(noteSplashesInputText);
		songTabGroup.add(new FlxText(tempoStepper.x, tempoStepper.y - 15, 0, 'Tempo:'));
		songTabGroup.add(new FlxText(stepperOffset.x, stepperOffset.y - 15, 0, 'Offset:'));
		songTabGroup.add(new FlxText(scrollSpeedStepper.x, scrollSpeedStepper.y - 15, 0, 'Scroll Speed:'));
		songTabGroup.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		songTabGroup.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		songTabGroup.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Player:'));
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
	private var check_bar_mustHit:FlxUICheckBox;
	private var check_gfSings:FlxUICheckBox;
	private var check_bar_altAnim:FlxUICheckBox;

	private var barToCopy:Int = 0;
	private var notesCopied:Array<ChartBarEntry> = [];

	private function addBarUI():Void
	{
		var barTabGroup:FlxUI = new FlxUI(null, UI_box);
		barTabGroup.name = 'Bar';

		var bar:Bar = song.bars[currentBar];

		stepperLength = new FlxUINumericStepper(10, 10, 4, 0, 0, 999, 0);
		stepperLength.value = bar.lengthInSteps;
		blockPressWhileTypingOnStepper.push(stepperLength);
		stepperLength.name = 'stepper_bar_length';

		check_bar_mustHit = new FlxUICheckBox(10, 30, null, null, 'Must Hit', 100);
		check_bar_mustHit.checked = bar.mustHit;
		check_bar_mustHit.name = 'check_bar_mustHit';

		check_gfSings = new FlxUICheckBox(130, 30, null, null, 'GF Sings', 100);
		check_gfSings.checked = bar.gfSings;
		check_gfSings.name = 'check_bar_gfSings';

		check_bar_altAnim = new FlxUICheckBox(10, 60, null, null, 'Alt Animation', 100);
		check_bar_altAnim.checked = bar.altAnim;
		check_bar_altAnim.name = 'check_bar_altAnim';

		var copyButton:FlxButton = new FlxButton(10, 150, 'Copy', () ->
		{
			var bar:Bar = song.bars[currentBar];

			FlxArrayUtil.clearArray(notesCopied);
			barToCopy = currentBar;
			for (note in bar.notes)
			{
				notesCopied.push(note);
			}

			for (event in song.events)
			{
				if (event.beat >= bar.startBeat && bar.endBeat > event.beat)
				{
					var copiedEventArray:Array<EventEntry> = Reflect.copy(event.events);
					notesCopied.push({beat: event.beat, events: copiedEventArray});
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(10, 180, 'Paste', () ->
		{
			if (notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var bar:Bar = song.bars[currentBar];

			var addToBeat:Float = (bar.lengthInSteps / Conductor.STEPS_PER_BEAT) * (currentBar - barToCopy);

			for (note in notesCopied)
			{
				if (note is BasicNote)
				{
					var note:BasicNote = note;
					var newBeat:Float = note.beat + addToBeat;
					var copiedNote:BasicNote = new BasicNote(note.data, note.sustainLength, note.type, newBeat);
					bar.notes.push(copiedNote);
				}
				else
				{
					var note:EventGroup = note;
					var newBeat:Float = note.beat + addToBeat;
					var copiedEventArray:Array<EventEntry> = Reflect.copy(note.events);
					var copiedEventGroup:EventGroup = {beat: newBeat, events: copiedEventArray};
					song.events.push(copiedEventGroup);
				}
			}
			updateGrid();
		});

		var clearBarButton:FlxButton = new FlxButton(10, 210, 'Clear', () ->
		{
			var bar:Bar = song.bars[currentBar];
			FlxArrayUtil.clearArray(bar.notes);

			var i:Int = song.events.length - 1;
			while (i >= 0)
			{
				var event:EventGroup = song.events[i];
				if (event != null && event.beat >= bar.startBeat && bar.endBeat > event.beat)
				{
					song.events.remove(event);
				}
				i--;
			}
			updateGrid();
			updateNoteUI();
		});

		var swapBar:FlxButton = new FlxButton(10, 240, 'Swap', () ->
		{
			var bar:Bar = song.bars[currentBar];
			for (note in bar.notes)
			{
				note.data = (note.data + NoteKey.createAll().length) % (NoteKey.createAll().length * 2);
			}
			updateGrid();
		});

		var copyLastStepper:FlxUINumericStepper = new FlxUINumericStepper(110, 276, 1, 1, Math.NEGATIVE_INFINITY, Math.POSITIVE_INFINITY, 0);
		blockPressWhileTypingOnStepper.push(copyLastStepper);

		var copyLastButton:FlxButton = new FlxButton(10, 270, 'Copy Previous', () ->
		{
			var value:Int = Std.int(copyLastStepper.value);
			if (value == 0)
				return;

			var barIndex:Int = FlxMath.maxInt(currentBar, value);

			for (note in song.bars[barIndex - value].notes)
			{
				var beat:Float = note.beat + ((song.bars[barIndex].lengthInSteps / Conductor.STEPS_PER_BEAT) * value);

				var copiedNote:BasicNote = new BasicNote(note.data, note.sustainLength, note.type, beat);
				song.bars[barIndex].notes.push(copiedNote);
			}

			var startTime:Float = barStartTime(-value);
			var endTime:Float = barStartTime(-value + 1);
			for (event in song.events)
			{
				// TODO Convert this to work with beats
				var strumTime:Float = song.getTimeFromBeat(event.beat);
				if (endTime > strumTime && strumTime >= startTime)
				{
					strumTime += Conductor.stepLength * (song.bars[barIndex].lengthInSteps * value);
					var copiedEventArray:Array<EventEntry> = Reflect.copy(event.events);
					song.events.push({beat: event.beat, events: copiedEventArray});
				}
			}
			updateGrid();
		});
		var duetButton:FlxButton = new FlxButton(10, 320, 'Duet Notes', () ->
		{
			var bar:Bar = song.bars[currentBar];

			var duetNotes:Array<BasicNote> = [];
			for (note in bar.notes)
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

				var copiedNote:BasicNote = new BasicNote(noteData, note.sustainLength, note.type, note.beat);
				duetNotes.push(copiedNote);
			}

			for (note in duetNotes)
			{
				bar.notes.push(note);
			}

			updateGrid();
		});
		var mirrorButton:FlxButton = new FlxButton(10, 350, 'Mirror Notes', () ->
		{
			var bar:Bar = song.bars[currentBar];

			for (note in bar.notes)
			{
				var noteData:Int = Std.int(note.data % NoteKey.createAll().length);
				noteData = NoteKey.createAll().length - 1 - noteData;
				if (note.data >= NoteKey.createAll().length)
					noteData += NoteKey.createAll().length;

				note.data = noteData;
			}

			updateGrid();
		});

		var startBarButton:FlxButton = new FlxButton(200, mirrorButton.y, 'Play Here', () ->
		{
			PlayState.song = song;
			song.inst.stop();
			if (!PlayState.isSM)
				song.vocals.stop();
			PlayState.startTime = song.bars[currentBar].startTime;
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

		barTabGroup.add(stepperLength);
		barTabGroup.add(check_bar_mustHit);
		barTabGroup.add(check_gfSings);
		barTabGroup.add(check_bar_altAnim);
		barTabGroup.add(copyButton);
		barTabGroup.add(pasteButton);
		barTabGroup.add(clearBarButton);
		barTabGroup.add(swapBar);
		barTabGroup.add(copyLastStepper);
		barTabGroup.add(copyLastButton);
		barTabGroup.add(duetButton);
		barTabGroup.add(mirrorButton);
		barTabGroup.add(startBarButton);

		UI_box.addGroup(barTabGroup);
	}

	private var stepperSustainLength:FlxUINumericStepper;
	private var stepperBeat:FlxUINumericStepper;
	private var noteTypeDropDown:FlxUIDropDownMenu;
	private var currentType:Int = 0;

	private function addNoteUI():Void
	{
		var noteTabGroup:FlxUI = new FlxUI(null, UI_box);
		noteTabGroup.name = 'Note';

		stepperBeat = new FlxUINumericStepper(10, 25, 1 / Conductor.STEPS_PER_BEAT, 0, 0, Math.POSITIVE_INFINITY, 3,
			new FlxUIInputText(0, 0, 75)); // Text field argument is for making it wider
		stepperBeat.name = 'stepper_note_beat';
		blockPressWhileTypingOnStepper.push(stepperBeat);

		stepperSustainLength = new FlxUINumericStepper(10, stepperBeat.y + 40, 1 / (Conductor.STEPS_PER_BEAT * 2), 0, 0, Math.POSITIVE_INFINITY, 3,
			new FlxUIInputText(0, 0, 75));
		stepperSustainLength.name = 'stepper_note_sustainLength';
		blockPressWhileTypingOnStepper.push(stepperSustainLength);

		var key:Int = 0;
		var noteTypes:Array<String> = [];
		while (key < noteTypeList.length)
		{
			noteTypes.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if FEATURE_SCRIPTS
		var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

		for (directory in directories)
		{
			var noteTypeDirectory:String = Path.join([directory, 'data', 'note_types']);
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
							noteTypes.push(noteTypeId);
							noteTypeMap.set(noteTypeId, key);
							noteTypeIntMap.set(key, noteTypeId);
							key++;
						}
					}
				}
			}
		}
		#end

		for (i in 1...noteTypes.length)
		{
			noteTypes[i] = '$i. ${noteTypes[i]}';
		}

		noteTypeDropDown = new FlxUIDropDownMenu(10, stepperSustainLength.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(noteTypes, true), (character:String) ->
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

		noteTabGroup.add(new FlxText(10, stepperBeat.y - 15, 0, 'Beat:'));
		noteTabGroup.add(new FlxText(10, stepperSustainLength.y - 15, 0, 'Sustain Length:'));
		noteTabGroup.add(new FlxText(10, noteTypeDropDown.y - 15, 0, 'Type:'));
		noteTabGroup.add(stepperBeat);
		noteTabGroup.add(stepperSustainLength);
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

		var eventTypeMap:Map<String, Bool> = [];
		#if FEATURE_SCRIPTS
		var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

		for (directory in directories)
		{
			var eventTypeDirectory:String = Path.join([directory, 'data', 'event_types']);
			if (Paths.fileSystem.exists(eventTypeDirectory))
			{
				for (file in Paths.fileSystem.readDirectory(eventTypeDirectory))
				{
					var path:String = Path.join([eventTypeDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path)
						&& Path.extension(path) == Paths.TEXT_EXT
						&& file != Path.withExtension('readme', Paths.TEXT_EXT))
					{
						var eventId:String = Path.withoutExtension(file);
						if (!eventTypeMap.exists(eventId))
						{
							eventTypeList.push({
								name: eventId,
								description: Paths.getTextDirect(path)
							});
							eventTypeMap.set(eventId, true);
						}
					}
				}
			}
		}
		#end

		descText = new FlxText(20, 200, 0, eventTypeList[0].description);

		var eventTypes:Array<String> = eventTypeList.map((eventType:EditorEventType) -> eventType.name);

		var text:FlxText = new FlxText(20, 30, 0, 'Event:');
		eventTabGroup.add(text);
		eventDropDown = new FlxUIDropDownMenu(20, 50, FlxUIDropDownMenu.makeStrIdLabelArray(eventTypes, true), (pressed:String) ->
		{
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventTypeList[selectedEvent].description;
			if (curSelectedNote != null && eventTypeList != null)
			{
				if (curSelectedNote != null && !(curSelectedNote is BasicNote))
				{
					var curSelectedNote:EventGroup = curSelectedNote;
					curSelectedNote.events[curEventSelected].type = eventTypeList[selectedEvent].name;
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
			if (curSelectedNote != null && !(curSelectedNote is BasicNote)) // Is event
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

				song.generateTimings();
				song.recalculateAllBarTimes();

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
			if (curSelectedNote != null && !(curSelectedNote is BasicNote)) // Is event
			{
				var curSelectedNote:EventGroup = curSelectedNote;
				var eventsGroup:Array<EventEntry> = curSelectedNote.events;
				eventsGroup.push({type: '', args: []});

				changeEventSelected(1);

				song.generateTimings();
				song.recalculateAllBarTimes();

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
		if (curSelectedNote != null && !(curSelectedNote is BasicNote)) // Is event
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
	private var waveformUseInstrumental:FlxUICheckBox;
	private var waveformUseVocals:FlxUICheckBox;
	private var instVolume:FlxUINumericStepper;
	private var vocalsVolume:FlxUINumericStepper;

	private function addChartingUI():Void
	{
		var chartTabGroup:FlxUI = new FlxUI(null, UI_box);
		chartTabGroup.name = 'Charting';

		if (EngineData.save.data.chart_waveformInst == null)
		{
			EngineData.save.data.chart_waveformInst = false;
			EngineData.flushSave();
		}
		if (EngineData.save.data.chart_waveformVocals == null)
		{
			EngineData.save.data.chart_waveformVocals = false;
			EngineData.flushSave();
		}

		waveformUseInstrumental = new FlxUICheckBox(10, 90, null, null, 'Waveform for Instrumental', 100);
		waveformUseInstrumental.checked = EngineData.save.data.chart_waveformInst;
		waveformUseInstrumental.callback = () ->
		{
			EngineData.save.data.chart_waveformInst = waveformUseInstrumental.checked;
			EngineData.flushSave();
			waveformInstrumental.visible = waveformUseInstrumental.checked;
			updateWaveform();
		};
		waveformInstrumental.visible = waveformUseInstrumental.checked;

		waveformUseVocals = new FlxUICheckBox(waveformUseInstrumental.x + 120, waveformUseInstrumental.y, null, null, 'Waveform for Vocals', 100);
		waveformUseVocals.checked = EngineData.save.data.chart_waveformVocals;
		waveformUseVocals.callback = () ->
		{
			EngineData.save.data.chart_waveformVocals = waveformUseVocals.checked;
			EngineData.flushSave();
			waveformVocals.visible = waveformUseVocals.checked;
			updateWaveform();
		};
		waveformVocals.visible = waveformUseVocals.checked;

		check_mute_inst = new FlxUICheckBox(10, 310, null, null, 'Mute Instrumental (in editor)', 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = () ->
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			song.inst.volume = vol;
		};
		check_vortex = new FlxUICheckBox(10, 160, null, null, 'Vortex Editor (BETA)', 100);
		if (EngineData.save.data.chart_vortex == null)
		{
			EngineData.save.data.chart_vortex = false;
			EngineData.flushSave();
		}
		check_vortex.checked = EngineData.save.data.chart_vortex;

		check_vortex.callback = () ->
		{
			EngineData.save.data.chart_vortex = check_vortex.checked;
			EngineData.flushSave();
			reloadGridLayer();
		};

		check_ignoreWarnings = new FlxUICheckBox(10, 120, null, null, 'Ignore Progress Warnings', 100);
		if (EngineData.save.data.ignoreWarnings == null)
		{
			EngineData.save.data.ignoreWarnings = false;
			EngineData.flushSave();
		}
		check_ignoreWarnings.checked = EngineData.save.data.ignoreWarnings;

		check_ignoreWarnings.callback = () ->
		{
			EngineData.save.data.ignoreWarnings = check_ignoreWarnings.checked;
			EngineData.flushSave();
		};

		var muteVocalsCheckBox:FlxUICheckBox = new FlxUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, null, null, 'Mute Vocals (in editor)', 100);
		muteVocalsCheckBox.checked = false;
		muteVocalsCheckBox.callback = () ->
		{
			if (song.vocals != null)
			{
				var vol:Float = 1;

				if (muteVocalsCheckBox.checked)
					vol = 0;

				song.vocals.volume = vol;
			}
		};

		playSoundBf = new FlxUICheckBox(check_mute_inst.x, muteVocalsCheckBox.y + 30, null, null, 'Play Sound (Boyfriend notes)', 100, () ->
		{
			EngineData.save.data.chart_playSoundBf = playSoundBf.checked;
			EngineData.flushSave();
		});
		if (EngineData.save.data.chart_playSoundBf == null)
		{
			EngineData.save.data.chart_playSoundBf = false;
			EngineData.flushSave();
		}
		playSoundBf.checked = EngineData.save.data.chart_playSoundBf;

		playSoundOpponent = new FlxUICheckBox(check_mute_inst.x + 120, playSoundBf.y, null, null, 'Play Sound (Opponent notes)', 100, () ->
		{
			EngineData.save.data.chart_playSoundOpponent = playSoundOpponent.checked;
			EngineData.flushSave();
		});
		if (EngineData.save.data.chart_playSoundOpponent == null)
		{
			EngineData.save.data.chart_playSoundOpponent = false;
			EngineData.flushSave();
		}
		playSoundOpponent.checked = EngineData.save.data.chart_playSoundOpponent;

		metronome = new FlxUICheckBox(10, 15, null, null, 'Metronome Enabled', 100, () ->
		{
			EngineData.save.data.chart_metronome = metronome.checked;
			EngineData.flushSave();
		});
		if (EngineData.save.data.chart_metronome == null)
		{
			EngineData.save.data.chart_metronome = false;
			EngineData.flushSave();
		}
		metronome.checked = EngineData.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, song.tempo, 1, 1500, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 120, metronome.y, null, null, 'Disable Autoscroll (Not Recommended)', 120, () ->
		{
			EngineData.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
			EngineData.flushSave();
		});
		if (EngineData.save.data.chart_noAutoScroll == null)
		{
			EngineData.save.data.chart_noAutoScroll = false;
			EngineData.flushSave();
		}
		disableAutoScrolling.checked = EngineData.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(metronomeStepper.x, 270, 0.1, 1, 0, 1, 1);
		instVolume.value = song.inst.volume;
		instVolume.name = 'stepper_inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		vocalsVolume = new FlxUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		vocalsVolume.value = song.vocals.volume;
		vocalsVolume.name = 'stepper_vocals_volume';
		blockPressWhileTypingOnStepper.push(vocalsVolume);

		chartTabGroup.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'Tempo:'));
		chartTabGroup.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):'));
		chartTabGroup.add(new FlxText(instVolume.x, instVolume.y - 15, 0, 'Inst Volume'));
		chartTabGroup.add(new FlxText(vocalsVolume.x, vocalsVolume.y - 15, 0, 'Vocals Volume'));
		chartTabGroup.add(metronome);
		chartTabGroup.add(disableAutoScrolling);
		chartTabGroup.add(metronomeStepper);
		chartTabGroup.add(metronomeOffsetStepper);
		chartTabGroup.add(waveformUseInstrumental);
		chartTabGroup.add(waveformUseVocals);
		chartTabGroup.add(instVolume);
		chartTabGroup.add(vocalsVolume);
		chartTabGroup.add(check_mute_inst);
		chartTabGroup.add(muteVocalsCheckBox);
		chartTabGroup.add(check_vortex);
		chartTabGroup.add(check_ignoreWarnings);
		chartTabGroup.add(playSoundBf);
		chartTabGroup.add(playSoundOpponent);
		UI_box.addGroup(chartTabGroup);
	}

	private function loadSong():Void
	{
		if (song.inst != null)
		{
			song.inst.stop();
			if (song.vocals != null)
			{
				song.vocals.stop();
			}
		}

		song.vocals = new FlxSound();
		if (song.needsVoices)
		{
			song.vocals.loadEmbedded(Paths.getVoices(currentSongName));
			FlxG.sound.list.add(song.vocals);
		}
		generateSong();
		song.inst.pause();

		var bar:Bar = song.bars[currentBar];
		if (bar == null)
		{
			bar = song.bars[0];
		}

		Conductor.songPosition = bar.startTime;
		song.inst.time = Conductor.songPosition;
	}

	private function generateSong():Void
	{
		FlxG.sound.playMusic(Paths.getInst(currentSongName));

		if (instVolume != null)
			song.inst.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked)
			song.inst.volume = 0;

		song.inst.onComplete = () ->
		{
			// TODO This is slightly desynced
			song.inst.pause();
			Conductor.songPosition = 0;
			if (song.vocals != null)
			{
				song.vocals.pause();
				song.vocals.time = 0;
				if (song.inst.looped)
				{
					song.vocals.play();
				}
			}
			setBar(0, false);
			updateGrid();
			updateBarUI();
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

	private function barStartTime(add:Int = 0):Float
	{
		var bar:Bar = song.bars[currentBar + add];
		if (bar != null)
			return bar.startTime;
		return 0;
	}

	private function barStartBeat(add:Int = 0):Float
	{
		var bar:Bar = song.bars[currentBar + add];
		if (bar != null)
			return bar.startBeat;
		return 0;
	}

	private function updateZoom():Void
	{
		zoomTxt.text = 'Zoom: ${ZOOMS[curZoom]}x';
		reloadGridLayer();
	}

	private function reloadGridLayer():Void
	{
		var noteKeyCount:Int = NoteKey.createAll().length;
		var gridColumnCount:Int = noteKeyCount * 2 + 1; // +1 for the event row

		var currentBarStepLength:Int = song.bars[currentBar].lengthInSteps;
		var nextBarStepLength:Int = song.bars[currentBar + 1] == null ? 0 : song.bars[currentBar + 1].lengthInSteps;

		gridLayer.clear();
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * gridColumnCount,
			Std.int(GRID_SIZE * (currentBarStepLength + nextBarStepLength) * ZOOMS[curZoom])); // * 2 because of the preview of the next bar
		gridLayer.add(gridBG);

		updateWaveform();

		var gridBlack:FlxSprite = new FlxSprite(0,
			gridBG.height / GRID_MULT).makeGraphic(Std.int(GRID_SIZE * gridColumnCount), Std.int(gridBG.height / GRID_MULT), FlxColor.BLACK);
		gridBlack.alpha = 0.4;
		gridLayer.add(gridBlack);

		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * noteKeyCount)).makeGraphic(2, Std.int(gridBG.height),
			FlxColor.BLACK);
		gridLayer.add(gridBlackLine);

		for (i in 1...4)
		{
			var beatSeparator:FlxSprite = new FlxSprite(gridBG.x,
				(GRID_SIZE * (noteKeyCount * curZoom)) * i).makeGraphic(Std.int(gridBG.width), 1, FlxColor.RED);
			gridLayer.add(beatSeparator);
		}

		gridBlackLine = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(2, Std.int(gridBG.height), FlxColor.BLACK);
		gridLayer.add(gridBlackLine);
		updateGrid();
	}

	// FIXME See issues below
	private function updateWaveform():Void
	{
		var bar:Bar = song.bars[currentBar];
		var startTime:Float = bar.startTime;
		var endTime:Float = bar.endTime;
		var lengthInSteps:Int = bar.lengthInSteps;
		var waveformWidth:Float = GRID_SIZE * NoteKey.createAll().length * 2;
		var waveformHeight:Float = GRID_SIZE * lengthInSteps * ZOOMS[curZoom];

		if (waveformUseInstrumental.checked)
		{
			waveformInstrumental.sound = song.inst;
			waveformInstrumental.startTime = startTime;
			waveformInstrumental.endTime = endTime;
			waveformInstrumental.makeGraphic(Std.int(waveformWidth), Std.int(waveformHeight), FlxColor.TRANSPARENT, false,
				Std.string(waveformInstrumental.ID));
			// waveformInstrumental.scale.y = ZOOMS[curZoom]; // Using these two lines makes the waveform blocky when zoomed in
			waveformInstrumental.updateHitbox();
			waveformInstrumental.height = waveformHeight; // Using this line makes the waveform get cut-off early when zoomed in
			waveformInstrumental.updateWaveform();
			waveformInstrumental.drawWaveform();
		}

		if (waveformUseVocals.checked)
		{
			waveformVocals.sound = song.vocals;
			waveformVocals.startTime = startTime;
			waveformVocals.endTime = endTime;
			waveformVocals.makeGraphic(Std.int(waveformWidth), Std.int(waveformHeight), FlxColor.TRANSPARENT, false, Std.string(waveformVocals.ID));
			// waveformVocals.scale.y = ZOOMS[curZoom];
			waveformVocals.updateHitbox();
			waveformVocals.height = waveformHeight;
			waveformVocals.updateWaveform();
			waveformVocals.drawWaveform();
		}
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

	private function resetBar(songBeginning:Bool = false):Void
	{
		updateGrid();

		var bar:Bar = song.bars[currentBar];

		song.inst.pause();
		song.inst.time = bar.startTime;

		if (songBeginning)
		{
			// setBar(0);
			currentBar = 0;
			song.inst.time = 0;
		}

		if (song.vocals != null)
		{
			song.vocals.pause();
			song.vocals.time = song.inst.time;
		}

		updateGrid();
		updateBarUI();
		updateWaveform();
	}

	private function setBar(bar:Int, updateMusic:Bool = true):Void
	{
		currentBar = FlxMath.wrap(bar, 0, song.bars.length - 1);

		if (updateMusic)
		{
			var bar:Bar = song.bars[currentBar];

			song.inst.pause();
			song.inst.time = bar.startTime;
			if (song.vocals != null)
			{
				song.vocals.pause();
				song.vocals.time = song.inst.time;
			}
		}
		Conductor.songPosition = song.inst.time;

		updateGrid();
		updateBarUI();
		updateWaveform();
	}

	private function changeBar(bar:Int = 0, updateMusic:Bool = true):Void
	{
		// TODO Find a way to add another "if" condition for whether song.inst.time will be larger than song.inst.length
		// TODO Also, use FlxMath more for these sorts of min/max things
		currentBar = FlxMath.wrap(currentBar + bar, 0, song.bars.length - 1);

		if (updateMusic)
		{
			var bar:Bar = song.bars[currentBar];

			song.inst.pause();
			song.inst.time = bar.startTime;
			if (song.vocals != null)
			{
				song.vocals.pause();
				song.vocals.time = song.inst.time;
			}
		}
		Conductor.songPosition = song.inst.time;

		updateGrid();
		updateBarUI();
		updateWaveform();
	}

	private function updateBarUI():Void
	{
		var bar:Bar = song.bars[currentBar];

		stepperLength.value = bar.lengthInSteps;
		check_bar_mustHit.checked = bar.mustHit;
		check_gfSings.checked = bar.gfSings;
		check_bar_altAnim.checked = bar.altAnim;

		updateHeads();
	}

	private function updateHeads():Void
	{
		// TODO Make a method similar to this but for changing the X values of notes when mustHit changes, so they don't keep swapping the strums
		var healthIconP1:String = loadHealthIconFromCharacter(song.player1);
		var healthIconP2:String = loadHealthIconFromCharacter(song.player2);
		var healthIconGF:String = loadHealthIconFromCharacter(song.gfVersion);

		var bar:Bar = song.bars[currentBar];

		#if CHART_FLIPPING
		// TODO Indicate whose turn it is
		leftIcon.changeIcon(healthIconP2);
		rightIcon.changeIcon(healthIconP1);
		leftIconBG.visible = !bar.mustHit;
		rightIconBG.visible = bar.mustHit;

		if (bar.gfSings)
		{
			if (bar.mustHit)
				rightIcon.changeIcon(healthIconGF);
			else
				leftIcon.changeIcon(healthIconGF);
		}
		#else
		if (bar.mustHit)
		{
			leftIcon.changeIcon(healthIconP1);
			rightIcon.changeIcon(healthIconP2);
			if (bar.gfSings)
				leftIcon.changeIcon(healthIconGF);
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(healthIconP1);
			if (bar.gfSings)
				leftIcon.changeIcon(healthIconGF);
		}
		#end
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
				stepperBeat.value = curSelectedNote.beat;
				stepperSustainLength.value = curSelectedNote.sustainLength;
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
			}
			else
			{
				var curSelectedNote:EventGroup = curSelectedNote;
				stepperBeat.value = curSelectedNote.beat;
				eventDropDown.selectedLabel = curSelectedNote.events[curEventSelected].type;
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if (selected > 0 && selected < eventTypeList.length)
				{
					descText.text = eventTypeList[selected].description;
				}
				value1InputText.text = curSelectedNote.events[curEventSelected].args[0];
				value2InputText.text = curSelectedNote.events[curEventSelected].args[1];
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

		var bar:Bar = song.bars[currentBar];

		// CURRENT BAR
		for (noteDef in bar.notes)
		{
			var note:Note = setupNoteData(noteDef, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSustainNote(note));
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
			note.mustPress = bar.mustHit;
			if (noteDef.data >= NoteKey.createAll().length)
				note.mustPress = !note.mustPress;
		}

		// CURRENT EVENTS
		for (eventGroup in song.events)
		{
			if (eventGroup.beat >= bar.startBeat && bar.endBeat > eventGroup.beat)
			{
				var note:Note = setupNoteData(eventGroup, false);
				curRenderedNotes.add(note);

				var textString:String;
				if (note.eventLength > 1)
					textString = '${note.eventLength} Events:\n${note.eventName}';
				else
					textString = 'Event: ${note.eventName} (Beat ${FlxMath.roundDecimal(note.beat, 3)})\nValue 1: ${note.eventVal1}\nValue 2: ${note.eventVal2}';

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

		// NEXT BAR
		if (currentBar < song.bars.length - 1)
		{
			for (noteDef in song.bars[currentBar + 1].notes)
			{
				var note:Note = setupNoteData(noteDef, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSustainNote(note));
				}
			}
		}

		// NEXT EVENTS
		var startBeat:Float = barStartBeat(1);
		var endBeat:Float = barStartBeat(2);
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

	private function setupNoteData(entry:ChartBarEntry, isNext:Bool):Note
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

		var strumTime:Float = song.getTimeFromBeat(beat);

		var noteData:Int = entry is BasicNote ? cast(entry, BasicNote).data : -1;

		var note:Note = new Note(strumTime, noteData % NoteKey.createAll().length, null, false, true, beat);
		if (entry is BasicNote)
		{ // Note
			var entry:BasicNote = entry;

			var sustainLength:Float = entry.sustainLength;
			var noteType:String = entry.type;
			note.sustainLength = sustainLength;
			note.noteType = noteType;
		}
		else
		{ // Event
			var entry:EventGroup = entry;

			note.loadGraphic(Paths.getGraphic('eventArrow'));
			note.eventName = getEventName(entry.events);
			note.eventLength = entry.events.length;
			if (entry.events.length < 2)
			{
				note.eventVal1 = entry.events[0].args[0];
				note.eventVal2 = entry.events[0].args[1];
			}
			note.noteData = -1;
			noteData = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = noteData * GRID_SIZE + GRID_SIZE;

		// var bar:Bar = getBarByBeat(beat); // TODO Get this damn function to work
		var bar:Bar = isNext ? song.bars[currentBar + 1] : song.bars[currentBar];
		#if CHART_FLIPPING
		if (bar.mustHit)
		#else
		if (isNext && bar.mustHit != song.bars[currentBar].mustHit)
		#end
		{
			if (entry is BasicNote)
			{
				if (noteData >= NoteKey.createAll().length)
				{
					note.x -= GRID_SIZE * NoteKey.createAll().length;
				}
				else
				{
					note.x += GRID_SIZE * NoteKey.createAll().length;
				}
			}
		}
		note.y = (GRID_SIZE * (isNext ? Conductor.STEPS_PER_BAR : 0)) * ZOOMS[curZoom] + getYFromBeat(note.beat - barStartBeat(isNext ? 1 : 0), false);

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

	private function setupSustainNote(note:Note):FlxSprite
	{
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.BEATS_PER_BAR, 0, (gridBG.height / GRID_MULT))
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

	private function addBar(lengthInSteps:Int = Conductor.STEPS_PER_BAR):Void
	{
		var start:Float = 0;

		var tempo:Float = song.tempo;
		for (i in 0...currentBar)
		{
			for (timing in song.timings)
			{
				var timingAtStart:TimingSegment = song.getTimingAtTimestamp(start);
				if ((timingAtStart != null ? timingAtStart.tempo : song.tempo) != tempo && tempo != timing.tempo)
					tempo = timing.tempo;
			}
			start += Conductor.calculateStepLength(tempo);
		}

		var bar:Bar = new Bar();
		bar.startTime = start;
		bar.endTime = Math.POSITIVE_INFINITY;
		bar.lengthInSteps = lengthInSteps;

		song.bars.push(bar);

		song.recalculateAllBarTimes();
	}

	private function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;

		if (noteDataToCheck > -1)
		{
			var bar:Bar = getBarByBeat(note.beat);
			if (note.mustPress != bar.mustHit)
				noteDataToCheck += NoteKey.createAll().length;
			for (noteDef in bar.notes)
			{
				// FIXME Notes will sometimes refuse to be selected or deleted--they are usually at the very beginning of the bar
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
					curEventSelected = curSelectedNote.events.length - 1;
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
		var bar:Bar = getBarByBeat(note.beat);
		if (noteDataToCheck > -1 && note.mustPress != bar.mustHit)
			noteDataToCheck += NoteKey.createAll().length;

		if (note.noteData > -1) // Normal Notes
		{
			for (noteDef in bar.notes)
			{
				if (noteDef.beat == note.beat && noteDef.data == noteDataToCheck)
				{
					if (noteDef == curSelectedNote)
					{
						curSelectedNote = null;
					}
					bar.notes.remove(noteDef);
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
		for (bar in song.bars)
		{
			FlxArrayUtil.clearArray(bar.notes);
		}

		updateGrid();
	}

	public function getBarByBeat(beat:Float):Bar
	{
		for (bar in song.bars)
		{
			var startBeat:Float = bar.startBeat;
			var endBeat:Float = bar.endBeat;

			if (beat >= startBeat && beat < endBeat)
			{
				return bar;
			}
		}

		return null;
	}

	// FIXME In CHART_FLIPPING mode, adding a note in a mustHit section puts it in the opposite strum set from where the mouse was clicked
	private function addNote(?beat:Float, ?noteData:Int, ?noteType:Int):Void
	{
		undos.push(Reflect.copy(song.bars));

		var bar:Bar = getBarByBeat(beat);
		if (beat == null)
		{
			bar = song.bars[currentBar];
			beat = getBeatFromY(dummyArrow.y, false) + bar.startBeat;
		}
		if (noteData == null)
		{
			noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		}

		if (noteData > -1)
		{
			var sustainLength:Float = 0;
			if (noteType == null)
			{
				noteType = currentType;
			}
			var noteTypeString:String = noteTypeIntMap.get(noteType);

			var newNote:BasicNote = new BasicNote(noteData, sustainLength, noteTypeString, beat);
			bar.notes.push(newNote);
			curSelectedNote = newNote;

			if (FlxG.keys.pressed.CONTROL) // Copies the note to both players' strums
			{
				bar.notes.push(new BasicNote((noteData + NoteKey.createAll().length) % (NoteKey.createAll().length * 2), sustainLength, noteTypeString, beat));
			}
		}
		else
		{
			var type:String = eventDropDown.selectedLabel;
			var value1:String = value1InputText.text;
			var value2:String = value2InputText.text;
			var eventGroup:EventGroup = {beat: beat, events: [{type: type, args: [value1, value2]}]}
			song.events.push(eventGroup);
			curSelectedNote = eventGroup;
			curEventSelected = 0;
			changeEventSelected();
		}

		stepperBeat.value = beat;

		updateGrid();
		updateNoteUI();
	}

	// TODO Undos and redos
	// I theorize that these methods do not work because, instead of cloning the bars, they are just getting a reference to them
	private function undo():Void
	{
		if (undos.length > 0)
		{
			var copiedNotes:Array<Bar> = Reflect.copy(song.bars);
			redos.push(copiedNotes);
			song.bars = undos.pop();
			updateGrid();
		}
	}

	private function redo():Void
	{
		if (redos.length > 0)
		{
			var copiedNotes:Array<Bar> = Reflect.copy(song.bars);
			undos.push(copiedNotes);
			song.bars = redos.pop();
			updateGrid();
		}
	}

	private function getBeatFromY(y:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = doZoomCalc ? ZOOMS[curZoom] : 1;
		return FlxMath.remapToRange(y, gridBG.y, gridBG.y + (gridBG.height / GRID_MULT) * zoom, 0, Conductor.BEATS_PER_BAR);
	}

	private function getYFromBeat(beat:Float, doZoomCalc:Bool = true):Float
	{
		var zoom:Float = doZoomCalc ? ZOOMS[curZoom] : 1;
		return FlxMath.remapToRange(beat, 0, Conductor.BEATS_PER_BAR, gridBG.y, gridBG.y + (gridBG.height / GRID_MULT) * zoom);
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
		// This is to fix the crash caused by the chart editor loading a new bar whilst the file dialog is opened
		if (song.inst.playing)
		{
			song.inst.pause();
			if (song.vocals != null)
				song.vocals.pause();
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
				if (loadedSong.bars != null) // Make sure it's really a dialogue character
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
		// This is to fix the crash caused by the chart editor loading a new bar whilst the file dialog is opened
		if (song.inst.playing)
		{
			song.inst.pause();
			if (song.vocals != null)
				song.vocals.pause();
		}

		song.events.sort(sortByTime);
		var json:Dynamic = {
			song: Song.toSongDef(song)
		};

		var data:String = Json.stringify(json, Constants.JSON_SPACE);

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

	private function sortByTime(obj1:ChartBarEntry, obj2:ChartBarEntry):Int
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
		// This is to fix the crash caused by the chart editor loading a new bar whilst the file dialog is opened
		if (song.inst.playing)
		{
			song.inst.pause();
			if (song.vocals != null)
				song.vocals.pause();
		}

		song.events.sort(sortByTime);
		// var eventsSong:MockSong = {
		// 	player1: song.player1,
		// 	player2: song.player2,
		// 	gfVersion: song.gfVersion,
		// 	stage: song.stage,
		// 	noteSkin: song.noteSkin,
		// 	splashSkin: song.splashSkin,
		// 	bpm: song.tempo,
		// 	speed: song.scrollSpeed,
		// 	needsVoices: song.needsVoices,
		// 	validScore: false,
		// 	notes: [],
		// 	events: song.events,
		// 	chartVersion: Song.LATEST_CHART
		// };
		// var json:MockSongWrapper = {
		// 	song: eventsSong
		// }
		// TODO Just a marker because Dynamic is a bit fucky to work with sometimes
		var json:Dynamic = {
			song: Song.toSongDef(song)
		};
		json.song.bars = [];
		json.song.validScore = false;

		var data:String = Json.stringify(json, Constants.JSON_SPACE);

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
