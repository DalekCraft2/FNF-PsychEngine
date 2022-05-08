package animateatlas;

import animateatlas.JSONData.AnimationData;
import animateatlas.JSONData.AtlasData;
import animateatlas.displayobject.SpriteAnimationLibrary;
import animateatlas.displayobject.SpriteMovieClip;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxGraphicAsset;
import haxe.Json;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

using StringTools;

class AtlasFrameMaker extends FlxFramesCollection
{
	/**
	 * Creates Frames from TextureAtlas (very early and broken ok) Originally made for FNF HD by Smokey and Rozebud
	 *
	 * @param key The file path.
	 * @param _excludeArray Use this to only create selected animations. Keep null to create all of them.
	 *
	 */
	public static function construct(key:String, ?_excludeArray:Array<String>, ?noAntialiasing:Bool = false):FlxFramesCollection
	{
		var frameCollection:FlxFramesCollection;
		var frameArray:Array<Array<FlxFrame>> = [];

		if (Paths.exists(Paths.file(Path.join(['images', key, Path.withExtension('spritemap1', Paths.JSON_EXT)]))))
		{
			#if FEATURE_SCRIPTS
			PlayState.instance.addTextToDebug('Only Spritemaps made with Adobe Animate 2018 are supported');
			#end
			Debug.logTrace('Only Spritemaps made with Adobe Animate 2018 are supported');
			return null;
		}

		var animationData:AnimationData = Paths.getJson(Path.join(['images', key, Path.withExtension('Animation', Paths.JSON_EXT)]));
		var atlasData:AtlasData = Json.parse(Paths.getText(Path.join(['images', key, Path.withExtension('spritemap', Paths.JSON_EXT)])).replace('\uFEFF', ''));

		var graphicAsset:FlxGraphicAsset = Paths.getGraphic(Path.join([key, 'spritemap']));
		var graphic:FlxGraphic = null;
		if (graphicAsset is FlxGraphic)
		{
			graphic = graphicAsset;
		}
		else if (graphicAsset is BitmapData)
		{
			graphic = FlxGraphic.fromBitmapData(graphicAsset);
		}

		var ss:SpriteAnimationLibrary = new SpriteAnimationLibrary(animationData, atlasData, graphic.bitmap);
		var t:SpriteMovieClip = ss.createAnimation(noAntialiasing);
		if (_excludeArray == null)
		{
			_excludeArray = t.getFrameLabels();
			// Debug.logTrace('Creating all animations');
		}
		Debug.logTrace('Creating: $_excludeArray');

		frameCollection = new FlxFramesCollection(graphic, FlxFrameCollectionType.IMAGE);
		for (x in _excludeArray)
		{
			frameArray.push(getFramesArray(t, x));
		}

		for (x in frameArray)
		{
			for (y in x)
			{
				frameCollection.pushFrame(y);
			}
		}
		return frameCollection;
	}

	@:noCompletion private static function getFramesArray(t:SpriteMovieClip, animation:String):Array<FlxFrame>
	{
		var sizeInfo:Rectangle = new Rectangle(0, 0);
		t.currentLabel = animation;
		var bitMapArray:Array<BitmapData> = [];
		var framesArray:Array<FlxFrame> = [];
		var firstPass:Bool = true;
		var frameSize:FlxPoint = new FlxPoint(0, 0);

		for (i in t.getFrame(animation)...t.numFrames)
		{
			t.currentFrame = i;
			if (t.currentLabel == animation)
			{
				sizeInfo = t.getBounds(t);
				var bitmapShit:BitmapData = new BitmapData(Std.int(sizeInfo.width + sizeInfo.x), Std.int(sizeInfo.height + sizeInfo.y), true, 0);
				bitmapShit.draw(t, null, null, null, null, true);
				bitMapArray.push(bitmapShit);

				if (firstPass)
				{
					frameSize.set(bitmapShit.width, bitmapShit.height);
					firstPass = false;
				}
			}
			else
				break;
		}

		for (i in 0...bitMapArray.length)
		{
			var b:FlxGraphic = FlxGraphic.fromBitmapData(bitMapArray[i]);
			var frame:FlxFrame = new FlxFrame(b);
			frame.parent = b;
			frame.name = animation + i;
			frame.sourceSize.set(frameSize.x, frameSize.y);
			frame.frame = new FlxRect(0, 0, bitMapArray[i].width, bitMapArray[i].height);
			framesArray.push(frame);
		}
		return framesArray;
	}
}
