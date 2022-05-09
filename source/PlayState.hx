package;

import Achievement.AchievementDef;
import DialogueBoxPsych.DialogueDef;
import Note.EventNoteDef;
import Replay.Ana;
import Replay.Analysis;
import Section.SectionDef;
import Song.SongDef;
import editors.CharacterEditorState;
import editors.ChartingState;
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
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.io.Path;
import openfl.events.KeyboardEvent;
import options.OptionsSubState;

using StringTools;

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

// TODO Make the input system much less pathetically easy and cheesable
// (An example of it is being able to hit any incoming hold notes by just pressing the keys early, missing the first note, and getting the rest of the hold anyway)
// TODO Abuse the fuck out of multithreading to make the game run faster
// TODO Use FlxG.sound.pause() instead of individually pausing sounds, because then we can pause everything at once, including sound effects
// TODO Man, this list keeps growing. Anyway, find a simple way to use camHUD as the default camera so substates and such don't need to be manually set to it
class PlayState extends MusicBeatState
{
	public static final STRUM_X:Float = 42;
	public static final STRUM_X_MIDDLESCROLL:Float = -278;
	// how big to stretch the pixel art assets
	public static final PIXEL_ZOOM:Float = 6;

	public static var instance:PlayState;

	// event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Boyfriend> = [];
	public var dadMap:Map<String, Character> = [];
	public var gfMap:Map<String, Character> = [];

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var noteKillOffset:Float = 350;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public static var isPixelStage:Bool = false;
	public static var song:SongDef;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public static var stageTesting:Bool = false;

	public static var stage:Stage;

	public var vocals:FlxSound;

	public static var isSM:Bool = false;
	#if FEATURE_STEPMANIA
	public static var sm:SMFile;
	public static var pathToSm:String;
	#end

	public var opponent:Character;
	public var gf:Character;
	public var boyfriend:Boyfriend;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNoteDef> = [];

	private var strumLine:FlxSprite;

	// Handles the new epic mega sexy cam code that i've done
	private var camFollow:FlxPoint;
	private var camFollowPos:FlxObject;

	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var camZooming:Bool = false;

	public var gfSpeed:Int = 1;
	public var health:Float = 1;
	public var combo:Int = 0;

	private var saveNotes:Array<Array<Any>> = [];
	private var saveJudge:Array<String> = [];
	private var replayAna:Analysis = new Analysis(); // replay analysis

	public static var highestCombo:Int = 0;

	private var healthBarBG:AttachedSprite;

	public var healthBar:FlxBar;

	private var songPercent:Float = 0;

	private var timeBarBG:AttachedSprite;

	public var timeBar:FlxBar;

	// Judgement and ranking variables
	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var campaignSicks:Int = 0;
	public static var campaignGoods:Int = 0;
	public static var campaignBads:Int = 0;
	public static var campaignShits:Int = 0;

	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;
	public var misses:Int = 0;

	public var songScore:Int = 0;
	// TODO Implement songScoreDefault and totalNotesHitDefault (They are songScore and totalNotesHit but they show what they would be if safeFrames is set to 10)
	public var songScoreDefault:Int = 0;
	public var songHits:Int = 0;
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

	private var generatedMusic:Bool = false;

	public var endingSong:Bool = false;
	public var startingSong:Bool = false;

	private var updateTime:Bool = true;

	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	private var dialogue:Array<String> = ['whoops', 'dialogue\'s missing'];
	private var dialogueJson:DialogueDef;

	private var turn:String = '';
	private var focus:String = '';

	private var timeTxt:FlxText;
	private var scoreTxtTween:FlxTween;

	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	public static var rep:Replay;
	public static var loadRep:Bool = false;
	public static var inResults:Bool = false;

	private var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float>;
	public var opponentCameraOffset:Array<Float>;
	public var girlfriendCameraOffset:Array<Float>;

	#if FEATURE_DISCORD
	// Discord RPC variables
	private var storyDifficultyText:String = '';
	private var detailsText:String = '';
	private var detailsPausedText:String = '';
	#end

	// Achievement shit
	private var keysPressed:Array<Bool> = [];
	private var boyfriendIdleTime:Float = 0.0;
	private var boyfriendIdled:Bool = false;

	#if FEATURE_SCRIPTS
	// Script API shit
	public var scriptArray:Array<FunkinScript> = [];
	public var scriptsToClose:Array<FunkinScript> = [];

	private var scriptDebugGroup:FlxTypedGroup<DebugScriptText>;

	public var scriptTweens:Map<String, FlxTween> = [];
	public var scriptSprites:Map<String, ScriptSprite> = [];
	public var scriptTimers:Map<String, FlxTimer> = [];
	public var scriptSounds:Map<String, FlxSound> = [];
	public var scriptTexts:Map<String, ScriptText> = [];
	public var scriptSaves:Map<String, FlxSave> = [];
	#end

	public var introSoundsSuffix:String = '';

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Array<FlxKey>>;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		instance = this;

		debugKeysChart = Options.copyKey(Options.save.data.keyBinds.get('debug_1'));
		debugKeysCharacter = Options.copyKey(Options.save.data.keyBinds.get('debug_2'));
		PauseSubState.songName = null; // Reset to default

		keysArray = [
			Options.copyKey(Options.save.data.keyBinds.get('note_left')),
			Options.copyKey(Options.save.data.keyBinds.get('note_down')),
			Options.copyKey(Options.save.data.keyBinds.get('note_up')),
			Options.copyKey(Options.save.data.keyBinds.get('note_right'))
		];

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		sicks = 0;
		goods = 0;
		bads = 0;
		shits = 0;

		misses = 0;

		highestCombo = 0;
		inResults = false;

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

		Conductor.mapBPMChanges(song);
		Conductor.changeBPM(song.bpm);

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
		Debug.logTrace('Stage is: $curStage');
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
			DAD_X = stage.opponent[0];
			DAD_Y = stage.opponent[1];
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
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
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
						add(dadGroup);
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
				var light:BGSprite = new BGSprite('philly/win$i', -10, 0, 0.3, 0.3);
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
			else if (members.indexOf(dadGroup) < position)
			{
				position = members.indexOf(dadGroup);
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
								tankman.strumTime = animationNote[0];
								tankman.resetShit(500, 200 + FlxG.random.int(50, 100), animationNote[1] < 2);
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
			dadGroup.add(opponent);
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

		if (opponent.id.startsWith('gf'))
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
			var file:String = Paths.json(Path.join(['songs', song.songId, 'dialogue'])); // Checks for json/Psych Engine dialogue
			if (Paths.exists(file))
			{
				dialogueJson = Paths.getJsonDirect(file);
			}

			var file:String = Paths.txt(Path.join(['songs', song.songId, '${song.songId}Dialogue'])); // Checks for vanilla/Senpai dialogue
			if (Paths.exists(file))
			{
				dialogue = CoolUtil.listFromTextFile(file);
			}
			doof = new DialogueBox(dialogue);
			doof.scrollFactor.set();
			doof.finishThing = startCountdown;
		}

		Conductor.songPosition = -5000;

		strumLine = new FlxSprite(Options.save.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if (Options.save.data.downScroll)
			strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();

		var showTime:Bool = (Options.save.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, 32);
		timeTxt.setFormat(Paths.font('vcr.ttf'), timeTxt.size, CENTER, OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = showTime;
		if (Options.save.data.downScroll)
			timeTxt.y = FlxG.height - 44;

		if (Options.save.data.timeBarType == 'Song Name')
		{
			timeTxt.text = song.songName;
		}
		updateTime = showTime;

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height / 4);
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = showTime;
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -4;
		timeBarBG.yAdd = -4;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
		timeBar.numDivisions = 800; // How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		strumLineNotes = new FlxTypedGroup();
		add(strumLineNotes);
		add(grpNoteSplashes);

		if (Options.save.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		opponentStrums = new FlxTypedGroup();
		playerStrums = new FlxTypedGroup();

		generateSong(song.songId);
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

		snapCamFollowToPos(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
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

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		FlxG.fixedTimestep = false;
		moveCameraSection(0);

		healthBarBG = new AttachedSprite('healthBar');
		healthBarBG.y = FlxG.height * 0.89;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.visible = !Options.save.data.hideHud;
		healthBarBG.xAdd = -4;
		healthBarBG.yAdd = -4;
		add(healthBarBG);
		if (Options.save.data.downScroll)
			healthBarBG.y = 0.11 * FlxG.height;

		// HealthBar
		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 2);
		healthBar.scrollFactor.set();
		healthBar.visible = !Options.save.data.hideHud;
		healthBar.alpha = Options.save.data.healthBarAlpha;
		add(healthBar);
		healthBarBG.sprTracker = healthBar;

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !Options.save.data.hideHud;
		iconP1.alpha = Options.save.data.healthBarAlpha;
		add(iconP1);

		iconP2 = new HealthIcon(opponent.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !Options.save.data.hideHud;
		iconP2.alpha = Options.save.data.healthBarAlpha;
		add(iconP2);
		reloadHealthBarColors();

		scoreTxt = new FlxText(0, healthBarBG.y + 36, FlxG.width, 20);
		scoreTxt.setFormat(Paths.font('vcr.ttf'), scoreTxt.size, CENTER, OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !Options.save.data.hideHud;
		add(scoreTxt);

		judgementCounter = new FlxText(20, 0, 0, 'Sicks: ${sicks}\nGoods: ${goods}\nBads: ${bads}\nShits: ${shits}\nMisses: ${misses}\n', 20);
		judgementCounter.setFormat(Paths.font('vcr.ttf'), judgementCounter.size, LEFT, OUTLINE, FlxColor.BLACK);
		judgementCounter.borderSize = 2;
		judgementCounter.borderQuality = 2;
		judgementCounter.scrollFactor.set();
		judgementCounter.cameras = [camHUD];
		judgementCounter.screenCenter(Y);
		if (Options.save.data.showCounters)
		{
			add(judgementCounter);
		}

		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, 'BOTPLAY', 32);
		botplayTxt.setFormat(Paths.font('vcr.ttf'), botplayTxt.size, CENTER, OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = PlayStateChangeables.botPlay;
		add(botplayTxt);
		if (Options.save.data.downScroll)
		{
			botplayTxt.y = timeBarBG.y - 78;
		}

		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		timeBarBG.cameras = [camHUD];
		timeTxt.cameras = [camHUD];
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
				var scriptDirectory:String = Path.join([directory, 'data/songs', song.songId]);
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
			switch (song.songId)
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
					if (song.songId == 'roses')
						FlxG.sound.play(Paths.getSound('ANGRY'));
					schoolIntro(doof);
				case 'ugh':
					inCutscene = true;
					startVideo('ughCutscene');
				case 'guns':
					inCutscene = true;
					startVideo('gunsCutscene');
				case 'stress':
					inCutscene = true;
					startVideo('stressCutscene');
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
		Paths.precacheSound('missnote1');
		Paths.precacheSound('missnote2');
		Paths.precacheSound('missnote3');

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
		DiscordClient.changePresence(detailsText, '${song.songName} ($storyDifficultyText)', iconP2.getCharacter());
		#end

		if (!Options.save.data.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		Conductor.safeZoneOffset = (Options.save.data.safeFrames / 60) * 1000;
		#if FEATURE_SCRIPTS
		callOnScripts('onCreatePost', []);
		#end
	}

	public var paused:Bool = false;

	private var startedCountdown:Bool = false;
	private var canPause:Bool = true;

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

		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, FlxMath.bound(1 - (elapsed * 9), 0, 1));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, FlxMath.bound(1 - (elapsed * 9), 0, 1));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x
			+ (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01))
			+ (150 * iconP1.scale.x - 150) / 2
			- iconOffset;
		iconP2.x = healthBar.x
			+ (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01))
			- (150 * iconP2.scale.x) / 2
			- iconOffset * 2;

		if (health > 2)
			health = 2;

		if (healthBar.percent < 30)
			iconP1.animation.curAnim.curFrame = 1;
		else if (healthBar.percent > 70 && iconP1.hasWinningIcon)
			iconP1.animation.curAnim.curFrame = 2;
		else
			iconP1.animation.curAnim.curFrame = 0;

		if (healthBar.percent > 70)
			iconP2.animation.curAnim.curFrame = 1;
		else if (healthBar.percent < 30 && iconP2.hasWinningIcon)
			iconP2.animation.curAnim.curFrame = 2;
		else
			iconP2.animation.curAnim.curFrame = 0;

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene)
		{
			persistentUpdate = false;
			paused = true;
			cancelMusicFadeTween();
			FlxG.switchState(new CharacterEditorState(song.player2));
			stageTesting = false;
		}

		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += FlxG.elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			Conductor.songPosition += FlxG.elapsed * 1000;

			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
					// Debug.logTrace('MISSED FRAME');
				}

				if (updateTime)
				{
					var curTime:Float = Conductor.songPosition - Options.save.data.noteOffset;
					if (curTime < 0)
						curTime = 0;
					songPercent = (curTime / songLength);

					var songCalc:Float = (songLength - curTime);
					if (Options.save.data.timeBarType == 'Time Elapsed')
						songCalc = curTime;

					var secondsTotal:Int = Math.floor(songCalc / 1000);
					if (secondsTotal < 0)
						secondsTotal = 0;

					if (Options.save.data.timeBarType != 'Song Name')
						timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
				}
			}
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, FlxMath.bound(1 - (elapsed * 3.125), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, FlxMath.bound(1 - (elapsed * 3.125), 0, 1));
		}

		Debug.quickWatch('Boyfriend Stunned', boyfriend.stunned);
		Debug.quickWatch('Health', health);

		Debug.quickWatch('Song Speed', songSpeed);
		Debug.quickWatch('BPM', Conductor.bpm);
		Debug.quickWatch('Beat', curBeat);
		Debug.quickWatch('Step', curStep);
		var curSection:Int = Math.floor(curStep / 16);
		Debug.quickWatch('Section', curSection);

		// RESET = Quick Game Over Screen
		if (Options.save.data.resetKey && controls.RESET && !inCutscene && !endingSong)
		{
			health = 0;
			Debug.logTrace('Reset key killed BF'); // Listen, I don't know how to frickin' word this.
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = 3000; // shit be weird on 4:3
			if (songSpeed < 1)
				time /= songSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if (!inCutscene)
			{
				if (!PlayStateChangeables.botPlay)
				{
					keyShit();
				}
				else if (boyfriend.holdTimer > Conductor.stepCrochet * 0.001 * boyfriend.singDuration
					&& boyfriend.animation.curAnim.name.startsWith('sing')
					&& !boyfriend.animation.curAnim.name.endsWith('miss'))
				{
					boyfriend.dance();
				}
			}

			var fakeCrochet:Float = (60 / song.bpm) * 1000;
			notes.forEachAlive((note:Note) ->
			{
				var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
				if (!note.mustPress)
					strumGroup = opponentStrums;

				var strumX:Float = strumGroup.members[note.noteData].x;
				var strumY:Float = strumGroup.members[note.noteData].y;
				var strumAngle:Float = strumGroup.members[note.noteData].angle;
				var strumDirection:Float = strumGroup.members[note.noteData].direction;
				var strumAlpha:Float = strumGroup.members[note.noteData].alpha;
				var strumScroll:Bool = strumGroup.members[note.noteData].downScroll;

				strumX += note.offsetX;
				strumY += note.offsetY;
				strumAngle += note.offsetAngle;
				strumAlpha *= note.multAlpha;

				if (strumScroll) // Downscroll
				{
					note.distance = (0.45 * (Conductor.songPosition - note.strumTime) * songSpeed);
				}
				else // Upscroll
				{
					note.distance = (-0.45 * (Conductor.songPosition - note.strumTime) * songSpeed);
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
					if (strumScroll && note.isSustainNote)
					{
						if (note.animation.curAnim.name.endsWith('end'))
						{
							note.y += 10.5 * (fakeCrochet / 400) * 1.5 * songSpeed + (46 * (songSpeed - 1));
							note.y -= 46 * (1 - (fakeCrochet / 600)) * songSpeed;
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
					opponentNoteHit(note);
				}

				if (note.mustPress && PlayStateChangeables.botPlay)
				{
					if (note.isSustainNote)
					{
						if (note.canBeHit)
						{
							goodNoteHit(note);
						}
					}
					else if (note.strumTime <= Conductor.songPosition || (note.isSustainNote && note.canBeHit && note.mustPress))
					{
						goodNoteHit(note);
					}
				}

				var center:Float = strumY + Note.STRUM_WIDTH / 2;
				if (strumGroup.members[note.noteData].sustainReduce
					&& note.isSustainNote
					&& (note.mustPress || !note.ignoreNote)
					&& (!note.mustPress || (note.wasGoodHit || (note.prevNote.wasGoodHit && !note.canBeHit))))
				{
					if (strumScroll)
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
				}

				// Kill extremely late notes and cause misses
				if (Conductor.songPosition > noteKillOffset + note.strumTime)
				{
					if (note.mustPress && !PlayStateChangeables.botPlay && !note.ignoreNote && !endingSong && (note.tooLate || !note.wasGoodHit))
					{
						noteMiss(note);
					}

					note.active = false;
					note.visible = false;

					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
			});
		}
		checkEventNote();

		#if debug
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				killNotes();
				FlxG.sound.music.onComplete();
			}
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

	private var preventScriptRemove:Bool = false;

	override public function destroy():Void
	{
		super.destroy();

		preventScriptRemove = true;

		#if FEATURE_SCRIPTS
		for (script in scriptArray)
		{
			script.call('onDestroy', []);
			script.stop();
		}
		scriptArray = [];
		#end

		if (!Options.save.data.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		instance = null;

		FlxG.cameras.reset();
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();

		Debug.logTrace('Lost focus');

		pause();
	}

	override public function onFocus():Void
	{
		super.onFocus();

		Debug.logTrace('Gained focus');

		#if FEATURE_DISCORD
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0.0)
			{
				DiscordClient.changePresence(detailsText, '${song.songName} ($storyDifficultyText)', iconP2.getCharacter(), true,
					songLength - Conductor.songPosition - Options.save.data.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, '${song.songName} ($storyDifficultyText)', iconP2.getCharacter());
			}
		}
		#end
	}

	override public function stepHit(step:Int):Void
	{
		super.stepHit(step);

		if (!Options.save.data.noStage)
			stage.stepHit(step);

		if (Math.abs(FlxG.sound.music.time - (Conductor.songPosition - Conductor.offset)) > 20
			|| (song.needsVoices && Math.abs(vocals.time - (Conductor.songPosition - Conductor.offset)) > 20))
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
			notes.sort(FlxSort.byY, Options.save.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		var section:SectionDef = song.notes[Math.floor(curStep / 16)];

		if (section != null)
		{
			if (section.changeBPM)
			{
				Conductor.changeBPM(section.bpm);
				// Debug.logTrace('Changed BPM to ${section.bpm}');
				#if FEATURE_SCRIPTS
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
				#end
			}
			#if FEATURE_SCRIPTS
			setOnScripts('mustHitSection', section.mustHitSection);
			setOnScripts('altAnim', section.altAnim);
			setOnScripts('gfSection', section.gfSection);
			#end
		}
		// Debug.logTrace('changeBPM: ${section.changeBPM}');

		if (generatedMusic && song.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
		{
			moveCameraSection(Std.int(curStep / 16));
			updateFocusedCharacter();
		}

		if (camZooming && FlxG.camera.zoom < 1.35 && Options.save.data.camZooms && beat % 4 == 0)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

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
		setOnScripts('curBeat', beat); // DAWGG?????
		callOnScripts('onBeatHit', [beat]);
		#end
	}

	#if FEATURE_SCRIPTS
	public function addTextToDebug(text:String):Void
	{
		scriptDebugGroup.forEachAlive((spr:DebugScriptText) ->
		{
			spr.y += 20;
		});

		if (scriptDebugGroup.members.length > 34)
		{
			var blah:DebugScriptText = scriptDebugGroup.members[34];
			if (blah != null) // Why the fuck is it null sometimes?!
				blah.destroy();
			scriptDebugGroup.remove(blah);
		}
		scriptDebugGroup.insert(0, new DebugScriptText(text, scriptDebugGroup));
	}
	#end

	public function reloadHealthBarColors():Void
	{
		healthBar.createFilledBar(FlxColor.fromRGB(opponent.healthBarColors[0], opponent.healthBarColors[1], opponent.healthBarColors[2]),
			FlxColor.fromRGB(boyfriend.healthBarColors[0], boyfriend.healthBarColors[1], boyfriend.healthBarColors[2]));

		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int):Void
	{
		switch (type)
		{
			case 0:
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

			case 1:
				if (!dadMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					#if FEATURE_SCRIPTS
					startCharacterScript(newDad.id);
					#end
				}

			case 2:
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

	private function startCharacterPos(char:Character, ?gfCheck:Bool = false):Void
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
		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);
		if (Paths.exists(fileName, BINARY))
		{
			foundFile = true;
		}

		if (foundFile)
		{
			inCutscene = true;
			var bg:FlxSprite = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);

			bg.scrollFactor.set();
			bg.cameras = [camHUD];
			add(bg);
			new VideoHandler(fileName).finishCallback = () ->
			{
				remove(bg);
				startAndEnd();
			}
			return;
		}
		else
		{
			Debug.logWarn('Couldnt find video file: $fileName');
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

	private var dialogueCount:Int = 0;

	public var psychDialogue:DialogueBoxPsych;

	// You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueDef, ?song:String):Void
	{
		// TODO: Make this more flexible, maybe?
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

		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.getSparrowAtlas('weeb/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();
		senpaiEvil.x += 300;

		if (song.songId == 'roses' || song.songId == 'thorns')
		{
			remove(black);

			if (song.songId == 'thorns')
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
					if (song.songId == 'thorns')
					{
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

	private var startTimer:FlxTimer;
	private var finishTimer:FlxTimer;

	// For being able to mess with the sprites in scripts
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	public static var startOnTime:Float = 0;

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
		var ret:Any = callOnScripts('onStartCountdown', []);
		if (ret != FunkinScript.FUNCTION_STOP)
		#end
		{
			if (skipCountdown || startOnTime > 0)
				skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);
			#if FEATURE_SCRIPTS
			for (i in 0...playerStrums.length)
			{
				setOnScripts('defaultPlayerStrumX$i', playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY$i', playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length)
			{
				setOnScripts('defaultOpponentStrumX$i', opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY$i', opponentStrums.members[i].y);
			}
			#end

			startedCountdown = true;
			Conductor.songPosition = 0;
			Conductor.songPosition -= Conductor.crochet * 5;
			#if FEATURE_SCRIPTS
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted', []);
			#end

			if (skipCountdown || startOnTime > 0)
			{
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 500);
				return;
			}

			startTimer = new FlxTimer().start(Conductor.crochet / 1000, (tmr:FlxTimer) ->
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

				var introAssets:Map<String, Array<String>> = [];
				introAssets.set('default', ['ready', 'set', 'go']);
				introAssets.set('pixel', ['weeb/pixelUI/ready-pixel', 'weeb/pixelUI/set-pixel', 'weeb/pixelUI/date-pixel']);

				var introAlts:Array<String> = introAssets.get('default');
				var antialias:Bool = Options.save.data.globalAntialiasing;
				if (isPixelStage)
				{
					introAlts = introAssets.get('pixel');
					antialias = false;
				}

				var curLoop:Int = tmr.elapsedLoops - 1;

				switch (curLoop)
				{
					case 0:
						FlxG.sound.play(Paths.getSound('intro3$introSoundsSuffix'), 0.6);
					case 1:
						countdownReady = new FlxSprite().loadGraphic(Paths.getGraphic(introAlts[0]));
						countdownReady.scrollFactor.set();
						countdownReady.updateHitbox();

						if (isPixelStage)
							countdownReady.setGraphicSize(Std.int(countdownReady.width * PIXEL_ZOOM));

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						add(countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: (twn:FlxTween) ->
							{
								remove(countdownReady);
								countdownReady.destroy();
							}
						});
						FlxG.sound.play(Paths.getSound('intro2$introSoundsSuffix'), 0.6);
					case 2:
						countdownSet = new FlxSprite().loadGraphic(Paths.getGraphic(introAlts[1]));
						countdownSet.scrollFactor.set();

						if (isPixelStage)
							countdownSet.setGraphicSize(Std.int(countdownSet.width * PIXEL_ZOOM));

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						add(countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: (twn:FlxTween) ->
							{
								remove(countdownSet);
								countdownSet.destroy();
							}
						});
						FlxG.sound.play(Paths.getSound('intro1$introSoundsSuffix'), 0.6);
					case 3:
						countdownGo = new FlxSprite().loadGraphic(Paths.getGraphic(introAlts[2]));
						countdownGo.scrollFactor.set();

						if (isPixelStage)
							countdownGo.setGraphicSize(Std.int(countdownGo.width * PIXEL_ZOOM));

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						add(countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: (twn:FlxTween) ->
							{
								remove(countdownGo);
								countdownGo.destroy();
							}
						});
						FlxG.sound.play(Paths.getSound('introGo$introSoundsSuffix'), 0.6);
					case 4:
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

	public function clearNotesBefore(time:Float):Void
	{
		while (unspawnNotes.length > 0)
		{
			var i:Int = unspawnNotes.length - 1;
			var note:Note = unspawnNotes[i];
			if (note.strumTime - 500 < time)
			{
				note.active = false;
				note.visible = false;
				note.ignoreNote = true;

				note.kill();
				unspawnNotes.remove(note);
				note.destroy();
			}
		}

		while (notes.length > 0)
		{
			var i:Int = notes.length - 1;
			var note:Note = notes.members[i];
			if (note.strumTime - 500 < time)
			{
				note.active = false;
				note.visible = false;
				note.ignoreNote = true;

				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
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

	// TODO Do whatever Kade does with this variable
	public static var songMultiplier:Float = 1.0;

	private var previousFrameTime:Int = 0;
	private var songTime:Float = 0;

	private function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;

		FlxG.sound.playMusic(Paths.getInst(song.songId), 1, false);
		FlxG.sound.music.onComplete = onSongComplete;
		// Destroys the music after it plays, so it doesn't continue playing in the Freeplay menu and crash the game when running the callback
		FlxG.sound.music.autoDestroy = true;
		vocals.play();
		vocals.autoDestroy = true;

		if (startOnTime > 0)
		{
			setSongTime(startOnTime - 500);
		}
		startOnTime = 0;

		if (paused)
		{
			// Debug.logTrace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, '${song.songName} ($storyDifficultyText)', iconP2.getCharacter(), true, songLength);
		#end

		#if FEATURE_SCRIPTS
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart', []);
		#end
	}

	private var noteTypeMap:Map<String, Bool> = [];
	private var eventPushedMap:Map<String, Bool> = [];

	private function generateSong(dataPath:String):Void
	{
		switch (PlayStateChangeables.scrollType)
		{
			case 'multiplicative':
				songSpeed = song.speed * PlayStateChangeables.scrollSpeed;
			case 'constant':
				songSpeed = PlayStateChangeables.scrollSpeed;
		}

		Conductor.changeBPM(song.bpm);

		vocals = new FlxSound();
		if (song.needsVoices #if FEATURE_STEPMANIA && !isSM #end)
		{
			vocals.loadEmbedded(Paths.getVoices(song.songId));
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
			Paths.precacheAudioDirect(Paths.inst(song.songId));
		}

		notes = new FlxTypedGroup();
		add(notes);

		var sections:Array<SectionDef> = song.notes;

		var file:String = Paths.json(Path.join(['songs', song.songId, 'events']));
		if (Paths.exists(file))
		{
			var eventsSong:SongDef = Song.getSongDef('events', '', song.songId);
			for (event in eventsSong.events) // Event Notes
			{
				// TODO Simplify this 'for' loop
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Any> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNoteDef = {
						strumTime: newEventNote[0] + Options.save.data.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}

		for (section in sections)
		{
			for (noteArray in section.sectionNotes)
			{
				var strumTime:Float = noteArray[0];
				var noteData:Int = Std.int(noteArray[1] % 4);
				var mustHitSection:Bool = section.mustHitSection;
				if (noteArray[1] > 3)
				{
					mustHitSection = !section.mustHitSection;
				}
				var oldNote:Null<Note> = null;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[unspawnNotes.length - 1];
				var note:Note = new Note(strumTime, noteData, oldNote);
				note.mustPress = mustHitSection;
				note.sustainLength = noteArray[2];
				note.gfNote = (section.gfSection && (noteArray[1] < 4));
				if (Std.isOfType(noteArray[3], String))
				{
					note.noteType = noteArray[3];
				}
				else
				{
					note.noteType = ChartingState.NOTE_TYPES[Std.int(noteArray[3])]; // Backward compatibility + compatibility with Week 7 charts
				}
				note.scrollFactor.set();
				var sustainLength:Float = note.sustainLength / Conductor.stepCrochet;
				unspawnNotes.push(note);
				var floorSustain:Int = Math.floor(sustainLength);

				if (floorSustain > 0)
				{
					for (susNote in 0...floorSustain + 1)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];
						var sustainNote:Note = new Note(strumTime
							+ (Conductor.stepCrochet * susNote)
							+ (Conductor.stepCrochet / FlxMath.roundDecimal(songSpeed, 2)), noteData, oldNote,
							true);

						sustainNote.mustPress = mustHitSection;
						sustainNote.gfNote = (section.gfSection && (noteArray[1] < 4));
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
		for (event in song.events) // Event Notes
		{
			// TODO Simplify this 'for' loop, too
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Any> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];

				var subEvent:EventNoteDef = {
					strumTime: newEventNote[0] + Options.save.data.noteOffset,
					event: newEventNote[1],
					value1: newEventNote[2],
					value2: newEventNote[3]
				};
				subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
				eventNotes.push(subEvent);
				eventPushed(subEvent);
			}
		}
		// Debug.logTrace(unspawnNotes.length);
		unspawnNotes.sort(sortByShit);
		if (eventNotes.length > 1)
		{
			// No need to sort if there's a single one or none at all
			eventNotes.sort(sortByTime);
		}
		checkEventNote();
		generatedMusic = true;
	}

	private function eventPushed(event:EventNoteDef):Void
	{
		switch (event.event)
		{
			case 'Change Character':
				var charType:Int = 0;
				switch (event.value1.toLowerCase())
				{
					case 'gf' | 'girlfriend' | '2':
						charType = 2;
					case 'dad' | 'opponent' | '1':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if (Math.isNaN(charType)) charType = 0;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);
		}

		if (!eventPushedMap.exists(event.event))
		{
			eventPushedMap.set(event.event, true);
		}
	}

	private function eventNoteEarlyTrigger(event:EventNoteDef):Float
	{
		#if FEATURE_SCRIPTS
		var returnedValue:Float = callOnScripts('eventEarlyTrigger', [event.event]);
		if (returnedValue != 0)
		{
			return returnedValue;
		}
		#end

		switch (event.event)
		{
			case 'Kill Henchmen': // Better timing so that the kill sound matches the beat intended
				return 280; // Plays 280ms before the actual position
		}
		return 0;
	}

	private function sortByShit(obj1:Note, obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.strumTime, obj2.strumTime);
	}

	private function sortByTime(obj1:EventNoteDef, obj2:EventNoteDef):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.strumTime, obj2.strumTime);
	}

	public var skipArrowStartTween:Bool = false; // for script API

	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if (player < 1 && Options.save.data.middleScroll)
				targetAlpha = 0.35;

			var babyArrow:StrumNote = new StrumNote(Options.save.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player);
			babyArrow.downScroll = Options.save.data.downScroll;
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
			var ret:Any = callOnScripts('onPause', []);
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
					if (FlxG.sound.music != null && FlxG.sound.music.playing)
						FlxG.sound.music.pause();
					if (vocals != null && vocals.playing)
						vocals.pause();

					Debug.logTrace('Current tick: ${FlxG.game.ticks}');
					openSubState(new PauseSubState());
				}

				#if FEATURE_DISCORD
				DiscordClient.changePresence(detailsPausedText, '${song.songName} ($storyDifficultyText)', iconP2.getCharacter());
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
			DiscordClient.changePresence(detailsText, '${song.songName} ($storyDifficultyText)', iconP2.getCharacter(), true,
				songLength - Conductor.songPosition - Options.save.data.noteOffset);
		}
		else
		{
			DiscordClient.changePresence(detailsText, '${song.songName} ($storyDifficultyText)', iconP2.getCharacter());
		}
		#end
	}

	private function resyncVocals():Void
	{
		if (finishTimer != null)
			return;

		vocals.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();
	}

	private function openChartEditor():Void
	{
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		FlxG.switchState(new ChartingState());
		stageTesting = false;
		chartingMode = true;

		#if FEATURE_DISCORD
		DiscordClient.changePresence('Chart Editor', null, null, true);
		#end
	}

	public var isDead:Bool = false; // Don't mess with this in scripts!!!

	private function doDeathCheck(?skipHealthCheck:Bool = false):Bool
	{
		if (((skipHealthCheck && PlayStateChangeables.instakillOnMiss) || health <= 0) && !PlayStateChangeables.practiceMode && !isDead)
		{
			#if FEATURE_SCRIPTS
			var ret:Any = callOnScripts('onGameOver', []);
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
				DiscordClient.changePresence('Game Over - $detailsText', '${song.songName} ($storyDifficultyText)', iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote():Void
	{
		while (eventNotes.length > 0)
		{
			var strumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < strumTime)
			{
				break;
			}

			var value1:String = '';
			if (eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if (eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEventNote(eventNotes[0].event, value1, value2);
			eventNotes.shift();
		}
	}

	public function getControl(key:String):Bool
	{
		var pressed:Bool = Reflect.getProperty(controls, key);
		Debug.logTrace('Control result: $pressed');
		return pressed;
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String):Void
	{
		switch (eventName)
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
					if (opponent.id.startsWith('gf'))
					{ // Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						opponent.playAnim('cheer', true);
						opponent.specialAnim = true;
						opponent.heyTimer = time;
					}
					else if (gf != null)
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

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Trigger BG Ghouls':
				// TODO Move this to the Stage class
				if (stage.id == 'schoolEvil' && !Options.save.data.lowQuality)
				{
					var bgGhouls:BGSprite = stage.layers['bgGhouls'];
					bgGhouls.dance(true);
					bgGhouls.visible = true;
				}

			case 'Play Animation':
				// Debug.logTrace('Animation to play: $value1');
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
				var charType:Int = 0;
				switch (value1)
				{
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if (Math.isNaN(charType)) charType = 0;
				}

				switch (charType)
				{
					case 0:
						if (boyfriend.id != value2)
						{
							if (!boyfriendMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						#if FEATURE_SCRIPTS
						setOnScripts('boyfriendName', boyfriend.id);
						#end

					case 1:
						if (opponent.id != value2)
						{
							if (!dadMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = opponent.id.startsWith('gf');
							var lastAlpha:Float = opponent.alpha;
							opponent.alpha = 0.00001;
							opponent = dadMap.get(value2);
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
							iconP2.changeIcon(opponent.healthIcon);
						}
						#if FEATURE_SCRIPTS
						setOnScripts('dadName', opponent.id);
						#end

					case 2:
						if (gf != null)
						{
							if (gf.id != value2)
							{
								if (!gfMap.exists(value2))
								{
									addCharacterToList(value2, charType);
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
		}
		#if FEATURE_SCRIPTS
		callOnScripts('onEvent', [eventName, value1, value2]);
		#end
	}

	private function moveCameraSection(?id:Int = 0):Void
	{
		if (song.notes[id] == null)
			return;

		if (gf != null && song.notes[id].gfSection)
		{
			camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
			camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
			tweenCamIn();
			#if FEATURE_SCRIPTS
			callOnScripts('onMoveCamera', ['gf']);
			#end
			return;
		}

		if (song.notes[id].mustHitSection)
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

	private var cameraTwn:FlxTween;

	public function moveCamera(isDad:Bool):Void
	{
		if (isDad)
		{
			camFollow.set(opponent.getMidpoint().x + 150, opponent.getMidpoint().y - 100);
			camFollow.x += opponent.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += opponent.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (song.songId == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {
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
		if (song.songId == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3)
		{
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {
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
	}

	// Any way to do this without using a different function? kinda dumb
	private function onSongComplete():Void
	{
		finishSong(false);
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
			finishTimer = new FlxTimer().start(Options.save.data.noteOffset / 1000, (tmr:FlxTimer) ->
			{
				finishCallback();
			});
		}
	}

	public var transitioning:Bool = false;

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
					health -= 0.05 * PlayStateChangeables.healthLoss;
				}
			});
			for (note in unspawnNotes)
			{
				if (note.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= 0.05 * PlayStateChangeables.healthLoss;
				}
			}

			if (doDeathCheck())
			{
				return;
			}
		}

		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
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
		var ret:Any = callOnScripts('onEndSong', []);
		#end
		if (#if FEATURE_SCRIPTS ret != FunkinScript.FUNCTION_STOP && #end!transitioning)
		{
			if (song.validScore && !PlayStateChangeables.practiceMode && !PlayStateChangeables.botPlay)
			{
				#if !switch
				var percent:Float = ratingPercent;
				if (Math.isNaN(percent))
					percent = 0;
				Highscore.saveScore(song.songId, songScore, storyDifficulty, percent);
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
				campaignScore += songScore;
				campaignMisses += misses;
				campaignSicks += sicks;
				campaignGoods += goods;
				campaignBads += bads;
				campaignShits += shits;

				storyPlaylist.remove(storyPlaylist[0]);

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
							FlxTween.tween(timeTxt, {alpha: 0}, 1);
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
							Debug.logTrace(Week.getCurrentWeekId());
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

					var winterHorrorlandNext:Bool = song.songId == 'eggnog';
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
	private var achievement:Achievement;

	private function startAchievement(achieve:String):Void
	{
		achievement = new Achievement(achieve);
		achievement.onFinish = achievementEnd;
		achievement.cameras = [camOther];
		add(achievement);
		Debug.logTrace('Giving achievement $achieve');
	}

	private function achievementEnd():Void
	{
		achievement = null;
		Debug.logTrace('Achievement end; endingSong: $endingSong, inCutscene: $inCutscene');
		if (endingSong && !inCutscene)
		{
			endSong();
		}
	}
	#end

	public function killNotes():Void
	{
		while (notes.length > 0)
		{
			var note:Note = notes.members[0];
			note.active = false;
			note.visible = false;

			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	private function popUpScore(?note:Note):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + Options.save.data.ratingOffset);

		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(FlxG.width * 0.35, 0, 0, placement, 32);
		coolText.screenCenter(Y);

		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		// tryna do MS based judgment due to popular demand
		var ratingName:String = Ratings.judgeNote(noteDiff);

		switch (ratingName)
		{
			case 'shit': // shit
				totalNotesHit += 0;
				note.ratingMod = 0;
				score = 50;
				if (!note.ratingDisabled)
					shits++;
			case 'bad': // bad
				totalNotesHit += 0.5;
				note.ratingMod = 0.5;
				score = 100;
				if (!note.ratingDisabled)
					bads++;
			case 'good': // good
				totalNotesHit += 0.75;
				note.ratingMod = 0.75;
				score = 200;
				if (!note.ratingDisabled)
					goods++;
			case 'sick': // sick
				totalNotesHit += 1;
				note.ratingMod = 1;
				if (!note.ratingDisabled)
					sicks++;
				if (!note.noteSplashDisabled)
					spawnNoteSplashOnNote(note);
		}
		note.rating = ratingName;

		songScore += score;
		if (!note.ratingDisabled)
		{
			songHits++;
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

		var pixelShitPart1:String = '';
		var pixelShitPart2:String = '';

		if (isPixelStage)
		{
			pixelShitPart1 = 'weeb/pixelUI';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.getGraphic(Path.join([pixelShitPart1, '$ratingName$pixelShitPart2'])));
		rating.cameras = [camHUD];
		rating.screenCenter();
		rating.x = coolText.x - 40 + Options.save.data.comboOffset[0];
		rating.y -= 60 + Options.save.data.comboOffset[1];
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.visible = (!Options.save.data.hideHud && showRating);

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join([pixelShitPart1, 'combo$pixelShitPart2'])));
		comboSpr.cameras = [camHUD];
		comboSpr.screenCenter();
		comboSpr.x = coolText.x + Options.save.data.comboOffset[0];
		comboSpr.y -= Options.save.data.comboOffset[1];
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.x += FlxG.random.int(1, 10);
		comboSpr.velocity.y -= 150;
		comboSpr.visible = (!Options.save.data.hideHud && showCombo);

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
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join([pixelShitPart1, 'num$digit$pixelShitPart2'])));
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
				startDelay: Conductor.crochet * 0.002
			});
		}

		coolText.text = separatedScore.join('');

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: (tween:FlxTween) ->
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		// Debug.logTrace('Pressed: $eventKey');

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
				sortedNotesList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				if (sortedNotesList.length > 0)
				{
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes)
						{
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
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}
					}
				}
				else if (canMiss)
				{
					noteMissPress(key);
					#if FEATURE_SCRIPTS
					callOnScripts('noteMissPress', [key]);
					#end
				}

				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				keysPressed[key] = true;

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
		// Debug.logTrace('Pressed: $controlArray');
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
		// Debug.logTrace('Released: $controlArray');
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

	// Hold notes
	private function keyShit():Void
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

		var anas:Array<Ana> = [null, null, null, null];

		for (i in 0...controlPressArray.length)
			if (controlPressArray[i])
				anas[i] = new Ana(Conductor.songPosition, null, false, 'miss', i);

		if (!boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			notes.forEachAlive((note:Note) ->
			{
				// hold note functions
				if (note.isSustainNote && controlHoldArray[note.noteData] && note.canBeHit && note.mustPress && !note.tooLate && !note.wasGoodHit)
				{
					goodNoteHit(note);
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
			else if (boyfriend.holdTimer > Conductor.stepCrochet * 0.001 * boyfriend.singDuration
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
			// Debug.logTrace('Checking ${Math.round(i[0])} against ${Math.round(time)}');
			if (i[0] == time)
				return i;
		}
		return null;
	}

	public function findByTimeIndex(time:Float):Int
	{
		for (i in 0...rep.replay.songNotes.length)
		{
			// Debug.logTrace('Checking ${Math.round(i[0])} against ${Math.round(time)}');
			if (rep.replay.songNotes[i][0] == time)
				return i;
		}
		return -1;
	}

	private function noteMiss(missedNote:Note):Void
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
			vocals.stop();
			doDeathCheck(true);
		}

		var direction:Int = missedNote.noteData;

		if (!loadRep)
		{
			saveNotes.push([
				missedNote.strumTime,
				0,
				direction,
				-(166 * Math.floor((rep.replay.sf / 60) * 1000) / 166)
			]);
			saveJudge.push('miss');
		}

		misses++;
		vocals.volume = 0;
		if (!PlayStateChangeables.practiceMode)
			songScore -= 10;

		totalPlayed++;
		recalculateRating();

		var char:Character = boyfriend;
		if (missedNote.gfNote)
		{
			char = gf;
		}

		if (char != null && char.hasMissAnimations)
		{
			var altSuffix:String = '';
			if (missedNote.noteType == 'Alt Animation')
				altSuffix = '-alt';

			var animToPlay:String = 'sing${NoteKey.createByIndex(missedNote.noteData)}miss$altSuffix';
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

	private function noteMissPress(direction:Int = 1):Void // You pressed a key when there was no notes to press for this key
	{
		if (!boyfriend.stunned)
		{
			health -= 0.05 * PlayStateChangeables.healthLoss;
			if (PlayStateChangeables.instakillOnMiss)
			{
				vocals.volume = 0;
				doDeathCheck(true);
			}

			if (Options.save.data.ghostTapping)
				return;

			if (combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			if (!PlayStateChangeables.practiceMode)
				songScore -= 10;
			if (!endingSong)
			{
				misses++;
			}
			totalPlayed++;
			recalculateRating();

			FlxG.sound.play(Paths.getRandomSound('missnote', 1, 3), FlxG.random.float(0.1, 0.2));

			// TODO Test this out?
			/*
				boyfriend.stunned = true;

				// get stunned for 1/60 of a second, makes you able to
				new FlxTimer().start(1 / 60, (tmr:FlxTimer) ->
				{
					boyfriend.stunned = false;
				});
			 */

			if (boyfriend.hasMissAnimations)
			{
				boyfriend.playAnim('sing${NoteKey.createByIndex(direction)}miss', true);
				updateDirectionalCamera();
			}
			vocals.volume = 0;
		}
	}

	private function opponentNoteHit(note:Note):Void
	{
		if (song.songId != 'tutorial')
			camZooming = true;

		if (note.noteType == 'Hey!' && opponent.animOffsets.exists('hey'))
		{
			opponent.playAnim('hey', true);
			opponent.specialAnim = true;
			opponent.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
			var altAnim:String = '';

			var curSection:Int = Math.floor(curStep / 16);
			if (song.notes[curSection] != null)
			{
				if (song.notes[curSection].altAnim || note.noteType == 'Alt Animation')
				{
					altAnim = '-alt';
				}
			}

			var char:Character = opponent;
			var animToPlay:String = 'sing${NoteKey.createByIndex(note.noteData)}$altAnim';
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
		strumPlayAnim(true, note.noteData % 4, time);
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

	// TODO Optimize this so it doesn't lag the fuck out of Polymod
	private function goodNoteHit(note:Note):Void
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
				noteMiss(note);
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
				var altSuffix:String = '';
				if (note.noteType == 'Alt Animation')
					altSuffix = '-alt';

				var animToPlay:String = 'sing${NoteKey.createByIndex(note.noteData)}';

				if (note.gfNote)
				{
					if (gf != null)
					{
						gf.playAnim(animToPlay + altSuffix, true);
						gf.holdTimer = 0;
						updateDirectionalCamera();
					}
				}
				else
				{
					boyfriend.playAnim(animToPlay + altSuffix, true);
					boyfriend.holdTimer = 0;
					updateDirectionalCamera();
				}

				if (note.noteType == 'Hey!')
				{
					if (boyfriend.animOffsets.exists('hey'))
					{
						boyfriend.playAnim('hey', true);
						boyfriend.specialAnim = true;
						boyfriend.heyTimer = 0.6;
					}

					if (gf != null && gf.animOffsets.exists('cheer'))
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
				strumPlayAnim(false, note.noteData % 4, time);
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

	// TODO Make it possible to have certain notes (e.g. mines) force notesplashes
	private function spawnNoteSplashOnNote(note:Note):Void
	{
		if (Options.save.data.noteSplashes && note != null)
		{
			var strum:StrumNote = playerStrums.members[note.noteData];
			if (strum != null)
			{
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note):Void
	{
		var skin:String = 'noteSplashes';
		if (song.splashSkin != null && song.splashSkin.length > 0)
			skin = song.splashSkin;

		var hue:Float = Options.save.data.arrowHSV[data % 4][0] / 360;
		var sat:Float = Options.save.data.arrowHSV[data % 4][1] / 100;
		var brt:Float = Options.save.data.arrowHSV[data % 4][2] / 100;
		if (note != null)
		{
			skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin, hue, sat, brt);
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

	#if FEATURE_SCRIPTS
	public function removeScript(script:FunkinScript):Void
	{
		if (scriptArray != null && !preventScriptRemove)
		{
			scriptArray.remove(script);
		}
	}
	#end

	public function updateFocusedCharacter():Void
	{
		if (song.notes[Std.int(curStep / 16)].mustHitSection)
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
			// FIXME Stuff like the ChallengEdd port's camera during the Eduardo bit don't work properly when this function is resetting the camera position constantly
			moveCameraSection(Std.int(curStep / 16)); // Reset the directional camera to be in the middle

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
					// Debug.logTrace('Camera is following animation "${focusedChar.animation.curAnim.name}" for ${focus}');
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
	public function callOnScripts(event:String, args:Array<Any>):Any
	{
		var returnVal:Any = FunkinScript.FUNCTION_CONTINUE;
		for (script in scriptArray)
		{
			var ret:Any = script.call(event, args);
			if (ret != FunkinScript.FUNCTION_CONTINUE)
			{
				returnVal = ret;
			}
		}

		for (script in scriptsToClose)
		{
			scriptArray.remove(script);
			script.stop();
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
		setOnScripts('score', songScore);
		setOnScripts('misses', misses);
		setOnScripts('hits', songHits);

		var ret:Any = callOnScripts('onRecalculateRating', []);
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
				// Debug.logTrace('$ratingPercent, Total notes: $totalPlayed, Notes hit: $totalNotesHit');

				// Rating Name
				ratingName = Ratings.generateLetterRank(ratingPercent);
			}

			// Rating FC
			ratingFC = Ratings.generateComboRank();

			scoreTxt.text = Ratings.calculateRanking(songScore, songScoreDefault, nps, maxNPS, ratingPercent);
			judgementCounter.text = 'Sicks: ${sicks}\nGoods: ${goods}\nBads: ${bads}\nShits: ${shits}\nMisses: ${misses}\n';
		}

		#if FEATURE_SCRIPTS
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		#end
	}

	#if FEATURE_ACHIEVEMENTS
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
						if (/*Options.save.data.frameRate <= 60 &&*/ Options.save.data.lowQuality
							&& !Options.save.data.globalAntialiasing
							&& !Options.save.data.imagesPersist)
						{
							unlock = true;
						}
					case 'debugger':
						if (song.songId == 'test' && !usedPractice)
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

	private function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
		{
			var ratio:Float = value / songSpeed; // funny word huh
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
		return value;
	}
}

#if FEATURE_SCRIPTS
private var curLight:Int = 0;
private var blammedLightsBlack:ScriptSprite;
private var blammedLightsBlackTween:FlxTween;
private var phillyCityLightsEventTween:FlxTween;
#end
