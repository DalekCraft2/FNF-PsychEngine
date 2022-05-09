package vlc;

#if cpp
import cpp.NativeArray;
import cpp.UInt8;
import flixel.FlxG;
import haxe.io.Bytes;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.errors.Error;
import openfl.events.Event;
import openfl.geom.Rectangle;

/**
 * @author Tommy S
 */
@:cppFileCode('#include "LibVLC.cpp"')
class VlcBitmap extends Bitmap
{
	/////////////////////////////////////////////////////////////////////////////////////
	// ===================================================================================
	// Consts
	//-----------------------------------------------------------------------------------
	// ===================================================================================
	// Properties
	//-----------------------------------------------------------------------------------
	public var videoWidth:Int;
	public var videoHeight:Int;
	public var repeat:Int = 0;
	public var duration:Float;
	public var length:Float;
	public var inWindow:Bool;
	public var initComplete:Bool;
	public var fullscreen:Bool;
	public var volume(default, set):Float = 1;

	public var isDisposed:Bool;
	public var isPlaying:Bool;
	public var disposeOnStop:Bool = false;
	public var time:Int;

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
	private var bufferMem:Array<UInt8>;
	private var libvlc:LibVLC;

	// ===================================================================================
	// Variables
	//-----------------------------------------------------------------------------------
	private var frameSize:Int;
	private var _width:Null<Float>;
	private var _height:Null<Float>;
	private var texture:RectangleTexture;
	private var texture2:RectangleTexture;
	private var bmdBuf:BitmapData;
	private var bmdBuf2:BitmapData;
	private var oldTime:Int;
	private var flipBuffer:Bool;
	private var frameRect:Rectangle;
	private var screenWidth:Float;
	private var screenHeight:Float;

	/////////////////////////////////////////////////////////////////////////////////////

	public function new()
	{
		super(null, null, true);

		init();
	}

	private function mThread():Void
	{
		init();
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function init():Void
	{
		addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
	}

	private function onAddedToStage(e:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

		libvlc = LibVLC.create();
		stage.addEventListener(Event.RESIZE, onResize);
		stage.addEventListener(Event.ENTER_FRAME, vLoop);
	}

	/////////////////////////////////////////////////////////////////////////////////////

	public function play(?source:String):Void
	{
		libvlc.setRepeat(repeat);

		if (!inWindow)
		{
			if (source != null)
				libvlc.play(source);
			else
				libvlc.play();
		}
		else
		{
			if (source != null)
				libvlc.playInWindow(source);
			else
				libvlc.playInWindow();

			libvlc.setWindowFullscreen(fullscreen);
		}

		if (onPlay != null)
			onPlay();
	}

	public function stop():Void
	{
		isPlaying = false;
		libvlc.stop();
		// if (disposeOnStop)
		// 	dispose();

		if (onStop != null)
			onStop();
	}

	public function pause():Void
	{
		isPlaying = false;
		libvlc.pause();
		if (onPause != null)
			onPause();
	}

	public function resume():Void
	{
		isPlaying = true;
		libvlc.resume();
		if (onResume != null)
			onResume();
	}

	public function seek(seekTotime:Float):Void
	{
		libvlc.setPosition(seekTotime);
		if (onSeek != null)
			onSeek();
	}

	public function getFPS():Float
	{
		if (libvlc != null && initComplete)
			return libvlc.getFPS();
		else
			return 0;
	}

	public function getTime():Int
	{
		if (libvlc != null && initComplete)
			return libvlc.getTime();
		else
			return 0;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function checkFlags():Void
	{
		if (!isDisposed)
		{
			if (untyped __cpp__('libvlc->flags[1]') == 1)
			{
				untyped __cpp__('libvlc->flags[1]=-1');
				statusOnPlaying();
			}
			if (untyped __cpp__('libvlc->flags[2]') == 1)
			{
				untyped __cpp__('libvlc->flags[2]=-1');
				statusOnPaused();
			}
			if (untyped __cpp__('libvlc->flags[3]') == 1)
			{
				untyped __cpp__('libvlc->flags[3]=-1');
				statusOnStopped();
			}
			if (untyped __cpp__('libvlc->flags[4]') == 1)
			{
				untyped __cpp__('libvlc->flags[4]=-1');
				statusOnEndReached();
			}
			if (untyped __cpp__('libvlc->flags[5]') != -1)
			{
				statusOnTimeChanged(untyped __cpp__('libvlc->flags[5]'));
			}
			if (untyped __cpp__('libvlc->flags[6]') != -1)
			{
				statusOnPositionChanged(untyped __cpp__('libvlc->flags[9]'));
			}
			if (untyped __cpp__('libvlc->flags[9]') == 1)
			{
				untyped __cpp__('libvlc->flags[9]=-1');
				statusOnError();
			}
			if (untyped __cpp__('libvlc->flags[10]') == 1)
			{
				untyped __cpp__('libvlc->flags[10]=-1');
				statusOnSeekableChanged(0);
			}
			if (untyped __cpp__('libvlc->flags[11]') == 1)
			{
				untyped __cpp__('libvlc->flags[11]=-1');
				statusOnOpening();
			}
			if (untyped __cpp__('libvlc->flags[12]') == 1)
			{
				untyped __cpp__('libvlc->flags[12]=-1');
				statusOnBuffering();
			}
			if (untyped __cpp__('libvlc->flags[13]') == 1)
			{
				untyped __cpp__('libvlc->flags[13]=-1');
				statusOnForward();
			}
			if (untyped __cpp__('libvlc->flags[14]') == 1)
			{
				untyped __cpp__('libvlc->flags[14]=-1');
				statusOnBackward();
			}
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function onResize(e:Event):Void
	{
		height = FlxG.stage.stageHeight;
		width = FlxG.stage.stageHeight * (16 / 9);
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function videoInitComplete():Void
	{
		videoWidth = libvlc.getWidth();
		videoHeight = libvlc.getHeight();

		duration = libvlc.getDuration();
		length = libvlc.getLength();

		if (bitmapData != null)
			bitmapData.dispose();

		if (texture != null)
			texture.dispose();
		if (texture2 != null)
			texture2.dispose();

		// BitmapData
		bitmapData = new BitmapData(videoWidth, videoHeight, true, 0);
		frameRect = new Rectangle(0, 0, videoWidth, videoHeight);

		// (Stage3D)
		// texture = Lib.current.stage.stage3Ds[0].context3D.createRectangleTexture(videoWidth, videoHeight, Context3DTextureFormat.BGRA, true);
		// this.bitmapData = BitmapData.fromTexture(texture);

		smoothing = true;

		if (_width != null)
			width = _width;
		else
			width = videoWidth;

		if (_height != null)
			height = _height;
		else
			height = videoHeight;

		bufferMem = [];
		frameSize = videoWidth * videoHeight * 4;

		setVolume(volume);

		initComplete = true;

		if (onVideoReady != null)
			onVideoReady();
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function vLoop(e):Void
	{
		checkFlags();
		render();
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function render():Void
	{
		var cTime:Int = Lib.getTimer();

		if ((cTime - oldTime) > 8.3) // min 8.3 ms between renders, but this is not a good way to do it...
		{
			oldTime = cTime;

			// if (isPlaying && texture != null) // (Stage3D)
			if (isPlaying)
			{
				try
				{
					NativeArray.setUnmanagedData(bufferMem, libvlc.getPixelData(), frameSize);
					if (bufferMem != null)
					{
						// BitmapData
						// libvlc.getPixelData() sometimes is null and the exe hangs ...
						if (libvlc.getPixelData() != null)
							bitmapData.setPixels(frameRect, Bytes.ofData(bufferMem));

						// (Stage3D)
						// texture.uploadFromByteArray(Bytes.ofData(cast(bufferMem)), 0);
						// this.width++; // This is a horrible hack to force the texture to update... Surely there is a better way...
						// this.width--;
					}
				}
				catch (e:Error)
				{
					Debug.logError('Error: $e');
					throw new Error('Render broke');
				}
			}
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function setVolume(vol:Float):Void
	{
		if (libvlc != null && initComplete)
			libvlc.setVolume(vol * 100);
	}

	public function getVolume():Float
	{
		if (libvlc != null && initComplete)
			return libvlc.getVolume();
		else
			return 0;
	}

	/////////////////////////////////////////////////////////////////////////////////////

	private function statusOnOpening():Void
	{
		if (onOpening != null)
			onOpening();
	}

	private function statusOnBuffering():Void
	{
		Debug.logTrace('buffering');

		if (onBuffer != null)
			onBuffer();
	}

	private function statusOnPlaying():Void
	{
		if (!initComplete)
		{
			isPlaying = true;
			initComplete = true;
			videoInitComplete();
		}
	}

	private function statusOnPaused():Void
	{
		if (isPlaying)
			isPlaying = false;

		if (onPause != null)
			onPause();
	}

	private function statusOnStopped():Void
	{
		if (isPlaying)
			isPlaying = false;

		if (onStop != null)
			onStop();
	}

	private function statusOnEndReached():Void
	{
		if (isPlaying)
			isPlaying = false;

		// Debug.logTrace('End reached!');
		if (onComplete != null)
			onComplete();
	}

	private function statusOnTimeChanged(newTime:Int):Void
	{
		time = newTime;
		if (onProgress != null)
			onProgress();
	}

	private function statusOnPositionChanged(newPos:Int):Void
	{
	}

	private function statusOnSeekableChanged(newPos:Int):Void
	{
		if (onSeek != null)
			onSeek();
	}

	private function statusOnForward():Void
	{
	}

	private function statusOnBackward():Void
	{
	}

	private function onDisplay():Void
	{
		// render();
	}

	private function statusOnError():Void
	{
		Debug.logError('VLC ERROR - File not found?');

		if (onError != null)
			onError();
	}

	/////////////////////////////////////////////////////////////////////////////////////

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

	private function get_volume():Float
	{
		return volume;
	}

	private function set_volume(value:Float):Float
	{
		setVolume(value);
		return volume = value;
	}

	// ===================================================================================
	// Dispose
	//-----------------------------------------------------------------------------------

	public function dispose():Void
	{
		libvlc.stop();

		stage.removeEventListener(Event.ENTER_FRAME, vLoop);

		if (texture != null)
		{
			texture.dispose();
			texture = null;
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
		bufferMem = null;
		isDisposed = true;

		while (!isPlaying && !isDisposed)
		{
			libvlc.dispose();
			libvlc = null;
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////
}
#end
