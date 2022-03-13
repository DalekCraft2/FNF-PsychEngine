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
import openfl.display.FPSMem;
import options.Options.OptionUtils;
import options.OptionsSubState;

class InitState extends FlxUIState
{
	public static var muteKeys:Array<FlxKey> = [ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [NUMPADMINUS, MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [NUMPADPLUS, PLUS];

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

	override function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		OptionUtils.bindSave();
		OptionUtils.loadOptions(OptionUtils.options);
		var currentOptions:Dynamic = OptionUtils.options;

		FPSMem.showFPS = currentOptions.showFPS;
		FPSMem.showMem = currentOptions.showMem;
		FPSMem.showMemPeak = currentOptions.showMemPeak;

		ClientPrefs.loadDefaultKeys();

		if (currentOptions.keyBinds == null)
		{
			Debug.logInfo('Keybinds are null; setting them to defaults (${ClientPrefs.defaultKeys})');
			currentOptions.keyBinds = ClientPrefs.defaultKeys.copy();
		}

		PlayerSettings.init();
		new OptionsSubState().createDefault(); // Load default options in case any are null
		OptionUtils.saveOptions(currentOptions); // Save initialized options

		FlxG.save.bind('funkin', 'ninjamuffin99');
		Highscore.load();

		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

		FlxG.sound.volumeHandler = function(volume:Float):Void
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

		// #if !FORCED_JUDGE
		// if (!JudgementManager.dataExists(currentOptions.judgementWindow))
		// {
		// 	OptionUtils.options.judgementWindow = 'Andromeda';
		// 	OptionUtils.saveOptions(OptionUtils.options);
		// }
		// #end

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		if (currentOptions.fps < 30 || currentOptions.fps > 360)
		{
			currentOptions.fps = 120;
		}

		Main.setFPSCap(currentOptions.fps);
		super.create();

		#if FEATURE_DISCORD
		if (!DiscordClient.isInitialized)
		{
			DiscordClient.initialize();
			Application.current.onExit.add(function(exitCode):Void
			{
				DiscordClient.shutdown();
			});
		}
		#end

		// FlxGraphic.defaultPersist = currentOptions.persistentImages;

		FlxG.fixedTimestep = false;

		var canCache:Bool = false;
		#if sys
		#if cpp // IDK IF YOU CAN DO "#IF SYS AND CPP" OR THIS'LL WORK I THINK
		canCache = true;
		#end
		#end
		if (canCache)
		{
			if (!currentOptions.cacheCharacters && !currentOptions.cacheSongs && !currentOptions.cacheSounds && !currentOptions.cachePreload)
				canCache = false;
		}

		var nextState:FlxUIState = new TitleState();
		// TODO Implement caching
		/*#if sys
			if (currentOptions.shouldCache && canCache)
			{
				nextState = new Caching(nextState);
			}
			else
			#end */
		{
			initTransition();
		}

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
