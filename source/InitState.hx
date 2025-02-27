package;

import flixel.FlxG;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.addons.ui.FlxUIState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class InitState extends FlxUIState
{
	public static var muteKeys:Array<FlxKey> = [ZERO, NUMPADZERO];
	public static var volumeDownKeys:Array<FlxKey> = [MINUS, NUMPADMINUS];
	public static var volumeUpKeys:Array<FlxKey> = [PLUS, NUMPADPLUS];

	override public function create():Void
	{
		super.create();

		EngineData.bindSave('funkin', 'ninjamuffin99');

		Options.bindSave();
		Options.fillMissingOptionFields(); // Load default options in case any are null
		Options.flushSave(); // Save initialized options

		Conductor.initializeSafeZoneOffset(); // Now that the options are loaded, this can be initialized

		PlayerSettings.init();

		Highscore.load();

		// FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;

		if (EngineData.save.data.fullscreen != null)
		{
			// TODO I'm pretty sure this doesn't work
			FlxG.fullscreen = EngineData.save.data.fullscreen;
		}

		if (EngineData.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = EngineData.save.data.weekCompleted;
		}

		if (Options.save.data.frameRate < 30 || Options.save.data.frameRate > 360)
		{
			Options.save.data.frameRate = 120;
		}

		Main.setFPSCap(Options.save.data.frameRate);

		#if FEATURE_DISCORD
		DiscordClient.initialize();
		#end

		// FlxGraphic.defaultPersist = Options.save.data.persistentImages;

		FlxG.fixedTimestep = false;
		FlxG.autoPause = false;

		#if web
		FlxG.autoPause = true;
		FlxG.mouse.visible = false;
		#end

		var canCache:Bool = false;
		#if sys
		canCache = true;
		#end
		if (canCache)
		{
			if (!Options.save.data.cacheCharacters && !Options.save.data.cacheSongs && !Options.save.data.cacheSounds && !Options.save.data.cachePreload)
				canCache = false;
		}

		var nextState:FlxUIState = new TitleState();
		// TODO Implement caching
		/*
			#if sys
			if (Options.save.data.shouldCache && canCache)
			{
				nextState = new CachingState(nextState);
			}
			else
			#end
		 */
		{
			initTransition();
		}

		// This state isn't visible anyway, so a transition from it to TitleState is pointless and wastes time
		transIn = null;
		transOut = null;

		#if FREEPLAY
		FlxG.switchState(new FreeplayState());
		#elseif CHARTING
		FlxG.switchState(new ChartEditorState());
		#elseif CHARACTER
		FlxG.switchState(new CharacterEditorState('bf', nextState));
		#else
		FlxG.switchState(nextState);
		#end
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
