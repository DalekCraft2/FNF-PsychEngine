package;

import animateatlas.HelperEnums.LoopMode;
import animateatlas.JSONData.AnimationData;
import animateatlas.JSONData.AtlasData;
import animateatlas.displayobject.SpriteAnimationLibrary;
import animateatlas.displayobject.SpriteMovieClip;
import animateatlas.tilecontainer.TileAnimationLibrary;
import animateatlas.tilecontainer.TileContainerMovieClip;
import openfl.Assets;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.Tilemap;
import openfl.events.Event;
import openfl.events.MouseEvent;

class Main extends Sprite
{
	private var aa:TileAnimationLibrary;
	private var ss:SpriteAnimationLibrary;

	private var tileSymbols:Array<TileContainerMovieClip>;

	private var spriteSymbols:Array<SpriteMovieClip>;

	private var renderer:Tilemap;

	public function new()
	{
		super();

		graphics.beginFill(0x333333);
		graphics.drawRect(0, 0, Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);

		var animationData:AnimationData = Paths.getJsonDirect('assets/TEST/Animation.json');
		var atlasData:AtlasData = Paths.getJsonDirect('assets/TEST/spritemap.json');
		var bitmapData:BitmapData = Assets.getBitmapData('assets/TEST/spritemap.png');

		aa = new TileAnimationLibrary(animationData, atlasData, bitmapData);
		ss = new SpriteAnimationLibrary(animationData, atlasData, bitmapData);

		renderer = new Tilemap(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight, null, true);

		renderer.tileAlphaEnabled = false;
		renderer.tileBlendModeEnabled = false;
		renderer.tileColorTransformEnabled = false;

		addChild(renderer);
		addChild(new FPSMem(10, 10, 0xFFFFFF));

		tileSymbols = [];
		spriteSymbols = [];

		addEventListener(Event.ENTER_FRAME, update);
		// addEventListener(MouseEvent.CLICK, addSpriteGirl);
		addEventListener(MouseEvent.CLICK, addTileGirl);
	}

	private var prev:Int = 0;
	private var dt:Int = 0;
	private var curr:Int = 0;

	public function update(e:Event):Void
	{
		// making a dt
		curr = Lib.getTimer();
		dt = curr - prev;
		prev = curr;

		for (symbol in tileSymbols)
		{
			symbol.update(dt);
		}
		for (symbol in spriteSymbols)
		{
			symbol.update(dt);
		}
	}

	public function addSpriteGirl(e:MouseEvent):Void
	{
		for (i in 0...1)
		{
			var t:SpriteMovieClip = ss.createAnimation(false);
			t.x = mouseX + i * 20 * (-1 * i % 2);
			t.y = mouseY + i * 20 * (-1 * i % 2);

			addChild(t);
			t.loopMode = LoopMode.SINGLE_FRAME;

			t.currentLabel = t.getFrameLabels()[Std.random(t.getFrameLabels().length)];
			spriteSymbols.push(t);
			Debug.logTrace(spriteSymbols.length);
		}
	}

	public function addTileGirl(e:MouseEvent):Void
	{
		for (i in 0...1)
		{
			var t:TileContainerMovieClip = aa.createAnimation();
			t.x = mouseX + i * 5 * (-1 * i % 2);
			t.y = mouseY + i * 5 * (-1 * i % 2);

			renderer.addTile(t);
			t.loopMode = LoopMode.SINGLE_FRAME;

			t.currentLabel = t.getFrameLabels()[Std.random(t.getFrameLabels().length)];
			tileSymbols.push(t);

			Debug.logTrace(tileSymbols.length);
		}
	}
}
