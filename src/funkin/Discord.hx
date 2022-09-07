package funkin;

#if FEATURE_DISCORD
import discord_rpc.DiscordRpc;
import openfl.Lib;

class DiscordClient
{
	private static var isInitialized:Bool = false;

	public static function initialize():Void
	{
		if (!isInitialized)
		{
			DiscordRpc.start({
				clientID: '863222024192262205',
				onReady: onReady,
				onError: onError,
				onDisconnected: onDisconnected
			});

			Lib.application.onUpdate.add((code:Int) ->
			{
				DiscordRpc.process();
			});

			Lib.application.onExit.add((exitCode:Int) ->
			{
				DiscordRpc.shutdown();
			});

			Debug.logInfo('Started!');

			isInitialized = true;
		}
	}

	public static function changePresence(details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Void
	{
		var startTimestamp:Float = hasStartTimestamp ? Date.now().getTime() : 0;

		if (endTimestamp > 0)
		{
			endTimestamp = startTimestamp + endTimestamp;
		}

		DiscordRpc.presence({
			details: details,
			state: state,
			largeImageKey: 'icon',
			largeImageText: 'Engine Version: ${EngineData.ENGINE_VERSION}',
			smallImageKey: smallImageKey,
			// Obtained times are in milliseconds so they are divided so Discord can use it
			startTimestamp: Std.int(startTimestamp / TimingConstants.SECONDS_PER_MINUTE),
			endTimestamp: Std.int(endTimestamp / TimingConstants.MILLISECONDS_PER_SECOND)
		});
	}

	private static function onReady():Void
	{
		DiscordRpc.presence({
			details: 'In the Menus',
			state: null,
			largeImageKey: 'icon',
			largeImageText: 'Mock Engine'
		});
	}

	// FIXME Repeated errors if no internet access
	private static function onError(code:Int, message:String):Void
	{
		Debug.logError('Error! $code : $message');
	}

	private static function onDisconnected(code:Int, message:String):Void
	{
		Debug.logInfo('Disconnected! $code : $message');
	}
}
#end
