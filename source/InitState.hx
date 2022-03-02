package;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;
import openfl.display.FPSMem;
import options.Options.OptionUtils;
import options.OptionsSubState;

class InitState extends FlxUIState
{
	public static var muteKeys:Array<FlxKey> = [ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [NUMPADMINUS, MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [NUMPADPLUS, PLUS];

	public static function initTransition()
	{ // TRANS RIGHTS
		// FlxTransitionableState.defaultTransIn = FadeTransitionSubState;
		// FlxTransitionableState.defaultTransOut = FadeTransitionSubState;
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		OptionUtils.bindSave();
		OptionUtils.loadOptions(OptionUtils.options);
		var currentOptions = OptionUtils.options;

		FPSMem.showFPS = currentOptions.showFPS;
		FPSMem.showMem = currentOptions.showMem;
		FPSMem.showMemPeak = currentOptions.showMemPeak;

		ClientPrefs.loadDefaultKeys();

		if (currentOptions.keyBinds == null)
			currentOptions.keyBinds = ClientPrefs.defaultKeys.copy();

		PlayerSettings.init();
		new OptionsSubState().createDefault(); // Load default options in case any are null

		FlxG.save.bind('funkin', 'ninjamuffin99');
		Highscore.load();

		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.sound.volume = FlxG.save.data.volume;
		FlxG.keys.preventDefaultKeys = [TAB];

		FlxG.sound.volumeHandler = function(volume:Float)
		{
			FlxG.save.data.volume = volume;
		}

		// #if !FORCED_JUDGE
		// if (!JudgementManager.dataExists(currentOptions.judgementWindow))
		// {
		// 	OptionUtils.options.judgementWindow = 'Andromeda';
		// 	OptionUtils.saveOptions(OptionUtils.options);
		// }
		// #end

		// FlxGraphic.defaultPersist = currentOptions.cacheUsedImages;

		if (FlxG.save.data != null && FlxG.save.data.fullscreen)
		{
			FlxG.fullscreen = FlxG.save.data.fullscreen;
			// trace('LOADED FULLSCREEN SETTING!!');
		}

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
		DiscordClient.initialize();

		Application.current.onExit.add(function(exitCode)
		{
			DiscordClient.shutdown();
		});
		#end

		var canCache = false;
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

		FlxG.fixedTimestep = false;

		var nextState:FlxUIState = new TitleState();
		// if (currentOptions.shouldCache && canCache)
		// {
		// 	nextState = new CachingState(nextState);
		// }
		// else
		{
			initTransition();
		}

		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#elseif CHARACTER
		FlxG.switchState(new CharacterEditorState('bf', nextState));
		#else
		FlxG.switchState(nextState);
		#end
	}
}
