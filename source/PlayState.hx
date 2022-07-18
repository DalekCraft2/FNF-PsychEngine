package;

import haxe.CallStack;
import haxe.Exception;
import Character.CharacterRole;
import Character.CharacterRoleTools;
import DialogueBoxPsych.DialogueDef;
import Ratings.Judgement;
import Replay.Analysis;
import Replay.Analytic;
import animateatlas.AtlasFrameMaker;
import chart.container.Event;
import chart.container.Section;
import chart.container.Song;
import editors.CharacterEditorState;
import editors.ChartEditorState;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxArrayUtil;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.io.Path;
import openfl.events.KeyboardEvent;
import ui.HealthBar;
import ui.TimeBar;
import util.CoolUtil;

using StringTools;

#if FEATURE_ACHIEVEMENTS
import Achievement.AchievementDef;
#end
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
#if FEATURE_SCRIPTS
import FunkinScript.DebugScriptText;
import FunkinScript.ScriptSprite;
import FunkinScript.ScriptText;
#end
#if FEATURE_STEPMANIA
import sm.SMFile;
#end

// Dear god, Dalek, calm down with the to-do comments.
// TODO Make the input system much less pathetically easy and cheesable
// (An example of it is being able to hit any incoming hold notes by just pressing the keys early, missing the first note, and getting the rest of the hold anyway)
// TODO Abuse the fuck out of multithreading to make the game run faster
class PlayState extends MusicBeatState
{
	// Constants
	public static final STRUM_X:Float = 42;
	public static final STRUM_X_MIDDLESCROLL:Float = -278;

	/**
	 * The scale factor for the pixel art assets.
	 */
	public static final PIXEL_ZOOM:Float = 6;

	/**
	 * The active PlayState instance.
	 */
	public static var instance:PlayState;

	// Song variables
	public static var song:Song;

	public static var isSM:Bool = false;
	#if FEATURE_STEPMANIA
	public static var sm:SMFile;
	public static var pathToSm:String;
	#end

	/**
	 * The scroll speed of the notes.
	 */
	public var songSpeed(default, set):Float = 1;

	public var songSpeedTween:FlxTween;
	public var noteKillOffset:Float = 350; // Arguably a Strum/Note variable
	public var currentSection:Section;
	public var startingSong:Bool = false;
	public var endingSong:Bool = false;

	// Audio variables

	/**
	 * The playback speed factor for the audio.
	 */
	public static var songMultiplier:Float = 1.0;

	public var vocals:FlxSound;

	/**
	 * The length of the song, in milliseconds.
	 */
	private var songLength:Float = 0;

	private var generatedMusic:Bool = false;

	// Strum and Note variables
	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var events:Array<Event> = [];

	private var strumLine:FlxSprite;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	private var noteTypeMap:Map<String, Bool> = [];
	private var eventPushedMap:Map<String, Bool> = [];

	// Stage variables
	public static var stage:Stage;
	public static var stageTesting:Bool = false;
	public static var isPixelStage:Bool = false;

	// Character variables
	public var boyfriend:Boyfriend;
	public var opponent:Character;
	public var gf:Character;
	public var boyfriendMap:Map<String, Boyfriend> = [];
	public var opponentMap:Map<String, Character> = [];
	public var gfMap:Map<String, Character> = [];
	public var boyfriendGroup:FlxSpriteGroup;
	public var opponentGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var OPPONENT_X:Float = 100;
	public var OPPONENT_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;
	public var gfSpeed:Int = 1;

	// Story Mode variables
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	// Camera variables
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;
	public var camZooming:Bool = false;
	public var defaultCamZoom:Float = 1.05;

	public var boyfriendCameraOffset:Array<Float>; // These three are arguably Character variables
	public var opponentCameraOffset:Array<Float>;
	public var girlfriendCameraOffset:Array<Float>;

	private var camFollow:FlxPoint;
	private var camFollowPos:FlxObject;

	/**
	 * Used to reset the camera position for the directional camera.
	 */
	private var camFollowNoDirectional:FlxPoint;

	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	private var cameraTwn:FlxTween;

	private var isCameraOnForcedPos:Bool = false;

	// Replay variables
	public static var rep:Replay;
	public static var loadRep:Bool = false;

	private var saveNotes:Array<Array<Any>> = [];
	private var saveJudge:Array<String> = [];
	private var replayAna:Analysis = new Analysis(); // replay analysis

	// Health and Health Bar variables
	public var health:Float = 1;
	public var healthBar:HealthBar;

	// Time Bar variables
	public var timeBar:TimeBar;

	private var songPercent:Float = 0;
	private var updateTime:Bool = true;

	// Skip variables
	private var needSkip:Bool = false;
	private var skipActive:Bool = false;
	private var skipText:FlxText;
	private var skipTo:Float;

	// Judgement and Ranking variables
	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var campaignSicks:Int = 0;
	public static var campaignGoods:Int = 0;
	public static var campaignBads:Int = 0;
	public static var campaignShits:Int = 0;

	public static var highestCombo:Int = 0;

	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;

	public var score:Int = 0;
	// TODO Implement scoreDefault and totalNotesHitDefault (They are score and totalNotesHit but they show what they would be if safeFrames is set to 10)
	public var scoreDefault:Int = 0;
	public var hits:Int = 0;
	public var misses:Int = 0;
	public var combo:Int = 0;
	public var nps:Int = 0;
	public var maxNPS:Int = 0;
	public var scoreTxt:FlxText;
	public var judgementCounter:FlxText;

	public var ratingName:String = '?';
	public var ratingPercent:Float = 0;
	public var ratingPercentDefault:Float = 0;
	public var ratingFC:String;

	public var notesHitArray:Array<Date> = [];
	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0;
	public var totalNotesHitDefault:Float = 0;
	public var showCombo:Bool = true;
	public var showRating:Bool = true;

	private var scoreTxtTween:FlxTween;

	// Cutscene and Dialogue variables
	public static var seenCutscene:Bool = false;

	public var inCutscene:Bool = false;

	public var psychDialogue:DialogueBoxPsych;

	private var dialogueCount:Int = 0;
	private var dialogue:Array<String> = ['whoops', 'dialogue\'s missing'];
	private var dialogueJson:DialogueDef;

	// Countdown variables
	public var skipCountdown:Bool = false;

	private var startedCountdown:Bool = false;

	// Start and Finish variables
	public var skipArrowStartTween:Bool = false;
	public var introSoundsSuffix:String = '';
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	private var startTimer:FlxTimer;
	private var finishTimer:FlxTimer;

	public static var startTime:Float = 0;

	// Death variables
	public static var deathCounter:Int = 0;

	public var isDead(default, null):Bool = false;

	// Pause variables
	public var paused:Bool = false;

	private var canPause:Bool = true;

	// Misc.
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	private var turn:String = '';
	private var focus:String = '';

	public var inResults:Bool = false;

	public var transitioning:Bool = false;

	#if FEATURE_DISCORD
	// Discord RPC variables
	private var storyDifficultyText:String = '';
	private var detailsText:String = '';
	private var detailsPausedText:String = '';
	#end

	#if FEATURE_ACHIEVEMENTS
	// Achievement variables
	private var achievement:Achievement;
	private var keysPressed:Array<Bool> = [];
	private var boyfriendIdleTime:Float = 0.0;
	private var boyfriendIdled:Bool = false;
	#end

	#if FEATURE_SCRIPTS
	// Script API variables
	public var scriptArray:Array<FunkinScript> = [];

	public var scriptTweens:Map<String, FlxTween> = [];
	public var scriptSprites:Map<String, ScriptSprite> = [];
	public var scriptTimers:Map<String, FlxTimer> = [];
	public var scriptSounds:Map<String, FlxSound> = [];
	public var scriptTexts:Map<String, ScriptText> = [];
	public var scriptSaves:Map<String, FlxSave> = [];

	private var scriptDebugGroup:FlxTypedGroup<DebugScriptText>;
	#end

	#if FEATURE_SCRIPTS
	// Pico variables
	private var curLight:Int = 0;
	private var blammedLightsBlack:ScriptSprite;
	private var blammedLightsBlackTween:FlxTween;
	private var phillyCityLightsEventTween:FlxTween;
	#end

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Array<FlxKey>>;

	override public function create():Void
	{
		// super.create(); // The super call is at the bottom of the method

		instance = this;

		FlxG.mouse.visible = false;

		if (startTime == 0) // This is so there is time for the transition to finish before the song starts, if the start time is not the default
		{
			persistentUpdate = true;
		}

		debugKeysChart = Options.copyKey(Options.save.data.keyBinds.get('debug_1'));
		debugKeysCharacter = Options.copyKey(Options.save.data.keyBinds.get('debug_2'));
		PauseSubState.songName = null; // Reset to default

		keysArray = [
			Options.copyKey(Options.save.data.keyBinds.get('note_left')),
			Options.copyKey(Options.save.data.keyBinds.get('note_down')),
			Options.copyKey(Options.save.data.keyBinds.get('note_up')),
			Options.copyKey(Options.save.data.keyBinds.get('note_right'))
		];

		#if FEATURE_ACHIEVEMENTS
		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}
		#end

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// TODO Make a method to automatically reset the static variables
		highestCombo = 0;

		PlayStateChangeables.healthGain = Options.save.data.healthGain;
		PlayStateChangeables.healthLoss = Options.save.data.healthLoss;
		PlayStateChangeables.instakillOnMiss = Options.save.data.instakillOnMiss;
		PlayStateChangeables.useDownscroll = Options.save.data.downScroll;
		PlayStateChangeables.safeFrames = Options.save.data.safeFrames;
		PlayStateChangeables.scrollSpeed = Options.save.data.scrollSpeed * songMultiplier;
		PlayStateChangeables.scrollType = Options.save.data.scrollType;
		PlayStateChangeables.practiceMode = Options.save.data.practiceMode;
		PlayStateChangeables.botPlay = Options.save.data.botPlay;
		PlayStateChangeables.optimize = Options.save.data.lowQuality;

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		grpNoteSplashes = new FlxTypedGroup();

		#if FEATURE_DISCORD
		storyDifficultyText = Difficulty.difficulties[storyDifficulty];
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
		{
			detailsText = 'Story Mode: ${Week.getCurrentWeek().weekName}';
		}
		else
		{
			detailsText = 'Freeplay';
		}
		// String for when the game is paused
		detailsPausedText = 'Paused - $detailsText';
		#end
		GameOverSubState.resetVariables();
		var curStage:String = song.stage;

		if (song.stage == null || song.stage.length < 1)
		{
			curStage = 'stage';
		}
		if (!stageTesting)
		{
			stage = new Stage(curStage);
		}
		defaultCamZoom = stage.defaultZoom;
		isPixelStage = stage.isPixelStage;
		if (stage.boyfriend != null && !stageTesting)
		{
			BF_X = stage.boyfriend[0];
			BF_Y = stage.boyfriend[1];
		}
		if (stage.girlfriend != null && !stageTesting)
		{
			GF_X = stage.girlfriend[0];
			GF_Y = stage.girlfriend[1];
		}
		if (stage.opponent != null && !stageTesting)
		{
			OPPONENT_X = stage.opponent[0];
			OPPONENT_Y = stage.opponent[1];
		}
		for (background in stage.backgrounds)
		{
			add(background);
		}
		if (stage.cameraSpeed != null)
			cameraSpeed = stage.cameraSpeed;
		boyfriendCameraOffset = stage.cameraBoyfriend;
		if (boyfriendCameraOffset == null) // Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];
		opponentCameraOffset = stage.cameraOpponent;
		if (opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];
		girlfriendCameraOffset = stage.cameraGirlfriend;
		if (girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];
		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		opponentGroup = new FlxSpriteGroup(OPPONENT_X, OPPONENT_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);
		if (isPixelStage)
		{
			introSoundsSuffix = '-pixel';
		}
		if (!PlayStateChangeables.optimize)
		{
			for (index => array in stage.foregrounds)
			{
				switch (index)
				{
					case 0:
						add(gfGroup);
						for (bg in array)
							add(bg);
					case 1:
						add(opponentGroup);
						for (bg in array)
							add(bg);
					case 2:
						add(boyfriendGroup);
						for (bg in array)
							add(bg);
				}
			}
		}
		#if FEATURE_SCRIPTS
		scriptDebugGroup = new FlxTypedGroup();
		scriptDebugGroup.cameras = [camOther];
		add(scriptDebugGroup);
		if (curStage == 'philly')
		{
			var phillyCityLightsEvent:FlxTypedGroup<BGSprite> = new FlxTypedGroup();
			for (i in 0...5)
			{
				var light:BGSprite = new BGSprite('stages/philly/win$i', -10, 0, 0.3, 0.3);

				light.visible = false;
				light.setGraphicSize(Std.int(light.width * 0.85));
				light.updateHitbox();
				phillyCityLightsEvent.add(light);
			}
			stage.groups['phillyCityLightsEvent'] = phillyCityLightsEvent;
		}
		if (Options.save.data.loadScripts)
		{
			// "GLOBAL" SCRIPTS
			var scriptList:Array<String> = [];
			var scriptsLoaded:Map<String, Bool> = [];

			var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

			for (directory in directories)
			{
				var scriptDirectory:String = Path.join([directory, 'data/scripts']);
				if (Paths.fileSystem.exists(scriptDirectory) && Paths.fileSystem.isDirectory(scriptDirectory))
				{
					for (file in Paths.fileSystem.readDirectory(scriptDirectory))
					{
						var path:String = Path.join([scriptDirectory, file]);
						if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.SCRIPT_EXT)
						{
							var scriptId:String = Path.withoutExtension(file);

							if (!scriptsLoaded.exists(scriptId))
							{
								scriptList.push(scriptId);
								scriptsLoaded.set(scriptId, true);
								scriptArray.push(new FunkinScript(path));
							}
						}
					}
				}
			}
			// STAGE SCRIPTS
			var stageScript:String = Paths.script(Path.join(['stages', curStage]));

			if (Paths.exists(stageScript))
			{
				scriptArray.push(new FunkinScript(stageScript));
			}
		}
		if (!scriptSprites.exists('blammedLightsBlack'))
		{ // Creates blammed light black fade in case you didn't make your own
			blammedLightsBlack = new ScriptSprite(FlxG.width * -0.5, FlxG.height * -0.5);
			blammedLightsBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
			var position:Int = members.indexOf(gfGroup);

			if (members.indexOf(boyfriendGroup) < position)
			{
				position = members.indexOf(boyfriendGroup);
			}
			else if (members.indexOf(opponentGroup) < position)
			{
				position = members.indexOf(opponentGroup);
			}
			insert(position, blammedLightsBlack);
			blammedLightsBlack.wasAdded = true;
			scriptSprites.set('blammedLightsBlack', blammedLightsBlack);
		}
		if (curStage == 'philly')
			insert(members.indexOf(blammedLightsBlack) + 1, stage.groups['phillyCityLightsEvent']);
		blammedLightsBlack = scriptSprites.get('blammedLightsBlack');
		blammedLightsBlack.alpha = 0.0;
		#end

		if (isStoryMode)
			songMultiplier = 1;

		var gfVersion:String = song.gfVersion;
		if (gfVersion == null || gfVersion.length < 1)
		{
			gfVersion = 'gf';
			song.gfVersion = gfVersion; // Fix for the Chart Editor
		}
		if (!stageTesting)
		{
			if (!stage.hideGirlfriend)
			{
				gf = new Character(0, 0, gfVersion);
				switch (gfVersion)
				{
					case 'pico-speaker':
						gf.loadMappedAnims('pico-speaker', '', 'stress');
						TankmenBG.animationNotes = gf.animationNotes;
						var tempTankman:TankmenBG = new TankmenBG(20, 500, true);

						tempTankman.strumTime = 10;
						tempTankman.resetShit(20, 600, true);
						var tankmanRun:FlxTypedGroup<FlxSprite> = cast stage.groups['tankmanRun'];

						tankmanRun.add(tempTankman);
						for (animationNote in TankmenBG.animationNotes)
						{
							if (FlxG.random.bool(16))
							{
								var tankman:TankmenBG = cast tankmanRun.recycle(TankmenBG);

								tankman.strumTime = animationNote.strumTime;
								// tankman.strumTime = TimingStruct.getTimeFromBeat(animationNote.beat);
								tankman.resetShit(500, 200 + FlxG.random.int(50, 100), animationNote.data < 2);
								tankmanRun.add(tankman);
							}
						}
				}
				startCharacterPos(gf);
				gf.scrollFactor.set(0.95, 0.95);
				gfGroup.add(gf);
				#if FEATURE_SCRIPTS
				startCharacterScript(gf.id);
				#end
			}
			opponent = new Character(0, 0, song.player2);
			startCharacterPos(opponent, true);
			opponentGroup.add(opponent);
			#if FEATURE_SCRIPTS
			startCharacterScript(opponent.id);
			#end
			boyfriend = new Boyfriend(0, 0, song.player1);
			startCharacterPos(boyfriend);
			boyfriendGroup.add(boyfriend);
			#if FEATURE_SCRIPTS
			startCharacterScript(boyfriend.id);
			#end
		}
		var camPos:FlxPoint = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);

		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}
		if (gf != null && opponent.id == gf.id) // For Tutorial and any other songs which use GF as the opponent
		{
			opponent.setPosition(GF_X, GF_Y);
			if (gf != null)
				gf.visible = false;
		}
		stage.update(0);
		switch (Options.save.data.cameraFocus)
		{
			case 1:
				focus = 'bf';
			case 2:
				focus = 'dad';
			case 3:
				focus = 'center';
		}
		if (Options.save.data.noChars)
		{
			focus = 'center';
			remove(gf);
			remove(opponent);
			remove(boyfriend);
		}
		if (loadRep)
		{
			PlayStateChangeables.useDownscroll = rep.replay.isDownscroll;
			PlayStateChangeables.safeFrames = rep.replay.sf;
			PlayStateChangeables.botPlay = true;
		}
		var doof:Null<DialogueBox> = null;
		if (isStoryMode)
		{
			var file:String = Paths.json(Path.join(['songs', song.id, 'dialogue'])); // Checks for json/Psych Engine dialogue

			if (Paths.exists(file))
			{
				dialogueJson = Paths.getJsonDirect(file);
			}
			var file:String = Paths.txt(Path.join(['songs', song.id, '${song.id}Dialogue'])); // Checks for vanilla/Senpai dialogue

			if (Paths.exists(file))
			{
				dialogue = CoolUtil.listFromTextFile(file);
			}
			doof = new DialogueBox(dialogue);
			doof.scrollFactor.set();
			doof.finishThing = startCountdown;
		}

		if (!isStoryMode)
		{
			var firstNoteTime = Math.POSITIVE_INFINITY;
			var playerTurn = false;
			for (index => section in song.notes)
			{
				if (section.sectionNotes.length > 0 && !isSM)
				{
					if (section.startTime > 5000)
					{
						needSkip = true;
						skipTo = section.startTime - 1000;
					}
					break;
				}
				else if (isSM)
				{
					for (note in section.sectionNotes)
					{
						var strumTime:Float = note.strumTime;
						// var strumTime:Float = TimingStruct.getTimeFromBeat(note.beat);
						if (strumTime < firstNoteTime)
						{
							if (!PlayStateChangeables.optimize)
							{
								firstNoteTime = strumTime;
								if (note.data >= NoteKey.createAll().length)
									playerTurn = true;
								else
									playerTurn = false;
							}
							else if (note.data >= NoteKey.createAll().length)
							{
								firstNoteTime = strumTime;
							}
						}
					}
					if (index + 1 == song.notes.length)
					{
						var timing:Float = ((!playerTurn && !PlayStateChangeables.optimize) ? firstNoteTime : TimingStruct.getTimeFromBeat(TimingStruct.getBeatFromTime(firstNoteTime)
							- 4));

						if (timing > 5000)
						{
							needSkip = true;
							skipTo = timing - 1000;
						}
					}
				}
			}
		}

		Conductor.songPosition = -5000;
		Conductor.rawPosition = Conductor.songPosition;

		strumLine = new FlxSprite(Options.save.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if (PlayStateChangeables.useDownscroll)
			strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();
		var showTime:Bool = Options.save.data.timeBarType != 'Disabled';

		updateTime = showTime;
		timeBar = new TimeBar(0, 19, song.name, this, 'songPercent');
		if (PlayStateChangeables.useDownscroll)
			timeBar.y = FlxG.height - 44;
		timeBar.screenCenter(X);
		timeBar.scrollFactor.set();
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		strumLineNotes = new FlxTypedGroup();
		add(strumLineNotes);
		add(grpNoteSplashes);
		var splash:NoteSplash = new NoteSplash(100, 100, 0);

		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;
		opponentStrums = new FlxTypedGroup();
		playerStrums = new FlxTypedGroup();
		generateSong();
		#if FEATURE_SCRIPTS
		if (Options.save.data.loadScripts)
		{
			for (notetype in noteTypeMap.keys())
			{
				var scriptPath:String = Paths.script(Path.join(['notetypes', notetype]));
				if (Paths.exists(scriptPath))
				{
					scriptArray.push(new FunkinScript(scriptPath));
				}
			}
		}
		if (Options.save.data.loadScripts)
		{
			for (event in eventPushedMap.keys())
			{
				var scriptPath:String = Paths.script(Path.join(['events', event]));
				if (Paths.exists(scriptPath))
				{
					scriptArray.push(new FunkinScript(scriptPath));
				}
			}
		}
		#end
		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;
		// After all characters being loaded, it makes them invisible 0.01s later so that the player won't freeze when you change characters
		camFollow = new FlxPoint();
		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowNoDirectional = new FlxPoint();
		snapCamFollowToPos(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			camFollowNoDirectional.set(camFollow.x, camFollow.y);
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null)
		{
			camFollowPos = prevCamFollowPos;
			prevCamFollowPos = null;
		}
		add(camFollowPos);
		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);
		FlxG.fixedTimestep = false;
		moveCameraSection(song.notes[0]);
		// HealthBar
		healthBar = new HealthBar(0, FlxG.height * 0.89, boyfriend.healthIcon, opponent.healthIcon, this, 'health');
		healthBar.screenCenter(X);
		healthBar.scrollFactor.set();
		healthBar.visible = !Options.save.data.hideHud;
		healthBar.alpha = Options.save.data.healthBarAlpha;
		reloadHealthBarColors();
		add(healthBar);
		scoreTxt = new FlxText(0, healthBar.y + 36, FlxG.width, 20);
		scoreTxt.setFormat(Paths.font('vcr.ttf'), scoreTxt.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !Options.save.data.hideHud;
		add(scoreTxt);
		judgementCounter = new FlxText(20, 0, 0, 'Sicks: ${sicks}\nGoods: ${goods}\nBads: ${bads}\nShits: ${shits}\nMisses: ${misses}\n', 20);
		judgementCounter.setFormat(Paths.font('vcr.ttf'), judgementCounter.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		judgementCounter.borderSize = 2;
		judgementCounter.borderQuality = 2;
		judgementCounter.scrollFactor.set();
		judgementCounter.cameras = [camHUD];
		judgementCounter.screenCenter(Y);
		if (Options.save.data.showCounters)
		{
			add(judgementCounter);
		}
		botplayTxt = new FlxText(400, timeBar.y + 55, FlxG.width - 800, 'BOTPLAY', 32);
		botplayTxt.setFormat(Paths.font('vcr.ttf'), botplayTxt.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = PlayStateChangeables.botPlay;
		add(botplayTxt);
		if (PlayStateChangeables.useDownscroll)
		{
			botplayTxt.y = timeBar.y - 78;
		}
		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		if (isStoryMode)
			doof.cameras = [camHUD];
		startingSong = true;
		#if FEATURE_SCRIPTS
		if (Options.save.data.loadScripts)
		{
			// SONG SPECIFIC SCRIPTS
			var scriptList:Array<String> = [];
			var scriptsLoaded:Map<String, Bool> = [];

			var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

			for (directory in directories)
			{
				var scriptDirectory:String = Path.join([directory, 'data/songs', song.id]);
				if (Paths.fileSystem.exists(scriptDirectory))
				{
					for (file in Paths.fileSystem.readDirectory(scriptDirectory))
					{
						var path:String = Path.join([scriptDirectory, file]);
						if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.SCRIPT_EXT)
						{
							var scriptId:String = Path.withoutExtension(file);

							if (!scriptsLoaded.exists(scriptId))
							{
								scriptList.push(scriptId);
								scriptsLoaded.set(scriptId, true);
								scriptArray.push(new FunkinScript(path));
							}
						}
					}
				}
			}
		}
		#end
		if (isStoryMode && !seenCutscene)
		{
			switch (song.id)
			{
				case 'monster':
					var whiteScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.WHITE);

					add(whiteScreen);
					whiteScreen.scrollFactor.set();
					whiteScreen.blend = ADD;
					camHUD.visible = false;
					snapCamFollowToPos(opponent.getMidpoint().x + 150, opponent.getMidpoint().y - 100);
					inCutscene = true;
					FlxTween.tween(whiteScreen, {alpha: 0}, 1, {
						startDelay: 0.1,
						ease: FlxEase.linear,
						onComplete: (twn:FlxTween) ->
						{
							camHUD.visible = true;
							remove(whiteScreen);
							startCountdown();
						}
					});
					FlxG.sound.play(Paths.getRandomSound('thunder_', 1, 2));
					if (gf != null)
						gf.playAnim('scared', true);
					boyfriend.playAnim('scared', true);
				case 'winter-horrorland':
					var blackScreen:FlxSprite = new FlxSprite().makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
					add(blackScreen);
					blackScreen.scrollFactor.set();
					camHUD.visible = false;
					inCutscene = true;
					FlxTween.tween(blackScreen, {alpha: 0}, 0.7, {
						ease: FlxEase.linear,
						onComplete: (twn:FlxTween) ->
						{
							remove(blackScreen);
						}
					});
					FlxG.sound.play(Paths.getSound('Lights_Turn_On'));
					snapCamFollowToPos(400, -2050);
					FlxG.camera.focusOn(camFollow);
					FlxG.camera.zoom = 1.5;
					new FlxTimer().start(0.8, (tmr:FlxTimer) ->
					{
						camHUD.visible = true;
						remove(blackScreen);
						FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 2.5, {
							ease: FlxEase.quadInOut,
							onComplete: (twn:FlxTween) ->
							{
								startCountdown();
							}
						});
					});
				case 'senpai' | 'roses' | 'thorns':
					if (song.id == 'roses')
						FlxG.sound.play(Paths.getSound('ANGRY'));
					schoolIntro(doof);
				case 'ugh':
					startVideo('ughCutscene');
				case 'guns':
					startVideo('gunsCutscene');
				case 'stress':
					startVideo('stressCutscene');
				// case 'ugh' | 'guns' | 'stress':
				// 	tankIntro(); // TODO Commit theft heh heh heh heh no not really I'll credit Psych Engine.
				default:
					startCountdown();
			}
			seenCutscene = true;
		}
		else
		{
			startCountdown();
		}
		if (!loadRep)
			rep = new Replay('na');
		recalculateRating();
		// PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if (Options.save.data.hitsoundVolume > 0)
			Paths.precacheSound('hitsound');
		for (i in 1...4)
		{
			if (isPixelStage)
			{
				Paths.precacheSound('missnote-pixel$i');
			}
			else
			{
				Paths.precacheSound('missnote$i');
			}
		}
		if (PauseSubState.songName != null)
		{
			Paths.precacheMusic(PauseSubState.songName);
		}
		else if (Options.save.data.pauseMusic != 'None')
		{
			Paths.precacheMusic(Paths.formatToSongPath(Options.save.data.pauseMusic));
		}
		#if FEATURE_DISCORD
		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char);
		#end
		if (!Options.save.data.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		Conductor.safeZoneOffset = (PlayStateChangeables.safeFrames / TimingConstants.SECONDS_PER_MINUTE) * TimingConstants.MILLISECONDS_PER_SECOND;

		super.create(); // This is down here so the transition is created after the custom cameras have been made

		#if FEATURE_SCRIPTS
		callOnScripts('onCreatePost', []);
		#end
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!Options.save.data.noStage)
			stage.update(elapsed);

		// reverse iterate to remove oldest notes first and not invalidate the iteration
		// stop iteration as soon as a note is not removed
		// all notes should be kept in the correct order and this is optimal, safe to do every frame/update
		{
			var noteIndex:Int = notesHitArray.length - 1;
			while (noteIndex >= 0)
			{
				var noteHitDate:Date = notesHitArray[noteIndex];
				if (noteHitDate != null && noteHitDate.getTime() + 1000 < Date.now().getTime())
					notesHitArray.remove(noteHitDate);
				else
					noteIndex = 0;
				noteIndex--;
			}
			nps = notesHitArray.length;
			if (nps > maxNPS)
				maxNPS = nps;
		}

		#if FEATURE_SCRIPTS
		callOnScripts('onUpdate', [elapsed]);
		#end

		if (!inCutscene)
		{
			var lerpVal:Float = FlxMath.bound(elapsed * 2.4 * cameraSpeed, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			#if FEATURE_ACHIEVEMENTS
			if (!startingSong && !endingSong && boyfriend.animation.curAnim.name.startsWith('idle'))
			{
				boyfriendIdleTime += elapsed;
				if (boyfriendIdleTime >= 0.15)
				{ // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			}
			else
			{
				boyfriendIdleTime = 0;
			}
			#end
		}

		recalculateRating();

		if (botplayTxt.visible)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			pause();
		}

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene)
		{
			openChartEditor();
		}

		if (health > healthBar.bar.max)
		{
			health = healthBar.bar.max;
		}

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene)
		{
			persistentUpdate = false;
			paused = true;
			cancelMusicFadeTween();
			FlxG.switchState(new CharacterEditorState(song.player2));
			stageTesting = false;
		}

		if (skipActive && Conductor.songPosition >= skipTo)
		{
			remove(skipText);
			skipActive = false;
		}

		if (FlxG.keys.justPressed.SPACE && skipActive)
		{
			FlxG.sound.music.pause();
			vocals.pause();
			Conductor.songPosition = skipTo;
			Conductor.rawPosition = skipTo;

			FlxG.sound.music.time = Conductor.songPosition;
			FlxG.sound.music.play();

			vocals.time = Conductor.songPosition;
			vocals.play();
			FlxTween.tween(skipText, {alpha: 0}, 0.2, {
				onComplete: function(tw:FlxTween)
				{
					remove(skipText);
				}
			});
			skipActive = false;
		}

		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += elapsed * TimingConstants.MILLISECONDS_PER_SECOND;
				Conductor.rawPosition = Conductor.songPosition;
				if (Conductor.songPosition >= 0)
				{
					startSong();
				}
			}
		}
		else
		{
			Conductor.songPosition += elapsed * TimingConstants.MILLISECONDS_PER_SECOND;
			Conductor.rawPosition = FlxG.sound.music.time;

			currentSection = getSectionByTime(Conductor.songPosition);
			// currentSection = getSectionByBeat(curDecimalBeat);

			if (!paused)
			{
				if (updateTime)
				{
					var curTime:Float = (Conductor.songPosition - Options.save.data.noteOffset) / songMultiplier;
					if (curTime < 0)
						curTime = 0;
					songPercent = curTime / songLength;

					var songCalc:Float = songLength - curTime;
					if (Options.save.data.timeBarType == 'Time Elapsed')
						songCalc = curTime;

					var secondsTotal:Int = Math.floor(songCalc / TimingConstants.MILLISECONDS_PER_SECOND);
					if (secondsTotal < 0)
						secondsTotal = 0;

					if (Options.save.data.timeBarType != 'Song Name')
						timeBar.text.text = FlxStringUtil.formatTime(secondsTotal, false);
				}
			}
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, FlxMath.bound(1 - (elapsed * 3.125), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, FlxMath.bound(1 - (elapsed * 3.125), 0, 1));
		}

		Debug.quickWatch('Song Speed', songSpeed);
		Debug.quickWatch('Tempo', Conductor.tempo);
		Debug.quickWatch('Beat', curBeat);
		Debug.quickWatch('Step', curStep);

		// RESET = Quick Game Over Screen
		if (Options.save.data.resetKey && controls.RESET && !inCutscene && !endingSong)
		{
			health = 0;
			Debug.logTrace('Reset key killed BF'); // Listen, I don't know how to frickin' word this.
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			// var time:Float = 3000; // shit be weird on 4:3
			var time:Float = 14000; // Kade uses this value instead; I have no idea what the significance of this variable is
			if (songSpeed < 1)
				time /= songSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time * songMultiplier)
			{
				var dunceNote:Note = unspawnNotes.shift();
				notes.insert(0, dunceNote); // This is basically Array.unshift() for FlxTypedGroup
			}
		}

		updatePlaybackSpeed();

		if (generatedMusic)
		{
			if (!inCutscene)
			{
				if (!PlayStateChangeables.botPlay)
				{
					handleNoteSustains();
				}
				else if (boyfriend.holdTimer > Conductor.semiquaverLength * 0.001 * boyfriend.singDuration
					&& boyfriend.animation.curAnim.name.startsWith('sing')
					&& !boyfriend.animation.curAnim.name.endsWith('miss'))
				{
					boyfriend.dance();
				}
			}

			if (startedCountdown) // This must be checked to ensure that the strum groups are not empty
			{
				var fakeCrotchet:Float = Conductor.calculateCrotchetLength(song.bpm);
				notes.forEachAlive((note:Note) ->
				{
					var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
					if (!note.mustPress)
						strumGroup = opponentStrums;

					var strumOfNote:StrumNote = strumGroup.members[note.noteData];

					var strumX:Float = strumOfNote.x;
					var strumY:Float = strumOfNote.y;
					var strumAngle:Float = strumOfNote.angle;
					var strumDirection:Float = strumOfNote.direction;
					var strumAlpha:Float = strumOfNote.alpha;
					var strumDownScroll:Bool = strumOfNote.downScroll;

					strumX += note.offsetX;
					strumY += note.offsetY;
					strumAngle += note.offsetAngle;
					strumAlpha *= note.multAlpha;

					if (strumDownScroll) // Downscroll
					{
						note.distance = (0.45 * ((Conductor.songPosition - note.strumTime) / songMultiplier) * songSpeed);
						// note.distance = (0.45 * (curDecimalBeat - note.beat) * songSpeed);
					}
					else // Upscroll
					{
						note.distance = (-0.45 * ((Conductor.songPosition - note.strumTime) / songMultiplier) * songSpeed);
						// note.distance = (-0.45 * (curDecimalBeat - note.beat) * songSpeed);
					}

					var angleDir:Float = strumDirection * Math.PI / 180;
					if (note.copyAngle)
						note.angle = strumDirection - 90 + strumAngle;

					if (note.copyAlpha)
						note.alpha = strumAlpha;

					if (note.copyX)
						note.x = strumX + Math.cos(angleDir) * note.distance;

					if (note.copyY)
					{
						note.y = strumY + Math.sin(angleDir) * note.distance;

						// Jesus fuck this took me so much mother fucking time AAAAAAAAAA
						// TODO Can we, uh, please have some constants so we know what we are looking at?
						if (strumDownScroll && note.isSustainNote)
						{
							if (note.animation.curAnim.name.endsWith('end'))
							{
								note.y += 10.5 * (fakeCrotchet / 400) * 1.5 * songSpeed + (46 * (songSpeed - 1));
								note.y -= 46 * (1 - (fakeCrotchet / 600)) * songSpeed;
								if (isPixelStage)
								{
									note.y += 8 + (6 - note.originalHeightForCalcs) * PIXEL_ZOOM;
								}
								else
								{
									note.y -= 19;
								}
							}
							note.y += (Note.STRUM_WIDTH / 2) - (60.5 * (songSpeed - 1));
							note.y += 27.5 * ((song.bpm / 100) - 1) * (songSpeed - 1);
						}
					}

					if (!note.mustPress && note.wasGoodHit && !note.hitByOpponent && !note.ignoreNote)
					{
						opponentHitNote(note);
					}

					if (note.mustPress && PlayStateChangeables.botPlay)
					{
						if (note.isSustainNote)
						{
							if (note.canBeHit)
							{
								playerHitNote(note);
							}
						}
						else if (note.strumTime <= Conductor.songPosition || (note.isSustainNote && note.canBeHit && note.mustPress))
						{
							playerHitNote(note);
						}
					}

					var center:Float = strumY + Note.STRUM_WIDTH / 2;
					if (strumOfNote.sustainReduce
						&& note.isSustainNote
						&& (note.mustPress || !note.ignoreNote)
						&& (!note.mustPress || (note.wasGoodHit || (note.prevNote.wasGoodHit && !note.canBeHit))))
					{
						if (strumDownScroll)
						{
							if (note.y - note.offset.y * note.scale.y + note.height >= center)
							{
								var clipRect:FlxRect = new FlxRect(0, 0, note.frameWidth, note.frameHeight);
								clipRect.height = (center - note.y) / note.scale.y;
								clipRect.y = note.frameHeight - clipRect.height;

								note.clipRect = clipRect;
							}
						}
						else
						{
							if (note.y + note.offset.y * note.scale.y <= center)
							{
								var clipRect:FlxRect = new FlxRect(0, 0, note.width / note.scale.x, note.height / note.scale.y);
								clipRect.y = (center - note.y) / note.scale.y;
								clipRect.height -= clipRect.y;

								note.clipRect = clipRect;
							}
						}

						// if (note.isParent)
						// {
						// 	for (childNote in note.children)
						// 	{
						// 		childNote.y = note.y - childNote.height;
						// 	}
						// }
					}

					// Kill extremely late notes and cause misses
					// if (Conductor.songPosition > noteKillOffset + TimingStruct.getTimeFromBeat(note.beat))
					if (Conductor.songPosition > noteKillOffset + note.strumTime)
					{
						if (note.mustPress && !PlayStateChangeables.botPlay && !note.ignoreNote && !endingSong && (note.tooLate || !note.wasGoodHit))
						{
							playerMissNote(note);
						}

						note.kill();
						notes.remove(note, true);
						note.destroy();
					}
				});
			}
		}

		if (FlxG.sound.music.playing)
		{
			var timingSeg:TimingStruct = TimingStruct.getTimingAtBeat(curDecimalBeat);
			// var timingSeg:TimingStruct = TimingStruct.getTimingAtTimestamp(Conductor.songPosition);

			if (timingSeg != null)
			{
				var timingSegTempo:Float = timingSeg.tempo;

				if (timingSegTempo != Conductor.tempo)
				{
					Debug.logTrace('Setting tempo from ${Conductor.tempo} to $timingSegTempo');
					Conductor.tempo = timingSegTempo;
					Conductor.crotchetLength /= songMultiplier;

					#if FEATURE_SCRIPTS
					setOnScripts('curBpm', Conductor.tempo);
					setOnScripts('crotchetLength', Conductor.crotchetLength);
					setOnScripts('semiquaverLength', Conductor.semiquaverLength);
					#end
				}
			}
		}

		checkEvent();

		#if debug
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				killNotes();
				FlxG.sound.music.onComplete();
			}
			// TODO Make this do stepHit() for each step it jumps over
			if (FlxG.keys.justPressed.TWO)
			{ // Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
				if (Conductor.songPosition >= songLength)
					endSong();
			}
		}
		#end

		#if FEATURE_SCRIPTS
		setOnScripts('cameraX', camFollowPos.x);
		setOnScripts('cameraY', camFollowPos.y);
		setOnScripts('botPlay', PlayStateChangeables.botPlay);
		callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	override public function openSubState(subState:FlxSubState):Void
	{
		super.openSubState(subState);

		subState.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]]; // This is so it doesn't use camGame

		if (paused)
		{
			if (FlxG.sound.music != null && FlxG.sound.music.playing)
				FlxG.sound.music.pause();
			if (vocals != null && vocals.playing)
				vocals.pause();

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (songSpeedTween != null)
				songSpeedTween.active = false;

			var chars:Array<Character> = [boyfriend, gf, opponent];
			for (char in chars)
			{
				if (char != null && char.colorTween != null)
				{
					char.colorTween.active = false;
				}
			}

			#if FEATURE_SCRIPTS
			for (tween in scriptTweens)
			{
				tween.active = false;
			}
			for (timer in scriptTimers)
			{
				timer.active = false;
			}
			#end
		}
	}

	override public function closeSubState():Void
	{
		super.closeSubState();

		if (paused)
		{
			resume();
		}
	}

	override public function destroy():Void
	{
		super.destroy();

		#if FEATURE_SCRIPTS
		for (script in scriptArray)
		{
			script.call('onDestroy', []);
			script.stop();
		}
		FlxArrayUtil.clearArray(scriptArray);
		#end

		if (!Options.save.data.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		FlxG.cameras.reset();

		instance = null;
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();

		pause();
	}

	override public function onFocus():Void
	{
		super.onFocus();

		#if FEATURE_DISCORD
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0)
			{
				DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char, true,
					songLength - Conductor.songPosition - Options.save.data.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char);
			}
		}
		#end
	}

	override public function stepHit(step:Int):Void
	{
		super.stepHit(step);

		if (!Options.save.data.noStage)
			stage.stepHit(step);

		if (Math.abs(FlxG.sound.music.time - (Conductor.rawPosition - Conductor.offset)) > 20
			|| (song.needsVoices && Math.abs(vocals.time - (Conductor.rawPosition - Conductor.offset)) > 20))
		{
			resyncVocals();
		}

		#if FEATURE_SCRIPTS
		setOnScripts('curStep', step);
		callOnScripts('onStepHit', [step]);
		#end
	}

	override public function beatHit(beat:Int):Void
	{
		super.beatHit(beat);

		if (!Options.save.data.noStage)
			stage.beatHit(beat);

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, PlayStateChangeables.useDownscroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		if (currentSection != null)
		{
			#if FEATURE_SCRIPTS
			setOnScripts('mustHitSection', currentSection.mustHitSection);
			setOnScripts('altAnim', currentSection.altAnim);
			setOnScripts('gfSection', currentSection.gfSection);
			#end
		}

		if (generatedMusic && currentSection != null && !endingSong && !isCameraOnForcedPos)
		{
			moveCameraSection(currentSection);
			updateFocusedCharacter();
		}

		if (camZooming && FlxG.camera.zoom < 1.35 && Options.save.data.camZooms && beat % Conductor.CROTCHETS_PER_MEASURE == 0)
		{
			FlxG.camera.zoom += 0.015 / songMultiplier;
			camHUD.zoom += 0.03 / songMultiplier;
		}

		healthBar.beatHit(beat);

		if (gf != null
			&& beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0
			&& !gf.stunned
			&& gf.animation.curAnim.name != null
			&& !gf.animation.curAnim.name.startsWith('sing')
			&& !gf.stunned)
		{
			gf.dance();
		}
		if (beat % boyfriend.danceEveryNumBeats == 0
			&& boyfriend.animation.curAnim != null
			&& !boyfriend.animation.curAnim.name.startsWith('sing')
			&& !boyfriend.stunned)
		{
			boyfriend.dance();
		}
		if (beat % opponent.danceEveryNumBeats == 0
			&& opponent.animation.curAnim != null
			&& !opponent.animation.curAnim.name.startsWith('sing')
			&& !opponent.stunned)
		{
			opponent.dance();
		}

		#if FEATURE_SCRIPTS
		setOnScripts('curBeat', beat);
		callOnScripts('onBeatHit', [beat]);
		#end
	}

	#if FEATURE_SCRIPTS
	public function addTextToDebug(text:String, color:FlxColor = FlxColor.WHITE):Void
	{
		scriptDebugGroup.forEachAlive((spr:DebugScriptText) ->
		{
			spr.y += 20;
		});

		if (scriptDebugGroup.length > 34)
		{
			var blah:DebugScriptText = scriptDebugGroup.getFirstAlive();
			blah.kill();
			blah.destroy();
			scriptDebugGroup.remove(blah, true);
		}
		scriptDebugGroup.add(new DebugScriptText(text, scriptDebugGroup, color));
	}
	#end

	public function reloadHealthBarColors():Void
	{
		healthBar.setColors(FlxColor.fromRGB(opponent.healthBarColors[0], opponent.healthBarColors[1], opponent.healthBarColors[2]),
			FlxColor.fromRGB(boyfriend.healthBarColors[0], boyfriend.healthBarColors[1], boyfriend.healthBarColors[2]));
	}

	public function addCharacterToList(newCharacter:String, role:CharacterRole):Void
	{
		switch (role)
		{
			case PLAYER:
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					#if FEATURE_SCRIPTS
					startCharacterScript(newBoyfriend.id);
					#end
				}

			case OPPONENT:
				if (!opponentMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter);
					opponentMap.set(newCharacter, newDad);
					opponentGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					#if FEATURE_SCRIPTS
					startCharacterScript(newDad.id);
					#end
				}

			case GIRLFRIEND:
				if (gf != null && !gfMap.exists(newCharacter))
				{
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					#if FEATURE_SCRIPTS
					startCharacterScript(newGf.id);
					#end
				}
		}
	}

	#if FEATURE_SCRIPTS
	private function startCharacterScript(name:String):Void
	{
		var scriptPath:String = Paths.script(Path.join(['characters', name]));
		if (Paths.exists(scriptPath))
		{
			for (script in scriptArray)
			{
				if (script.scriptName == scriptPath)
					return;
			}
			scriptArray.push(new FunkinScript(scriptPath));
		}
	}
	#end

	private function startCharacterPos(char:Character, gfCheck:Bool = false):Void
	{
		if (gfCheck && char.id.startsWith('gf'))
		{ // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function startVideo(name:String):Void
	{
		#if FEATURE_VIDEOS
		var filePath:String = Paths.video(name);
		if (Paths.exists(filePath, BINARY))
		{
			inCutscene = true;
			// Blocks any scenery behind the video sprite
			var bg:FlxSprite = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			// var bg:FlxSprite = new FlxSprite(FlxG.width, FlxG.height).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

			bg.scrollFactor.set();
			bg.cameras = [camHUD];
			add(bg);
			var videoHandler:VideoHandler = new VideoHandler(filePath);
			videoHandler.finishCallback = () ->
			{
				remove(bg);
				startAndEnd();
			}
			return;
		}
		else
		{
			Debug.logWarn('Couldn\'t find video file: $filePath');
		}
		#end
		startAndEnd();
	}

	private function startAndEnd():Void
	{
		if (endingSong)
			endSong();
		else
			startCountdown();
	}

	// You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueDef, ?song:String):Void
	{
		// TODO: Make this more flexible, maybe? (In what way, previous todo-commenter?)
		if (psychDialogue != null)
			return;

		if (dialogueFile.dialogue.length > 0)
		{
			inCutscene = true;
			// PRECACHE SOUNDS
			Paths.precacheSound('dialogue');
			Paths.precacheSound('dialogueClose');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if (endingSong)
			{
				psychDialogue.finishThing = () ->
				{
					psychDialogue = null;
					endSong();
				}
			}
			else
			{
				psychDialogue.finishThing = () ->
				{
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		}
		else
		{
			Debug.logWarn('Your dialogue file is badly formatted!');
			if (endingSong)
			{
				endSong();
			}
			else
			{
				startCountdown();
			}
		}
	}

	// TODO Move this to Stage, maybe
	private function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		inCutscene = true;
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		add(black);

		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFFF1B31);
		red.scrollFactor.set();

		if (song.id == 'roses' || song.id == 'thorns')
		{
			remove(black);

			if (song.id == 'thorns')
			{
				add(red);
				camHUD.visible = false;
			}
		}

		new FlxTimer().start(0.3, (tmr:FlxTimer) ->
		{
			black.alpha -= 0.15;

			if (black.alpha > 0)
			{
				tmr.reset(0.3);
			}
			else
			{
				if (dialogueBox != null)
				{
					if (song.id == 'thorns')
					{
						var senpaiEvil:FlxSprite = new FlxSprite();
						senpaiEvil.frames = Paths.getSparrowAtlas('stages/weeb/senpaiCrazy');
						senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
						senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
						senpaiEvil.scrollFactor.set();
						senpaiEvil.updateHitbox();
						senpaiEvil.screenCenter();
						senpaiEvil.x += 300;
						add(senpaiEvil);
						senpaiEvil.alpha = 0;
						new FlxTimer().start(0.3, (deathTimer:FlxTimer) ->
						{
							senpaiEvil.alpha += 0.15;
							if (senpaiEvil.alpha < 1)
							{
								deathTimer.reset();
							}
							else
							{
								senpaiEvil.animation.play('idle');
								FlxG.sound.play(Paths.getSound('Senpai_Dies'), 1, false, null, true, () ->
								{
									remove(senpaiEvil);
									remove(red);
									FlxG.camera.fade(FlxColor.WHITE, 0.01, true, () ->
									{
										add(dialogueBox);
										camHUD.visible = true;
									}, true);
								});
								new FlxTimer().start(3.2, (deadTime:FlxTimer) ->
								{
									FlxG.camera.fade(FlxColor.WHITE, 1.6, false);
								});
							}
						});
					}
					else
					{
						add(dialogueBox);
					}
				}
				else
					startCountdown();

				remove(black);
			}
		});
	}

	// TODO This

	/*
		private function tankIntro():Void
		{
			var cutsceneHandler:CutsceneHandler = new CutsceneHandler();

			opponentGroup.alpha = 0.00001;
			camHUD.visible = false;
			// inCutscene = true; //this would stop the camera movement, oops

			var tankman:FlxSprite = new FlxSprite(-20, 320);
			tankman.frames = Paths.getSparrowAtlas('cutscenes/' + song.id);
			tankman.antialiasing = Options.save.data.globalAntialiasing;
			addBehindDad(tankman);
			cutsceneHandler.push(tankman);

			var tankman2:FlxSprite = new FlxSprite(16, 312);
			tankman2.antialiasing = Options.save.data.globalAntialiasing;
			tankman2.alpha = 0.000001;
			cutsceneHandler.push(tankman2);
			var gfDance:FlxSprite = new FlxSprite(gf.x - 107, gf.y + 140);
			gfDance.antialiasing = Options.save.data.globalAntialiasing;
			cutsceneHandler.push(gfDance);
			var gfCutscene:FlxSprite = new FlxSprite(gf.x - 104, gf.y + 122);
			gfCutscene.antialiasing = Options.save.data.globalAntialiasing;
			cutsceneHandler.push(gfCutscene);
			var picoCutscene:FlxSprite = new FlxSprite(gf.x - 849, gf.y - 264);
			picoCutscene.antialiasing = Options.save.data.globalAntialiasing;
			cutsceneHandler.push(picoCutscene);
			var boyfriendCutscene:FlxSprite = new FlxSprite(boyfriend.x + 5, boyfriend.y + 20);
			boyfriendCutscene.antialiasing = Options.save.data.globalAntialiasing;
			cutsceneHandler.push(boyfriendCutscene);

			cutsceneHandler.finishCallback = function()
			{
				var timeForStuff:Float = Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND * 4.5;
				FlxG.sound.music.fadeOut(timeForStuff);
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, timeForStuff, {ease: FlxEase.quadInOut});
				moveCamera(true);
				startCountdown();

				opponentGroup.alpha = 1;
				camHUD.visible = true;
				boyfriend.animation.finishCallback = null;
				gf.animation.finishCallback = null;
				gf.dance();
			};

			camFollow.set(opponent.x + 280, opponent.y + 170);
			switch (song.id)
			{
				case 'ugh':
					cutsceneHandler.endTime = 12;
					cutsceneHandler.music = 'DISTORTO';
					precacheList.set('wellWellWell', 'sound');
					precacheList.set('killYou', 'sound');
					precacheList.set('bfBeep', 'sound');

					var wellWellWell:FlxSound = new FlxSound().loadEmbedded(Paths.sound('wellWellWell'));
					FlxG.sound.list.add(wellWellWell);

					tankman.animation.addByPrefix('wellWell', 'TANK TALK 1 P1', 24, false);
					tankman.animation.addByPrefix('killYou', 'TANK TALK 1 P2', 24, false);
					tankman.animation.play('wellWell', true);
					FlxG.camera.zoom *= 1.2;

					// Well well well, what do we got here?
					cutsceneHandler.timer(0.1, function()
					{
						wellWellWell.play(true);
					});

					// Move camera to BF
					cutsceneHandler.timer(3, function()
					{
						camFollow.x += 750;
						camFollow.y += 100;
					});

					// Beep!
					cutsceneHandler.timer(4.5, function()
					{
						boyfriend.playAnim('singUP', true);
						boyfriend.specialAnim = true;
						FlxG.sound.play(Paths.sound('bfBeep'));
					});

					// Move camera to Tankman
					cutsceneHandler.timer(6, function()
					{
						camFollow.x -= 750;
						camFollow.y -= 100;

						// We should just kill you but... what the hell, it's been a boring day... let's see what you've got!
						tankman.animation.play('killYou', true);
						FlxG.sound.play(Paths.sound('killYou'));
					});

				case 'guns':
					cutsceneHandler.endTime = 11.5;
					cutsceneHandler.music = 'DISTORTO';
					tankman.x += 40;
					tankman.y += 10;
					precacheList.set('tankSong2', 'sound');

					var tightBars:FlxSound = new FlxSound().loadEmbedded(Paths.getSound('tankSong2'));
					FlxG.sound.list.add(tightBars);

					tankman.animation.addByPrefix('tightBars', 'TANK TALK 2', 24, false);
					tankman.animation.play('tightBars', true);
					boyfriend.animation.curAnim.finish();

					cutsceneHandler.onStart = function()
					{
						tightBars.play(true);
						FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 4, {ease: FlxEase.quadInOut});
						FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2 * 1.2}, 0.5, {ease: FlxEase.quadInOut, startDelay: 4});
						FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 1, {ease: FlxEase.quadInOut, startDelay: 4.5});
					};

					cutsceneHandler.timer(4, function()
					{
						gf.playAnim('sad', true);
						gf.animation.finishCallback = function(name:String)
						{
							gf.playAnim('sad', true);
						};
					});

				case 'stress':
					cutsceneHandler.endTime = 35.5;
					tankman.x -= 54;
					tankman.y -= 14;
					gfGroup.alpha = 0.00001;
					boyfriendGroup.alpha = 0.00001;
					camFollow.set(opponent.x + 400, opponent.y + 170);
					FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2}, 1, {ease: FlxEase.quadInOut});
					foregroundSprites.forEach(function(spr:BGSprite)
					{
						spr.y += 100;
					});
					precacheList.set('stressCutscene', 'sound');

					tankman2.frames = Paths.getSparrowAtlas('cutscenes/stress2');
					addBehindDad(tankman2);

					if (!Options.save.data.lowQuality)
					{
						gfDance.frames = Paths.getSparrowAtlas('characters/gfTankmen');
						gfDance.animation.addByPrefix('dance', 'GF Dancing at Gunpoint', 24, true);
						gfDance.animation.play('dance', true);
						addBehindGF(gfDance);
					}

					gfCutscene.frames = Paths.getSparrowAtlas('cutscenes/stressGF');
					gfCutscene.animation.addByPrefix('dieBitch', 'GF STARTS TO TURN PART 1', 24, false);
					gfCutscene.animation.addByPrefix('getRektLmao', 'GF STARTS TO TURN PART 2', 24, false);
					gfCutscene.animation.play('dieBitch', true);
					gfCutscene.animation.pause();
					addBehindGF(gfCutscene);
					if (!Options.save.data.lowQuality)
					{
						gfCutscene.alpha = 0.00001;
					}

					picoCutscene.frames = AtlasFrameMaker.construct('cutscenes/stressPico');
					picoCutscene.animation.addByPrefix('anim', 'Pico Badass', 24, false);
					addBehindGF(picoCutscene);
					picoCutscene.alpha = 0.00001;

					boyfriendCutscene.frames = Paths.getSparrowAtlas('characters/BOYFRIEND');
					boyfriendCutscene.animation.addByPrefix('idle', 'BF idle dance', 24, false);
					boyfriendCutscene.animation.play('idle', true);
					boyfriendCutscene.animation.curAnim.finish();
					addBehindBF(boyfriendCutscene);

					var cutsceneSnd:FlxSound = new FlxSound().loadEmbedded(Paths.sound('stressCutscene'));
					FlxG.sound.list.add(cutsceneSnd);

					tankman.animation.addByPrefix('godEffingDamnIt', 'TANK TALK 3', 24, false);
					tankman.animation.play('godEffingDamnIt', true);

					var calledTimes:Int = 0;
					var zoomBack:Void->Void = function()
					{
						var camPosX:Float = 630;
						var camPosY:Float = 425;
						camFollow.set(camPosX, camPosY);
						camFollowPos.setPosition(camPosX, camPosY);
						FlxG.camera.zoom = 0.8;
						cameraSpeed = 1;

						calledTimes++;
						if (calledTimes > 1)
						{
							foregroundSprites.forEach(function(spr:BGSprite)
							{
								spr.y -= 100;
							});
						}
					}

					cutsceneHandler.onStart = function()
					{
						cutsceneSnd.play(true);
					};

					cutsceneHandler.timer(15.2, function()
					{
						FlxTween.tween(camFollow, {x: 650, y: 300}, 1, {ease: FlxEase.sineOut});
						FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 2.25, {ease: FlxEase.quadInOut});

						gfDance.visible = false;
						gfCutscene.alpha = 1;
						gfCutscene.animation.play('dieBitch', true);
						gfCutscene.animation.finishCallback = function(name:String)
						{
							if (name == 'dieBitch') // Next part
							{
								gfCutscene.animation.play('getRektLmao', true);
								gfCutscene.offset.set(224, 445);
							}
							else
							{
								gfCutscene.visible = false;
								picoCutscene.alpha = 1;
								picoCutscene.animation.play('anim', true);

								boyfriendGroup.alpha = 1;
								boyfriendCutscene.visible = false;
								boyfriend.playAnim('bfCatch', true);
								boyfriend.animation.finishCallback = function(name:String)
								{
									if (name != 'idle')
									{
										boyfriend.playAnim('idle', true);
										boyfriend.animation.curAnim.finish(); // Instantly goes to last frame
									}
								};

								picoCutscene.animation.finishCallback = function(name:String)
								{
									picoCutscene.visible = false;
									gfGroup.alpha = 1;
									picoCutscene.animation.finishCallback = null;
								};
								gfCutscene.animation.finishCallback = null;
							}
						};
					});

					cutsceneHandler.timer(17.5, function()
					{
						zoomBack();
					});

					cutsceneHandler.timer(19.5, function()
					{
						tankman2.animation.addByPrefix('lookWhoItIs', 'TANK TALK 3', 24, false);
						tankman2.animation.play('lookWhoItIs', true);
						tankman2.alpha = 1;
						tankman.visible = false;
					});

					cutsceneHandler.timer(20, function()
					{
						camFollow.set(opponent.x + 500, opponent.y + 170);
					});

					cutsceneHandler.timer(31.2, function()
					{
						boyfriend.playAnim('singUPmiss', true);
						boyfriend.animation.finishCallback = function(name:String)
						{
							if (name == 'singUPmiss')
							{
								boyfriend.playAnim('idle', true);
								boyfriend.animation.curAnim.finish(); // Instantly goes to last frame
							}
						};

						camFollow.set(boyfriend.x + 280, boyfriend.y + 200);
						cameraSpeed = 12;
						FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 0.25, {ease: FlxEase.elasticOut});
					});

					cutsceneHandler.timer(32.2, function()
					{
						zoomBack();
					});
			}
		}
	 */
	public function startCountdown():Void
	{
		if (startedCountdown)
		{
			#if FEATURE_SCRIPTS
			callOnScripts('onStartCountdown', []);
			#end
			return;
		}

		inCutscene = false;
		#if FEATURE_SCRIPTS
		var ret:Any = callOnScripts('onStartCountdown', [], false);
		if (ret != FunkinScript.FUNCTION_STOP)
		#end
		{
			if (skipCountdown || startTime > 0)
				skipArrowStartTween = true;

			generateStrumNotes(0);
			generateStrumNotes(1);
			#if FEATURE_SCRIPTS
			for (i in 0...playerStrums.length)
			{
				var strumNote:StrumNote = playerStrums.members[i];
				setOnScripts('defaultPlayerStrumX$i', strumNote.x);
				setOnScripts('defaultPlayerStrumY$i', strumNote.y);
			}
			for (i in 0...opponentStrums.length)
			{
				var strumNote:StrumNote = opponentStrums.members[i];
				setOnScripts('defaultOpponentStrumX$i', strumNote.x);
				setOnScripts('defaultOpponentStrumY$i', strumNote.y);
			}
			#end

			startedCountdown = true;
			Conductor.songPosition = -(Conductor.crotchetLength * 5);
			#if FEATURE_SCRIPTS
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted', []);
			#end

			if (startTime < 0)
			{
				startTime = 0;
			}

			if (startTime > 0)
			{
				clearNotesBefore(startTime);
				setSongTime(startTime);
				return;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return;
			}

			startTimer = new FlxTimer().start(Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND, (tmr:FlxTimer) ->
			{
				if (gf != null
					&& tmr.loopsLeft % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0
					&& !gf.stunned
					&& gf.animation.curAnim.name != null
					&& !gf.animation.curAnim.name.startsWith('sing')
					&& !gf.stunned)
				{
					gf.dance();
				}
				if (tmr.loopsLeft % boyfriend.danceEveryNumBeats == 0
					&& boyfriend.animation.curAnim != null
					&& !boyfriend.animation.curAnim.name.startsWith('sing')
					&& !boyfriend.stunned)
				{
					boyfriend.dance();
				}
				if (tmr.loopsLeft % opponent.danceEveryNumBeats == 0
					&& opponent.animation.curAnim != null
					&& !opponent.animation.curAnim.name.startsWith('sing')
					&& !opponent.stunned)
				{
					opponent.dance();
				}

				var introAssets:Map<String, Array<String>> = [
					'default' => ['ui/countdown/ready', 'ui/countdown/set', 'ui/countdown/go'],
					'pixel' => ['ui/countdown/ready-pixel', 'ui/countdown/set-pixel', 'ui/countdown/date-pixel']
				];

				var introAlts:Array<String> = introAssets.get(isPixelStage ? 'pixel' : 'default');
				var antialias:Bool = isPixelStage ? false : Options.save.data.globalAntialiasing;

				var curLoop:Int = tmr.elapsedLoops - 1;

				switch (curLoop)
				{
					case 0: // Three
						FlxG.sound.play(Paths.getSound('intro3$introSoundsSuffix'), 0.6);
					case 1: // Two
						countdownReady = new FlxSprite().loadGraphic(Paths.getGraphic(introAlts[0]));
						countdownReady.scrollFactor.set();
						countdownReady.updateHitbox();

						if (isPixelStage)
							countdownReady.setGraphicSize(Std.int(countdownReady.width * PIXEL_ZOOM));

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						add(countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0},
							Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND, {
								ease: FlxEase.cubeInOut,
								onComplete: (twn:FlxTween) ->
								{
									remove(countdownReady);
									countdownReady.destroy();
								}
							});
						FlxG.sound.play(Paths.getSound('intro2$introSoundsSuffix'), 0.6);
					case 2: // One
						countdownSet = new FlxSprite().loadGraphic(Paths.getGraphic(introAlts[1]));
						countdownSet.scrollFactor.set();

						if (isPixelStage)
							countdownSet.setGraphicSize(Std.int(countdownSet.width * PIXEL_ZOOM));

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						add(countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0},
							Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND, {
								ease: FlxEase.cubeInOut,
								onComplete: (twn:FlxTween) ->
								{
									remove(countdownSet);
									countdownSet.destroy();
								}
							});
						FlxG.sound.play(Paths.getSound('intro1$introSoundsSuffix'), 0.6);
					case 3: // Go
						countdownGo = new FlxSprite().loadGraphic(Paths.getGraphic(introAlts[2]));
						countdownGo.scrollFactor.set();

						if (isPixelStage)
							countdownGo.setGraphicSize(Std.int(countdownGo.width * PIXEL_ZOOM));

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						add(countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0},
							Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND, {
								ease: FlxEase.cubeInOut,
								onComplete: (twn:FlxTween) ->
								{
									remove(countdownGo);
									countdownGo.destroy();
								}
							});
						FlxG.sound.play(Paths.getSound('introGo$introSoundsSuffix'), 0.6);
					case 4: // Song starts on this loop
				}

				notes.forEachAlive((note:Note) ->
				{
					note.copyAlpha = false;
					note.alpha = note.multAlpha;
					if (Options.save.data.middleScroll && !note.mustPress)
					{
						note.alpha *= 0.5;
					}
				});
				#if FEATURE_SCRIPTS
				callOnScripts('onCountdownTick', [curLoop]);
				#end
			}, 5);
		}
	}

	public function addBehindBF(obj:FlxObject):Void
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}

	public function addBehindDad(obj:FlxObject):Void
	{
		insert(members.indexOf(opponentGroup), obj);
	}

	public function addBehindGF(obj:FlxObject):Void
	{
		insert(members.indexOf(gfGroup), obj);
	}

	// TODO Make these loops tidier
	public function clearNotesBefore(time:Float):Void
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0)
		{
			var note:Note = unspawnNotes[i];
			if (note.strumTime < time)
			{
				note.ignoreNote = true;

				note.kill();
				unspawnNotes.remove(note);
				note.destroy();
			}
			i--;
		}

		var i:Int = notes.length - 1;
		while (i >= 0)
		{
			var note:Note = notes.members[i];
			if (note.strumTime < time)
			{
				note.ignoreNote = true;

				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
			i--;
		}
	}

	public function setSongTime(time:Float):Void
	{
		if (time < 0)
			time = 0;

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.play();

		vocals.time = time;
		vocals.play();
		Conductor.songPosition = time;
	}

	public function restartSong(noTrans:Bool = false):Void
	{
		paused = true; // For scripts
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			FlxG.sound.music.stop();
		}
		if (vocals != null && vocals.playing)
		{
			vocals.stop();
		}

		if (noTrans)
		{
			FlxTransitionableState.skipNextTransOut = true;
		}
		stageTesting = false;
		FlxG.resetState();
	}

	private function startNextDialogue():Void
	{
		dialogueCount++;
		#if FEATURE_SCRIPTS
		callOnScripts('onNextDialogue', [dialogueCount]);
		#end
	}

	private function skipDialogue():Void
	{
		#if FEATURE_SCRIPTS
		callOnScripts('onSkipDialogue', [dialogueCount]);
		#end
	}

	private function startSong():Void
	{
		startingSong = false;

		FlxG.sound.playMusic(Paths.getInst(song.id), 1, false);
		FlxG.sound.music.onComplete = () ->
		{
			finishSong(false);
		};
		// Destroys the music after it plays, so it doesn't continue playing in the Freeplay menu and crash the game when running the callback
		FlxG.sound.music.autoDestroy = true;
		vocals.play();
		vocals.autoDestroy = true;

		if (startTime > 0)
		{
			setSongTime(startTime);
			clearNotesBefore(Conductor.songPosition);
		}
		startTime = 0;

		updatePlaybackSpeed();

		if (paused)
		{
			FlxG.sound.music.pause();
			vocals.pause();
		}

		if (needSkip)
		{
			skipActive = true;
			skipText = new FlxText(healthBar.x + 80, healthBar.y - 110, 500);
			skipText.text = 'Press Space to Skip Intro';
			skipText.size = 30;
			skipText.color = FlxColor.WHITE;
			skipText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
			skipText.cameras = [camHUD];
			skipText.alpha = 0;
			FlxTween.tween(skipText, {alpha: 1}, 0.2);
			add(skipText);
		}

		// Song duration in a float, useful for the time left feature
		// songLength = FlxG.sound.music.length;
		// songLength = (FlxG.sound.music.length / songMultiplier) / TimingConstants.MILLISECONDS_PER_SECOND;
		songLength = FlxG.sound.music.length / songMultiplier;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char, true, songLength);
		#end

		#if FEATURE_SCRIPTS
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart', []);
		#end
	}

	private function generateSong():Void
	{
		switch (PlayStateChangeables.scrollType)
		{
			case 'multiplicative':
				songSpeed = song.speed * PlayStateChangeables.scrollSpeed;
			case 'constant':
				songSpeed = PlayStateChangeables.scrollSpeed;
		}

		Conductor.tempo = song.bpm;
		Conductor.mapTempoChanges(song);
		TimingStruct.generateTimings(song, songMultiplier);
		song.recalculateAllSectionTimes();

		vocals = new FlxSound();
		if (song.needsVoices #if FEATURE_STEPMANIA && !isSM #end)
		{
			Paths.precacheAudioDirect(Paths.voices(song.id));
			vocals.loadEmbedded(Paths.getVoices(song.id));
		}

		FlxG.sound.list.add(vocals);

		#if FEATURE_STEPMANIA
		if (!isStoryMode && isSM)
		{
			var smPath:String = Path.join([pathToSm, sm.header.MUSIC]);
			Debug.logTrace('Loading $smPath');
			Paths.precacheAudioDirect(smPath);
		}
		else
		#end
		{
			Paths.precacheAudioDirect(Paths.inst(song.id));
		}

		notes = new FlxTypedGroup();
		add(notes);

		var file:String = Paths.json(Path.join(['songs', song.id, 'events']));
		if (Paths.exists(file))
		{
			var eventsSong:Song = Song.loadSong('events', '', song.id);
			for (eventGroup in eventsSong.events) // Event Notes
			{
				for (eventEntry in eventGroup.events)
				{
					var event:Event = new Event(0, eventGroup.beat, eventEntry.type, eventEntry.value1, eventEntry.value2);
					var strumTime:Float = TimingStruct.getTimeFromBeat(event.beat);
					strumTime += Std.parseInt(Options.save.data.noteOffset);
					strumTime -= eventEarlyTrigger(event);
					event.beat = TimingStruct.getBeatFromTime(strumTime);

					events.push(event);
					eventPushed(event);
				}
			}
			TimingStruct.generateTimings(song);
		}

		var sections:Array<Section> = song.notes;
		for (section in sections)
		{
			for (noteDef in section.sectionNotes)
			{
				var strumTime:Float = noteDef.strumTime / songMultiplier;
				// var strumTime:Float = TimingStruct.getTimeFromBeat(noteDef.beat) / songMultiplier;
				var noteData:Int = Std.int(noteDef.data % NoteKey.createAll().length);
				var mustHitSection:Bool = section.mustHitSection;
				if (noteDef.data >= NoteKey.createAll().length)
				{
					mustHitSection = !section.mustHitSection;
				}
				var oldNote:Null<Note> = null;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[unspawnNotes.length - 1];
				var note:Note = new Note(strumTime, noteData, oldNote, false, false, TimingStruct.getBeatFromTime(strumTime));
				note.mustPress = mustHitSection;
				note.sustainLength = TimingStruct.getTimeFromBeat((TimingStruct.getBeatFromTime(noteDef.sustainLength / songMultiplier)));
				note.gfNote = section.gfSection && noteDef.data < NoteKey.createAll().length;
				note.noteType = noteDef.type;
				note.scrollFactor.set();
				unspawnNotes.push(note);

				var sustainLength:Float = note.sustainLength / Conductor.semiquaverLength;
				if (sustainLength > 0)
				{
					note.isParent = true;
				}

				var floorSustain:Int = Math.floor(sustainLength);
				if (floorSustain > 0)
				{
					for (sustainFactor in 0...floorSustain + 1)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];
						var finalStrumTime = strumTime
							+ (Conductor.semiquaverLength * sustainFactor)
							+ (Conductor.semiquaverLength / FlxMath.roundDecimal(songSpeed, 2));
						var sustainNote:Note = new Note(finalStrumTime, noteData, oldNote, true, false, TimingStruct.getBeatFromTime(finalStrumTime));

						sustainNote.mustPress = mustHitSection;
						sustainNote.gfNote = section.gfSection && noteDef.data < NoteKey.createAll().length;
						sustainNote.noteType = note.noteType;
						sustainNote.scrollFactor.set();
						unspawnNotes.push(sustainNote);
						if (sustainNote.mustPress)
						{
							sustainNote.x += FlxG.width / 2; // general offset
						}
						else if (Options.save.data.middleScroll)
						{
							sustainNote.x += 310;
							if (noteData > 1) // Up and Right
							{
								sustainNote.x += FlxG.width / 2 + 25;
							}
						}

						sustainNote.parent = note;
						note.children.push(sustainNote);
						sustainNote.spotInLine = sustainFactor;
					}
				}
				if (note.mustPress)
				{
					note.x += FlxG.width / 2; // general offset
				}
				else if (Options.save.data.middleScroll)
				{
					note.x += 310;
					if (noteData > 1) // Up and Right
					{
						note.x += FlxG.width / 2 + 25;
					}
				}
				if (!noteTypeMap.exists(note.noteType))
				{
					noteTypeMap.set(note.noteType, true);
				}
			}
		}
		unspawnNotes.sort(sortNoteByTime);

		for (eventGroup in song.events) // Event Notes
		{
			for (eventEntry in eventGroup.events)
			{
				var event:Event = new Event(0, eventGroup.beat, eventEntry.type, eventEntry.value1, eventEntry.value2);
				var strumTime:Float = TimingStruct.getTimeFromBeat(event.beat);
				strumTime += Std.parseInt(Options.save.data.noteOffset);
				strumTime -= eventEarlyTrigger(event);
				event.beat = TimingStruct.getBeatFromTime(strumTime);

				events.push(event);
				eventPushed(event);
			}
		}
		if (events.length > 1)
		{
			// No need to sort if there's a single one or none at all
			events.sort(sortEventByTime);
		}
		checkEvent();

		generatedMusic = true;
	}

	private function eventPushed(event:Event):Void
	{
		switch (event.type)
		{
			case 'Change Character':
				var role:CharacterRole = CharacterRoleTools.createByString(event.value1.toLowerCase());
				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, role);
		}

		if (!eventPushedMap.exists(event.type))
		{
			eventPushedMap.set(event.type, true);
		}
	}

	private function eventEarlyTrigger(event:Event):Float
	{
		#if FEATURE_SCRIPTS
		var returnedValue:Float = callOnScripts('eventNoteEarlyTrigger', [event.type]);
		if (returnedValue != 0)
		{
			return returnedValue;
		}
		#end

		switch (event.type)
		{
			case 'Kill Henchmen': // Better timing so that the kill sound matches the beat intended
				return 280; // Plays 280ms before the actual position
		}
		return 0;
	}

	private function sortNoteByTime(obj1:Note, obj2:Note):Int
	{
		// return FlxSort.byValues(FlxSort.ASCENDING, obj1.beat, obj2.beat);
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.strumTime, obj2.strumTime);
	}

	private function sortEventByTime(obj1:Event, obj2:Event):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.beat, obj2.beat);
	}

	private function generateStrumNotes(player:Int):Void
	{
		for (i in 0...NoteKey.createAll().length)
		{
			var targetAlpha:Float = 1;
			if (player < 1 && Options.save.data.middleScroll)
				targetAlpha = 0.35;

			var babyArrow:StrumNote = new StrumNote(Options.save.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player);
			babyArrow.downScroll = PlayStateChangeables.useDownscroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else
			{
				babyArrow.alpha = targetAlpha;
			}

			if (player == 1)
			{
				playerStrums.add(babyArrow);
			}
			else
			{
				if (Options.save.data.middleScroll)
				{
					babyArrow.x += 310;
					if (i > 1)
					{ // Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	private function pause():Void
	{
		if (!paused && !inCutscene && !inResults)
		{
			#if FEATURE_SCRIPTS
			var ret:Any = callOnScripts('onPause', [], false);
			if (ret != FunkinScript.FUNCTION_STOP)
			#end
			{
				persistentUpdate = false;
				persistentDraw = true;
				paused = true;

				#if GITAROO_EASTER_EGG
				// 1 / 1000 chance for Gitaroo Man easter egg
				if (FlxG.random.bool(0.1))
				{
					// gitaroo man easter egg
					cancelMusicFadeTween();
					FlxG.switchState(new GitarooPauseState());
				}
				else
				#end
				{
					FlxG.sound.pause();

					if (FlxG.sound.music != null && FlxG.sound.music.playing)
						FlxG.sound.music.pause();
					if (vocals != null && vocals.playing)
						vocals.pause();

					openSubState(new PauseSubState());
				}

				#if FEATURE_DISCORD
				DiscordClient.changePresence(detailsPausedText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char);
				#end
			}
		}
	}

	private function resume():Void
	{
		if (FlxG.sound.music != null && !startingSong)
		{
			resyncVocals();
		}

		FlxG.sound.resume();

		if (startTimer != null && !startTimer.finished)
			startTimer.active = true;
		if (finishTimer != null && !finishTimer.finished)
			finishTimer.active = true;
		if (songSpeedTween != null)
			songSpeedTween.active = true;

		var chars:Array<Character> = [boyfriend, gf, opponent];
		for (char in chars)
		{
			if (char != null && char.colorTween != null)
			{
				char.colorTween.active = true;
			}
		}

		#if FEATURE_SCRIPTS
		for (tween in scriptTweens)
		{
			tween.active = true;
		}
		for (timer in scriptTimers)
		{
			timer.active = true;
		}
		#end

		paused = false;

		#if FEATURE_SCRIPTS
		callOnScripts('onResume', []);
		#end

		#if FEATURE_DISCORD
		if (startTimer != null && startTimer.finished)
		{
			DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char, true,
				songLength - Conductor.songPosition - Options.save.data.noteOffset);
		}
		else
		{
			DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char);
		}
		#end
	}

	private function resyncVocals():Void
	{
		if (finishTimer != null)
			return;

		vocals.pause();

		FlxG.sound.music.play();
		// TODO This is a comment to remind me that this next line is new
		// FlxG.sound.music.time = Conductor.songPosition * songMultiplier;
		Conductor.songPosition = FlxG.sound.music.time / songMultiplier;
		// Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();

		updatePlaybackSpeed();
	}

	private function openChartEditor():Void
	{
		persistentUpdate = false;
		paused = true;
		songMultiplier = 1;
		cancelMusicFadeTween();
		FlxG.switchState(new ChartEditorState());
		stageTesting = false;
		chartingMode = true;

		#if FEATURE_DISCORD
		DiscordClient.changePresence('Chart Editor', null, null, true);
		#end
	}

	private function doDeathCheck(skipHealthCheck:Bool = false):Bool
	{
		if (((skipHealthCheck && PlayStateChangeables.instakillOnMiss) || health <= 0) && !PlayStateChangeables.practiceMode && !isDead)
		{
			#if FEATURE_SCRIPTS
			var ret:Any = callOnScripts('onGameOver', [], false);
			if (ret != FunkinScript.FUNCTION_STOP)
			#end
			{
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				if (FlxG.sound.music != null && FlxG.sound.music.playing)
					FlxG.sound.music.stop();
				if (vocals != null && vocals.playing)
					vocals.stop();

				persistentUpdate = false;
				persistentDraw = false;
				#if FEATURE_SCRIPTS
				for (tween in scriptTweens)
				{
					tween.active = true;
				}
				for (timer in scriptTimers)
				{
					timer.active = true;
				}
				#end
				openSubState(new GameOverSubState(boyfriend.getScreenPosition().x - boyfriend.positionArray[0],
					boyfriend.getScreenPosition().y - boyfriend.positionArray[1]));

				#if FEATURE_DISCORD
				// Game Over doesn't get his own variable because it's only used here
				DiscordClient.changePresence('Game Over - $detailsText', '${song.name} ($storyDifficultyText)', healthBar.iconP2.char);
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEvent():Void
	{
		while (events.length > 0)
		{
			var event:Event = events[0];
			var beat:Float = event.beat;
			if (curDecimalBeat < beat)
			{
				break;
			}

			var value1:String = '';
			if (event.value1 != null)
				value1 = event.value1;

			var value2:String = '';
			if (event.value2 != null)
				value2 = event.value2;

			triggerEvent(event.type, value1, value2);
			events.shift();
		}
	}

	public function getControl(key:String):Bool
	{
		var pressed:Bool = Reflect.getProperty(controls, key);
		return pressed;
	}

	public function triggerEvent(type:String, value1:String, value2:String):Void
	{
		switch (type)
		{
			case 'Hey!':
				var value:Int = 2;
				switch (value1.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if (Math.isNaN(time) || time <= 0)
					time = 0.6;

				if (value != 0)
				{
					if (gf != null && opponent.id == gf.id && opponent.animation.exists('cheer'))
					{
						opponent.playAnim('cheer', true);
						opponent.specialAnim = true;
						opponent.heyTimer = time;
					}
					else if (gf != null && gf.animation.exists('cheer'))
					{
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}

					// TODO Don't hard-code any stage stuff in PlayState; move it all to Stage
					if (stage.id == 'mall')
					{
						var bottomBoppers:FlxSprite = stage.layers['bottomBoppers'];
						bottomBoppers.animation.play('hey', true);
						stage.heyTimer = time;
					}
				}
				if (value != 1)
				{
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if (Math.isNaN(value) || value < 1)
					value = 1;
				gfSpeed = value;

			case 'Blammed Lights':
				#if FEATURE_SCRIPTS
				var lightId:Int = Std.parseInt(value1);
				if (Math.isNaN(lightId))
					lightId = 0;

				var chars:Array<Character> = [boyfriend, gf, opponent];

				var phillyCityLightsEvent:FlxTypedGroup<BGSprite> = cast stage.groups['phillyCityLightsEvent'];

				if (lightId > 0 && curLight != lightId)
				{
					if (lightId > 5)
						lightId = FlxG.random.int(1, 5, [curLight]);

					var color:FlxColor = FlxColor.WHITE;
					switch (lightId)
					{
						case 1: // Blue
							color = 0xFF31A2FD;
						case 2: // Green
							color = 0xFF31FD8C;
						case 3: // Pink
							color = 0xFFF794F7;
						case 4: // Red
							color = 0xFFF96D63;
						case 5: // Orange
							color = 0xFFFBA633;
					}
					curLight = lightId;

					if (blammedLightsBlack.alpha == 0)
					{
						if (blammedLightsBlackTween != null)
						{
							blammedLightsBlackTween.cancel();
						}
						blammedLightsBlackTween = FlxTween.tween(blammedLightsBlack, {alpha: 1}, 1, {
							ease: FlxEase.quadInOut,
							onComplete: (twn:FlxTween) ->
							{
								blammedLightsBlackTween = null;
							}
						});

						for (char in chars)
						{
							if (char.colorTween != null)
							{
								char.colorTween.cancel();
							}
							char.colorTween = FlxTween.color(char, 1, FlxColor.WHITE, color, {
								onComplete: (twn:FlxTween) ->
								{
									char.colorTween = null;
								},
								ease: FlxEase.quadInOut
							});
						}
					}
					else
					{
						if (blammedLightsBlackTween != null)
						{
							blammedLightsBlackTween.cancel();
						}
						blammedLightsBlackTween = null;
						blammedLightsBlack.alpha = 1;

						for (char in chars)
						{
							if (char.colorTween != null)
							{
								char.colorTween.cancel();
							}
							char.colorTween = null;
						}
						opponent.color = color;
						boyfriend.color = color;
						if (gf != null)
							gf.color = color;
					}

					if (stage.id == 'philly')
					{
						if (phillyCityLightsEvent != null)
						{
							phillyCityLightsEvent.forEach((spr:BGSprite) ->
							{
								spr.visible = false;
							});
							phillyCityLightsEvent.members[lightId - 1].visible = true;
							phillyCityLightsEvent.members[lightId - 1].alpha = 1;
						}
					}
				}
				else
				{
					if (blammedLightsBlack.alpha != 0)
					{
						if (blammedLightsBlackTween != null)
						{
							blammedLightsBlackTween.cancel();
						}
						blammedLightsBlackTween = FlxTween.tween(blammedLightsBlack, {alpha: 0}, 1, {
							ease: FlxEase.quadInOut,
							onComplete: (twn:FlxTween) ->
							{
								blammedLightsBlackTween = null;
							}
						});
					}

					if (stage.id == 'philly')
					{
						var phillyCityLights:FlxTypedGroup<BGSprite> = cast stage.groups['phillyCityLights'];
						phillyCityLights.forEach((spr:BGSprite) ->
						{
							spr.visible = false;
						});
						phillyCityLightsEvent.forEach((spr:BGSprite) ->
						{
							spr.visible = false;
						});

						var memb:FlxSprite = phillyCityLightsEvent.members[curLight - 1];
						if (memb != null)
						{
							memb.visible = true;
							memb.alpha = 1;
							if (phillyCityLightsEventTween != null)
								phillyCityLightsEventTween.cancel();

							phillyCityLightsEventTween = FlxTween.tween(memb, {alpha: 0}, 1, {
								onComplete: (twn:FlxTween) ->
								{
									phillyCityLightsEventTween = null;
								},
								ease: FlxEase.quadInOut
							});
						}
					}

					for (char in chars)
					{
						if (char.colorTween != null)
						{
							char.colorTween.cancel();
						}
						char.colorTween = FlxTween.color(char, 1, char.color, FlxColor.WHITE, {
							onComplete: (twn:FlxTween) ->
							{
								char.colorTween = null;
							},
							ease: FlxEase.quadInOut
						});
					}
					curLight = 0;
				}
				#end
			case 'Kill Henchmen':
				stage.killHenchmen();

			case 'Add Camera Zoom':
				if (Options.save.data.camZooms && FlxG.camera.zoom < 1.35)
				{
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if (Math.isNaN(camZoom))
						camZoom = 0.015;
					if (Math.isNaN(hudZoom))
						hudZoom = 0.03;
					camZoom /= songMultiplier;
					hudZoom /= songMultiplier;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Trigger BG Ghouls':
				// TODO Move this to the Stage class
				if (stage.id == 'schoolEvil' && !PlayStateChangeables.optimize)
				{
					var bgGhouls:BGSprite = stage.layers['bgGhouls'];
					bgGhouls.dance(true);
					bgGhouls.visible = true;
				}

			case 'Play Animation':
				var char:Character = opponent;
				switch (value2.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if (Math.isNaN(val2))
							val2 = 0;

						switch (val2)
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
					updateDirectionalCamera();
				}

			case 'Camera Follow Pos':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if (Math.isNaN(val1))
					val1 = 0;
				if (Math.isNaN(val2))
					val2 = 0;

				isCameraOnForcedPos = false;
				if (!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2)))
				{
					camFollow.x = val1;
					camFollow.y = val2;

					camFollowNoDirectional.set(camFollow.x, camFollow.y);

					isCameraOnForcedPos = true;
				}

			case 'Alt Idle Animation':
				var char:Character = opponent;
				switch (value1.toLowerCase())
				{
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if (Math.isNaN(val))
							val = 0;

						switch (val)
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length)
				{
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null)
						duration = Std.parseFloat(split[0].trim());
					if (split[1] != null)
						intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration))
						duration = 0;
					if (Math.isNaN(intensity))
						intensity = 0;

					if (duration > 0 && intensity != 0)
					{
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var role:CharacterRole = CharacterRoleTools.createByString(value1.toLowerCase());
				switch (role)
				{
					case PLAYER:
						if (boyfriend.id != value2)
						{
							if (!boyfriendMap.exists(value2))
							{
								addCharacterToList(value2, role);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							healthBar.setIcons(boyfriend.healthIcon);
						}
						#if FEATURE_SCRIPTS
						setOnScripts('boyfriendName', boyfriend.id);
						#end

					case OPPONENT:
						if (opponent.id != value2)
						{
							if (!opponentMap.exists(value2))
							{
								addCharacterToList(value2, role);
							}

							var wasGf:Bool = opponent.id.startsWith('gf');
							var lastAlpha:Float = opponent.alpha;
							opponent.alpha = 0.00001;
							opponent = opponentMap.get(value2);
							if (!opponent.id.startsWith('gf'))
							{
								if (wasGf && gf != null)
								{
									gf.visible = true;
								}
							}
							else if (gf != null)
							{
								gf.visible = false;
							}
							opponent.alpha = lastAlpha;
							healthBar.setIcons(null, opponent.healthIcon);
						}
						#if FEATURE_SCRIPTS
						setOnScripts('dadName', opponent.id);
						#end

					case GIRLFRIEND:
						if (gf != null)
						{
							if (gf.id != value2)
							{
								if (!gfMap.exists(value2))
								{
									addCharacterToList(value2, role);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							#if FEATURE_SCRIPTS
							setOnScripts('gfName', gf.id);
							#end
						}
				}
				reloadHealthBarColors();

			case 'BG Freaks Expression':
				var bgGirls:BackgroundGirls = stage.layers['bgGirls'];
				if (bgGirls != null)
					bgGirls.swapDanceType();

			case 'Change Scroll Speed':
				if (PlayStateChangeables.scrollType == 'constant')
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if (Math.isNaN(val1))
					val1 = 1;
				if (Math.isNaN(val2))
					val2 = 0;

				var newValue:Float = song.speed * PlayStateChangeables.scrollSpeed * val1;

				if (val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2, {
						ease: FlxEase.linear,
						onComplete: (twn:FlxTween) ->
						{
							songSpeedTween = null;
						}
					});
				}
				/*
					case 'Change BPM':
						// var timingSeg:TimingStruct = TimingStruct.getTimingAtBeat(curDecimalBeat);

						// if (timingSeg != null)
						{
							// var timingSegBpm:Float = timingSeg.bpm;
							var timingSegBpm:Float = Std.parseFloat(value1);

							if (timingSegBpm != Conductor.tempo)
							{
								Conductor.tempo = timingSegBpm;
								Conductor.crotchetLength /= songMultiplier;

								#if FEATURE_SCRIPTS
								setOnScripts('curBpm', Conductor.tempo);
								setOnScripts('crotchetLength', Conductor.crotchetLength);
								setOnScripts('semiquaverLength', Conductor.semiquaverLength);
								#end
							}
						}
				 */
		}
		#if FEATURE_SCRIPTS
		callOnScripts('onEvent', [type, value1, value2]);
		#end
	}

	private function moveCameraSection(?section:Section):Void
	{
		if (section == null)
			return;

		if (gf != null && section.gfSection)
		{
			camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
			camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];

			camFollowNoDirectional.set(camFollow.x, camFollow.y);

			tweenCamIn();
			#if FEATURE_SCRIPTS
			callOnScripts('onMoveCamera', ['gf']);
			#end
			return;
		}

		if (section.mustHitSection)
		{
			moveCamera(false);
			#if FEATURE_SCRIPTS
			callOnScripts('onMoveCamera', ['boyfriend']);
			#end
		}
		else
		{
			moveCamera(true);
			#if FEATURE_SCRIPTS
			callOnScripts('onMoveCamera', ['dad']);
			#end
		}
	}

	public function moveCamera(isDad:Bool):Void
	{
		if (isDad)
		{
			camFollow.set(opponent.getMidpoint().x + 150, opponent.getMidpoint().y - 100);
			camFollow.x += opponent.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += opponent.cameraPosition[1] + opponentCameraOffset[1];

			camFollowNoDirectional.set(camFollow.x, camFollow.y);

			tweenCamIn();
		}
		else
		{
			camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			camFollowNoDirectional.set(camFollow.x, camFollow.y);

			if (song.id == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND), {
					ease: FlxEase.elasticInOut,
					onComplete: (twn:FlxTween) ->
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	private function tweenCamIn():Void
	{
		if (song.id == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3)
		{
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND), {
				ease: FlxEase.elasticInOut,
				onComplete: (twn:FlxTween) ->
				{
					cameraTwn = null;
				}
			});
		}
	}

	private function snapCamFollowToPos(x:Float, y:Float):Void
	{
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
		camFollowNoDirectional.set(x, y);
	}

	public function finishSong(ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:() -> Void = endSong; // In case you want to change it in a specific song.

		updateTime = false;
		FlxG.sound.music.stop();
		vocals.stop();
		if (Options.save.data.noteOffset <= 0 || ignoreNoteOffset)
		{
			finishCallback();
		}
		else
		{
			finishTimer = new FlxTimer().start(Options.save.data.noteOffset / TimingConstants.MILLISECONDS_PER_SECOND, (tmr:FlxTimer) ->
			{
				finishCallback();
			});
		}
	}

	public function endSong():Void
	{
		if (loadRep)
		{
			PlayStateChangeables.botPlay = false;
			PlayStateChangeables.scrollSpeed = 1 / songMultiplier;
			PlayStateChangeables.useDownscroll = false;
		}
		else
		{
			rep.saveReplay(saveNotes, saveJudge, replayAna);
		}

		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.stop();
		if (vocals != null && vocals.playing)
			vocals.stop();

		// Should kill you if you tried to cheat
		if (!startingSong)
		{
			notes.forEach((note:Note) ->
			{
				if (note.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= note.missHealth * PlayStateChangeables.healthLoss;
				}
			});
			for (note in unspawnNotes)
			{
				if (note.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= note.missHealth * PlayStateChangeables.healthLoss;
				}
			}

			if (doDeathCheck())
			{
				return;
			}
		}

		timeBar.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if FEATURE_ACHIEVEMENTS
		if (achievement != null)
		{
			return;
		}
		else
		{
			var achieve:String = checkForAchievement();

			if (achieve != null)
			{
				startAchievement(achieve);
				return;
			}
		}
		#end

		#if FEATURE_SCRIPTS
		var ret:Any = callOnScripts('onEndSong', [], false);
		#end
		if (#if FEATURE_SCRIPTS ret != FunkinScript.FUNCTION_STOP && #end!transitioning)
		{
			if (song.validScore && !PlayStateChangeables.practiceMode && !PlayStateChangeables.botPlay)
			{
				#if !switch
				var percent:Float = ratingPercent;
				if (Math.isNaN(percent))
					percent = 0;
				Highscore.saveScore(song.id, score, storyDifficulty, percent);
				#end
			}

			if (chartingMode)
			{
				openChartEditor();
				return;
			}
			else if (stageTesting)
			{
				new FlxTimer().start(0.3, (tmr:FlxTimer) ->
				{
					for (bg in stage.backgrounds)
					{
						remove(bg);
					}
					for (array in stage.foregrounds)
					{
						for (bg in array)
							remove(bg);
					}
					remove(boyfriend);
					remove(opponent);
					remove(gf);
				});
				// FlxG.switchState(new StageDebugState(stage.id));
			}

			if (isStoryMode)
			{
				campaignScore += score;
				campaignMisses += misses;
				campaignSicks += sicks;
				campaignGoods += goods;
				campaignBads += bads;
				campaignShits += shits;

				storyPlaylist.shift();

				if (storyPlaylist.length <= 0)
				{
					paused = true;

					if (FlxG.sound.music != null && FlxG.sound.music.playing)
						FlxG.sound.music.stop();
					if (vocals != null && vocals.playing)
						vocals.stop();
					if (Options.save.data.scoreScreen)
					{
						if (Options.save.data.timeBarType != 'Disabled')
						{
							FlxTween.tween(timeBar, {alpha: 0}, 1);
						}
						openSubState(new ResultsSubState());
						inResults = true;
					}
					else
					{
						cancelMusicFadeTween();
						FlxG.switchState(new StoryMenuState());
					}

					if (!PlayStateChangeables.practiceMode && !PlayStateChangeables.botPlay)
					{
						StoryMenuState.weekCompleted.set(Week.weekList[storyWeek], true);

						if (song.validScore)
						{
							Highscore.saveWeekScore(Week.getCurrentWeekId(), campaignScore, storyDifficulty);
						}

						EngineData.save.data.weekCompleted = StoryMenuState.weekCompleted;
						EngineData.flushSave();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = Difficulty.getDifficultyFilePath(storyDifficulty);

					Debug.logTrace('Loading next song: ${storyPlaylist[0]}$difficulty');

					var winterHorrorlandNext:Bool = song.id == 'eggnog';
					if (winterHorrorlandNext)
					{
						var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
							-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
						blackShit.scrollFactor.set();
						add(blackShit);
						camHUD.visible = false;

						FlxG.sound.play(Paths.getSound('Lights_Shut_Off'));
					}

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					song = Song.loadSong(storyPlaylist[0], difficulty);

					if (winterHorrorlandNext)
					{
						new FlxTimer().start(1.5, (tmr:FlxTimer) ->
						{
							cancelMusicFadeTween();
							LoadingState.loadAndSwitchState(new PlayState());
						});
					}
					else
					{
						cancelMusicFadeTween();
						LoadingState.loadAndSwitchState(new PlayState());
					}
				}
			}
			else
			{
				Debug.logTrace('Went back to Freeplay');
				cancelMusicFadeTween();

				if (Options.save.data.scoreScreen)
				{
					openSubState(new ResultsSubState());
					inResults = true;
				}
				else
				{
					FlxG.switchState(new FreeplayState());
					changedDifficulty = false;
				}
			}
			transitioning = true;
		}
	}

	#if FEATURE_ACHIEVEMENTS
	private function startAchievement(achieve:String):Void
	{
		achievement = new Achievement(achieve);
		achievement.onFinish = achievementEnd;
		achievement.cameras = [camOther];
		add(achievement);
	}

	private function achievementEnd():Void
	{
		achievement = null;
		if (endingSong && !inCutscene)
		{
			endSong();
		}
	}

	private function checkForAchievement(?achievesToCheck:Array<String>):String
	{
		if (achievesToCheck == null)
		{
			achievesToCheck = Achievement.achievementList;
		}

		if (chartingMode)
			return null;

		var usedPractice:Bool = (PlayStateChangeables.practiceMode || PlayStateChangeables.botPlay);
		for (achievementId in achievesToCheck)
		{
			if (!Achievement.isAchievementUnlocked(achievementId) && !PlayStateChangeables.botPlay)
			{
				var unlock:Bool = false;

				var achievementDef:AchievementDef = Achievement.achievementsLoaded.get(achievementId);

				if (isStoryMode
					&& campaignMisses + misses < 1
					&& Difficulty.difficultyString() == 'HARD'
					&& storyPlaylist.length <= 1
					&& !changedDifficulty
					&& !usedPractice)
				{
					var weekId:String = Week.getCurrentWeekId();
					if (achievementDef != null && achievementDef.unlocksAfter != null && achievementDef.unlocksAfter != ''
						&& achievementDef.unlocksAfter == weekId)
						unlock = true;
				}

				switch (achievementId)
				{
					case 'ur_bad':
						if (ratingPercent < 20 && !PlayStateChangeables.practiceMode)
						{
							unlock = true;
						}
					case 'ur_good':
						if (ratingPercent >= 100 && !usedPractice)
						{
							unlock = true;
						}
					case 'roadkill_enthusiast':
						if (Achievement.henchmenDeath >= 100)
						{
							unlock = true;
						}
					case 'oversinging':
						if (boyfriend.holdTimer >= 10 && !usedPractice)
						{
							unlock = true;
						}
					case 'hype':
						if (!boyfriendIdled && !usedPractice)
						{
							unlock = true;
						}
					case 'two_keys':
						if (!usedPractice)
						{
							var howManyPresses:Int = 0;
							for (keyPressed in keysPressed)
							{
								if (keyPressed)
									howManyPresses++;
							}

							if (howManyPresses <= 2)
							{
								unlock = true;
							}
						}
					case 'toastie':
						if (/*Options.save.data.frameRate <= 60 &&*/ PlayStateChangeables.optimize
							&& !Options.save.data.globalAntialiasing
							&& !Options.save.data.imagesPersist)
						{
							unlock = true;
						}
					case 'debugger':
						if (song.id == 'test' && !usedPractice)
						{
							unlock = true;
						}
				}

				if (unlock)
				{
					Achievement.unlockAchievement(achievementId);
					return achievementId;
				}
			}
		}
		return null;
	}
	#end

	public function killNotes():Void
	{
		for (note in notes)
		{
			note.kill();
			note.destroy();
		}
		notes.clear();
		FlxArrayUtil.clearArray(unspawnNotes);
		FlxArrayUtil.clearArray(events);
	}

	private function popUpScore(?note:Note):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + Options.save.data.ratingOffset);

		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(FlxG.width * 0.35, 0, 0, placement, 32);
		coolText.screenCenter(Y);

		var rating:FlxSprite = new FlxSprite();
		var scoreChange:Int = 350;

		// tryna do MS based judgment due to popular demand
		var ratingName:Judgement = Ratings.judgeNote(noteDiff);

		switch (ratingName)
		{
			case Judgement.SHIT:
				totalNotesHit += 0;
				note.ratingMod = 0;
				scoreChange = 50;
				if (!note.ratingDisabled)
					shits++;
			case Judgement.BAD:
				totalNotesHit += 0.5;
				note.ratingMod = 0.5;
				scoreChange = 100;
				if (!note.ratingDisabled)
					bads++;
			case Judgement.GOOD:
				totalNotesHit += 0.75;
				note.ratingMod = 0.75;
				scoreChange = 200;
				if (!note.ratingDisabled)
					goods++;
			case Judgement.SICK:
				totalNotesHit += 1;
				note.ratingMod = 1;
				if (!note.ratingDisabled)
					sicks++;
				if (!note.noteSplashDisabled)
					spawnNoteSplashOnNote(note);
		}
		note.rating = ratingName;

		// if (songMultiplier >= 1.05)
		// 	score = getRatesScore(songMultiplier, score);
		score += scoreChange;

		if (!note.ratingDisabled)
		{
			hits++;
			totalPlayed++;
			recalculateRating();
		}

		if (Options.save.data.scoreZoom)
		{
			if (scoreTxtTween != null)
			{
				scoreTxtTween.cancel();
			}
			scoreTxt.scale.x = 1.075;
			scoreTxt.scale.y = 1.075;
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: (twn:FlxTween) ->
				{
					scoreTxtTween = null;
				}
			});
		}

		var pixelSuffix:String = '';

		if (isPixelStage)
		{
			pixelSuffix = '-pixel';
		}

		rating.loadGraphic(Paths.getGraphic(Path.join(['ui/judgements', '$ratingName$pixelSuffix'])));
		rating.cameras = [camHUD];
		rating.screenCenter();
		rating.x = coolText.x - 40 + Options.save.data.comboOffset[0];
		rating.y -= 60 + Options.save.data.comboOffset[1];
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.visible = !Options.save.data.hideHud && showRating;

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui/combo', 'combo$pixelSuffix'])));
		comboSpr.cameras = [camHUD];
		comboSpr.screenCenter();
		comboSpr.x = coolText.x + Options.save.data.comboOffset[0];
		comboSpr.y -= Options.save.data.comboOffset[1];
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.x += FlxG.random.int(1, 10);
		comboSpr.velocity.y -= 150;
		comboSpr.visible = !Options.save.data.hideHud && showCombo;

		insert(members.indexOf(strumLineNotes), rating);

		if (isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * PIXEL_ZOOM * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * PIXEL_ZOOM * 0.85));
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = Options.save.data.globalAntialiasing;
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			comboSpr.antialiasing = Options.save.data.globalAntialiasing;
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		if (combo > highestCombo)
			highestCombo = combo;

		var separatedScore:Array<Int> = [for (i in placement.split('')) Std.parseInt(i)];

		for (i in 0...separatedScore.length)
		{
			var digit:Int = separatedScore[i];
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui/combo', 'num$digit$pixelSuffix'])));
			numScore.cameras = [camHUD];
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * i) - 90 + Options.save.data.comboOffset[2];
			numScore.y += 80 - Options.save.data.comboOffset[3];

			if (isPixelStage)
			{
				numScore.setGraphicSize(Std.int(numScore.width * PIXEL_ZOOM));
			}
			else
			{
				numScore.antialiasing = Options.save.data.globalAntialiasing;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);
			numScore.visible = !Options.save.data.hideHud;

			insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: (tween:FlxTween) ->
				{
					numScore.destroy();
				},
				startDelay: Conductor.crotchetLength * 0.002
			});
		}

		coolText.text = separatedScore.join('');

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crotchetLength * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: (tween:FlxTween) ->
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crotchetLength * 0.001
		});
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);

		if (!PlayStateChangeables.botPlay
			&& !paused
			&& key > -1
			&& (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || Options.save.data.controllerMode))
		{
			if (!boyfriend.stunned && generatedMusic && !endingSong)
			{
				// more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !Options.save.data.ghostTapping;

				// TODO Fix it even if it ain't broken
				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				var notesStopped:Bool = false;

				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive((note:Note) ->
				{
					if (note.canBeHit && note.mustPress && !note.tooLate && !note.wasGoodHit && !note.isSustainNote)
					{
						if (note.noteData == key)
						{
							sortedNotesList.push(note);
						}
						canMiss = true;
					}
				});
				// sortedNotesList.sort((a:Note, b:Note) -> Std.int(a.beat - b.beat));
				sortedNotesList.sort((a:Note, b:Note) -> Std.int(a.strumTime - b.strumTime));

				if (sortedNotesList.length > 0)
				{
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes)
						{
							// if (Math.abs(TimingStruct.getTimeFromBeat(doubleNote.beat) - TimingStruct.getTimeFromBeat(epicNote.beat)) < 1)
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1)
							{
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							}
							else
								notesStopped = true;
						}

						// eee jack detection before was not super good
						if (!notesStopped)
						{
							playerHitNote(epicNote);
							pressNotes.push(epicNote);
						}
					}
				}
				else if (canMiss)
				{
					ghostTap(key);
				}

				#if FEATURE_ACHIEVEMENTS
				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				keysPressed[key] = true;
				#end

				// more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if (spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}

			#if FEATURE_SCRIPTS
			callOnScripts('onKeyPress', [key]);
			#end
		}
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if (!PlayStateChangeables.botPlay && !paused && key > -1)
		{
			var spr:StrumNote = playerStrums.members[key];
			if (spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			#if FEATURE_SCRIPTS
			callOnScripts('onKeyRelease', [key]);
			#end
		}
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if (key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	private function handleNoteSustains():Void
	{
		// HOLDING
		var controlHoldArray:Array<Bool> = [controls.NOTE_LEFT, controls.NOTE_DOWN, controls.NOTE_UP, controls.NOTE_RIGHT];
		var controlPressArray:Array<Bool> = [
			controls.NOTE_LEFT_P,
			controls.NOTE_DOWN_P,
			controls.NOTE_UP_P,
			controls.NOTE_RIGHT_P
		];
		var controlReleaseArray:Array<Bool> = [
			controls.NOTE_LEFT_R,
			controls.NOTE_DOWN_R,
			controls.NOTE_UP_R,
			controls.NOTE_RIGHT_R
		];

		// TODO: Find a better way to handle controller inputs, this should work for now
		if (Options.save.data.controllerMode)
		{
			if (controlPressArray.contains(true))
			{
				for (i in 0...controlPressArray.length)
				{
					if (controlPressArray[i])
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}

		var anas:Array<Analytic> = [null, null, null, null];

		for (i in 0...controlPressArray.length)
			if (controlPressArray[i])
				anas[i] = new Analytic(Conductor.songPosition, null, false, Judgement.MISS, i);

		if (!boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			notes.forEachAlive((note:Note) ->
			{
				// hold note functions
				if (note.isSustainNote && controlHoldArray[note.noteData] && note.canBeHit && note.mustPress && !note.tooLate && !note.wasGoodHit)
				{
					playerHitNote(note);
				}
			});

			if (controlHoldArray.contains(true) && !endingSong)
			{
				#if FEATURE_ACHIEVEMENTS
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null)
				{
					startAchievement(achieve);
				}
				#end
			}
			else if (boyfriend.holdTimer > Conductor.semiquaverLength * 0.001 * boyfriend.singDuration
				&& boyfriend.animation.curAnim.name.startsWith('sing')
				&& !boyfriend.animation.curAnim.name.endsWith('miss'))
			{
				boyfriend.dance();
			}
		}

		// TODO: Find a better way to handle controller inputs, this should work for now
		if (Options.save.data.controllerMode)
		{
			if (controlReleaseArray.contains(true))
			{
				for (i in 0...controlReleaseArray.length)
				{
					if (controlReleaseArray[i])
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}

			if (!loadRep)
				for (i in anas)
					if (i != null)
						replayAna.anaArray.push(i); // put em all there
		}
	}

	public function findByTime(time:Float):Array<Any>
	{
		for (i in rep.replay.songNotes)
		{
			if (i[0] == time)
				return i;
		}
		return null;
	}

	public function findByTimeIndex(time:Float):Int
	{
		for (i in 0...rep.replay.songNotes.length)
		{
			if (rep.replay.songNotes[i][0] == time)
				return i;
		}
		return -1;
	}

	// TODO Optimize this so it doesn't lag the fuck out of Polymod
	private function playerHitNote(note:Note):Void
	{
		var noteDiff:Float = Conductor.songPosition - note.strumTime;

		if (loadRep)
		{
			noteDiff = findByTime(note.strumTime)[3];
			note.rating = rep.replay.songJudgements[findByTimeIndex(note.strumTime)];
		}
		else
			note.rating = Ratings.judgeNote(noteDiff);

		// add newest note to front of notesHitArray
		// the oldest notes are at the end and are removed first
		if (!note.isSustainNote)
			notesHitArray.unshift(Date.now());

		if (!note.wasGoodHit)
		{
			if (Options.save.data.hitsoundVolume > 0 && !note.hitsoundDisabled)
			{
				FlxG.sound.play(Paths.getSound('hitsound'), Options.save.data.hitsoundVolume);
			}

			if (PlayStateChangeables.botPlay && (note.ignoreNote || note.hitCausesMiss))
				return;

			if (!loadRep && note.mustPress)
			{
				var array:Array<Any> = [note.strumTime, note.sustainLength, note.noteData, noteDiff];
				if (note.isSustainNote)
					array[1] = -1;
				saveNotes.push(array);
				saveJudge.push(note.rating);
			}

			if (note.hitCausesMiss)
			{
				playerMissNote(note);
				if (!note.noteSplashDisabled && !note.isSustainNote)
				{
					spawnNoteSplashOnNote(note);
				}

				switch (note.noteType)
				{
					case 'Hurt Note': // Hurt note
						if (boyfriend.animation.getByName('hurt') != null)
						{
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
				}

				note.wasGoodHit = true;
				if (!note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote)
			{
				combo += 1;
				popUpScore(note);
			}
			health += note.hitHealth * PlayStateChangeables.healthGain;

			if (!note.noAnimation)
			{
				var animToPlay:String = 'sing${NoteKey.createByIndex(note.noteData)}';
				if (note.animSuffix != null && note.animSuffix.length > 0)
				{
					animToPlay += note.animSuffix;
				}

				if (note.gfNote)
				{
					if (gf != null)
					{
						gf.playAnim(animToPlay, true);
						gf.holdTimer = 0;
						updateDirectionalCamera();
					}
				}
				else
				{
					boyfriend.playAnim(animToPlay, true);
					boyfriend.holdTimer = 0;
					updateDirectionalCamera();
				}

				if (note.noteType == 'Hey!')
				{
					if (boyfriend.animation.exists('hey'))
					{
						boyfriend.playAnim('hey', true);
						boyfriend.specialAnim = true;
						boyfriend.heyTimer = 0.6;
					}

					if (gf != null && gf.animation.exists('cheer'))
					{
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = 0.6;
					}
				}
			}

			if (PlayStateChangeables.botPlay)
			{
				var time:Float = 0.15;
				if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
				{
					time += 0.15;
				}
				strumPlayAnim(false, note.noteDataModulo, time);
			}
			else
			{
				playerStrums.forEach((spr:StrumNote) ->
				{
					if (note.noteData == spr.ID)
					{
						spr.playAnim('confirm', true);
					}
				});
			}
			note.wasGoodHit = true;
			vocals.volume = 1;

			#if FEATURE_SCRIPTS
			callOnScripts('goodNoteHit', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
			#end

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	private function playerMissNote(missedNote:Note):Void
	{ // You didn't hit the key and let it go offscreen, also used by Hurt Notes
		// Dupe note remove
		notes.forEachAlive((note:Note) ->
		{
			if (missedNote != note
				&& missedNote.mustPress
				&& missedNote.noteData == note.noteData
				&& missedNote.isSustainNote == note.isSustainNote
				&& Math.abs(missedNote.strumTime - note.strumTime) < 1)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		combo = 0;

		health -= missedNote.missHealth * PlayStateChangeables.healthLoss;
		if (PlayStateChangeables.instakillOnMiss)
		{
			doDeathCheck(true);
		}

		var direction:Int = missedNote.noteData;

		if (!loadRep)
		{
			saveNotes.push([
				missedNote.strumTime,
				0,
				direction,
				-(166 * Math.floor((rep.replay.sf / TimingConstants.SECONDS_PER_MINUTE) * TimingConstants.MILLISECONDS_PER_SECOND) / 166)
			]);
			saveJudge.push(Judgement.MISS);
		}

		misses++;
		vocals.volume = 0;
		if (!PlayStateChangeables.practiceMode)
			score -= 10;

		totalPlayed++;
		recalculateRating();

		var char:Character = boyfriend;
		if (missedNote.gfNote)
		{
			char = gf;
		}

		if (char != null && char.hasMissAnimations)
		{
			var animToPlay:String = 'sing${NoteKey.createByIndex(missedNote.noteData)}miss';
			if (missedNote.animSuffix != null && missedNote.animSuffix.length > 0)
			{
				animToPlay += missedNote.animSuffix;
			}
			char.playAnim(animToPlay, true);
			updateDirectionalCamera();
		}

		#if FEATURE_SCRIPTS
		callOnScripts('noteMiss', [
			notes.members.indexOf(missedNote),
			missedNote.noteData,
			missedNote.noteType,
			missedNote.isSustainNote
		]);
		#end
	}

	private function ghostTap(key:Int):Void // You pressed a key when there was no notes to press for this key
	{
		if (!boyfriend.stunned)
		{
			if (Options.save.data.ghostTapping)
				return;

			health -= 0.05 * PlayStateChangeables.healthLoss;
			if (PlayStateChangeables.instakillOnMiss)
			{
				doDeathCheck(true);
			}

			if (combo > 5 && gf != null && gf.animation.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			if (!PlayStateChangeables.practiceMode)
				score -= 10;
			if (!endingSong)
			{
				misses++;
			}
			totalPlayed++;
			recalculateRating();

			var soundToPlay:String = isPixelStage ? 'missnote-pixel' : 'missnote';
			FlxG.sound.play(Paths.getRandomSound(soundToPlay, 1, 3), FlxG.random.float(0.1, 0.2));

			if (boyfriend.hasMissAnimations)
			{
				boyfriend.playAnim('sing${NoteKey.createByIndex(key)}miss', true);
				updateDirectionalCamera();
			}
			vocals.volume = 0;

			#if FEATURE_SCRIPTS
			callOnScripts('noteMissPress', [key]);
			#end
		}
	}

	private function opponentHitNote(note:Note):Void
	{
		if (song.id != 'tutorial')
			camZooming = true;

		if (note.noteType == 'Hey!' && opponent.animation.exists('hey'))
		{
			opponent.playAnim('hey', true);
			opponent.specialAnim = true;
			opponent.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
			if (currentSection != null)
			{
				if (currentSection.altAnim && (note.animSuffix == null || note.animSuffix.length <= 0))
				{
					note.animSuffix = '-alt';
				}
			}

			var char:Character = opponent;
			var animToPlay:String = 'sing${NoteKey.createByIndex(note.noteData)}';
			if (note.animSuffix != null && note.animSuffix.length > 0)
			{
				animToPlay += note.animSuffix;
			}

			if (note.gfNote)
			{
				char = gf;
			}

			if (char != null)
			{
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
				updateDirectionalCamera();
			}
		}

		if (song.needsVoices)
			vocals.volume = 1;

		var time:Float = 0.15;
		if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
		{
			time += 0.15;
		}
		strumPlayAnim(true, note.noteDataModulo, time);
		note.hitByOpponent = true;

		#if FEATURE_SCRIPTS
		callOnScripts('opponentNoteHit', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
		#end

		if (!note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	private function spawnNoteSplashOnNote(note:Note):Void
	{
		if (Options.save.data.noteSplashes && note != null)
		{
			var strum:StrumNote = playerStrums.members[note.noteData];
			if (strum != null)
			{
				spawnNoteSplash(strum.x, strum.y, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, note:Note):Void
	{
		var skin:String = note.noteSplashTexture;
		var hue:Float = note.noteSplashHue;
		var sat:Float = note.noteSplashSat;
		var brt:Float = note.noteSplashBrt;

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, note.noteData, skin, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	public static function cancelMusicFadeTween():Void
	{
		if (FlxG.sound.music.fadeTween != null)
		{
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	public function updateFocusedCharacter():Void
	{
		if (currentSection.mustHitSection)
		{
			if (turn != 'bf')
			{
				turn = 'bf';
				if (Options.save.data.cameraFocus == 0)
					focus = 'bf';
			}
		}
		else
		{
			if (turn != 'dad')
			{
				turn = 'dad';
				if (Options.save.data.cameraFocus == 0)
					focus = 'dad';
			}
		}
	}

	public function updateDirectionalCamera():Void
	{
		if (Options.save.data.camFollowsAnims)
		{
			// Reset the directional camera
			camFollow.set(camFollowNoDirectional.x, camFollowNoDirectional.y);

			var focusedChar:Null<Character> = null;
			switch (focus)
			{
				case 'dad':
					focusedChar = opponent;
				case 'bf':
					focusedChar = boyfriend;
				case 'gf':
					focusedChar = gf;
				case 'center':
					focusedChar = null;
			}
			if (focusedChar != null)
			{
				if (focusedChar.animation.curAnim != null)
				{
					switch (focusedChar.animation.curAnim.name)
					{
						case 'singUP' | 'singUP-alt' | 'singUPmiss':
							camFollow.y -= 20 * focusedChar.cameraMotionFactor;
						case 'singDOWN' | 'singDOWN-alt' | 'singDOWNmiss':
							camFollow.y += 20 * focusedChar.cameraMotionFactor;
						case 'singLEFT' | 'singLEFT-alt' | 'singLEFTmiss':
							camFollow.x -= 20 * focusedChar.cameraMotionFactor;
						case 'singRIGHT' | 'singRIGHT-alt' | 'singRIGHTmiss':
							camFollow.x += 20 * focusedChar.cameraMotionFactor;
					}
				}
			}
		}
	}

	#if FEATURE_SCRIPTS
	public function callOnScripts(event:String, args:Array<Any>, ignoreStops:Bool = true, ?exclusions:Array<String>):Any
	{
		var returnVal:Any = FunkinScript.FUNCTION_CONTINUE;
		for (script in scriptArray)
		{
			if (exclusions != null && exclusions.contains(script.scriptName))
			{
				continue;
			}

			var ret:Any = script.call(event, args);
			if (ret == FunkinScript.FUNCTION_STOP_LUA && !ignoreStops)
			{
				break;
			}

			if (ret != FunkinScript.FUNCTION_CONTINUE)
			{
				returnVal = ret;
			}
		}

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Any):Void
	{
		for (script in scriptArray)
		{
			script.set(variable, arg);
		}
	}
	#end

	private function strumPlayAnim(isDad:Bool, id:Int, time:Float):Void
	{
		var spr:StrumNote;
		if (isDad)
		{
			spr = strumLineNotes.members[id];
		}
		else
		{
			spr = playerStrums.members[id];
		}

		if (spr != null)
		{
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public function recalculateRating():Void
	{
		#if FEATURE_SCRIPTS
		setOnScripts('score', score);
		setOnScripts('misses', misses);
		setOnScripts('hits', hits);

		var ret:Any = callOnScripts('onRecalculateRating', [], false);
		if (ret != FunkinScript.FUNCTION_STOP)
		#end
		{
			if (totalPlayed < 1) // Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(100, Math.max(0, totalNotesHit / totalPlayed * 100));
				ratingPercentDefault = Math.min(100, Math.max(0, totalNotesHitDefault / totalPlayed * 100));

				// Rating Name
				ratingName = Ratings.generateGrade(ratingPercent);
			}

			// Rating FC
			ratingFC = Ratings.generateComboRank();

			scoreTxt.text = Ratings.calculateRanking(score, scoreDefault, nps, maxNPS, ratingPercent);
			judgementCounter.text = 'Sicks: ${sicks}\nGoods: ${goods}\nBads: ${bads}\nShits: ${shits}\nMisses: ${misses}\n';
		}

		#if FEATURE_SCRIPTS
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		#end
	}

	public function getSectionByTime(ms:Float):Section
	{
		for (section in song.notes)
		{
			var startTime:Float = section.startTime;
			var endTime:Float = section.endTime;

			if (ms >= startTime && ms < endTime)
			{
				return section;
			}
		}

		return null;
	}

	public function getSectionByBeat(beat:Float):Section
	{
		for (section in song.notes)
		{
			var startBeat:Float = section.startBeat;
			var endBeat:Float = section.endBeat;

			if (beat >= startBeat && beat < endBeat)
			{
				return section;
			}
		}

		return null;
	}

	private function updatePlaybackSpeed():Void
	{
		#if cpp
		// TODO Figure out whether there is a better way to change audio playback speed
		// (As in, a way which does not involve accessing private variables)
		if (FlxG.sound.music.playing)
		{
			@:privateAccess
			{
				lime.media.openal.AL.sourcef(FlxG.sound.music._channel.__source.__backend.handle, lime.media.openal.AL.PITCH, songMultiplier);
				if (vocals.playing)
					lime.media.openal.AL.sourcef(vocals._channel.__source.__backend.handle, lime.media.openal.AL.PITCH, songMultiplier);
			}
		}
		#end
	}

	private function set_songSpeed(value:Float):Float
	{
		if (songSpeed != value)
		{
			if (generatedMusic)
			{
				var ratio:Float = value / songSpeed;
				for (note in notes)
				{
					if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
					{
						note.scale.y *= ratio;
						note.updateHitbox();
					}
				}
				for (note in unspawnNotes)
				{
					if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
					{
						note.scale.y *= ratio;
						note.updateHitbox();
					}
				}
			}
			songSpeed = value;
			noteKillOffset = 350 / songSpeed;
		}
		return value;
	}
}
