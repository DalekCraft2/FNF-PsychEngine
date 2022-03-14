package;

#if FEATURE_FILESYSTEM
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.ui.FlxBar;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.TransitionData;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Exception;
import lime.app.Application;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;
import options.Options.OptionUtils;
#if FEATURE_FILESYSTEM
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class Caching extends MusicBeatState
{
	var toBeDone:Int = 0;
	var done:Int = 0;

	var loaded:Bool = false;

	var text:FlxText;
	var kadeLogo:FlxSprite;

	public static var bitmapData:Map<String, FlxGraphic>;

	var images:Array<String> = [];
	var music:Array<String> = [];
	var charts:Array<String> = [];

	private var nextState:FlxState;

	public function new(nextState:FlxState)
	{
		super();

		this.nextState = nextState;
	}

	override function create():Void
	{
		super.create();

		// It doesn't reupdate the list before u restart rn lmao
		// NoteskinHelpers.updateNoteskins();

		bitmapData = [];

		text = new FlxText(FlxG.width / 2, FlxG.height / 2 + 300, 0, "Loading...");
		text.size = 34;
		text.alignment = CENTER;
		text.alpha = 0;

		kadeLogo = new FlxSprite(FlxG.width / 2, FlxG.height / 2).loadGraphic(Paths.loadImage('KadeEngineLogo'));
		kadeLogo.x -= kadeLogo.width / 2;
		kadeLogo.y -= kadeLogo.height / 2 + 100;
		text.y -= kadeLogo.height / 2 - 125;
		text.x -= 170;
		kadeLogo.setGraphicSize(Std.int(kadeLogo.width * 0.6));
		if (OptionUtils.options.antialiasing != null)
			kadeLogo.antialiasing = FlxG.save.data.antialiasing;
		else
			kadeLogo.antialiasing = true;

		kadeLogo.alpha = 0;

		FlxGraphic.defaultPersist = OptionUtils.options.persistentImages;

		#if FEATURE_FILESYSTEM
		if (OptionUtils.options.cacheImages)
		{
			Debug.logTrace("caching images...");

			// TODO: Refactor this to use OpenFlAssets.
			for (i in FileSystem.readDirectory(FileSystem.absolutePath("assets/shared/images/characters")))
			{
				if (!i.endsWith(".png"))
					continue;
				images.push(i);
			}

			/*for (i in FileSystem.readDirectory(FileSystem.absolutePath("assets/shared/images/noteskins")))
				{
					if (!i.endsWith(".png"))
						continue;
					images.push(i);
			}*/
		}

		Debug.logTrace("Caching music...");

		// TODO: Get the song list from OpenFlAssets.
		music = Paths.listSongsToCache();
		#end

		toBeDone = Lambda.count(images) + Lambda.count(music);

		var bar = new FlxBar(10, FlxG.height - 50, FlxBarFillDirection.LEFT_TO_RIGHT, FlxG.width, 40, null, "done", 0, toBeDone);
		bar.color = FlxColor.PURPLE;

		add(bar);

		add(kadeLogo);
		add(text);

		Debug.logTrace('Starting caching...');

		#if FEATURE_MULTITHREADING
		// update thread

		Thread.create(() ->
		{
			while (!loaded)
			{
				if (toBeDone != 0 && done != toBeDone)
				{
					var alpha = CoolUtil.truncateFloat(done / toBeDone * 100, 2) / 100;
					kadeLogo.alpha = alpha;
					text.alpha = alpha;
					text.text = "Loading... (" + done + "/" + toBeDone + ")";
				}
			}
		});

		// cache thread
		Thread.create(() ->
		{
			cache();
		});
		#end
	}

	function cache():Void
	{
		#if FEATURE_FILESYSTEM
		Debug.logTrace("LOADING: " + toBeDone + " OBJECTS.");

		for (i in images)
		{
			var replaced = i.replace(".png", "");

			var imagePath:String = Paths.image('characters/$i', 'shared');
			Debug.logTrace('Caching character graphic $i ($imagePath)...');
			var data:BitmapData = OpenFlAssets.getBitmapData(imagePath);
			var graph:FlxGraphic = FlxGraphic.fromBitmapData(data);
			graph.persist = true;
			graph.destroyOnNoUse = false;
			bitmapData.set(replaced, graph);
			done++;
		}

		for (i in music)
		{
			var inst = Paths.inst(i);
			if (Paths.doesSoundAssetExist(inst))
			{
				FlxG.sound.cache(inst);
			}

			var voices = Paths.voices(i);
			if (Paths.doesSoundAssetExist(voices))
			{
				FlxG.sound.cache(voices);
			}

			done++;
		}

		Debug.logTrace("Finished caching...");

		loaded = true;

		Debug.logTrace(OpenFlAssets.cache.hasBitmapData('GF_assets'));
		#end

		InitState.initTransition();
		FlxG.switchState(nextState);
	}
}
#end
