package;

import flixel.FlxBasic;
import flixel.FlxG;

using StringTools;

#if web
import openfl.events.NetStatusEvent;
import openfl.media.Video;
import openfl.net.NetConnection;
import openfl.net.NetStream;
#else
import openfl.events.Event;
import vlc.VlcBitmap;
#end

// TODO Find a way to speed up the loading times for desktop video (Maybe use the WebmHandler from Kade Engine)
#if FEATURE_VIDEOS
class FlxVideo extends FlxBasic
{
	public var finishCallback:() -> Void;

	#if desktop
	public static var vlcBitmap:VlcBitmap;
	#end

	public function new(name:String)
	{
		super();

		#if web
		var player:Video = new Video();
		player.x = 0;
		player.y = 0;
		FlxG.addChildBelowMouse(player);
		var netConnect:NetConnection = new NetConnection();
		netConnect.connect(null);
		var netStream:NetStream = new NetStream(netConnect);
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
				netStream.dispose();
				if (FlxG.game.contains(player))
					FlxG.game.removeChild(player);

				if (finishCallback != null)
					finishCallback();
			}
		});
		netStream.play(name);
		#elseif desktop
		// by Polybius, check out PolyEngine! https://github.com/polybiusproxy/PolyEngine

		vlcBitmap = new VlcBitmap();
		vlcBitmap.height = FlxG.stage.stageHeight;
		vlcBitmap.width = FlxG.stage.stageHeight * (16 / 9);

		vlcBitmap.onComplete = onVLCComplete;
		vlcBitmap.onError = onVLCError;

		FlxG.stage.addEventListener(Event.ENTER_FRAME, fixVolume);
		vlcBitmap.repeat = 0;
		vlcBitmap.inWindow = false;
		vlcBitmap.fullscreen = false;
		fixVolume(null);

		FlxG.addChildBelowMouse(vlcBitmap);
		vlcBitmap.play(checkFile(name));
		#end
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

		return pDir + fileName;
	}

	public static function onFocus():Void
	{
		if (vlcBitmap != null)
		{
			if (FlxG.autoPause || !vlcBitmap.isPlaying)
			{
				vlcBitmap.resume();
			}
		}
	}

	public static function onFocusLost():Void
	{
		if (vlcBitmap != null)
		{
			if (FlxG.autoPause)
			{
				vlcBitmap.pause();
			}
		}
	}

	// This function also checks for whether the video should be skipped, and I would rename it to "update" if that wasn't taken by FlxBasic
	private function fixVolume(e:Event):Void
	{
		// TODO Find a way to skip videos without causing the game to just freeze afterward
		// Skip video if enter is pressed
		// if (FlxG.keys.justPressed.ENTER)
		// {
		// 	if (vlcBitmap.isPlaying)
		// 	{
		// 		onVLCComplete();
		// 	}
		// }

		// shitty volume fix
		vlcBitmap.volume = 0;
		if (!FlxG.sound.muted && FlxG.sound.volume > 0.01)
		{ // Kind of fixes the volume being too low when you decrease it
			vlcBitmap.volume = FlxG.sound.volume * 0.5 + 0.5;
		}
	}

	public function onVLCComplete():Void
	{
		vlcBitmap.stop();

		// Clean player, just in case!
		vlcBitmap.dispose();

		if (FlxG.game.contains(vlcBitmap))
		{
			FlxG.game.removeChild(vlcBitmap);
		}

		if (finishCallback != null)
		{
			finishCallback();
		}
	}

	private function onVLCError():Void
	{
		Debug.logError('An error has occured while trying to load the video.\nPlease, check if the file you\'re loading exists.');
		if (finishCallback != null)
		{
			finishCallback();
		}
	}
	#end
}
#end
