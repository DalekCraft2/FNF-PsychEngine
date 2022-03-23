package;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.TransitionData;
import flixel.addons.ui.FlxUIState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import lime.app.Application;

class InitState extends FlxUIState
{
	public static var muteKeys:Array<FlxKey> = [ZERO, NUMPADZERO];
	public static var volumeDownKeys:Array<FlxKey> = [MINUS, NUMPADMINUS];
	public static var volumeUpKeys:Array<FlxKey> = [PLUS, NUMPADPLUS];

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

	override public function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		super.create();

		Options.bindOptions(); //
		Options.fillMissingOptionFields(); // Load default options in case any are null
		Options.saveOptions(); // Save initialized options

		Conductor.initializeSafeZoneOffset(); // Now that the options are loaded, this can be initialized

		PlayerSettings.init();

		FlxG.save.bind('funkin', 'ninjamuffin99');
		Highscore.load();

		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

		FlxG.sound.volumeHandler = (volume:Float) ->
		{
			FlxG.save.data.volume = volume;
		}
		if (FlxG.save.data.volume != null)
		{
			FlxG.sound.volume = FlxG.save.data.volume;
		}
		if (FlxG.save.data.mute != null)
		{
			FlxG.sound.muted = FlxG.save.data.mute;
		}
		if (FlxG.save.data.fullscreen != null)
		{
			FlxG.fullscreen = FlxG.save.data.fullscreen;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		if (Options.save.data.framerate < 30 || Options.save.data.framerate > 360)
		{
			Options.save.data.framerate = 120;
		}

		Main.setFPSCap(Options.save.data.framerate);

		#if FEATURE_DISCORD
		if (!DiscordClient.isInitialized)
		{
			DiscordClient.initialize();
			Application.current.onExit.add((exitCode) ->
			{
				DiscordClient.shutdown();
			});
		}
		#end

		// FlxGraphic.defaultPersist = Options.save.data.persistentImages;

		FlxG.fixedTimestep = false;
		FlxG.autoPause = false;

		#if html5
		// FlxG.autoPause = true;
		FlxG.mouse.visible = false;
		#end

		var canCache:Bool = false;
		#if sys
		#if cpp // IDK IF YOU CAN DO "#IF SYS AND CPP" OR THIS'LL WORK I THINK
		canCache = true;
		#end
		#end
		if (canCache)
		{
			if (!Options.save.data.cacheCharacters && !Options.save.data.cacheSongs && !Options.save.data.cacheSounds && !Options.save.data.cachePreload)
				canCache = false;
		}

		var nextState:FlxUIState = new TitleState();
		// TODO Implement caching
		/*#if sys
			if (Options.save.data.shouldCache && canCache)
			{
				nextState = new Caching(nextState);
			}
			else
			#end */
		{
			initTransition();
		}

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		#if FREEPLAY
		FlxG.switchState(new FreeplayState());
		#elseif CHARTING
		FlxG.switchState(new ChartingState());
		#elseif CHARACTER
		FlxG.switchState(new CharacterEditorState('bf', nextState));
		#else
		FlxG.switchState(nextState);
		#end
	}
}
