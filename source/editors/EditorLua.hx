package editors;

#if FEATURE_LUA
import Type.ValueType;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import lime.app.Application;
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

// TODO What if FunkinLua extended this to reduce code duplication? Maybe same with PlayState and EditorPlayState?
class EditorLua
{
	private static final FUNCTION_STOP:Int = 1;
	private static final FUNCTION_CONTINUE:Int = 0;

	private var lua:State;

	public function new(script:String)
	{
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);

		Debug.logTrace('Lua version: ${Lua.version()}');
		Debug.logTrace('LuaJIT version: ${Lua.versionJIT()}');

		var result:Dynamic = LuaL.dofile(lua, script);
		var resultStr:String = Lua.tostring(lua, result);
		if (resultStr != null && result != 0)
		{
			Application.current.window.alert(resultStr, 'Error on .LUA script!');
			Debug.logError('Error on .LUA script! $resultStr');
			lua = null;
			return;
		}
		Debug.logTrace('Lua file loaded succesfully: $script');

		// Lua variables
		set('FUNCTION_STOP', FUNCTION_STOP);
		set('FUNCTION_CONTINUE', FUNCTION_CONTINUE);

		// These two are for legacy support
		set('Function_Stop', FUNCTION_STOP);
		set('Function_Continue', FUNCTION_CONTINUE);

		set('inChartEditor', true);

		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.song.bpm);
		set('scrollSpeed', PlayState.song.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('songId', PlayState.song.songId);
		set('songName', PlayState.song.songName);

		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		for (i in 0...4)
		{
			set('defaultPlayerStrumX$i', 0);
			set('defaultPlayerStrumY$i', 0);
			set('defaultOpponentStrumX$i', 0);
			set('defaultOpponentStrumY$i', 0);
		}

		set('downscroll', Options.save.data.downScroll);
		set('middlescroll', Options.save.data.middleScroll);

		Lua_helper.add_callback(lua, 'getProperty', function(variable:String):Dynamic
		{
			var killMe:Array<String> = variable.split('.');
			if (killMe.length > 1)
			{
				var coverMeInPiss:Dynamic = Reflect.getProperty(EditorPlayState.instance, killMe[0]);

				for (i in 1...killMe.length - 1)
				{
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length - 1]);
			}
			return Reflect.getProperty(EditorPlayState.instance, variable);
		});
		Lua_helper.add_callback(lua, 'setProperty', function(variable:String, value:Dynamic):Void
		{
			var killMe:Array<String> = variable.split('.');
			if (killMe.length > 1)
			{
				var coverMeInPiss:Dynamic = Reflect.getProperty(EditorPlayState.instance, killMe[0]);

				for (i in 1...killMe.length - 1)
				{
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				Reflect.setProperty(coverMeInPiss, killMe[killMe.length - 1], value);
				return;
			}
			Reflect.setProperty(EditorPlayState.instance, variable, value);
		});
		Lua_helper.add_callback(lua, 'getPropertyFromGroup', function(obj:String, index:Int, variable:Dynamic):Dynamic
		{
			if (Std.isOfType(Reflect.getProperty(EditorPlayState.instance, obj), FlxTypedGroup))
			{
				return Reflect.getProperty(Reflect.getProperty(EditorPlayState.instance, obj).members[index], variable);
			}

			var leArray:Dynamic = Reflect.getProperty(EditorPlayState.instance, obj)[index];
			if (leArray != null)
			{
				if (Type.typeof(variable) == ValueType.TInt)
				{
					return leArray[variable];
				}
				return Reflect.getProperty(leArray, variable);
			}
			return null;
		});
		Lua_helper.add_callback(lua, 'setPropertyFromGroup', function(obj:String, index:Int, variable:Dynamic, value:Dynamic):Void
		{
			if (Std.isOfType(Reflect.getProperty(EditorPlayState.instance, obj), FlxTypedGroup))
			{
				Reflect.setProperty(Reflect.getProperty(EditorPlayState.instance, obj).members[index], variable, value);
				return;
			}

			var leArray:Dynamic = Reflect.getProperty(EditorPlayState.instance, obj)[index];
			if (leArray != null)
			{
				if (Type.typeof(variable) == ValueType.TInt)
				{
					leArray[variable] = value;
					return;
				}
				Reflect.setProperty(leArray, variable, value);
			}
		});
		Lua_helper.add_callback(lua, 'removeFromGroup', function(obj:String, index:Int, dontDestroy:Bool = false):Void
		{
			if (Std.isOfType(Reflect.getProperty(EditorPlayState.instance, obj), FlxTypedGroup))
			{
				var sex:Dynamic = Reflect.getProperty(EditorPlayState.instance, obj).members[index];
				if (!dontDestroy)
					sex.kill();
				Reflect.getProperty(EditorPlayState.instance, obj).remove(sex, true);
				if (!dontDestroy)
					sex.destroy();
				return;
			}
			Reflect.getProperty(EditorPlayState.instance, obj).remove(Reflect.getProperty(EditorPlayState.instance, obj)[index]);
		});

		Lua_helper.add_callback(lua, 'getColorFromHex', function(color:String):Int
		{
			if (!color.startsWith('0x'))
				color = '0xFF$color';
			return Std.parseInt(color);
		});

		Lua_helper.add_callback(lua, 'setGraphicSize', function(obj:String, x:Int, y:Int = 0):Void
		{
			var poop:FlxSprite = Reflect.getProperty(EditorPlayState.instance, obj);
			if (poop != null)
			{
				poop.setGraphicSize(x, y);
				poop.updateHitbox();
				return;
			}
		});
		Lua_helper.add_callback(lua, 'scaleObject', function(obj:String, x:Float, y:Float):Void
		{
			var poop:FlxSprite = Reflect.getProperty(EditorPlayState.instance, obj);
			if (poop != null)
			{
				poop.scale.set(x, y);
				poop.updateHitbox();
				return;
			}
		});
		Lua_helper.add_callback(lua, 'updateHitbox', function(obj:String):Void
		{
			var poop:FlxSprite = Reflect.getProperty(EditorPlayState.instance, obj);
			if (poop != null)
			{
				poop.updateHitbox();
				return;
			}
		});

		#if FEATURE_DISCORD
		DiscordClient.addLuaCallbacks(lua);
		#end

		call('onCreate', []);
	}

	public function call(event:String, args:Array<Dynamic>):Dynamic
	{
		if (lua == null)
		{
			return FUNCTION_CONTINUE;
		}

		Lua.getglobal(lua, event);

		for (arg in args)
		{
			Convert.toLua(lua, arg);
		}

		var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);
		if (result != null && resultIsAllowed(lua, result))
		{
			/*var resultStr:String = Lua.tostring(lua, result);
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1); */
			if (Lua.type(lua, -1) == Lua.LUA_TSTRING)
			{
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				if (error == 'attempt to call a nil value')
				{ // Makes it ignore warnings and not break stuff if you didn't put the functions on your lua file
					return FUNCTION_CONTINUE;
				}
			}

			var conv:Dynamic = Convert.fromLua(lua, result);
			return conv;
		}
		return FUNCTION_CONTINUE;
	}

	public function resultIsAllowed(leLua:State, ?leResult:Int):Bool
	{ // Makes it ignore warnings
		switch (Lua.type(leLua, leResult))
		{
			case Lua.LUA_TNIL | Lua.LUA_TBOOLEAN | Lua.LUA_TNUMBER | Lua.LUA_TSTRING | Lua.LUA_TTABLE:
				return true;
		}
		return false;
	}

	public function set(variable:String, data:Dynamic):Void
	{
		if (lua == null)
		{
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

	public function getBool(variable:String):Bool
	{
		var result:String;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if (result == null)
		{
			return false;
		}

		// YES! FINALLY IT WORKS
		// Debug.logTrace('variable: $variable, $result');
		return (result == 'true');
	}

	public function stop():Void
	{
		if (lua == null)
		{
			return;
		}

		Lua.close(lua);
		lua = null;
	}
}
#end
