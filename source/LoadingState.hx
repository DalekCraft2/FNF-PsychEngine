package;

import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxTween;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import openfl.Assets;
import openfl.utils.AssetLibrary;
import openfl.utils.Future;
import openfl.utils.Promise;

using StringTools;

// TODO Load assets for stages and such whilst in the loading screen, perhaps
class LoadingState extends MusicBeatState
{
	private static inline final MIN_TIME:Float = 1.0;

	// Browsers will load create(), you can make your song load a custom directory there
	// If you're compiling to desktop (or something that uses PRELOAD_ALL), search for getNextState instead
	// I'd recommend doing it on both actually lol
	private var target:FlxState;
	private var stopMusic:Bool = false;
	private var directory:String;
	private var targetShit:Float = 0;
	private var promise:Promise<AssetLibrary>;

	private function new(target:FlxState, stopMusic:Bool, directory:String)
	{
		super();

		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;

		transIn = null;
		transOut = null;
	}

	private var funkay:FlxSprite;
	private var loadBar:FlxBar;
	private var loadText:FlxText;

	override public function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		super.create();

		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFFCAFF4D);
		add(bg);
		funkay = new FlxSprite(0, 0).loadGraphic(Paths.getGraphic('funkay'));
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		funkay.antialiasing = Options.save.data.globalAntialiasing;
		funkay.scrollFactor.set();
		funkay.screenCenter();
		add(funkay);

		loadBar = new FlxBar(0, FlxG.height, LEFT_TO_RIGHT, FlxG.width, 10, this, 'targetShit');
		loadBar.y -= loadBar.height;
		loadBar.createFilledBar(FlxColor.TRANSPARENT, 0xFFFF16D2);
		loadBar.antialiasing = Options.save.data.globalAntialiasing;
		add(loadBar);

		loadText = new FlxText(0, 0, 0, '0%', 32);
		loadText.scrollFactor.set();
		loadText.setFormat(Paths.font('vcr.ttf'), loadText.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		loadText.screenCenter(X);
		loadText.y = FlxG.height - loadText.height;
		add(loadText);

		promise = new Promise();
		var future:Future<AssetLibrary> = Assets.loadLibrary('shared')
			.onProgress(updateProgress)
			.then((library:AssetLibrary) -> Assets.loadLibrary(directory));
		promise.completeWith(future);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		funkay.setGraphicSize(Std.int(0.88 * FlxG.width + 0.9 * (funkay.width - 0.88 * FlxG.width)));
		funkay.updateHitbox();
		if (controls.ACCEPT)
		{
			funkay.setGraphicSize(Std.int(funkay.width + 60));
			funkay.updateHitbox();
		}

		if (promise.isComplete)
		{
			onLoad();
		}
	}

	private function updateProgress(progress:Int, total:Int):Void
	{
		targetShit = (progress / total) * loadBar.max;

		loadText.text = '${loadBar.percent}%';
		loadText.screenCenter(X);
	}

	private function onLoad():Void
	{
		Debug.logTrace('Finished loading!');
		FlxG.switchState(target);
	}

	public static inline function loadAndSwitchState(target:FlxState, stopMusic = false):Void
	{
		FlxG.switchState(getNextState(target, stopMusic));
	}

	private static function getNextState(target:FlxState, stopMusic = false):FlxState
	{
		var directory:String = 'shared';
		var weekDir:String = Stage.forceNextDirectory;
		Stage.forceNextDirectory = null;

		if (weekDir != null && weekDir.length > 0 && weekDir != '')
			directory = weekDir;

		Paths.currentLevel = directory;

		if (stopMusic && FlxG.sound.music != null)
		{
			if (FlxTransitionableState.skipNextTransOut)
			{
				FlxG.sound.music.stop();
				FreeplayState.destroyFreeplayVocals();
			}
			else
			{
				FlxG.sound.music.fadeOut(FlxTransitionableState.defaultTransOut.duration, 0, (?twn:FlxTween) ->
				{
					FlxG.sound.music.stop();
				});
				FreeplayState.destroyFreeplayVocals(true);
			}
		}

		var loaded:Bool = false;
		if (PlayState.song != null)
		{
			loaded = Assets.hasLibrary('shared') && Assets.hasLibrary(directory);
		}

		if (!loaded)
		{
			return new LoadingState(target, stopMusic, directory);
		}

		return target;
	}
}
