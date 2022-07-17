package vlc;

#if cpp
import cpp.NativeArray;
import cpp.Pointer;
import cpp.Star;
import cpp.UInt8;
import haxe.io.Bytes;
import haxe.io.BytesData;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.geom.Rectangle;

/**
 * @author Tommy S
 */
class VlcBitmap extends Bitmap
{
	/////////////////////////////////////////////////////////////////////////////////////
	// ===================================================================================
	// Consts
	//-----------------------------------------------------------------------------------
	// ===================================================================================
	// Properties
	//-----------------------------------------------------------------------------------
	public var fullscreen(get, set):Bool;
	public var length(get, never):Float;
	public var videoWidth(get, never):Int;
	public var videoHeight(get, never):Int;
	public var playing(get, never):Bool;
	public var seekable(get, never):Bool;
	public var volume(get, set):Float;
	public var time(get, set):Int;
	public var position(get, set):Float;
	public var repeats(get, set):Int;
	public var pixelData(get, never):Pointer<UInt8>;
	public var fps(get, never):Float;

	public var inWindow:Bool = false;
	public var initComplete:Bool = false;

	public var onVideoReady:() -> Void;
	public var onPlay:() -> Void;
	public var onStop:() -> Void;
	public var onPause:() -> Void;
	public var onResume:() -> Void;
	public var onSeek:() -> Void;
	public var onBuffer:() -> Void;
	public var onProgress:() -> Void;
	public var onOpening:() -> Void;
	public var onComplete:() -> Void;
	public var onError:() -> Void;

	// ===================================================================================
	// Declarations
	//-----------------------------------------------------------------------------------
	private var bufferMem:BytesData;
	private var libVlc:Star<LibVLC>;

	// ===================================================================================
	// Variables
	//-----------------------------------------------------------------------------------
	private var frameSize:Int;
	private var _width:Null<Float>;
	private var _height:Null<Float>;
	// private var texture:RectangleTexture; // (Stage3D)
	private var frameRect:Rectangle;

	public function new()
	{
		super(null, null, true);

		libVlc = new LibVLC();

		addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	public function play(?source:String):Void
	{
		// if (inWindow)
		// {
		// 	if (source != null)
		// 		libVlc.playInWindow(source);
		// 	else
		// 		libVlc.playInWindow();
		// }
		// else
		{
			if (source != null)
				libVlc.play(source);
			else
				libVlc.play();
		}

		if (onPlay != null)
			onPlay();
	}

	public function stop():Void
	{
		libVlc.stop();
		if (onStop != null)
			onStop();
	}

	public function pause():Void
	{
		libVlc.pause();
		if (onPause != null)
			onPause();
	}

	public function resume():Void
	{
		libVlc.resume();
		if (onResume != null)
			onResume();
	}

	public function dispose():Void
	{
		removeEventListener(Event.ENTER_FRAME, onEnterFrame);

		// (BitmapData)
		if (bitmapData != null)
		{
			bitmapData.dispose();
			bitmapData = null;
		}

		// (Stage3D)
		// if (texture != null)
		// {
		// 	texture.dispose();
		// 	texture = null;
		// }

		onVideoReady = null;
		onComplete = null;
		onPause = null;
		onPlay = null;
		onResume = null;
		onSeek = null;
		onStop = null;
		onBuffer = null;
		onProgress = null;
		onError = null;
		bufferMem = null;

		// The game fucking crashes when I set this to null and I have no idea why.
		// I don't think it was even being set to null before I changed this, so it must have always an undiscovered issue.
		// libVlc = null;
	}

	private function onEnterFrame(e:Event):Void
	{
		checkFlags();
		render();
	}

	private function checkFlags():Void
	{
		// if (libVlc.getFlag(0) != -1)
		// {
		// 	statusOnMediaChanged(libVlc.getFlag(0));
		// 	libVlc.setFlag(0, -1);
		// }
		if (libVlc.getFlag(1) != -1)
		{
			statusOnNothingSpecial();
			libVlc.setFlag(1, -1);
		}
		if (libVlc.getFlag(2) != -1)
		{
			statusOnOpening();
			libVlc.setFlag(2, -1);
		}
		if (libVlc.getFlag(3) != -1)
		{
			statusOnBuffering(libVlc.getFlag(3));
			libVlc.setFlag(3, -1);
		}
		if (libVlc.getFlag(4) != -1)
		{
			statusOnPlaying();
			libVlc.setFlag(4, -1);
		}
		if (libVlc.getFlag(5) != -1)
		{
			statusOnPaused();
			libVlc.setFlag(5, -1);
		}
		if (libVlc.getFlag(6) != -1)
		{
			statusOnStopped();
			libVlc.setFlag(6, -1);
		}
		if (libVlc.getFlag(7) != -1)
		{
			statusOnForward();
			libVlc.setFlag(7, -1);
		}
		if (libVlc.getFlag(8) != -1)
		{
			statusOnBackward();
			libVlc.setFlag(8, -1);
		}
		if (libVlc.getFlag(9) != -1)
		{
			statusOnEndReached();
			libVlc.setFlag(9, -1);
		}
		if (libVlc.getFlag(10) != -1)
		{
			statusOnEncounteredError();
			libVlc.setFlag(10, -1);
		}
		if (libVlc.getFlag(11) != -1)
		{
			statusOnTimeChanged(libVlc.getFlag(11));
			libVlc.setFlag(11, -1);
		}
		if (libVlc.getFlag(12) != -1)
		{
			statusOnPositionChanged(libVlc.getFlag(12));
			libVlc.setFlag(12, -1);
		}
		if (libVlc.getFlag(13) != -1)
		{
			statusOnSeekableChanged(libVlc.getFlag(13));
			libVlc.setFlag(13, -1);
		}
		if (libVlc.getFlag(14) != -1)
		{
			statusOnPausableChanged(libVlc.getFlag(14));
			libVlc.setFlag(14, -1);
		}
		if (libVlc.getFlag(15) != -1)
		{
			statusOnTitleChanged(libVlc.getFlag(15));
			libVlc.setFlag(15, -1);
		}
		// if (libVlc.getFlag(16) != -1)
		// {
		// 	statusOnSnapshotTaken(libVlc.getFlag(16));
		// 	libVlc.setFlag(16, -1);
		// }
		if (libVlc.getFlag(17) != -1)
		{
			statusOnLengthChanged(libVlc.getFlag(17));
			libVlc.setFlag(17, -1);
		}
		if (libVlc.getFlag(18) != -1)
		{
			statusOnVout(libVlc.getFlag(18));
			libVlc.setFlag(18, -1);
		}
	}

	private function render():Void
	{
		if (initComplete && playing)
		{
			// libVlc.getPixelData() sometimes returns null
			if (pixelData != null)
			{
				// TODO Try to use native CPP stuff as little as possible; in other words, make this not use NativeArray
				NativeArray.setData(bufferMem, pixelData, frameSize);
				if (bufferMem != null)
				{
					// (BitmapData)
					bitmapData.setPixels(frameRect, Bytes.ofData(bufferMem));

					// (Stage3D)
					// texture.uploadFromByteArray(Bytes.ofData(bufferMem), 0);
					// this.width++; // This is a horrible hack to force the texture to update... Surely there is a better way...
					// this.width--;
				}
			}
		}
	}

	private function videoInitComplete():Void
	{
		// (BitmapData)
		if (bitmapData != null)
			bitmapData.dispose();
		bitmapData = new BitmapData(videoWidth, videoHeight, true, 0);
		frameRect = new Rectangle(0, 0, videoWidth, videoHeight);

		// (Stage3D)
		// if (texture != null)
		// 	texture.dispose();
		// texture = Lib.current.stage.stage3Ds[0].context3D.createRectangleTexture(videoWidth, videoHeight, BGRA, true);
		// bitmapData = BitmapData.fromTexture(texture);

		smoothing = true;

		if (_width != null)
			width = _width;
		else
			width = videoWidth;

		if (_height != null)
			height = _height;
		else
			height = videoHeight;

		bufferMem = new BytesData();
		frameSize = videoWidth * videoHeight * 4;

		initComplete = true;

		if (onVideoReady != null)
			onVideoReady();
	}

	private function statusOnMediaChanged(newMedia: /*Pointer<libvlc_media_t>*/ Dynamic):Void
	{
	}

	private function statusOnNothingSpecial():Void
	{
	}

	private function statusOnOpening():Void
	{
		if (onOpening != null)
			onOpening();
	}

	private function statusOnBuffering(newCache:Float):Void
	{
		if (onBuffer != null)
			onBuffer();
	}

	private function statusOnPlaying():Void
	{
		if (!initComplete)
			videoInitComplete();
		if (onPlay != null)
			onPlay();
	}

	private function statusOnPaused():Void
	{
		if (onPause != null)
			onPause();
	}

	private function statusOnStopped():Void
	{
		if (onStop != null)
			onStop();
	}

	private function statusOnForward():Void
	{
	}

	private function statusOnBackward():Void
	{
	}

	private function statusOnEndReached():Void
	{
		if (onComplete != null)
			onComplete();
	}

	private function statusOnEncounteredError():Void
	{
		if (onError != null)
			onError();
	}

	private function statusOnTimeChanged(newTime:Int):Void
	{
		if (onProgress != null)
			onProgress();
	}

	private function statusOnPositionChanged(newPosition:Float):Void
	{
		if (onSeek != null)
			onSeek();
	}

	private function statusOnSeekableChanged(newSeekable:Bool):Void
	{
	}

	private function statusOnPausableChanged(newPausable:Bool):Void
	{
	}

	private function statusOnTitleChanged(newTitle:Int):Void
	{
	}

	private function statusOnSnapshotTaken(pszFilename:String):Void
	{
	}

	private function statusOnLengthChanged(newLength:Int):Void
	{
	}

	private function statusOnVout(newCount:Int):Void
	{
	}

	override private function get_width():Float
	{
		return _width;
	}

	override private function set_width(value:Float):Float
	{
		_width = value;
		return super.set_width(value);
	}

	override private function get_height():Float
	{
		return _height;
	}

	override private function set_height(value:Float):Float
	{
		_height = value;
		return super.set_height(value);
	}

	private function get_fullscreen():Bool
	{
		return libVlc.getFullscreen();
	}

	private function set_fullscreen(value:Bool):Bool
	{
		libVlc.setFullscreen(value);
		return value;
	}

	private function get_length():Float
	{
		return libVlc.getLength();
	}

	private function get_videoWidth():Int
	{
		return libVlc.getWidth();
	}

	private function get_videoHeight():Int
	{
		return libVlc.getHeight();
	}

	private function get_playing():Bool
	{
		return libVlc.isPlaying();
	}

	private function get_seekable():Bool
	{
		return libVlc.isSeekable();
	}

	private function get_volume():Float
	{
		return libVlc.getVolume() / 100;
	}

	private function set_volume(value:Float):Float
	{
		libVlc.setVolume(value * 100);
		return value;
	}

	private function get_time():Int
	{
		return libVlc.getTime();
	}

	private function set_time(value:Int):Int
	{
		libVlc.setTime(value);
		return value;
	}

	private function get_position():Float
	{
		return libVlc.getPosition();
	}

	private function set_position(value:Float):Float
	{
		libVlc.setPosition(value);
		return value;
	}

	private function get_repeats():Int
	{
		return libVlc.getRepeats();
	}

	private function set_repeats(value:Int):Int
	{
		libVlc.setRepeats(value);
		return value;
	}

	private function get_pixelData():Pointer<UInt8>
	{
		return libVlc.getPixelData();
	}

	private function get_fps():Float
	{
		return libVlc.getFPS();
	}
}
#end
