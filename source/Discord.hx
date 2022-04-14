package;

#if FEATURE_DISCORD
import Sys.sleep;
import discord_rpc.DiscordRpc;
import sys.thread.Thread;
#if FEATURE_LUA
import llua.Lua.Lua_helper;
import llua.State;
#end

class DiscordClient
{
	public static var isInitialized:Bool = false;

	public static function shutdown():Void
	{
		DiscordRpc.shutdown();
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

	private static function onError(_code:Int, _message:String):Void
	{
		Debug.logError('Error! $_code : $_message');
	}

	private static function onDisconnected(_code:Int, _message:String):Void
	{
		Debug.logInfo('Disconnected! $_code : $_message');
	}

	public static function initialize():Void
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
				sleep(2);
			}
		});
		Debug.logTrace('Discord Client initialized');
		isInitialized = true;
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

	#if FEATURE_LUA
	public static function addLuaCallbacks(lua:State):Void
	{
		Lua_helper.add_callback(lua, 'changePresence', (details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) ->
		{
			changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
		});
	}
	#end
}
#end
