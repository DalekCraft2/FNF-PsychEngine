package animateatlas.tilecontainer;

import animateatlas.HelperEnums.LoopMode;
import animateatlas.HelperEnums.SymbolType;
import animateatlas.JSONData.BitmapPosData;
import animateatlas.JSONData.ColorData;
import animateatlas.JSONData.ElementData;
import animateatlas.JSONData.LayerData;
import animateatlas.JSONData.LayerFrameData;
import animateatlas.JSONData.Matrix3DData;
import animateatlas.JSONData.SpriteData;
import animateatlas.JSONData.SymbolData;
import animateatlas.JSONData.SymbolInstanceData;
import haxe.Exception;
import openfl.display.FrameLabel;
import openfl.display.Tile;
import openfl.display.TileContainer;
import openfl.display.Tileset;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
import openfl.geom.ColorTransform;
import openfl.geom.Rectangle;

class TileContainerSymbol extends TileContainer
{
	public var currentLabel(get, never):String;
	public var currentFrame(default, set):Int;
	public var type(default, set):String;
	public var loopMode(default, set):String;
	public var symbolName(default, null):String;
	public var numLayers(default, null):Int;
	public var numFrames(default, null):Int;

	private var _data:SymbolData;
	private var _library:TileAnimationLibrary;
	private var _composedFrame:Int;
	private var _bitmap:Tile;
	private var _frameLabels:Array<FrameLabel>;
	private var _colorTransform:ColorTransform;
	private var _layers:Array<TileContainer>;

	private function new(data:SymbolData, library:TileAnimationLibrary, tileset:Tileset)
	{
		super();

		this.tileset = tileset;
		_data = data;
		_library = library;
		_composedFrame = -1;
		numLayers = data.TIMELINE.LAYERS.length;
		numFrames = getNumFrames();
		_frameLabels = _getFrameLabels();
		symbolName = data.SYMBOL_name;
		type = SymbolType.GRAPHIC;
		loopMode = LoopMode.LOOP;

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
		matrix.identity();

		// copied from the setter for tile so we don't create a new matrix.
		__rotation = null;
		__scaleX = null;
		__scaleY = null;
		__setRenderDirty();

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
				_bitmap = new Tile(-1);
				_bitmap.rect = new Rectangle();
				addTile(_bitmap);
			}

			_bitmap.rect.setTo(spriteData.x, spriteData.y, spriteData.w, spriteData.h);
			_bitmap.__setRenderDirty(); // setTo() doesn't trigger the renderdirty

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

			addTileAt(_bitmap, 0);
		}
		else if (_bitmap != null)
		{
			if (_bitmap.parent != null)
				_bitmap.parent.removeTile(_bitmap);
		}
	}

	public function getFrameLabels():Array<String>
	{
		return _frameLabels.map(f -> f.name); // Inlining. I feel a js
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
			var layer:TileContainer = getLayer(l);
			var numElements:Int = layer.numTiles;

			for (e in 0...numElements)
			{
				(try cast layer.getTileAt(e)
				catch (e:Exception) null).moveMovieclip_MovieClips(direction);
			}
		}
	}

	@:access(animateatlas)
	private function updateLayer(layerIndex:Int):Void
	{
		var layer:TileContainer = getLayer(layerIndex);
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
			var oldSymbol:TileContainerSymbol = (layer.numTiles > i) ? try
				cast layer.getTileAt(i)
			catch (e:Exception)
				null : null;

			var newSymbol:TileContainerSymbol;
			var symbolName:String = elementData.SYMBOL_name;

			if (!_library.hasSymbol(symbolName))
			{
				symbolName = TileAnimationLibrary.BITMAP_SYMBOL_NAME;
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
						oldSymbol.removeTile(oldSymbol);
					_library.putSymbol(oldSymbol);
				}

				newSymbol = _library.getSymbol(symbolName);
				layer.addTileAt(newSymbol, i);
			}

			newSymbol.setTransformationMatrix(elementData.Matrix3D);
			newSymbol.setBitmap(elementData.bitmap);
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

		var numObsoleteSymbols:Int = (layer.numTiles - numElements);

		for (i in 0...numObsoleteSymbols)
		{
			try
			{
				var oldSymbol:TileContainerSymbol = cast layer.removeTileAt(numElements);
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
				var layer:TileContainer = new TileContainer();
				if (layer.data == null)
				{
					layer.data = {Layer_name: getLayerData(i).Layer_name};
				}
				else
				{
					layer.data.Layer_name = getLayerData(i).Layer_name;
				}
				addTile(layer);
				_layers.push(layer);
			}
		}
	}

	private function setTransformationMatrix(data:Matrix3DData):Void
	{
		if (data.m00 != matrix.a || data.m01 != matrix.b || data.m10 != matrix.c || data.m11 != matrix.d || data.m30 != matrix.tx || data.m31 != matrix.ty)
		{
			matrix.setTo(data.m00, data.m01, data.m10, data.m11, data.m30, data.m31);

			// copied from the setter for tile so we don't create a new matrix.
			__rotation = null;
			__scaleX = null;
			__scaleY = null;
			__setRenderDirty();
		}
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
		colorTransform = newTransform;
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

	private function getLayer(layerIndex:Int):TileContainer
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
		var numLabels:Int = _frameLabels.length;
		var highestLabel:FrameLabel = (numLabels != 0) ? _frameLabels[0] : null;

		for (i in 1...numLabels)
		{
			var label:FrameLabel = _frameLabels[i];

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
		return currentFrame;
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
		return type;
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
		return loopMode;
	}
}
