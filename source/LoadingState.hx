package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import openfl.utils.AssetLibrary;
import openfl.utils.Assets;
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
	private var skipTransition:Bool = false;
	private var targetShit:Float = 0;
	private var promise:Promise<AssetLibrary>;

	private function new(target:FlxState, stopMusic:Bool, directory:String, skipTransition:Bool)
	{
		super();

		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;
		this.skipTransition = skipTransition;

		// FlxTransitionableState.skipNextTransIn = true;
	}

	private var funkay:FlxSprite;
	private var loadBar:FlxBar;
	private var loadText:FlxText;

	override public function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		super.create();

		// FlxTransitionableState.skipNextTransOut = true;

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

		loadBar = new FlxBar(0, FlxG.height - 20, LEFT_TO_RIGHT, FlxG.width, 10, this, 'targetShit');
		loadBar.createFilledBar(FlxColor.TRANSPARENT, 0xFFFF16D2);
		loadBar.antialiasing = Options.save.data.globalAntialiasing;
		loadBar.filledCallback = () ->
		{
			loadText.text = '100%';
		};
		add(loadBar);

		loadText = new FlxText(0, 0, '0%', 32);
		loadText.scrollFactor.set();
		loadText.setFormat(Paths.font('vcr.ttf'), loadText.size, CENTER, OUTLINE, FlxColor.BLACK);
		loadText.screenCenter(X);
		loadText.y = FlxG.height - loadText.height;
		add(loadText);

		promise = new Promise();
		var future:Future<AssetLibrary> = Assets.loadLibrary('shared').onProgress(updateProgress);
		// future.then((library:AssetLibrary) ->
		// {
		// 	var songPromise:Promise<Sound> = new Promise();
		// 	if (PlayState.song != null)
		// 	{
		// 		songPromise.completeWith(Assets.loadSound(getSongPath()));
		// 		if (PlayState.song.needsVoices)
		// 		{
		// 			songPromise.completeWith(Assets.loadSound(getVocalPath()));
		// 		}
		// 	}
		// 	return songPromise.future;
		// });
		promise.completeWith(future).completeWith(Assets.loadLibrary(directory));

		promise.future.onComplete((library:AssetLibrary) ->
		{
			onLoad();
		});
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
	}

	private function updateProgress(progress:Int, total:Int):Void
	{
		loadBar.setRange(0, total);
		loadBar.numDivisions = total;

		targetShit = (progress / total) * loadBar.max;

		loadText.text = '${loadBar.percent}%';
		loadText.screenCenter(X);
	}

	private function onLoad():Void
	{
		Paths.clearUnusedMemory();

		FlxTransitionableState.skipNextTransOut = skipTransition;

		FlxG.switchState(target);
	}

	private static function getSongPath():String
	{
		return Paths.inst(PlayState.song.songId);
	}

	private static function getVocalPath():String
	{
		return Paths.voices(PlayState.song.songId);
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

		Paths.setCurrentLevel(directory);

		if (stopMusic && FlxG.sound.music != null)
		{
			// FlxG.sound.music.fadeOut(1, 0, (?twn:FlxTween) ->
			// {
			FlxG.sound.music.stop();
			FlxG.sound.music.destroy();
			// });
			FreeplayState.destroyFreeplayVocals(true);
		}

		var loaded:Bool = false;
		if (PlayState.song != null)
		{
			loaded = Assets.cache.hasSound(getSongPath())
				&& (!PlayState.song.needsVoices || Assets.cache.hasSound(getVocalPath()))
				&& Assets.hasLibrary('shared')
				&& Assets.hasLibrary(directory);
		}

		if (!loaded)
		{
			return new LoadingState(target, stopMusic, directory, FlxTransitionableState.skipNextTransOut);
		}

		return target;
	}
}

class MultiCallback
{
	public var callback:() -> Void;
	public var logId:String;
	public var length(default, null):Int = 0;
	public var numRemaining(default, null):Int = 0;

	private var unfired:Map<String, () -> Void> = [];
	private var fired:Array<String> = [];

	public function new(callback:() -> Void, ?logId:String)
	{
		this.callback = callback;
		this.logId = logId;
	}

	public function add(id = 'untitled'):() -> Void
	{
		id = '$length:$id';
		length++;
		numRemaining++;
		var func:() -> Void = () ->
		{
			if (unfired.exists(id))
			{
				unfired.remove(id);
				fired.push(id);
				numRemaining--;

				log('Fired $id, $numRemaining remaining');

				if (numRemaining == 0)
				{
					log('All callbacks fired');
					callback();
				}
			}
			else
				log('Already fired $id');
		}
		unfired[id] = func;
		return func;
	}

	private inline function log(msg):Void
	{
		if (logId != null)
			Debug.logTrace('$logId: $msg');
	}

	public function getFired():Array<String>
		return fired.copy();

	public function getUnfired():Array<String>
		return [for (id in unfired.keys()) id];
}
