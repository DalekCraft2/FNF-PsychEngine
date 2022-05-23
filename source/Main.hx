package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.events.Event;
#if USE_CUSTOM_CACHE
import flixel.graphics.FlxGraphic;
import openfl.Assets;
#end

class Main extends Sprite
{
	private var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	private var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	private var initialState:Class<FlxState> = InitState; // The FlxState the game starts with.
	private var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	private var frameRate:Int = #if cpp 120 #else 60 #end; // How many frames per second the game should run at.
	private var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	private var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		// quick checks
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?e:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}

		// Run this first so we can see logs.
		Debug.onInitProgram();

		#if polymod
		// Gotta run this before any assets get loaded.
		ModCore.initialize();
		#end

		#if USE_CUSTOM_CACHE
		// fuck you, persistent caching stays ON during sex
		FlxGraphic.defaultPersist = true;
		Assets.cache.enabled = false;
		// the reason for this is we're going to be handling our own cache smartly
		#end
		addChild(new FlxGame(gameWidth, gameHeight, initialState, zoom, frameRate, frameRate, skipSplash, startFullscreen));

		#if !mobile
		addChild(new FPSMem(10, 3, 0xFFFFFF));
		Lib.current.stage.align = 'tl';
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		#end

		// Finish up loading debug tools.
		Debug.onGameStart();
	}

	public static function setFPSCap(cap:Float):Void
	{
		Lib.current.stage.frameRate = cap;
	}

	public static function getFPSCap():Float
	{
		return Lib.current.stage.frameRate;
	}

	public static function adjustFPS(num:Float):Float
	{
		return FlxG.elapsed / (1 / 60) * num;
	}
}
