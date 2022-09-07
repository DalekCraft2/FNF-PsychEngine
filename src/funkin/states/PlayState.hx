package funkin.states;

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
import funkin.Character.CharacterRole;
import funkin.Character.CharacterRoleTools;
import funkin.DialogueBoxPsych.DialogueDef;
import funkin.Ratings.Judgement;
import funkin.Replay.Analysis;
import funkin.Replay.Analytic;
import funkin.chart.container.Bar;
import funkin.chart.container.Event;
import funkin.chart.container.Song;
import funkin.states.editors.CharacterEditorState;
import funkin.states.editors.ChartEditorState;
import funkin.states.substates.GameOverSubState;
import funkin.states.substates.PauseSubState;
import funkin.states.substates.ResultsSubState;
import funkin.ui.HealthBar;
import funkin.ui.TimeBar;
import funkin.util.CoolUtil;
import haxe.io.Path;
import openfl.events.KeyboardEvent;

using StringTools;

#if FEATURE_ACHIEVEMENTS
import funkin.Achievement.AchievementDef;
#end
#if FEATURE_DISCORD
import funkin.Discord.DiscordClient;
#end
#if FEATURE_SCRIPTS
import funkin.FunkinScript.DebugScriptText;
import funkin.FunkinScript.ScriptSprite;
import funkin.FunkinScript.ScriptText;
#end
#if FEATURE_STEPMANIA
import funkin.sm.SMFile;
#end

// Dear god, Dalek, calm down with the to-do comments.
// TODO Make the input system much less pathetically easy and cheesable
// (An example of it is being able to hit any incoming hold notes by just pressing the keys early, missing the first note, and getting the rest of the hold anyway)
// TODO Abuse the fuck out of multithreading to make the game run faster
// TODO Use Flixel utilities as often as possible to clean up code (I.E. perhaps I could use something like LinearMotion or FlxPath for note sprites)
// TODO Try not to get option data directly from the Options class, because that could screw up gameplay if changed during the song
class PlayState extends MusicBeatState
{
	// Constants
	public static inline final STRUM_X:Float = 42;
	public static inline final STRUM_X_MIDDLESCROLL:Float = -278;

	/**
	 * How many milliseconds late/early the Conductor must be relative to song.inst.time in order for resyncVocals() to be called.
	 */
	public static inline final RESYNC_THRESHOLD:Float = 20;

	/**
	 * The scale factor for the pixel art assets.
	 */
	public static inline final PIXEL_ZOOM:Float = 6;

	/**
	 * The active PlayState instance.
	 */
	public static var instance:PlayState;

	// Song variables
	public static var song:Song;

	// TODO Get rid of these variables after making the StepMania conversion function return a Song struct
	public static var isSM:Bool = false;
	#if FEATURE_STEPMANIA
	public static var sm:SMFile;
	public static var pathToSm:String;
	#end

	/**
	 * The scroll speed of the notes.
	 */
	public var scrollSpeed(default, set):Float = 1;

	public var scrollSpeedTween:FlxTween;
	public var noteKillOffset:Float = 350; // Arguably a Strum/Note variable
	public var startingSong:Bool = false;
	public var endingSong:Bool = false;

	// Audio variables

	/**
	 * The playback speed factor for the audio.
	 */
	// TODO Finish implementing this
	public static var songMultiplier:Float = 1;

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
	public var boyfriend:PlayableCharacter;
	public var opponent:Character;
	public var gf:Character;
	public var boyfriendMap:Map<String, PlayableCharacter> = [];
	public var opponentMap:Map<String, Character> = [];
	public var gfMap:Map<String, Character> = [];
	public var boyfriendGroup:FlxSpriteGroup;
	public var opponentGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
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
	public var camZooming:Bool = true;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	public var defaultCamZoom:Float = 1.05;
	public var camDirectional:Bool = true;

	public var boyfriendCameraOffset:FlxPoint; // These three are arguably Character variables
	public var opponentCameraOffset:FlxPoint;
	public var girlfriendCameraOffset:FlxPoint;

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

	// Pico variables
	public static final PHILLY_LIGHTS_COLORS:Array<FlxColor> = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];

	private var curLightEvent:Int = -1;

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Array<FlxKey>>;

	// Misc.
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var inResults:Bool = false;

	public var transitioning:Bool = false;
	public var canReset:Bool = true;

	private var focus:CharacterRole;

	override public function create():Void
	{
		// super.create(); // The super call is at the bottom of the method

		instance = this;

		FlxG.mouse.visible = false;

		if (startTime == 0) // This is so there is time for the transition to finish before the song starts, if the start time is not the default
		{
			persistentUpdate = true;
		}

		debugKeysChart = Options.copyKey(Options.profile.keyBinds.get('debug_1'));
		debugKeysCharacter = Options.copyKey(Options.profile.keyBinds.get('debug_2'));
		PauseSubState.songName = null; // Reset to default

		keysArray = [
			Options.copyKey(Options.profile.keyBinds.get('note_left')),
			Options.copyKey(Options.profile.keyBinds.get('note_down')),
			Options.copyKey(Options.profile.keyBinds.get('note_up')),
			Options.copyKey(Options.profile.keyBinds.get('note_right'))
		];

		#if FEATURE_ACHIEVEMENTS
		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}
		#end

		if (song.inst != null)
			song.inst.stop();

		// TODO Make a method to automatically reset the static variables
		highestCombo = 0;

		PlayStateChangeables.healthGain = Options.profile.healthGain;
		PlayStateChangeables.healthLoss = Options.profile.healthLoss;
		PlayStateChangeables.instakillOnMiss = Options.profile.instakillOnMiss;
		PlayStateChangeables.useDownscroll = Options.profile.downScroll;
		PlayStateChangeables.safeFrames = Options.profile.safeFrames;
		PlayStateChangeables.scrollSpeed = Options.profile.scrollSpeed * songMultiplier;
		PlayStateChangeables.scrollType = Options.profile.scrollType;
		PlayStateChangeables.practiceMode = Options.profile.practiceMode;
		PlayStateChangeables.botPlay = Options.profile.botPlay;
		PlayStateChangeables.optimize = Options.profile.lowQuality;

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
		defaultCamZoom = stage.cameraZoom;
		isPixelStage = stage.isPixelStage;
		for (background in stage.backgrounds)
		{
			add(background);
		}
		cameraSpeed = stage.cameraSpeed;
		boyfriendCameraOffset = stage.playerCameraOffset;
		opponentCameraOffset = stage.opponentCameraOffset;
		girlfriendCameraOffset = stage.gfCameraOffset;
		boyfriendGroup = new FlxSpriteGroup(stage.playerPosition.x, stage.playerPosition.y);
		opponentGroup = new FlxSpriteGroup(stage.opponentPosition.x, stage.opponentPosition.y);
		gfGroup = new FlxSpriteGroup(stage.gfPosition.x, stage.gfPosition.y);
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

		if (Options.profile.loadScripts)
		{
			// "GLOBAL" SCRIPTS
			var scriptList:Array<String> = [];
			var scriptsLoaded:Map<String, Bool> = [];

			var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

			for (directory in directories)
			{
				var scriptDirectory:String = Path.join([directory, 'data', 'scripts']);
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
						var tankmanRun:FlxTypedGroup<TankmenBG> = cast stage.groups['tankmanRun'];

						tankmanRun.add(tempTankman);
						for (animationNote in TankmenBG.animationNotes)
						{
							if (FlxG.random.bool(16))
							{
								var tankman:TankmenBG = tankmanRun.recycle(TankmenBG);

								tankman.strumTime = song.getTimeFromBeat(animationNote.beat);
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
			boyfriend = new PlayableCharacter(0, 0, song.player1);
			startCharacterPos(boyfriend);
			boyfriendGroup.add(boyfriend);
			#if FEATURE_SCRIPTS
			startCharacterScript(boyfriend.id);
			#end
		}
		var camPos:FlxPoint = girlfriendCameraOffset;

		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition.x;
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition.y;
		}
		// if (gf != null && opponent.id == gf.id) // For Tutorial and any other songs which use GF as the opponent
		if (opponent.id.startsWith('gf'))
		{
			opponent.setPosition(gfGroup.x, gfGroup.y);
			if (gf != null)
				gf.visible = false;
		}
		if (Options.profile.noChars)
		{
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
			doof = new DialogueBox(song.id, dialogue);
			doof.scrollFactor.set();
			doof.finishThing = startCountdown;
		}

		if (!isStoryMode)
		{
			var firstNoteTime:Float = Math.POSITIVE_INFINITY;
			var playerTurn:Bool = false;
			for (index => bar in song.bars)
			{
				if (bar.notes.length > 0 && !isSM)
				{
					if (bar.startTime > 5000)
					{
						needSkip = true;
						skipTo = bar.startTime - 1000;
					}
					break;
				}
				else if (isSM)
				{
					for (note in bar.notes)
					{
						var strumTime:Float = Conductor.getTimeFromBeat(note.beat);
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
					if (index + 1 == song.bars.length)
					{
						var timing:Float = ((!playerTurn && !PlayStateChangeables.optimize) ? firstNoteTime : Conductor.getTimeFromBeat(Conductor.getBeatFromTime(firstNoteTime)
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

		strumLine = new FlxSprite(Options.profile.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X,
			PlayStateChangeables.useDownscroll ? FlxG.height - 150 : 50).makeGraphic(FlxG.width, 10);
		strumLine.scrollFactor.set();
		var showTime:Bool = Options.profile.timeBarType != 'Disabled';

		updateTime = showTime;
		timeBar = new TimeBar(0, PlayStateChangeables.useDownscroll ? FlxG.height - 44 : 19, song.name, this, 'songPercent');
		timeBar.screenCenter(X);
		timeBar.scrollFactor.set();
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		strumLineNotes = new FlxTypedGroup();
		add(strumLineNotes);
		add(grpNoteSplashes);
		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		splash.alpha = 0.0;
		grpNoteSplashes.add(splash);
		opponentStrums = new FlxTypedGroup();
		playerStrums = new FlxTypedGroup();
		generateSong();
		if (song.id == 'tutorial')
			camZooming = false;
		#if FEATURE_SCRIPTS
		if (Options.profile.loadScripts)
		{
			for (noteType in noteTypeMap.keys())
			{
				var scriptPath:String = Paths.script(Path.join(['note_types', noteType]));
				if (Paths.exists(scriptPath))
				{
					scriptArray.push(new FunkinScript(scriptPath));
				}
			}
		}
		if (Options.profile.loadScripts)
		{
			for (eventType in eventPushedMap.keys())
			{
				var scriptPath:String = Paths.script(Path.join(['event_types', eventType]));
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
		camFollow = FlxPoint.get();
		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowNoDirectional = FlxPoint.get();
		snapCamFollowToPos(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow.copyFrom(prevCamFollow);
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null)
		{
			camFollowPos.setPosition(prevCamFollowPos.x, prevCamFollowPos.y);
			prevCamFollowPos = null;
		}
		camFollowNoDirectional.copyFrom(camFollow);
		add(camFollowPos);
		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);
		// FlxG.camera.snapToTarget(); // Snaps the camera to camFollowPos (IT DOESN'T; FIX THIS)
		// FlxG.fixedTimestep = false;
		updateFocusedCharacter(song.bars[0]);
		moveCameraBar(song.bars[0]);
		// HealthBar
		healthBar = new HealthBar(0, PlayStateChangeables.useDownscroll ? FlxG.height * (1 - 0.89) : FlxG.height * 0.89, boyfriend.healthIcon,
			opponent.healthIcon, this, 'health');
		healthBar.screenCenter(X);
		healthBar.scrollFactor.set();
		healthBar.visible = !Options.profile.hideHUD;
		healthBar.alpha = Options.profile.healthBarAlpha;
		reloadHealthBarColors();
		add(healthBar);
		scoreTxt = new FlxText(0, healthBar.y + 36, FlxG.width, 20);
		scoreTxt.setFormat(Paths.font('vcr.ttf'), scoreTxt.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !Options.profile.hideHUD;
		add(scoreTxt);
		judgementCounter = new FlxText(20, 0, 0, 'Sicks: ${sicks}\nGoods: ${goods}\nBads: ${bads}\nShits: ${shits}\nMisses: ${misses}\n', 20);
		judgementCounter.setFormat(Paths.font('vcr.ttf'), judgementCounter.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		judgementCounter.borderSize = 2;
		judgementCounter.borderQuality = 2;
		judgementCounter.scrollFactor.set();
		judgementCounter.cameras = [camHUD];
		judgementCounter.screenCenter(Y);
		if (Options.profile.showCounters)
		{
			add(judgementCounter);
		}
		botplayTxt = new FlxText(400, PlayStateChangeables.useDownscroll ? timeBar.y - 78 : timeBar.y + 55, FlxG.width - 800, 'BOTPLAY', 32);
		botplayTxt.setFormat(Paths.font('vcr.ttf'), botplayTxt.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = PlayStateChangeables.botPlay;
		add(botplayTxt);
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
		if (Options.profile.loadScripts)
		{
			// SONG SPECIFIC SCRIPTS
			var scriptList:Array<String> = [];
			var scriptsLoaded:Map<String, Bool> = [];

			var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

			for (directory in directories)
			{
				var scriptDirectory:String = Path.join([directory, 'data', 'songs', song.id]);
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

					// FIXME Because I made beatHit() get called before the song starts, these get overridden by dance()
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
				// case 'ugh':
				// 	startVideo('ughCutscene');
				// case 'guns':
				// 	startVideo('gunsCutscene');
				// case 'stress':
				// 	startVideo('stressCutscene');
				case 'ugh' | 'guns' | 'stress':
					tankIntro();
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
		if (Options.profile.hitSoundVolume > 0)
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
		else if (Options.profile.pauseMusic != 'None')
		{
			Paths.precacheMusic(Paths.formatToSongPath(Options.profile.pauseMusic));
		}
		#if FEATURE_DISCORD
		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char);
		#end
		if (!Options.profile.controllerMode)
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

		#if FEATURE_SCRIPTS
		callOnScripts('onUpdate', [elapsed]);
		#end

		if (!Options.profile.noStage)
			stage.update(elapsed);

		#if FEATURE_SCRIPTS
		setOnScripts('curDecimalBeat', curDecimalBeat);
		setOnScripts('curDecimalStep', curDecimalStep);
		#end

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

		if (!inCutscene)
		{
			var lerpVal:Float = FlxMath.bound(elapsed * 2.4 * cameraSpeed, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			#if FEATURE_ACHIEVEMENTS
			if (!startingSong && !endingSong && boyfriend.animation.name.startsWith('idle'))
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
			song.inst.pause();
			song.vocals.pause();
			Conductor.songPosition = skipTo;
			Conductor.rawPosition = skipTo;

			song.inst.time = Conductor.songPosition;
			song.inst.play();

			song.vocals.time = Conductor.songPosition;
			song.vocals.play();
			FlxTween.tween(skipText, {alpha: 0}, 0.2, {
				onComplete: (tw:FlxTween) ->
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
			Conductor.rawPosition = song.inst.time;

			if (!paused)
			{
				if (updateTime)
				{
					var curTime:Float = (Conductor.songPosition - Options.profile.noteOffset) / songMultiplier;
					if (curTime < 0)
						curTime = 0;
					songPercent = curTime / songLength;

					var songCalc:Float = songLength - curTime;
					if (Options.profile.timeBarType == 'Time Elapsed')
						songCalc = curTime;

					var secondsTotal:Int = Math.floor(songCalc / TimingConstants.MILLISECONDS_PER_SECOND);
					if (secondsTotal < 0)
						secondsTotal = 0;

					if (Options.profile.timeBarType != 'Song Name')
						timeBar.text.text = FlxStringUtil.formatTime(secondsTotal, false);
				}
			}
		}

		if (camZooming && !startingSong && !endingSong)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, FlxMath.bound(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, FlxMath.bound(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
		}

		// RESET = Quick Game Over Screen
		if (controls.RESET && Options.profile.resetKey && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			Debug.logTrace('Reset key killed BF'); // Listen, I don't know how to frickin' word this.
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = 3000; // shit be weird on 4:3
			// var time:Float = 14000; // Kade uses this value instead; I have no idea what the significance of this variable is
			if (scrollSpeed < 1)
				time /= scrollSpeed;

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
				else if (boyfriend.holdTimer > Conductor.stepLength * 0.0011 * boyfriend.singDuration
					&& boyfriend.animation.name.startsWith('sing')
					&& !boyfriend.animation.name.endsWith('miss'))
				{
					boyfriend.dance();
				}
			}

			if (startedCountdown) // This must be checked to ensure that the strum groups are not empty
			{
				var beatLength:Float = Conductor.calculateBeatLength(song.tempo);
				// var beatLength:Float = Conductor.beatLength;
				notes.forEachAlive((note:Note) ->
				{
					// var beatLength:Float = Conductor.calculateBeatLength(song.getTimingAtBeat(note.beat).tempo);

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
						note.distance = 0.45 * (Conductor.songPosition - note.strumTime) / songMultiplier * scrollSpeed;
					}
					else // Upscroll
					{
						note.distance = -0.45 * (Conductor.songPosition - note.strumTime) / songMultiplier * scrollSpeed;
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
						// The FlxSprite Y field is a property so I made a variable in order to only set it once
						var y:Float = strumY + Math.sin(angleDir) * note.distance;

						// Jesus fuck this took me so much mother fucking time AAAAAAAAAA
						// TODO Can we, uh, please have some constants so we know what we are looking at?
						if (strumDownScroll && note.isSustainNote)
						{
							if (note.animation.name.endsWith('end'))
							{
								y += 10.5 * (beatLength / 400) * 1.5 * scrollSpeed;
								y -= 46 * ((1 - beatLength / 600) * scrollSpeed - (scrollSpeed - 1));
								if (isPixelStage)
								{
									y += 8 + (6 - note.originalHeightForCalcs) * PIXEL_ZOOM;
								}
								else
								{
									y -= 19;
								}
							}
							y += (Note.STRUM_WIDTH / 2) - (60.5 * (scrollSpeed - 1));
							y += 27.5 * ((song.tempo / 100) - 1) * (scrollSpeed - 1);
						}
						note.y = y;
					}

					// TODO Maybe make a function for the opponent "missing" a note, for scripts
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
					// if (Conductor.songPosition > noteKillOffset + Conductor.getTimeFromBeat(note.beat))
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

		if (song.inst.playing)
		{
			var timingSeg:TimingSegment = Conductor.getTimingAtBeat(curDecimalBeat);

			if (timingSeg != null)
			{
				var timingSegTempo:Float = timingSeg.tempo;

				if (timingSegTempo != Conductor.tempo)
				{
					Conductor.tempo = timingSegTempo;
					Conductor.beatLength /= songMultiplier;

					#if FEATURE_SCRIPTS
					setOnScripts('curTempo', Conductor.tempo);
					setOnScripts('beatLength', Conductor.beatLength);
					setOnScripts('stepLength', Conductor.stepLength);
					#end
				}
			}
		}

		checkEvent();

		updateDirectionalCamera(); // After the event check because the Play Animation event exists

		#if debug
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				killNotes();
				song.inst.onComplete();
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

		Debug.quickWatch('Scroll Speed', scrollSpeed);
	}

	override public function openSubState(subState:FlxSubState):Void
	{
		super.openSubState(subState);

		subState.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]]; // This is so it doesn't use camGame

		if (paused)
		{
			if (song.inst != null && song.inst.playing)
				song.inst.pause();
			if (song.vocals != null && song.vocals.playing)
				song.vocals.pause();

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (scrollSpeedTween != null)
				scrollSpeedTween.active = false;

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

		if (!Options.profile.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		FlxG.cameras.reset();

		Conductor.song = null;

		instance = null;
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();

		if (startedCountdown)
		{
			pause();
		}
	}

	override public function onFocus():Void
	{
		super.onFocus();

		#if FEATURE_DISCORD
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0)
			{
				var endTimestamp:Float = FlxMath.bound(songLength - Conductor.songPosition - Options.profile.noteOffset, 0);
				DiscordClient.changePresence(detailsText, '${song.name} ($storyDifficultyText)', healthBar.iconP2.char, true, endTimestamp);
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

		if (!Options.profile.noStage)
			stage.stepHit(step);

		if (song.inst != null && !startingSong && !endingSong)
		{
			// if (Math.abs(song.inst.time - (Conductor.rawPosition - Conductor.offset)) > RESYNC_THRESHOLD
			// 	|| (song.needsVoices && Math.abs(song.vocals.time - (Conductor.rawPosition - Conductor.offset)) > RESYNC_THRESHOLD))
			if (Math.abs(song.inst.time - (Conductor.songPosition - Conductor.offset)) > RESYNC_THRESHOLD
				|| (song.needsVoices && Math.abs(song.vocals.time - (Conductor.songPosition - Conductor.offset)) > RESYNC_THRESHOLD))
			{
				resyncVocals();
			}
		}

		#if FEATURE_SCRIPTS
		setOnScripts('curStep', step);
		callOnScripts('onStepHit', [step]);
		#end
	}

	override public function beatHit(beat:Int):Void
	{
		super.beatHit(beat);

		if (!Options.profile.noStage)
			stage.beatHit(beat);

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, PlayStateChangeables.useDownscroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		healthBar.beatHit(beat);

		if (gf != null
			&& beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0
			&& !gf.stunned
			&& gf.animation.curAnim != null
			&& !gf.animation.name.startsWith('sing')
			&& !gf.stunned)
		{
			gf.dance();
		}
		if (beat % boyfriend.danceEveryNumBeats == 0
			&& boyfriend.animation.curAnim != null
			&& !boyfriend.animation.name.startsWith('sing')
			&& !boyfriend.stunned)
		{
			boyfriend.dance();
		}
		if (beat % opponent.danceEveryNumBeats == 0
			&& opponent.animation.curAnim != null
			&& !opponent.animation.name.startsWith('sing')
			&& !opponent.stunned)
		{
			opponent.dance();
		}

		#if FEATURE_SCRIPTS
		setOnScripts('curBeat', beat);
		callOnScripts('onBeatHit', [beat]);
		#end
	}

	override public function barHit(bar:Int):Void
	{
		super.barHit(bar);

		if (!Options.profile.noStage)
			stage.barHit(bar);

		if (camZooming && FlxG.camera.zoom < 1.35 && Options.profile.camZooms)
		{
			FlxG.camera.zoom += 0.015 * camZoomingMult / songMultiplier;
			camHUD.zoom += 0.03 * camZoomingMult / songMultiplier;
		}

		var barObj:Bar = song.bars[bar];
		if (barObj != null)
		{
			updateFocusedCharacter(barObj);
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
			{
				moveCameraBar(barObj);
			}

			#if FEATURE_SCRIPTS
			setOnScripts('mustHit', barObj.mustHit);
			setOnScripts('altAnim', barObj.altAnim);
			setOnScripts('gfSings', barObj.gfSings);
			#end
		}

		#if FEATURE_SCRIPTS
		setOnScripts('curBar', bar);
		callOnScripts('onBarHit', [bar]);
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
		healthBar.setColors(opponent.healthBarColor, boyfriend.healthBarColor);
	}

	public function addCharacterToList(newCharacter:String, role:CharacterRole):Void
	{
		switch (role)
		{
			case PLAYER:
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:PlayableCharacter = new PlayableCharacter(0, 0, newCharacter);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					// newBoyfriend.visible = false;
					#if FEATURE_SCRIPTS
					startCharacterScript(newBoyfriend.id);
					#end
				}

			case OPPONENT:
				if (!opponentMap.exists(newCharacter))
				{
					var newOpponent:Character = new Character(0, 0, newCharacter);
					opponentMap.set(newCharacter, newOpponent);
					opponentGroup.add(newOpponent);
					startCharacterPos(newOpponent, true);
					newOpponent.alpha = 0.00001;
					// newOpponent.visible = false;
					#if FEATURE_SCRIPTS
					startCharacterScript(newOpponent.id);
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
					// newGf.visible = false;
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
		{ // IF OPPONENT IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(gfGroup.x, gfGroup.y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		var hasSwappedRole:Bool = char.isPlayer != char.originalFlipX;
		if (hasSwappedRole)
		{
			char.x -= char.position.x;
		}
		else
		{
			char.x += char.position.x;
		}
		char.y += char.position.y;
	}

	public function startVideo(name:String):Void
	{
		#if FEATURE_VIDEOS
		var filePath:String = Paths.video(name);
		if (Paths.exists(filePath, BINARY))
		{
			inCutscene = true;
			// Blocks any scenery behind the video sprite
			// var bg:FlxSprite = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
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
						senpaiEvil.frames = Paths.getFrames(Path.join(['stages', 'weeb', 'senpaiCrazy']));
						senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
						senpaiEvil.scale.set(PIXEL_ZOOM, PIXEL_ZOOM);
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

	// This is from Psych Engine.
	private function tankIntro():Void
	{
		var cutsceneHandler:CutsceneHandler = new CutsceneHandler();

		add(cutsceneHandler);

		var camFollow:FlxPoint = camFollowNoDirectional;

		opponentGroup.alpha = 0.00001;
		// opponentGroup.visible = false;
		camHUD.visible = false;
		// inCutscene = true; // this would stop the camera movement, oops

		var tankman:FlxSprite = new FlxSprite(-20, 320);
		tankman.frames = Paths.getFrames(Path.join(['cutscenes', song.id]));
		tankman.antialiasing = Options.profile.globalAntialiasing;
		addBehindOpponent(tankman);
		cutsceneHandler.push(tankman);

		var tankman2:FlxSprite = new FlxSprite(16, 312);
		tankman2.antialiasing = Options.profile.globalAntialiasing;
		tankman2.alpha = 0.000001;
		// tankman2.visible = false;
		cutsceneHandler.push(tankman2);
		var gfDance:FlxSprite = new FlxSprite(gf.x - 107, gf.y + 140);
		gfDance.antialiasing = Options.profile.globalAntialiasing;
		cutsceneHandler.push(gfDance);
		var gfCutscene:FlxSprite = new FlxSprite(gf.x - 104, gf.y + 122);
		gfCutscene.antialiasing = Options.profile.globalAntialiasing;
		cutsceneHandler.push(gfCutscene);
		var picoCutscene:FlxSprite = new FlxSprite(gf.x - 849, gf.y - 264);
		picoCutscene.antialiasing = Options.profile.globalAntialiasing;
		cutsceneHandler.push(picoCutscene);
		var boyfriendCutscene:FlxSprite = new FlxSprite(boyfriend.x + 5, boyfriend.y + 20);
		boyfriendCutscene.antialiasing = Options.profile.globalAntialiasing;
		cutsceneHandler.push(boyfriendCutscene);

		cutsceneHandler.finishCallback = () ->
		{
			var timeForStuff:Float = Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND * 4.5;
			FlxG.sound.music.fadeOut(timeForStuff);
			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, timeForStuff, {ease: FlxEase.quadInOut});
			moveCamera(OPPONENT);
			startCountdown();

			opponentGroup.alpha = 1;
			// opponentGroup.visible = true;
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
				Paths.precacheSound('wellWellWell');
				Paths.precacheSound('killYou');
				Paths.precacheSound('bfBeep');

				var wellWellWell:FlxSound = new FlxSound().loadEmbedded(Paths.getSound('wellWellWell'));
				FlxG.sound.list.add(wellWellWell);

				tankman.animation.addByPrefix('wellWell', 'TANK TALK 1 P1', 24, false);
				tankman.animation.addByPrefix('killYou', 'TANK TALK 1 P2', 24, false);
				tankman.animation.play('wellWell', true);
				FlxG.camera.zoom *= 1.2;

				// Well well well, what do we got here?
				cutsceneHandler.timer(0.1, () ->
				{
					wellWellWell.play(true);
				});

				// Move camera to BF
				cutsceneHandler.timer(3, () ->
				{
					camFollow.add(750, 100);
				});

				// Beep!
				cutsceneHandler.timer(4.5, () ->
				{
					boyfriend.playAnim('singUP', true);
					boyfriend.specialAnim = true;
					FlxG.sound.play(Paths.getSound('bfBeep'));
				});

				// Move camera to Tankman
				cutsceneHandler.timer(6, () ->
				{
					camFollow.subtract(750, 100);

					// We should just kill you but... what the hell, it's been a boring day... let's see what you've got!
					tankman.animation.play('killYou', true);
					FlxG.sound.play(Paths.getSound('killYou'));
				});

			case 'guns':
				cutsceneHandler.endTime = 11.5;
				// cutsceneHandler.music = 'DISTORTO';
				tankman.x += 40;
				tankman.y += 10;
				Paths.precacheSound('tankSong2');

				var tightBars:FlxSound = new FlxSound().loadEmbedded(Paths.getSound('tankSong2'));
				FlxG.sound.list.add(tightBars);

				tankman.animation.addByPrefix('tightBars', 'TANK TALK 2', 24, false);
				tankman.animation.play('tightBars', true);
				boyfriend.animation.curAnim.finish();

				cutsceneHandler.onStart = () ->
				{
					tightBars.play(true);
					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 4, {ease: FlxEase.quadInOut});
					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2 * 1.2}, 0.5, {ease: FlxEase.quadInOut, startDelay: 4});
					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 1, {ease: FlxEase.quadInOut, startDelay: 4.5});
				};

				cutsceneHandler.timer(4, () ->
				{
					gf.playAnim('sad', true);
					gf.animation.finishCallback = (name:String) ->
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
				// gfGroup.visible = false;
				// boyfriendGroup.visible = false;
				camFollow.set(opponent.x + 400, opponent.y + 170);
				FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2}, 1, {ease: FlxEase.quadInOut});
				for (spr in stage.foregrounds[2])
				{
					spr.y += 100;
				}
				Paths.precacheSound('stressCutscene');

				tankman2.frames = Paths.getFrames(Path.join(['cutscenes', 'stress2']));
				addBehindOpponent(tankman2);

				if (!Options.profile.lowQuality)
				{
					gfDance.frames = Paths.getFrames(Path.join(['characters', 'gfTankmen']));
					gfDance.animation.addByPrefix('dance', 'GF Dancing at Gunpoint', 24, true);
					gfDance.animation.play('dance', true);
					addBehindGF(gfDance);
				}

				gfCutscene.frames = Paths.getFrames(Path.join(['cutscenes', 'stressGF']));
				gfCutscene.animation.addByPrefix('dieBitch', 'GF STARTS TO TURN PART 1', 24, false);
				gfCutscene.animation.addByPrefix('getRektLmao', 'GF STARTS TO TURN PART 2', 24, false);
				gfCutscene.animation.play('dieBitch', true);
				gfCutscene.animation.pause();
				addBehindGF(gfCutscene);
				if (!Options.profile.lowQuality)
				{
					gfCutscene.alpha = 0.00001;
					// gfCutscene.visible = false;
				}

				picoCutscene.frames = Paths.getFrames(Path.join(['cutscenes', 'stressPico']), TEXTURE_ATLAS);
				picoCutscene.animation.addByPrefix('anim', 'Pico Badass', 24, false);
				addBehindGF(picoCutscene);
				picoCutscene.alpha = 0.00001;
				// picoCutscene.visible = false;

				boyfriendCutscene.frames = Paths.getFrames(Path.join(['characters', 'BOYFRIEND']));
				boyfriendCutscene.animation.addByPrefix('idle', 'BF idle dance', 24, false);
				boyfriendCutscene.animation.play('idle', true);
				boyfriendCutscene.animation.curAnim.finish();
				addBehindBF(boyfriendCutscene);

				var cutsceneSnd:FlxSound = new FlxSound().loadEmbedded(Paths.sound('stressCutscene'));
				FlxG.sound.list.add(cutsceneSnd);

				tankman.animation.addByPrefix('godEffingDamnIt', 'TANK TALK 3', 24, false);
				tankman.animation.play('godEffingDamnIt', true);

				var calledTimes:Int = 0;
				var zoomBack:() -> Void = () ->
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
						for (spr in stage.foregrounds[2])
						{
							spr.y -= 100;
						}
					}
				}

				cutsceneHandler.onStart = () ->
				{
					cutsceneSnd.play(true);
				};

				cutsceneHandler.timer(15.2, () ->
				{
					FlxTween.tween(camFollow, {x: 650, y: 300}, 1, {ease: FlxEase.sineOut});
					FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 2.25, {ease: FlxEase.quadInOut});

					gfDance.visible = false;
					gfCutscene.alpha = 1;
					// gfCutscene.visible = true;
					gfCutscene.animation.play('dieBitch', true);
					gfCutscene.animation.finishCallback = (name:String) ->
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
							// picoCutscene.visible = true;
							picoCutscene.animation.play('anim', true);

							boyfriendCutscene.visible = false;
							boyfriendGroup.alpha = 1;
							// boyfriendGroup.visible = true;
							boyfriend.playAnim('bfCatch', true);
							boyfriend.animation.finishCallback = (name:String) ->
							{
								if (name != 'idle')
								{
									boyfriend.playAnim('idle', true);
									boyfriend.animation.curAnim.finish(); // Instantly goes to last frame
								}
							};

							picoCutscene.animation.finishCallback = (name:String) ->
							{
								picoCutscene.visible = false;
								picoCutscene.animation.finishCallback = null;
								gfGroup.alpha = 1;
								// gfGroup.visible = true;
							};
							gfCutscene.animation.finishCallback = null;
						}
					};
				});

				cutsceneHandler.timer(17.5, () ->
				{
					zoomBack();
				});

				cutsceneHandler.timer(19.5, () ->
				{
					tankman.alpha = 0.00001;
					tankman2.alpha = 1;
					// tankman.visible = false;
					// tankman2.visible = true;
					tankman2.animation.addByPrefix('lookWhoItIs', 'TANK TALK 3', 24, false);
					tankman2.animation.play('lookWhoItIs', true);
				});

				cutsceneHandler.timer(20, () ->
				{
					camFollow.set(opponent.x + 500, opponent.y + 170);
				});

				cutsceneHandler.timer(31.2, () ->
				{
					boyfriend.playAnim('singUPmiss', true);
					boyfriend.animation.finishCallback = (name:String) ->
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

				cutsceneHandler.timer(32.2, () ->
				{
					zoomBack();
				});
		}
	}

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
			Conductor.songPosition = -(Conductor.beatLength * 5);
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

			startTimer = new FlxTimer().start(Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND, (tmr:FlxTimer) ->
			{
				var introAssets:Map<String, Array<String>> = [
					'default' => [
						Path.join(['ui', 'countdown', 'ready']),
						Path.join(['ui', 'countdown', 'set']),
						Path.join(['ui', 'countdown', 'go'])
					],
					'pixel' => [
						Path.join(['ui', 'countdown', 'ready-pixel']),
						Path.join(['ui', 'countdown', 'set-pixel']),
						Path.join(['ui', 'countdown', 'date-pixel'])
					]
				];

				var introAlts:Array<String> = introAssets.get(isPixelStage ? 'pixel' : 'default');
				var antialias:Bool = isPixelStage ? false : Options.profile.globalAntialiasing;

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
							countdownReady.scale.set(PIXEL_ZOOM, PIXEL_ZOOM);

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						add(countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0},
							Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND, {
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
							countdownSet.scale.set(PIXEL_ZOOM, PIXEL_ZOOM);

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						add(countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0}, Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND, {
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
							countdownGo.scale.set(PIXEL_ZOOM, PIXEL_ZOOM);

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						add(countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0}, Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND, {
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

				if (Options.profile.showOpponentStrums)
				{
					notes.forEachAlive((note:Note) ->
					{
						if (note.mustPress)
						{
							note.copyAlpha = false;
							note.alpha = note.multAlpha;
							if (Options.profile.middleScroll && !note.mustPress)
							{
								note.alpha *= 0.5;
							}
						}
					});
				}
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

	public function addBehindOpponent(obj:FlxObject):Void
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

		Conductor.songPosition = time;

		song.inst.pause();
		song.vocals.pause();

		song.inst.time = Conductor.songPosition;
		song.inst.play();

		song.vocals.time = Conductor.songPosition;
		song.vocals.play();
	}

	public function restartSong(noTrans:Bool = false):Void
	{
		paused = true; // For scripts
		if (song.inst != null && song.inst.playing)
		{
			song.inst.stop();
		}
		if (song.vocals != null && song.vocals.playing)
		{
			song.vocals.stop();
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
		song.inst.onComplete = () ->
		{
			finishSong(false);
		};
		// Destroys the music after it plays, so it doesn't continue playing in the Freeplay menu and crash the game when running the callback
		song.inst.autoDestroy = true;
		song.vocals.play();
		song.vocals.autoDestroy = true;

		if (startTime > 0)
		{
			setSongTime(startTime);
			clearNotesBefore(Conductor.songPosition);
		}
		startTime = 0;

		updatePlaybackSpeed();

		if (paused)
		{
			song.inst.pause();
			song.vocals.pause();
		}

		if (needSkip)
		{
			skipActive = true;
			skipText = new FlxText(healthBar.x + 80, PlayStateChangeables.useDownscroll ? healthBar.y + 110 : healthBar.y - 110, 500,
				'Press Space to Skip Intro', 30);
			skipText.color = FlxColor.WHITE;
			skipText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
			skipText.cameras = [camHUD];
			skipText.alpha = 0;
			FlxTween.tween(skipText, {alpha: 1}, 0.2);
			add(skipText);
		}

		// Song duration in a float, useful for the time left feature
		songLength = song.inst.length / songMultiplier;
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
				scrollSpeed = song.scrollSpeed * PlayStateChangeables.scrollSpeed;
			case 'constant':
				scrollSpeed = PlayStateChangeables.scrollSpeed;
		}

		song.generateTimings(songMultiplier);
		song.recalculateAllBarTimes();
		Conductor.prepareFromSong(song);

		song.vocals = new FlxSound();
		if (song.needsVoices #if FEATURE_STEPMANIA && !isSM #end)
		{
			Paths.precacheAudioDirect(Paths.voices(song.id));
			song.vocals.loadEmbedded(Paths.getVoices(song.id));
		}

		FlxG.sound.list.add(song.vocals);

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
			for (eventGroup in eventsSong.events) // Events
			{
				for (eventEntry in eventGroup.events)
				{
					var event:Event = new Event(eventGroup.beat, eventEntry.type, eventEntry.args);
					var strumTime:Float = Conductor.getTimeFromBeat(event.beat);
					strumTime += Options.profile.noteOffset;
					strumTime -= eventEarlyTrigger(event);
					event.beat = Conductor.getBeatFromTime(strumTime);

					events.push(event);
					eventPushed(event);
				}
			}
		}

		var bars:Array<Bar> = song.bars;
		for (bar in bars)
		{
			for (noteDef in bar.notes)
			{
				var strumTime:Float = song.getTimeFromBeat(noteDef.beat) / songMultiplier;
				var noteData:Int = Std.int(noteDef.data % NoteKey.createAll().length);
				var mustHit:Bool = noteDef.data >= NoteKey.createAll().length ? !bar.mustHit : bar.mustHit;
				var oldNote:Null<Note> = unspawnNotes.length > 0 ? unspawnNotes[unspawnNotes.length - 1] : null;
				var note:Note = new Note(strumTime, noteData, oldNote, false, false, noteDef.beat);
				note.mustPress = mustHit;
				note.sustainLength = noteDef.sustainLength;
				note.gfNote = bar.gfSings && noteDef.data < NoteKey.createAll().length;
				note.noteType = noteDef.type;

				note.scrollFactor.set();
				unspawnNotes.push(note);

				if (note.sustainLength > 0)
				{
					note.isParent = true;

					var floorSustain:Int = Math.floor(note.sustainLength * Conductor.STEPS_PER_BEAT); // Measured in steps instead of beats just for the sake of rounding
					if (floorSustain > 0)
					{
						for (sustainFactor in 0...floorSustain + 1)
						{
							oldNote = unspawnNotes[unspawnNotes.length - 1];
							// FIXME Some scroll speeds make the sustains look messed up (or maybe it's tempo changes causing it?)
							var finalBeat:Float = noteDef.beat + (sustainFactor + 1) / Conductor.STEPS_PER_BEAT;
							var finalStrumTime:Float = song.getTimeFromBeat(finalBeat) / songMultiplier;
							var sustainNote:Note = new Note(finalStrumTime, noteData, oldNote, true, false, finalBeat);

							sustainNote.mustPress = note.mustPress;
							sustainNote.gfNote = note.gfNote;
							sustainNote.noteType = note.noteType;
							sustainNote.scrollFactor.set();
							unspawnNotes.push(sustainNote);
							if (sustainNote.mustPress)
							{
								sustainNote.x += FlxG.width / 2; // general offset
							}
							else if (Options.profile.middleScroll)
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
				}
				if (note.mustPress)
				{
					note.x += FlxG.width / 2; // general offset
				}
				else if (Options.profile.middleScroll)
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

				if (bar.altAnim && !note.mustPress) // I'll make this work with both players at some point
				{
					note.animSuffix = '-alt';
				}
			}
		}
		unspawnNotes.sort(sortNoteByBeat);

		for (eventGroup in song.events) // Events
		{
			for (eventEntry in eventGroup.events)
			{
				var event:Event = new Event(eventGroup.beat, eventEntry.type, eventEntry.args);
				var strumTime:Float = song.getTimeFromBeat(event.beat);
				strumTime += Options.profile.noteOffset;
				strumTime -= eventEarlyTrigger(event);
				event.beat = song.getBeatFromTime(strumTime);

				events.push(event);
				eventPushed(event);
			}
		}
		if (events.length > 1)
		{
			// No need to sort if there's a single one or none at all
			events.sort(sortEventByBeat);
		}

		generatedMusic = true;
	}

	private function eventPushed(event:Event):Void
	{
		switch (event.type)
		{
			case 'Change Character':
				var roleName:String = event.args[0];
				var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
				var newCharacter:String = event.args[1];
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

	private function sortNoteByBeat(obj1:Note, obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.beat, obj2.beat);
	}

	private function sortEventByBeat(obj1:Event, obj2:Event):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.beat, obj2.beat);
	}

	private function generateStrumNotes(player:Int):Void
	{
		for (i in 0...NoteKey.createAll().length)
		{
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if (!Options.profile.showOpponentStrums)
					targetAlpha = 0;
				else if (Options.profile.middleScroll)
					targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(Options.profile.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player);
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
				if (Options.profile.middleScroll)
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
		if (canPause && !paused && !inCutscene && !inResults)
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

					if (song.inst != null && song.inst.playing)
						song.inst.pause();
					if (song.vocals != null && song.vocals.playing)
						song.vocals.pause();

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
		if (song.inst != null && !startingSong && !endingSong)
		{
			resyncVocals();
		}

		FlxG.sound.resume();

		if (startTimer != null && !startTimer.finished)
			startTimer.active = true;
		if (finishTimer != null && !finishTimer.finished)
			finishTimer.active = true;
		if (scrollSpeedTween != null)
			scrollSpeedTween.active = true;

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
				songLength - Conductor.songPosition - Options.profile.noteOffset);
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

		song.vocals.pause();

		song.inst.play();
		Conductor.songPosition = song.inst.time / songMultiplier;
		song.vocals.time = Conductor.songPosition;
		song.vocals.play();

		// song.inst.pause();
		// song.vocals.pause();
		// song.inst.time = Conductor.songPosition * songMultiplier;
		// song.vocals.time = Conductor.songPosition * songMultiplier;
		// song.inst.play();
		// song.vocals.play();

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

				if (song.inst != null && song.inst.playing)
					song.inst.stop();
				if (song.vocals != null && song.vocals.playing)
					song.vocals.stop();

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
				openSubState(new GameOverSubState(boyfriend.getScreenPosition().x - boyfriend.position.x,
					boyfriend.getScreenPosition().y - boyfriend.position.y));

				#if FEATURE_DISCORD
				// Game Over doesn't get its own variable because it's only used here
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
			if (curDecimalBeat < event.beat)
			{
				break;
			}
			triggerEvent(event.type, event.args);
			events.shift();
		}
	}

	public function getControl(key:String):Bool
	{
		var pressed:Bool = Reflect.getProperty(controls, key);
		return pressed;
	}

	public function triggerEvent(type:String, args:Array<Any>):Void
	{
		var value1:Any = args[0];
		var value2:Any = args[1];

		switch (type)
		{
			case 'Hey!':
				var value1:String = Std.string(value1);
				var value:Int = 2;
				switch (value1.toLowerCase().trim())
				{
					case 'boyfriend' | 'bf' | '0':
						value = 0;
					case 'girlfriend' | 'gf' | '1':
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
				var newSpeed:Int = Std.parseInt(value1);
				if (Math.isNaN(newSpeed) || newSpeed < 1)
					newSpeed = 1;
				gfSpeed = newSpeed;

			case 'Philly Glow':
				var lightId:Int = Std.parseInt(value1);
				if (Math.isNaN(lightId))
					lightId = 0;

				var doFlash:() -> Void = () ->
				{
					var color:FlxColor = FlxColor.WHITE;
					if (!Options.profile.flashing)
						color.alphaFloat = 0.5;

					FlxG.camera.flash(color, 0.15, null, true);
				};

				var phillyStreet:FlxSprite = stage.layers['street'];
				var blammedLightsBlack:FlxSprite = stage.layers['blammedLightsBlack'];
				var phillyWindowEvent:FlxSprite = stage.layers['phillyWindowEvent'];
				var phillyGlowGradient:PhillyGlow.PhillyGlowGradient = cast stage.layers['phillyGlowGradient'];
				var phillyGlowParticles:FlxTypedGroup<PhillyGlow.PhillyGlowParticle> = cast stage.groups['phillyGlowParticles'];

				var chars:Array<Character> = [boyfriend, gf, opponent];
				switch (lightId)
				{
					case 0:
						if (phillyGlowGradient.visible)
						{
							doFlash();
							if (Options.profile.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = false;
							phillyWindowEvent.visible = false;
							phillyGlowGradient.visible = false;
							phillyGlowParticles.visible = false;
							curLightEvent = -1;

							for (char in chars)
							{
								char.color = FlxColor.WHITE;
							}
							phillyStreet.color = FlxColor.WHITE;
						}

					case 1: // turn on
						curLightEvent = FlxG.random.int(0, PHILLY_LIGHTS_COLORS.length - 1, [curLightEvent]);
						var color:FlxColor = PHILLY_LIGHTS_COLORS[curLightEvent];

						if (!phillyGlowGradient.visible)
						{
							doFlash();
							if (Options.profile.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = true;
							blammedLightsBlack.alpha = 1;
							phillyWindowEvent.visible = true;
							phillyGlowGradient.visible = true;
							phillyGlowParticles.visible = true;
						}
						else if (Options.profile.flashing)
						{
							var colorButLower:FlxColor = color;
							colorButLower.alphaFloat = 0.25;
							FlxG.camera.flash(colorButLower, 0.5, null, true);
						}

						var charColor:FlxColor = color;
						if (!Options.profile.flashing)
							charColor.saturation *= 0.5;
						else
							charColor.saturation *= 0.75;

						for (char in chars)
						{
							char.color = charColor;
						}
						phillyGlowParticles.forEachAlive((particle:PhillyGlow.PhillyGlowParticle) ->
						{
							particle.color = color;
						});
						phillyGlowGradient.color = color;
						phillyWindowEvent.color = color;

						color.brightness *= 0.5;
						phillyStreet.color = color;

					case 2: // spawn particles
						if (!Options.profile.lowQuality)
						{
							var particlesNum:Int = FlxG.random.int(8, 12);
							var width:Float = (2000 / particlesNum);
							var color:FlxColor = PHILLY_LIGHTS_COLORS[curLightEvent];
							for (j in 0...3)
							{
								for (i in 0...particlesNum)
								{
									var particle:PhillyGlow.PhillyGlowParticle = new PhillyGlow.PhillyGlowParticle(-400
										+ width * i
										+ FlxG.random.float(-width / 5, width / 5),
										phillyGlowGradient.originalY
										+ 200
										+ (FlxG.random.float(0, 125) + j * 40), color);
									phillyGlowParticles.add(particle);
								}
							}
						}
						phillyGlowGradient.bop();
				}
			case 'Kill Henchmen':
				stage.killHenchmen();

			case 'Add Camera Zoom':
				if (Options.profile.camZooms && FlxG.camera.zoom < 1.35)
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
					var bgGhouls:FlxSprite = stage.layers['bgGhouls'];
					if (bgGhouls != null)
					{
						bgGhouls.animation.play('dance', true);
						bgGhouls.visible = true;
					}
				}

			case 'Play Animation':
				var animToPlay:String = Std.string(value1);
				var value2:String = Std.string(value2);
				var char:Character = opponent;
				switch (value2.toLowerCase().trim())
				{
					case 'boyfriend' | 'bf':
						char = boyfriend;
					case 'girlfriend' | 'gf':
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
					char.playAnim(animToPlay, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				var x:Float = Std.parseFloat(value1);
				var y:Float = Std.parseFloat(value2);
				isCameraOnForcedPos = false;
				if (!Math.isNaN(x) || !Math.isNaN(y))
				{
					if (Math.isNaN(x))
						x = 0;
					if (Math.isNaN(x))
						y = 0;

					camFollow.set(x, y);
					camFollowNoDirectional.copyFrom(camFollow);

					isCameraOnForcedPos = true;
				}

			case 'Alt Idle Animation':
				var value1:String = Std.string(value1);
				var idleSuffix:String = Std.string(value2);
				var char:Character = opponent;
				switch (value1.toLowerCase())
				{
					case 'girlfriend' | 'gf':
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
					char.idleSuffix = idleSuffix;
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
				var value1:String = Std.string(value1);
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
							// boyfriend.visible = false;
							boyfriend = boyfriendMap.get(value2);
							// boyfriend.visible = true;
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
							// opponent.visible = false;
							opponent = opponentMap.get(value2);
							// opponent.visible = true;
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
						setOnScripts('opponentName', opponent.id);
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
								// gf.visible = false;
								gf = gfMap.get(value2);
								// gf.visible = true;
								gf.alpha = lastAlpha;
							}
							#if FEATURE_SCRIPTS
							setOnScripts('gfName', gf.id);
							#end
						}
				}
				reloadHealthBarColors();

			case 'BG Freaks Expression':
				var bgGirls:BackgroundGirls = cast stage.layers['bgGirls'];
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

				var newValue:Float = song.scrollSpeed * PlayStateChangeables.scrollSpeed * val1;

				if (val2 <= 0)
				{
					scrollSpeed = newValue;
				}
				else
				{
					scrollSpeedTween = FlxTween.tween(this, {scrollSpeed: newValue}, val2, {
						ease: FlxEase.linear,
						onComplete: (twn:FlxTween) ->
						{
							scrollSpeedTween = null;
						}
					});
				}
			case 'Set Property':
				var value1:String = Std.string(value1);
				var killMe:Array<String> = value1.split('.');
				if (killMe.length > 1)
				{
					Reflect.setProperty(FunkinScript.getPropertyLoop(killMe, true, true), killMe[killMe.length - 1], value2);
				}
				else
				{
					Reflect.setProperty(this, value1, value2);
				}
		}
		#if FEATURE_SCRIPTS
		callOnScripts('onEvent', [type, value1, value2]);
		#end
	}

	private function moveCameraBar(bar:Bar):Void
	{
		if (bar == null)
			return;

		if (gf != null && bar.gfSings)
		{
			moveCamera(GIRLFRIEND);
		}
		else if (bar.mustHit)
		{
			moveCamera(PLAYER);
		}
		else
		{
			moveCamera(OPPONENT);
		}
	}

	public function moveCamera(role:CharacterRole):Void
	{
		switch (role)
		{
			case GIRLFRIEND:
				gf.getMidpoint(camFollow);

				var hasSwappedRole:Bool = gf.isPlayer != gf.originalFlipX;
				if (hasSwappedRole)
				{
					camFollow.x += gf.cameraPosition.x;
				}
				else
				{
					camFollow.x -= gf.cameraPosition.x;
				}

				camFollow.add(girlfriendCameraOffset.x, gf.cameraPosition.y + girlfriendCameraOffset.y);
				camFollowNoDirectional.copyFrom(camFollow);

				tweenCamIn();

				#if FEATURE_SCRIPTS
				callOnScripts('onMoveCamera', ['gf']);
				#end
			case OPPONENT:
				camFollow.set(opponent.getMidpoint().x + 150, opponent.getMidpoint().y - 100);

				var hasSwappedRole:Bool = opponent.isPlayer != opponent.originalFlipX;
				if (hasSwappedRole)
				{
					camFollow.x -= opponent.cameraPosition.x;
				}
				else
				{
					camFollow.x += opponent.cameraPosition.x;
				}

				camFollow.add(opponentCameraOffset.x, opponent.cameraPosition.y + opponentCameraOffset.y);
				camFollowNoDirectional.copyFrom(camFollow);

				tweenCamIn();

				#if FEATURE_SCRIPTS
				callOnScripts('onMoveCamera', ['opponent']);
				#end
			case PLAYER:
				camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);

				var hasSwappedRole:Bool = boyfriend.isPlayer != boyfriend.originalFlipX;
				if (hasSwappedRole)
				{
					camFollow.x += boyfriend.cameraPosition.x;
				}
				else
				{
					camFollow.x -= boyfriend.cameraPosition.x;
				}

				camFollow.add(boyfriendCameraOffset.x, boyfriend.cameraPosition.y + boyfriendCameraOffset.y);
				camFollowNoDirectional.copyFrom(camFollow);

				if (song.id == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
				{
					cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND), {
						ease: FlxEase.elasticInOut,
						onComplete: (twn:FlxTween) ->
						{
							cameraTwn = null;
						}
					});
				}

				#if FEATURE_SCRIPTS
				callOnScripts('onMoveCamera', ['boyfriend']);
				#end
		}
	}

	private function tweenCamIn():Void
	{
		if (song.id == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3)
		{
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND), {
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
		song.inst.stop();
		song.vocals.stop();
		if (Options.profile.noteOffset <= 0 || ignoreNoteOffset)
		{
			finishCallback();
		}
		else
		{
			finishTimer = new FlxTimer().start(Options.profile.noteOffset / TimingConstants.MILLISECONDS_PER_SECOND, (tmr:FlxTimer) ->
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

		if (song.inst != null && song.inst.playing)
			song.inst.stop();
		if (song.vocals != null && song.vocals.playing)
			song.vocals.stop();

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
				HighScore.saveScore(song.id, score, storyDifficulty, percent);
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

					if (song.inst != null && song.inst.playing)
						song.inst.stop();
					if (song.vocals != null && song.vocals.playing)
						song.vocals.stop();
					if (Options.profile.scoreScreen)
					{
						if (Options.profile.timeBarType != 'Disabled')
						{
							FlxTween.tween(timeBar, {alpha: 0}, 1);
						}
						openSubState(new ResultsSubState());
						inResults = true;
						persistentUpdate = false;
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
							HighScore.saveWeekScore(Week.getCurrentWeekId(), campaignScore, storyDifficulty);
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

				if (Options.profile.scoreScreen)
				{
					openSubState(new ResultsSubState());
					inResults = true;
					persistentUpdate = false;
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
						if (/*Options.profile.frameRate <= 60 &&*/ PlayStateChangeables.optimize && !Options.profile.globalAntialiasing)
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
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + Options.profile.ratingOffset);

		song.vocals.volume = 1;

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
				if (note.noteSplashForced && !note.noteSplashDisabled)
					spawnNoteSplashOnNote(note);
			case Judgement.BAD:
				totalNotesHit += 0.5;
				note.ratingMod = 0.5;
				scoreChange = 100;
				if (!note.ratingDisabled)
					bads++;
				if (note.noteSplashForced && !note.noteSplashDisabled)
					spawnNoteSplashOnNote(note);
			case Judgement.GOOD:
				totalNotesHit += 0.75;
				note.ratingMod = 0.75;
				scoreChange = 200;
				if (!note.ratingDisabled)
					goods++;
				if (note.noteSplashForced && !note.noteSplashDisabled)
					spawnNoteSplashOnNote(note);
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

		if (Options.profile.scoreZoom)
		{
			if (scoreTxtTween != null)
			{
				scoreTxtTween.cancel();
			}
			scoreTxt.scale.set(1.075, 1.075);
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: (twn:FlxTween) ->
				{
					scoreTxtTween = null;
				}
			});
		}

		var pixelSuffix:String = isPixelStage ? '-pixel' : '';

		rating.loadGraphic(Paths.getGraphic(Path.join(['ui', 'judgements', '$ratingName$pixelSuffix'])));
		rating.cameras = [camHUD];
		rating.screenCenter();
		rating.x = coolText.x - 40 + Options.profile.comboOffset[0];
		rating.y -= 60 + Options.profile.comboOffset[1];
		rating.acceleration.y = 550;
		rating.velocity.subtract(FlxG.random.int(0, 10), FlxG.random.int(140, 175));
		rating.visible = !Options.profile.hideHUD && showRating;

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'combo', 'combo$pixelSuffix'])));
		comboSpr.cameras = [camHUD];
		comboSpr.screenCenter();
		comboSpr.x = coolText.x + Options.profile.comboOffset[0];
		comboSpr.y -= Options.profile.comboOffset[1];
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.x += FlxG.random.int(1, 10);
		comboSpr.velocity.y -= 150;
		comboSpr.visible = !Options.profile.hideHUD && showCombo;

		insert(members.indexOf(strumLineNotes), rating);

		if (isPixelStage)
		{
			rating.scale.set(PIXEL_ZOOM * 0.85, PIXEL_ZOOM * 0.85);
			comboSpr.scale.set(PIXEL_ZOOM * 0.85, PIXEL_ZOOM * 0.85);
		}
		else
		{
			rating.scale.set(0.7, 0.7);
			rating.antialiasing = Options.profile.globalAntialiasing;
			comboSpr.scale.set(0.7, 0.7);
			comboSpr.antialiasing = Options.profile.globalAntialiasing;
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		if (combo > highestCombo)
			highestCombo = combo;

		var separatedScore:Array<Int> = [for (i in placement.split('')) Std.parseInt(i)];

		for (i in 0...separatedScore.length)
		{
			var digit:Int = separatedScore[i];
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'combo', 'num$digit$pixelSuffix'])));
			numScore.cameras = [camHUD];
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * i) - 90 + Options.profile.comboOffset[2];
			numScore.y += 80 - Options.profile.comboOffset[3];

			if (isPixelStage)
			{
				numScore.scale.set(PIXEL_ZOOM, PIXEL_ZOOM);
			}
			else
			{
				numScore.antialiasing = Options.profile.globalAntialiasing;
				numScore.scale.set(0.5, 0.5);
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);
			numScore.visible = !Options.profile.hideHUD;

			insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: (tween:FlxTween) ->
				{
					numScore.destroy();
				},
				startDelay: Conductor.beatLength * 0.002
			});
		}

		coolText.text = separatedScore.join('');

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.beatLength * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: (tween:FlxTween) ->
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.beatLength * 0.001
		});
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);

		if (!PlayStateChangeables.botPlay
			&& startedCountdown
			&& !paused
			&& key > -1
			&& (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || Options.profile.controllerMode))
		{
			if (!boyfriend.stunned && generatedMusic && !endingSong)
			{
				// more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = song.inst.time;

				var canMiss:Bool = !Options.profile.ghostTapping;

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
				sortedNotesList.sort(sortNoteByBeat);

				if (sortedNotesList.length > 0)
				{
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes)
						{
							// if (Math.abs(Conductor.getTimeFromBeat(doubleNote.beat) - Conductor.getTimeFromBeat(epicNote.beat)) < 1)
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
			if (spr != null && spr.animation.name != 'confirm')
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
		if (!PlayStateChangeables.botPlay && startedCountdown && !paused && key > -1)
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
		if (Options.profile.controllerMode)
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

		if (startedCountdown && !boyfriend.stunned && generatedMusic)
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
			else if (boyfriend.holdTimer > Conductor.stepLength * 0.0011 * boyfriend.singDuration
				&& boyfriend.animation.name.startsWith('sing')
				&& !boyfriend.animation.name.endsWith('miss'))
			{
				boyfriend.dance();
			}
		}

		// TODO: Find a better way to handle controller inputs, this should work for now
		if (Options.profile.controllerMode)
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
			if (PlayStateChangeables.botPlay && (note.ignoreNote || note.hitCausesMiss))
				return;

			if (Options.profile.hitSound && Options.profile.hitSoundVolume > 0 && !note.hitSoundDisabled)
			{
				FlxG.sound.play(Paths.getSound('hitsound'), Options.profile.hitSoundVolume);
			}

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
					}
				}
				else
				{
					boyfriend.playAnim(animToPlay, true);
					boyfriend.holdTimer = 0;
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
				if (note.isSustainNote && !note.animation.name.endsWith('end'))
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
			song.vocals.volume = 1;

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
		song.vocals.volume = 0;
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
		if (Options.profile.ghostTapping)
			return;

		if (!boyfriend.stunned)
		{
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
			}
			song.vocals.volume = 0;

			#if FEATURE_SCRIPTS
			callOnScripts('noteMissPress', [key]);
			#end
		}
	}

	private function opponentHitNote(note:Note):Void
	{
		if (note.noteType == 'Hey!' && opponent.animation.exists('hey'))
		{
			opponent.playAnim('hey', true);
			opponent.specialAnim = true;
			opponent.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
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
			}
		}

		if (song.needsVoices)
			song.vocals.volume = 1;

		var time:Float = 0.15;
		if (note.isSustainNote && !note.animation.name.endsWith('end'))
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
		if (Options.profile.noteSplashes && note != null)
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
		if (song.inst.fadeTween != null)
		{
			song.inst.fadeTween.cancel();
		}
		song.inst.fadeTween = null;
	}

	public function updateFocusedCharacter(bar:Bar):Void
	{
		if (bar == null)
			return;

		if (bar.gfSings && gf != null)
		{
			focus = GIRLFRIEND;
		}
		else if (bar.mustHit)
		{
			focus = PLAYER;
		}
		else
		{
			focus = OPPONENT;
		}
	}

	public function updateDirectionalCamera():Void
	{
		// Reset the directional camera (It's outside of the conditional in case the option is changed during the song)
		camFollow.copyFrom(camFollowNoDirectional);

		if (camDirectional && Options.profile.camFollowsAnims)
		{
			var focusedChar:Null<Character> = null;
			switch (focus)
			{
				case PLAYER:
					focusedChar = boyfriend;
				case OPPONENT:
					focusedChar = opponent;
				case GIRLFRIEND:
					focusedChar = gf;
			}
			if (focusedChar != null)
			{
				if (focusedChar.animation.curAnim != null)
				{
					var motionFactor:Float = 25 * focusedChar.cameraMotionFactor;
					var animName:String = focusedChar.animation.name;

					if (animName.startsWith('singUP'))
						camFollow.y -= motionFactor;
					else if (animName.startsWith('singDOWN'))
						camFollow.y += motionFactor;
					else if (animName.startsWith('singLEFT'))
						camFollow.x -= motionFactor;
					else if (animName.startsWith('singRIGHT'))
						camFollow.x += motionFactor;
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

	private function strumPlayAnim(isOpponent:Bool, id:Int, time:Float):Void
	{
		var spr:StrumNote;
		if (isOpponent)
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
			ratingFC = Ratings.generateComboRank(misses, shits, bads, goods);

			// TODO What if the score text was a separate class...?
			scoreTxt.text = Ratings.calculateRanking(score, scoreDefault, nps, maxNPS, misses, shits, bads, goods, ratingPercent);
			judgementCounter.text = 'Sicks: ${sicks}\nGoods: ${goods}\nBads: ${bads}\nShits: ${shits}\nMisses: ${misses}\n';
		}

		#if FEATURE_SCRIPTS
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		#end
	}

	private function updatePlaybackSpeed():Void
	{
		#if cpp
		// TODO Figure out whether there is a better way to change audio playback speed
		// (As in, a way which does not involve accessing private variables)
		if (song.inst.playing)
		{
			@:privateAccess
			{
				// TODO Find out how to change playback speed because this only changes pitch
				lime.media.openal.AL.sourcef(song.inst._channel.__source.__backend.handle, lime.media.openal.AL.PITCH, songMultiplier);
				if (song.vocals.playing)
					lime.media.openal.AL.sourcef(song.vocals._channel.__source.__backend.handle, lime.media.openal.AL.PITCH, songMultiplier);
				// song.inst.pitch = songMultiplier;
				// if (song.vocals.playing)
				// 	song.vocals.pitch = songMultiplier;
			}
		}
		#end
	}

	private function set_scrollSpeed(value:Float):Float
	{
		if (scrollSpeed != value)
		{
			if (generatedMusic)
			{
				var ratio:Float = value / scrollSpeed;
				for (note in notes)
				{
					if (note.isSustainNote && !note.animation.name.endsWith('end'))
					{
						note.scale.y *= ratio;
						note.updateHitbox();
					}
				}
				for (note in unspawnNotes)
				{
					if (note.isSustainNote && !note.animation.name.endsWith('end'))
					{
						note.scale.y *= ratio;
						note.updateHitbox();
					}
				}
			}
			scrollSpeed = value;
			noteKillOffset = 350 / scrollSpeed;
		}
		return value;
	}
}
