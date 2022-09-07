package vlc;

#if cpp
import cpp.Pointer;
import cpp.Star;
import cpp.UInt8;
import haxe.io.Bytes;
import haxe.io.BytesData;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;

/**
 * @author Tommy Svensson
 */
class VlcBitmap extends Bitmap
{
	public var fullscreen(get, set):Bool;
	public var length(get, never):Int;
	public var videoWidth(get, never):Int;
	public var videoHeight(get, never):Int;
	public var playing(get, never):Bool;
	public var seekable(get, never):Bool;
	public var volume(get, set):Float;
	public var time(get, set):Int;
	public var position(get, set):Float;
	public var pixelData(get, never):Pointer<UInt8>;
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

	private var libVlc:Star<LibVLC> = new LibVLC();

	private var frameSize:Int;
	private var _width:Null<Float>;
	private var _height:Null<Float>;
	private var frameRect:Rectangle;

	public function new()
	{
		super();

		addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	public function play(?source:String):Void
	{
		if (source != null)
			libVlc.play(source);
		else
			libVlc.play();

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

		if (bitmapData != null)
		{
			bitmapData.dispose();
			bitmapData = null;
		}

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
		for (i in 0...19) // 19 flags
		{
			var flag:Float = libVlc.getFlag(i);
			if (flag != -1)
			{
				switch (i)
				{
					// case 0:
					// 	statusOnMediaChanged(flag);
					case 1:
						statusOnNothingSpecial();
					case 2:
						statusOnOpening();
					case 3:
						statusOnBuffering(flag);
					case 4:
						statusOnPlaying();
					case 5:
						statusOnPaused();
					case 6:
						statusOnStopped();
					case 7:
						statusOnForward();
					case 8:
						statusOnBackward();
					case 9:
						statusOnEndReached();
					case 10:
						statusOnEncounteredError();
					case 11:
						statusOnTimeChanged(Std.int(flag));
					case 12:
						statusOnPositionChanged(flag);
					case 13:
						statusOnSeekableChanged(flag == 1);
					case 14:
						statusOnPausableChanged(flag == 1);
					case 15:
						statusOnTitleChanged(Std.int(flag));
					// case 16:
					// 	statusOnSnapshotTaken(flag);
					case 17:
						statusOnLengthChanged(Std.int(flag));
					case 18:
						statusOnVout(Std.int(flag));
				}
				libVlc.setFlag(i, -1);
			}
		}
	}

	private function render():Void
	{
		if (initComplete && playing)
		{
			// libVlc.getPixelData() sometimes returns null
			if (pixelData != null)
			{
				var bufferMem:BytesData = pixelData.toUnmanagedArray(frameSize);
				var byteArray:ByteArray = Bytes.ofData(bufferMem);
				// FIXME This specific line causes the game to sometimes, but not always, crash.
				// I may have to resort to using hxCodec if I can't figure out how to fix this...
				bitmapData.setPixels(frameRect, byteArray);
			}
		}
	}

	private function videoInitComplete():Void
	{
		if (bitmapData != null)
			bitmapData.dispose();
		bitmapData = new BitmapData(videoWidth, videoHeight, true, 0);
		frameRect = new Rectangle(0, 0, videoWidth, videoHeight);

		if (_width != null)
			width = _width;
		else
			width = videoWidth;

		if (_height != null)
			height = _height;
		else
			height = videoHeight;

		frameSize = videoWidth * videoHeight * 4;

		initComplete = true;

		if (onVideoReady != null)
			onVideoReady();
	}

	// private function statusOnMediaChanged(newMedia: /*Pointer<libvlc_media_t>*/ Dynamic):Void
	// {
	// }

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

	// private function statusOnSnapshotTaken(pszFilename:String):Void
	// {
	// }

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

	private function get_length():Int
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

	private function get_pixelData():Pointer<UInt8>
	{
		return libVlc.getPixelData();
	}
}
#end
