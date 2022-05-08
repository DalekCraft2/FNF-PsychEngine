package;

import flixel.FlxG;
import openfl.events.Event;

using StringTools;

#if web
import openfl.events.NetStatusEvent;
import openfl.media.SoundTransform;
import openfl.media.Video;
import openfl.net.NetConnection;
import openfl.net.NetStream;
#else
import vlc.VlcBitmap;
#end

// TODO Find a way to speed up the loading times for desktop video (Maybe use the WebmHandler from Kade Engine)
#if FEATURE_VIDEOS
class VideoHandler
{
	public static var instance:VideoHandler;

	public var finishCallback:() -> Void;

	#if web
	private var netStream:NetStream;
	private var player:Video;
	#elseif desktop
	private var vlcBitmap:VlcBitmap;
	#end

	public function new(name:String)
	{
		instance = this;

		#if web
		FlxG.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		player = new Video();
		player.x = 0;
		player.y = 0;
		FlxG.addChildBelowMouse(player);
		var netConnect:NetConnection = new NetConnection();
		netConnect.connect(null);
		netStream = new NetStream(netConnect);
		netStream.client = {
			onMetaData: () ->
			{
				player.attachNetStream(netStream);
				player.width = FlxG.width;
				player.height = FlxG.height;
			}
		};
		netConnect.addEventListener(NetStatusEvent.NET_STATUS, (event:NetStatusEvent) ->
		{
			if (event.info.code == 'NetStream.Play.Complete')
			{
				onComplete();
			}
		});
		netStream.play(name);
		#elseif desktop
		// by Polybius, check out PolyEngine! https://github.com/polybiusproxy/PolyEngine

		vlcBitmap = new VlcBitmap();
		vlcBitmap.height = FlxG.stage.stageHeight;
		vlcBitmap.width = FlxG.stage.stageHeight * (16 / 9);

		vlcBitmap.onComplete = onComplete;
		vlcBitmap.onError = onError;

		FlxG.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		vlcBitmap.repeat = 0;
		vlcBitmap.inWindow = false;
		vlcBitmap.fullscreen = false;
		onEnterFrame(null);

		FlxG.addChildBelowMouse(vlcBitmap);
		vlcBitmap.play(checkFile(name));
		#end
	}

	public function onFocusLost():Void
	{
		#if web
		if (netStream != null)
		{
			if (FlxG.autoPause)
			{
				netStream.pause();
			}
		}
		#elseif desktop
		if (vlcBitmap != null)
		{
			if (FlxG.autoPause)
			{
				vlcBitmap.pause();
			}
		}
		#end
	}

	public function onFocus():Void
	{
		#if web
		if (netStream != null)
		{
			if (FlxG.autoPause)
			{
				netStream.resume();
			}
		}
		#elseif desktop
		if (vlcBitmap != null)
		{
			if (FlxG.autoPause || !vlcBitmap.isPlaying)
			{
				vlcBitmap.resume();
			}
		}
		#end
	}

	// This function also checks for whether the video should be skipped, and I would rename it to "update" if that wasn't taken by FlxBasic
	private function onEnterFrame(event:Event):Void
	{
		#if web
		// Skip video if the accept keybind is pressed
		if (PlayerSettings.player1.controls.ACCEPT)
		{
			onComplete();
		}

		var soundTransform:SoundTransform = new SoundTransform(FlxG.sound.volume, netStream.soundTransform.pan);
		if (FlxG.sound.muted)
		{
			soundTransform.volume = 0;
		}
		netStream.soundTransform = soundTransform;
		#elseif desktop
		// Skip video if the accept keybind  is pressed
		if (PlayerSettings.player1.controls.ACCEPT)
		{
			if (vlcBitmap.isPlaying)
			{
				onComplete();
			}
		}

		// shitty volume fix
		vlcBitmap.volume = 0;
		if (!FlxG.sound.muted && FlxG.sound.volume > 0.01)
		{ // Kind of fixes the volume being too low when you decrease it
			vlcBitmap.volume = FlxG.sound.volume * 0.5 + 0.5;
		}
		#end
	}

	private function onComplete():Void
	{
		#if web
		netStream.close();

		netStream.dispose();
		if (FlxG.game.contains(player))
		{
			FlxG.game.removeChild(player);
		}
		#elseif desktop
		vlcBitmap.stop();

		// Clean player, just in case!
		vlcBitmap.dispose();

		if (FlxG.game.contains(vlcBitmap))
		{
			FlxG.game.removeChild(vlcBitmap);
		}
		#end

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

	#if desktop
	private function checkFile(fileName:String):String
	{
		var pDir:String = '';
		var appDir:String = 'file:///${Sys.getCwd()}/';
		if (!fileName.contains(':')) // Not a path
			pDir = appDir;
		else if (!fileName.contains('file://') || !fileName.contains('http')) // C:, D: etc? ..missing "file:///" ?
			pDir = 'file:///';
		return '$pDir$fileName';
	}
	#end
}
#end
