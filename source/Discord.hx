package;

#if FEATURE_DISCORD
import discord_rpc.DiscordRpc;
import openfl.Lib;
import sys.thread.Thread;

class DiscordClient
{
	private static var isInitialized:Bool = false;

	public static function initialize():Void
	{
		if (!isInitialized)
		{
			Debug.logTrace('Discord Client starting...');
			DiscordRpc.start({
				clientID: '863222024192262205',
				onReady: onReady,
				onError: onError,
				onDisconnected: onDisconnected
			});
			Debug.logTrace('Discord Client started.');

			Thread.create(() ->
			{
				while (true)
				{
					DiscordRpc.process();
					// Debug.logTrace('Discord Client Update');
					Sys.sleep(2);
				}
			});

			// Lib.application.onUpdate.add((code:Int) ->
			// {
			// 	DiscordRpc.process();
			// });

			Lib.application.onExit.add((exitCode:Int) ->
			{
				DiscordRpc.shutdown();
			});

			Debug.logTrace('Discord Client initialized');
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
			startTimestamp: Std.int(startTimestamp / 1000),
			endTimestamp: Std.int(endTimestamp / 1000)
		});

		// Debug.logTrace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp');
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
