package funkin;

#if FEATURE_VIDEOS
import flixel.FlxG;
import openfl.events.Event;

using StringTools;

#if (js && html5)
import openfl.events.NetStatusEvent;
import openfl.media.SoundTransform;
import openfl.media.Video;
import openfl.net.NetConnection;
import openfl.net.NetStream;
#elseif cpp
import vlc.VlcBitmap;
#end

class VideoHandler
{
	public static var instance:VideoHandler;

	public var finishCallback:() -> Void;

	#if (js && html5)
	private var netStream:NetStream;
	private var player:Video;
	#elseif cpp
	private var vlcBitmap:VlcBitmap;
	#end

	public function new(name:String)
	{
		instance = this;

		#if (js && html5)
		player = new Video();
		player.addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		player.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		FlxG.addChildBelowMouse(player);

		var netConnect:NetConnection = new NetConnection();
		netConnect.connect(null);
		netStream = new NetStream(netConnect);
		netStream.client = {
			onMetaData: () ->
			{
				player.attachNetStream(netStream);
				updateSize();
			},
			// Can't do this because it gets called when the video starts for some reason,
			// rather than when it ends like the NetStream class suggests
			// onPlayStatus: onComplete
		};
		netConnect.addEventListener(NetStatusEvent.NET_STATUS, (event:NetStatusEvent) ->
		{
			if (event.info.code == 'NetStream.Play.Complete')
			{
				onComplete();
			}
		});
		netStream.play(name);
		#elseif cpp
		// by Polybius, check out PolyEngine! https://github.com/polybiusproxy/PolyEngine

		vlcBitmap = new VlcBitmap();
		vlcBitmap.onVideoReady = updateSize;
		vlcBitmap.onComplete = onComplete;
		vlcBitmap.onError = onError;
		vlcBitmap.addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		vlcBitmap.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		FlxG.addChildBelowMouse(vlcBitmap);

		vlcBitmap.play(name);
		#end
	}

	public function onFocusLost():Void
	{
		#if (js && html5)
		var playbackCtrl:NetStream = netStream;
		#elseif cpp
		var playbackCtrl:VlcBitmap = vlcBitmap;
		#else
		var playbackCtrl:Dynamic = null;
		#end

		if (playbackCtrl != null)
		{
			if (FlxG.autoPause)
			{
				playbackCtrl.pause();
			}
		}
	}

	public function onFocus():Void
	{
		#if (js && html5)
		var playbackCtrl:NetStream = netStream;
		#elseif cpp
		var playbackCtrl:VlcBitmap = vlcBitmap;
		#else
		var playbackCtrl:Dynamic = null;
		#end

		if (playbackCtrl != null)
		{
			if (FlxG.autoPause)
			{
				playbackCtrl.resume();
			}
		}
	}

	private function onAddedToStage(e:Event):Void
	{
		#if (js && html5)
		var displayObj:Video = player;
		#elseif cpp
		var displayObj:VlcBitmap = vlcBitmap;
		#else
		var displayObj:Dynamic = null;
		#end

		if (displayObj != null)
		{
			displayObj.removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			displayObj.stage.addEventListener(Event.RESIZE, onResize);
		}
	}

	private function onEnterFrame(event:Event):Void
	{
		// Skip video if the accept keybind  is pressed
		if (PlayerSettings.player1.controls.ACCEPT)
		{
			onComplete();
		}

		#if (js && html5)
		var soundTransform:SoundTransform = new SoundTransform(FlxG.sound.volume, netStream.soundTransform.pan);
		if (FlxG.sound.muted)
		{
			soundTransform.volume = 0;
		}
		netStream.soundTransform = soundTransform;
		#elseif cpp
		// TODO There's probably a mathematical equation related to decibels which fixes this properly, so I should find that; maybe HaxeFlixel uses it
		// shitty volume fix
		vlcBitmap.volume = 0;
		if (!FlxG.sound.muted && FlxG.sound.volume > 0.01)
		{
			// Kind of fixes the volume being too low when you decrease it
			vlcBitmap.volume = FlxG.sound.volume * 0.5 + 0.5;
		}

		// vlcBitmap.volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		#end
	}

	private function onResize(e:Event):Void
	{
		updateSize();
	}

	// TODO If hxCodec doesn't have this, and I have to switch to hxCodec to get video to work again, I'm going to (1) make a PR to add this auto-resize code, and (2) add the HTML5 parts of VideoHandler.
	private function updateSize():Void
	{
		#if (js && html5)
		var displayObj:Video = player;
		#elseif cpp
		var displayObj:VlcBitmap = vlcBitmap;
		#else
		var displayObj:Dynamic = null;
		#end

		if (displayObj != null && displayObj.stage != null)
		{
			var stageWidth:Int = displayObj.stage.stageWidth;
			var stageHeight:Int = displayObj.stage.stageHeight;
			var stageRatio:Float = stageWidth / stageHeight;

			var ratio:Float = displayObj.videoWidth / displayObj.videoHeight;

			if (stageRatio > ratio)
			{
				displayObj.width = stageHeight * ratio;
				displayObj.height = stageHeight;
			}
			else
			{
				displayObj.width = stageWidth;
				displayObj.height = stageWidth / ratio;
			}
		}
	}

	private function onComplete():Void
	{
		#if (js && html5)
		var displayObj:Video = player;
		#elseif cpp
		var displayObj:VlcBitmap = vlcBitmap;
		#else
		var displayObj:Dynamic = null;
		#end

		if (displayObj != null)
		{
			if (FlxG.game.contains(displayObj))
			{
				FlxG.game.removeChild(displayObj);
			}
			displayObj.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
			#if (js && html5)
			netStream.dispose();
			#elseif cpp
			displayObj.stop();

			// Clean player, just in case!
			displayObj.dispose();
			#end
		}

		if (finishCallback != null)
		{
			finishCallback();
		}

		instance = null;
	}

	private function onError():Void
	{
		Debug.logError('An error has occured while trying to load the video.\nPlease, check if the file you\'re loading exists.');
		if (finishCallback != null)
		{
			finishCallback();
		}

		instance = null;
	}
}
#end
