package;

#if sys
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import haxe.io.Path;
import openfl.Assets;
import openfl.display.BitmapData;
import sys.thread.Thread;

using StringTools;

class CachingState extends MusicBeatState
{
	private var toBeDone:Int = 0;
	private var done:Int = 0;

	private var loaded:Bool = false;

	private var text:FlxText;
	private var kadeLogo:FlxSprite;

	public static var bitmapData:Map<String, FlxGraphicAsset>;

	private var images:Array<String> = [];
	private var music:Array<String> = [];
	private var charts:Array<String> = [];

	private var nextState:FlxState;

	public function new(nextState:FlxState)
	{
		super();

		this.nextState = nextState;
	}

	override public function create():Void
	{
		super.create();

		// It doesn't reupdate the list before u restart rn lmao
		// NoteskinHelpers.updateNoteskins();

		bitmapData = [];

		text = new FlxText(FlxG.width / 2, FlxG.height / 2 + 300, 0, 'Loading...', 34);
		text.alignment = CENTER;
		text.alpha = 0;

		kadeLogo = new FlxSprite(FlxG.width / 2, FlxG.height / 2).loadGraphic(Paths.getGraphic('KadeEngineLogo'));
		kadeLogo.x -= kadeLogo.width / 2;
		kadeLogo.y -= kadeLogo.height / 2 + 100;
		text.y -= kadeLogo.height / 2 - 125;
		text.x -= 170;
		kadeLogo.setGraphicSize(Std.int(kadeLogo.width * 0.6));
		if (Options.save.data.antialiasing != null)
			kadeLogo.antialiasing = Options.save.data.globalAntialiasing;
		else
			kadeLogo.antialiasing = true;

		kadeLogo.alpha = 0;

		FlxGraphic.defaultPersist = Options.save.data.persistentImages;

		if (Options.save.data.cacheImages)
		{
			Debug.logTrace('Caching images...');

			// TODO: Refactor this to use OpenFLAssets.
			for (file in Paths.fileSystem.readDirectoryRecursive('assets/shared/images'))
			{
				if (Path.extension(file) != Paths.IMAGE_EXT)
					continue;
				images.push(file);
			}
		}

		Debug.logTrace('Caching music...');

		// TODO: Get the song list from OpenFLAssets.
		music = Paths.listSongsToCache();

		toBeDone = Lambda.count(images) + Lambda.count(music);

		var bar:FlxBar = new FlxBar(10, FlxG.height - 50, FlxBarFillDirection.LEFT_TO_RIGHT, FlxG.width, 40, null, 'done', 0, toBeDone);
		bar.color = FlxColor.PURPLE;

		add(bar);

		add(kadeLogo);
		add(text);

		Debug.logTrace('Starting caching...');

		#if target.threaded
		// update thread

		Thread.create(() ->
		{
			while (!loaded)
			{
				if (toBeDone != 0 && done != toBeDone)
				{
					var alpha:Float = FlxMath.roundDecimal(done / toBeDone * 100, 2) / 100;
					kadeLogo.alpha = alpha;
					text.alpha = alpha;
					text.text = 'Loading... ($done/$toBeDone)';
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

	private function cache():Void
	{
		#if sys
		Debug.logTrace('LOADING: $toBeDone OBJECTS.');

		for (imageFile in images)
		{
			var replaced:String = Path.withoutExtension(imageFile);

			var imagePath:String = Paths.image(Path.join(['characters', imageFile]), 'shared');
			Debug.logTrace('Caching character graphic $imageFile ($imagePath)...');
			var graphicAsset:FlxGraphicAsset = Paths.getGraphicDirect(imagePath);
			var graphic:FlxGraphic = null;
			if (graphicAsset is FlxGraphic)
			{
				graphic = graphicAsset;
			}
			else if (graphicAsset is BitmapData)
			{
				graphic = FlxGraphic.fromBitmapData(graphicAsset);
			}

			graphic.persist = true;
			graphic.destroyOnNoUse = false;
			bitmapData.set(replaced, graphic);
			done++;
		}

		for (musicFile in music)
		{
			var inst:String = Paths.inst(musicFile);
			if (Paths.exists(inst, MUSIC))
			{
				FlxG.sound.cache(inst);
			}

			var voices:String = Paths.voices(musicFile);
			if (Paths.exists(voices, MUSIC))
			{
				FlxG.sound.cache(voices);
			}

			done++;
		}

		Debug.logTrace('Finished caching.');

		loaded = true;

		Debug.logTrace(Assets.cache.hasBitmapData('GF_assets'));
		#end

		InitState.initTransition();
		FlxG.switchState(nextState);
	}
}
#end
