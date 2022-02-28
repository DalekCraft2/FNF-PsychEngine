package;

import options.*;
import options.Options;
import flixel.input.keyboard.FlxKey;
import flixel.addons.ui.FlxUIState;
import sys.thread.Thread;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import lime.app.Application;
import Discord.DiscordClient;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import haxe.Json;
import sys.FileSystem;
import ui.*;

using StringTools;

class InitState extends FlxUIState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static function initTransition()
	{ // TRANS RIGHTS
		// FlxTransitionableState.defaultTransIn = FadeTransitionSubstate;
		// FlxTransitionableState.defaultTransOut = FadeTransitionSubstate;
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		OptionUtils.bindSave();
		OptionUtils.loadOptions(OptionUtils.options);
		var currentOptions = OptionUtils.options;

		EngineData.options = currentOptions;
		Main.fpsCounter.visible = currentOptions.showFPS;
		// Main.fpsCounter.showFPS = currentOptions.showFPS;
		// Main.fpsCounter.showMem = currentOptions.showMem;
		// Main.fpsCounter.showMemPeak = currentOptions.showMemPeak;

		PlayerSettings.init();

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

		ClientPrefs.loadPrefs();

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
