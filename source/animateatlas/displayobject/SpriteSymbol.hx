package animateatlas.displayobject;

import animateatlas.HelperEnums.LoopMode;
import animateatlas.HelperEnums.SymbolType;
import animateatlas.JSONData.BitmapPosData;
import animateatlas.JSONData.ColorData;
import animateatlas.JSONData.ElementData;
import animateatlas.JSONData.FilterData;
import animateatlas.JSONData.LayerData;
import animateatlas.JSONData.LayerFrameData;
import animateatlas.JSONData.Matrix3DData;
import animateatlas.JSONData.SpriteData;
import animateatlas.JSONData.SymbolData;
import animateatlas.JSONData.SymbolInstanceData;
import haxe.Exception;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.FrameLabel;
import openfl.display.PixelSnapping;
import openfl.display.Sprite;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
import openfl.filters.BlurFilter;
import openfl.filters.GlowFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;

class SpriteSymbol extends Sprite
{
	private static final S_MATRIX:Matrix = new Matrix();

	public var smoothing:Bool = true;

	public var currentLabel(get, never):String;
	public var currentFrame(default, set):Int;
	public var type(default, set):String;
	public var loopMode(default, set):String;
	public var symbolName(default, null):String;
	public var numLayers(default, null):Int;
	public var numFrames(default, null):Int;

	private var _data:SymbolData;
	private var _library:SpriteAnimationLibrary;
	private var _composedFrame:Int;
	private var _bitmap:Bitmap;
	private var _frameLabels:Array<FrameLabel>;
	private var _colorTransform:ColorTransform;
	private var _layers:Array<Sprite>;
	private var _texture:BitmapData;
	private var _tempRect:Rectangle = new Rectangle();
	private var _zeroPoint:Point = new Point(0, 0);
	private var filterHelper:BitmapData;

	private function new(data:SymbolData, library:SpriteAnimationLibrary, texture:BitmapData)
	{
		super();

		_data = data;
		_library = library;
		_composedFrame = -1;
		numLayers = data.TIMELINE.LAYERS.length;
		numFrames = getNumFrames();
		_frameLabels = _getFrameLabels();
		symbolName = data.SYMBOL_name;
		type = SymbolType.GRAPHIC;
		loopMode = LoopMode.LOOP;
		_texture = texture;

		createLayers();

		// Create FrameMap caches if don't exist
		for (layer in data.TIMELINE.LAYERS)
		{
			if (layer.FrameMap != null)
				return;

			var map:Map<Int, LayerFrameData> = [];

			for (i in 0...layer.Frames.length)
			{
				var frame:LayerFrameData = layer.Frames[i];
				for (j in 0...frame.duration)
				{
					map.set(i + j, frame);
				}
			}

			layer.FrameMap = map;
		}
	}

	public function reset():Void
	{
		S_MATRIX.identity();
		transform.matrix = S_MATRIX.clone();
		alpha = 1.0;
		currentFrame = 0;
		_composedFrame = -1;
	}

	public function nextFrame():Void
	{
		if (loopMode != LoopMode.SINGLE_FRAME)
		{
			currentFrame += 1;
		}

		moveMovieclip_MovieClips(1);
	}

	public function prevFrame():Void
	{
		if (loopMode != LoopMode.SINGLE_FRAME)
		{
			currentFrame -= 1;
		}

		moveMovieclip_MovieClips(-1);
	}

	public function update():Void
	{
		for (i in 0...numLayers)
		{
			updateLayer(i);
		}

		_composedFrame = currentFrame;
	}

	@:access(animateatlas)
	public function setBitmap(data:BitmapPosData):Void
	{
		if (data != null)
		{
			var spriteData:SpriteData = _library.getSpriteData(data.name);

			if (_bitmap == null)
			{
				_bitmap = new Bitmap(new BitmapData(1, 1), PixelSnapping.AUTO, smoothing);
				addChild(_bitmap);
			}

			if (_tempRect.x != spriteData.x || _tempRect.y != spriteData.y || _tempRect.width != spriteData.w || _tempRect.height != spriteData.h)
			{
				var clippedTexture:BitmapData = new BitmapData(spriteData.w, spriteData.h);
				_tempRect.setTo(spriteData.x, spriteData.y, spriteData.w, spriteData.h);
				clippedTexture.copyPixels(_texture, _tempRect, _zeroPoint);
				_bitmap.bitmapData = clippedTexture;
				_bitmap.smoothing = smoothing;
			}
			// aditional checks for rotation
			if (spriteData.rotated)
			{
				_bitmap.rotation = -90;
				_bitmap.x = data.Position.x;
				_bitmap.y = data.Position.y + spriteData.w;
			}
			else
			{
				_bitmap.rotation = 0;
				_bitmap.x = data.Position.x;
				_bitmap.y = data.Position.y;
			}

			addChildAt(_bitmap, 0);
		}
		else if (_bitmap != null)
		{
			if (_bitmap.parent != null)
				_bitmap.parent.removeChild(_bitmap);
		}
	}

	public function getFrameLabels():Array<String>
	{
		return _frameLabels.map((f:FrameLabel) -> f.name); // Inlining. I feel a js
	}

	public function getTexture():BitmapData
	{
		// THIS GETS THE ENTIRE THING I'M RETARDED LOL
		return _texture;
	}

	public function getNextLabel(?afterLabel:String):String
	{
		var startFrame:Int = getFrame(afterLabel == null ? currentLabel : afterLabel);

		for (label in _frameLabels)
		{
			if (label.frame > startFrame)
			{
				return label.name;
			}
		}

		return (_frameLabels != null) ? _frameLabels[0].name : null;
	}

	public function getFrame(label:String):Int
	{
		for (frameLabel in _frameLabels)
		{
			if (frameLabel.name == label)
			{
				return frameLabel.frame;
			}
		}
		return -1;
	}

	/** 
	 * Moves all movie clips and frames, recursively.
	 */
	private function moveMovieclip_MovieClips(direction:Int = 1):Void
	{
		if (type == SymbolType.MOVIE_CLIP)
		{
			currentFrame += direction;
		}

		for (l in 0...numLayers)
		{
			var layer:Sprite = getLayer(l);
			var numElements:Int = layer.numChildren;

			for (e in 0...numElements)
			{
				(try cast layer.getChildAt(e)
				catch (e:Exception) null).moveMovieclip_MovieClips(direction);
			}
		}
	}

	@:access(animateatlas)
	private function updateLayer(layerIndex:Int):Void
	{
		var layer:Sprite = getLayer(layerIndex);
		var frameData:LayerFrameData = getFrameData(layerIndex, currentFrame);
		var elements:Array<ElementData> = (frameData != null) ? frameData.elements : null;
		var numElements:Int = (elements != null) ? elements.length : 0;
		for (i in 0...numElements)
		{
			var elementData:SymbolInstanceData = elements[i].SYMBOL_Instance;

			if (elementData == null)
			{
				continue;
			}

			// this is confusing but needed :(
			var oldSymbol:SpriteSymbol = (layer.numChildren > i) ? try
				cast layer.getChildAt(i)
			catch (e:Exception)
				null : null;

			var newSymbol:SpriteSymbol;

			var symbolName:String = elementData.SYMBOL_name;

			if (!_library.hasSymbol(symbolName))
			{
				symbolName = SpriteAnimationLibrary.BITMAP_SYMBOL_NAME;
			}

			if (oldSymbol != null && oldSymbol.symbolName == symbolName)
			{
				newSymbol = oldSymbol;
			}
			else
			{
				if (oldSymbol != null)
				{
					if (oldSymbol.parent != null)
						oldSymbol.removeChild(oldSymbol);
					_library.putSymbol(oldSymbol);
				}

				newSymbol = _library.getSymbol(symbolName);
				layer.addChildAt(newSymbol, i);
			}

			newSymbol.setTransformationMatrix(elementData.Matrix3D);
			newSymbol.setBitmap(elementData.bitmap);
			newSymbol.setFilterData(elementData.filters);
			newSymbol.setColor(elementData.color);
			newSymbol.setLoop(elementData.loop);
			newSymbol.setType(elementData.symbolType);

			if (newSymbol.type == SymbolType.GRAPHIC)
			{
				var firstFrame:Int = elementData.firstFrame;
				var frameAge:Int = currentFrame - frameData.index;

				if (newSymbol.loopMode == LoopMode.SINGLE_FRAME)
				{
					newSymbol.currentFrame = firstFrame;
				}
				else if (newSymbol.loopMode == LoopMode.LOOP)
				{
					newSymbol.currentFrame = (firstFrame + frameAge) % newSymbol.numFrames;
				}
				else
				{
					newSymbol.currentFrame = firstFrame + frameAge;
				}
			}
		}

		var numObsoleteSymbols:Int = (layer.numChildren - numElements);

		for (i in 0...numObsoleteSymbols)
		{
			try
			{
				var oldSymbol:SpriteSymbol = cast layer.removeChildAt(numElements);
				if (oldSymbol != null)
					_library.putSymbol(oldSymbol);
			}
			catch (e:Exception)
			{
			}
		}
	}

	private function createLayers():Void
	{
		// TODO safety check for not initialiing twice
		if (_layers != null)
		{
			throw new Error('You must not call this twice');
		}
		_layers = [];

		if (numLayers <= 1)
		{
			_layers.push(this);
		}
		else
		{
			for (i in 0...numLayers)
			{
				var layer:Sprite = new Sprite();
				layer.name = getLayerData(i).Layer_name;
				addChild(layer);
				_layers.push(layer);
			}
		}
	}

	private function setFilterData(data:FilterData):Void
	{
		var blur:BlurFilter;
		var glow:GlowFilter;
		if (data != null)
		{
			if (data.BlurFilter != null)
			{
				blur = new BlurFilter();
				blur.blurX = data.BlurFilter.blurX;
				blur.blurY = data.BlurFilter.blurY;
				blur.quality = data.BlurFilter.quality;
				_bitmap.bitmapData.applyFilter(_bitmap.bitmapData, new Rectangle(0, 0, _bitmap.bitmapData.width, _bitmap.bitmapData.height), new Point(0, 0),
					blur);
				filters.push(blur);
			}
			if (data.GlowFilter != null)
			{
				glow = new GlowFilter();
				glow.blurX = data.GlowFilter.blurX;
				glow.blurY = data.GlowFilter.blurY;
				glow.color = data.GlowFilter.color;
				glow.alpha = data.GlowFilter.alpha;
				glow.quality = data.GlowFilter.quality;
				glow.strength = data.GlowFilter.strength;
				glow.knockout = data.GlowFilter.knockout;
				glow.inner = data.GlowFilter.inner;
				filters.push(glow);
			}
		}
	}

	private function setTransformationMatrix(data:Matrix3DData):Void
	{
		S_MATRIX.setTo(data.m00, data.m01, data.m10, data.m11, data.m30, data.m31);
		if (S_MATRIX.a != transform.matrix.a || S_MATRIX.b != transform.matrix.b || S_MATRIX.c != transform.matrix.c || S_MATRIX.d != transform.matrix.d
			|| S_MATRIX.tx != transform.matrix.tx || S_MATRIX.ty != transform.matrix.ty)
			transform.matrix = S_MATRIX.clone(); // TODO stop the cloning :(
	}

	private function setColor(data:ColorData):Void
	{
		var newTransform:ColorTransform = new ColorTransform();
		if (data != null)
		{
			newTransform.redOffset = (data.redOffset == null ? 0 : data.redOffset);
			newTransform.greenOffset = (data.greenOffset == null ? 0 : data.greenOffset);
			newTransform.blueOffset = (data.blueOffset == null ? 0 : data.blueOffset);
			newTransform.alphaOffset = (data.AlphaOffset == null ? 0 : data.AlphaOffset);

			newTransform.redMultiplier = (data.RedMultiplier == null ? 1 : data.RedMultiplier);
			newTransform.greenMultiplier = (data.greenMultiplier == null ? 1 : data.greenMultiplier);
			newTransform.blueMultiplier = (data.blueMultiplier == null ? 1 : data.blueMultiplier);
			newTransform.alphaMultiplier = (data.alphaMultiplier == null ? 1 : data.alphaMultiplier);
		}
		transform.colorTransform = newTransform;
	}

	private function setLoop(data:String):Void
	{
		if (data != null)
		{
			loopMode = data;
		}
		else
		{
			loopMode = LoopMode.LOOP;
		}
	}

	private function setType(data:String):Void
	{
		if (data != null)
		{
			type = data;
		}
	}

	private function getNumFrames():Int
	{
		var numFrames:Int = 0;

		for (i in 0...numLayers)
		{
			var layer:LayerData = getLayerData(i);
			var frameDates:Array<LayerFrameData> = (layer == null ? [] : layer.Frames);
			var numFrameDates:Int = (frameDates != null) ? frameDates.length : 0;
			var layerNumFrames:Int = (numFrameDates != 0) ? frameDates[0].index : 0;

			for (j in 0...numFrameDates)
			{
				layerNumFrames += frameDates[j].duration;
			}

			if (layerNumFrames > numFrames)
			{
				numFrames = layerNumFrames;
			}
		}

		return numFrames == 0 ? 1 : numFrames;
	}

	private function _getFrameLabels():Array<FrameLabel>
	{
		var labels:Array<FrameLabel> = [];

		for (i in 0...numLayers)
		{
			var layer:LayerData = getLayerData(i);
			var frameDates:Array<LayerFrameData> = (layer == null ? [] : layer.Frames);
			var numFrameDates:Int = (frameDates != null) ? frameDates.length : 0;

			for (j in 0...numFrameDates)
			{
				var frameData:LayerFrameData = frameDates[j];
				if (frameData.name != null)
				{
					labels.push(new FrameLabel(frameData.name, frameData.index));
				}
			}
		}
		labels.sort(sortLabels);
		return labels;
	}

	private function sortLabels(i1:FrameLabel, i2:FrameLabel):Int
	{
		var f1:Int = i1.frame;
		var f2:Int = i2.frame;
		if (f1 < f2)
		{
			return -1;
		}
		else if (f1 > f2)
		{
			return 1;
		}
		else
		{
			return 0;
		}
	}

	private function getLayer(layerIndex:Int):Sprite
	{
		return _layers[layerIndex];
	}

	private function getLayerData(layerIndex:Int):LayerData
	{
		return _data.TIMELINE.LAYERS[layerIndex];
	}

	private function getFrameData(layerIndex:Int, frameIndex:Int):LayerFrameData
	{
		var layer:LayerData = getLayerData(layerIndex);
		if (layer == null)
			return null;

		return layer.FrameMap.get(frameIndex);
	}

	private function get_currentLabel():String
	{
		var highestLabel:FrameLabel = (_frameLabels.length != 0) ? _frameLabels[0] : null;

		for (label in _frameLabels)
		{
			if (label.frame <= currentFrame)
			{
				highestLabel = label;
			}
			else
			{
				break;
			}
		}

		return (highestLabel != null) ? highestLabel.name : null;
	}

	private function set_currentFrame(value:Int):Int
	{
		while (value < 0)
		{
			value += numFrames;
		}

		if (loopMode == LoopMode.PLAY_ONCE)
		{
			currentFrame = Std.int(Math.min(Math.max(value, 0), numFrames - 1));
		}
		else
		{
			currentFrame = Std.int(Math.abs(value % numFrames));
		}

		if (_composedFrame != currentFrame)
		{
			update();
		}
		return value;
	}

	private function set_type(value:String):String
	{
		if (SymbolType.isValid(value))
		{
			type = value;
		}
		else
		{
			throw new ArgumentError('Invalid symbol type: $value');
		}
		return value;
	}

	private function set_loopMode(value:String):String
	{
		if (LoopMode.isValid(value))
		{
			loopMode = value;
		}
		else
		{
			throw new ArgumentError('Invalid loop mode: $value');
		}
		return value;
	}
}
