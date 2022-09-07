package funkin.states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.addons.ui.FlxUIState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import openfl.Lib;
#if FEATURE_DISCORD
import funkin.Discord.DiscordClient;
#end
#if CHARTING
import funkin.states.editors.ChartEditorState;
#elseif CHARACTER
import funkin.states.editors.CharacterEditorState;
#end

class InitState extends FlxUIState
{
	public static var muteKeys:Array<FlxKey> = [ZERO, NUMPADZERO];
	public static var volumeDownKeys:Array<FlxKey> = [MINUS, NUMPADMINUS];
	public static var volumeUpKeys:Array<FlxKey> = [PLUS, NUMPADPLUS];

	override public function create():Void
	{
		super.create();

		// FlxG.log.redirectTraces = true;

		EngineData.bindSave('funkin', 'ninjamuffin99');

		Options.bindSave();
		Options.flushSave(); // Save initialized options

		Conductor.initializeSafeZoneOffset(); // Now that the options are loaded, this can be initialized

		PlayerSettings.init();

		HighScore.load();

		// FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;

		if (EngineData.save.data.fullscreen != null)
		{
			FlxG.fullscreen = EngineData.save.data.fullscreen;
		}

		if (EngineData.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = EngineData.save.data.weekCompleted;
		}

		if (Options.profile.frameRate < 30 || Options.profile.frameRate > 360)
		{
			Options.profile.frameRate = 120;
		}

		Lib.current.stage.frameRate = Options.profile.frameRate;

		#if FEATURE_DISCORD
		DiscordClient.initialize();
		#end

		// FlxG.fixedTimestep = false;
		FlxG.mouse.visible = false;

		#if web
		FlxG.autoPause = true;
		#else
		FlxG.autoPause = false;
		#end

		// Initialize the EngineData.latestVersion property
		EngineData.fetchLatestVersion();

		initTransition();

		var nextState:FlxState;
		#if FREEPLAY
		nextState = new FreeplayState();
		#elseif CHARTING
		nextState = new ChartEditorState();
		#elseif CHARACTER
		nextState = new CharacterEditorState();
		#else
		nextState = new TitleState();
		#end

		// This state isn't visible anyway, so a transition from it to TitleState is pointless and wastes time
		transIn = null;
		transOut = null;

		FlxG.switchState(nextState);
	}

	public static function initTransition():Void
	{
		var diamond:FlxGraphic = FlxGraphic.fromClass(GraphicTransTileDiamond);
		diamond.persist = true;
		diamond.destroyOnNoUse = false;
		FlxTransitionableState.defaultTransIn = new TransitionData(FADE, FlxColor.BLACK, 1, new FlxPoint(0, -1), {asset: diamond, width: 32, height: 32},
			new FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4));
		FlxTransitionableState.defaultTransOut = new TransitionData(FADE, FlxColor.BLACK, 0.7, new FlxPoint(0, 1), {asset: diamond, width: 32, height: 32},
			new FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4));
	}
}
