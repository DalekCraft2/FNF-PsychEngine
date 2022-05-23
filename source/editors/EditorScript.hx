package editors;

#if FEATURE_SCRIPTS
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;

using StringTools;

#if FEATURE_LUA
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
#elseif hscript
import haxe.Constraints.Function;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
#end
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

// TODO Possibly switch to hscript
class EditorScript
{
	private static inline final FUNCTION_STOP:Int = FunkinScript.FUNCTION_STOP;
	private static inline final FUNCTION_CONTINUE:Int = FunkinScript.FUNCTION_CONTINUE;

	#if FEATURE_LUA
	// Fuck this, I can't figure out linc_lua, so I'mma set everything in Lua itself - Super
	// TODO Figure out linc_lua (Maybe use Lua.setglobal for these)
	private static inline final CLENSE:String = '
	os.execute = nil
	os.exit = nil
	package.loaded.os.execute = nil
	package.loaded.os.exit = nil
	process = nil
	package.loaded.process = nil';

	public var lua:State;
	#elseif hscript
	public var interp:Interp = new Interp();
	#end
	public var scriptName:String = '';

	private var gonnaClose:Bool = false;

	public function new(path:String)
	{
		var script:String = Paths.getTextDirect(path);
		if (script == null)
		{
			Debug.logError('Could not read script at path "$path"');
			return;
		}

		#if FEATURE_LUA
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);

		Debug.logTrace('Lua version: ${Lua.version()}');
		Debug.logTrace('LuaJIT version: ${Lua.versionJIT()}');

		LuaL.dostring(lua, CLENSE);
		var result:Int = LuaL.dostring(lua, script);
		var resultStr:String = Lua.tostring(lua, result);
		if (resultStr != null && result != 0)
		{
			Debug.logError('Error loading script "$path": $resultStr');
			scriptTrace('Error loading script: "$path"\n$resultStr', true, false);
			#if windows
			Debug.displayAlert(resultStr, 'Error loading script');
			#end
			lua = null;
			return;
		}
		#elseif hscript
		var parser:Parser = new Parser();
		var program:Expr = parser.parseString(script);
		if (program == null)
		{
			Debug.logError('Error loading script "$path"');
			scriptTrace('Error loading script: "$path"', true, false);
			// Debug.displayAlert('Error loading script');
			interp = null;
			return;
		}
		#end
		scriptName = script;
		Debug.logTrace('Script loaded succesfully: $path');

		// Script variables
		set('FUNCTION_STOP', FUNCTION_STOP);
		set('FUNCTION_CONTINUE', FUNCTION_CONTINUE);

		// These two are for legacy support
		set('Function_Stop', FUNCTION_STOP);
		set('Function_Continue', FUNCTION_CONTINUE);

		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', true);

		// Song/Week variables
		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.song.bpm);
		set('scrollSpeed', PlayState.song.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('songId', PlayState.song.songId);
		set('songName', PlayState.song.songName);
		set('song', PlayState.song.songId);
		set('startedCountdown', false);

		// Block require and os, Should probably have a proper function but this should be good enough for now until someone smarter comes along and recreates a safe version of the OS library
		set('require', false);

		// Camera variables
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen variables
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// EditorPlayState variables
		set('curBeat', 0);
		set('curStep', 0);

		set('score', 0);
		set('misses', 0);
		set('hits', 0);

		set('rating', 0);
		set('ratingName', '');
		set('ratingFC', '');
		set('version', EngineData.ENGINE_VERSION.trim());

		set('inGameOver', false);
		set('mustHitSection', false);
		set('altAnim', false);
		set('gfSection', false);

		// Gameplay settings
		set('healthGainMult', PlayStateChangeables.healthGain);
		set('healthLossMult', PlayStateChangeables.healthLoss);
		set('instakillOnMiss', PlayStateChangeables.instakillOnMiss);
		set('botPlay', PlayStateChangeables.botPlay);
		set('practiceMode', PlayStateChangeables.practiceMode);

		for (i in 0...NoteKey.createAll().length)
		{
			set('defaultPlayerStrumX$i', 0);
			set('defaultPlayerStrumY$i', 0);
			set('defaultOpponentStrumX$i', 0);
			set('defaultOpponentStrumY$i', 0);
		}

		// Some settings
		set('downScroll', Options.save.data.downScroll);
		set('middleScroll', Options.save.data.middleScroll);
		set('frameRate', Options.save.data.frameRate);
		set('ghostTapping', Options.save.data.ghostTapping);
		set('hideHud', Options.save.data.hideHud);
		set('timeBarType', Options.save.data.timeBarType);
		set('scoreZoom', Options.save.data.scoreZoom);
		set('cameraZoomOnBeat', Options.save.data.camZooms);
		set('flashingLights', Options.save.data.flashing);
		set('noteOffset', Options.save.data.noteOffset);
		set('healthBarAlpha', Options.save.data.healthBarAlpha);
		set('resetButton', Options.save.data.resetKey);
		set('lowQuality', Options.save.data.lowQuality);

		#if windows
		set('buildTarget', 'windows');
		#elseif linux
		set('buildTarget', 'linux');
		#elseif mac
		set('buildTarget', 'mac');
		#elseif html5
		set('buildTarget', 'browser');
		#elseif android
		set('buildTarget', 'android');
		#else
		set('buildTarget', 'unknown');
		#end

		set('getProperty', function(variable:String):Any
		{
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				return Reflect.getProperty(getPropertyLoopThingWhatever(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			return Reflect.getProperty(getInstance(), variable);
		});
		set('setProperty', function(variable:String, value:Any):Void
		{
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				Reflect.setProperty(getPropertyLoopThingWhatever(qualifierArray), qualifierArray[qualifierArray.length - 1], value);
				return;
			}
			Reflect.setProperty(getInstance(), variable, value);
		});
		set('getPropertyFromGroup', function(obj:String, index:Int, variable:Dynamic):Dynamic
		{
			var group:Dynamic = Reflect.getProperty(getInstance(), obj);
			if (Std.isOfType(group, FlxTypedGroup))
			{
				return getGroupStuff(group.members[index], variable);
			}

			var groupEntry:Dynamic = group[index];
			if (groupEntry != null)
			{
				if (Type.typeof(variable) == TInt)
				{
					return groupEntry[variable];
				}
				return getGroupStuff(groupEntry, variable);
			}
			scriptTrace('Object #$index from group: $obj doesn\'t exist!');
			return null;
		});
		set('setPropertyFromGroup', function(obj:String, index:Int, variable:Dynamic, value:Dynamic):Void
		{
			var group:Dynamic = Reflect.getProperty(getInstance(), obj);
			if (Std.isOfType(group, FlxTypedGroup))
			{
				setGroupStuff(group.members[index], variable, value);
				return;
			}

			var groupEntry:Dynamic = group[index];
			if (groupEntry != null)
			{
				if (Type.typeof(variable) == TInt)
				{
					groupEntry[variable] = value;
					return;
				}
				setGroupStuff(groupEntry, variable, value);
			}
		});
		set('removeFromGroup', function(obj:String, index:Int, dontDestroy:Bool = false):Void
		{
			var group:Dynamic = Reflect.getProperty(getInstance(), obj);
			if (Std.isOfType(group, FlxTypedGroup))
			{
				var groupEntry:FlxTypedGroup<FlxBasic> = group.members[index];
				if (!dontDestroy)
					groupEntry.kill();
				group.remove(groupEntry, true);
				if (!dontDestroy)
					groupEntry.destroy();
				return;
			}
			group.remove(group[index]);
		});

		set('getColorFromHex', function(color:String):Int
		{
			if (!color.startsWith('0x'))
				color = '0xFF$color';
			return Std.parseInt(color);
		});
		set('setGraphicSize', function(obj:String, x:Int, y:Int = 0):Void
		{
			var sprite:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (sprite != null)
			{
				sprite.setGraphicSize(x, y);
				sprite.updateHitbox();
				return;
			}
			scriptTrace('Couldn\'t find object: $obj');
		});
		set('scaleObject', function(obj:String, x:Float, y:Float):Void
		{
			var sprite:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (sprite != null)
			{
				sprite.scale.set(x, y);
				sprite.updateHitbox();
				return;
			}
			scriptTrace('Couldn\'t find object: $obj');
		});
		set('updateHitbox', function(obj:String):Void
		{
			var sprite:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (sprite != null)
			{
				sprite.updateHitbox();
				return;
			}
			scriptTrace('Couldn\'t find object: $obj');
		});
		set('updateHitboxFromGroup', function(group:String, index:Int):Void
		{
			if (Std.isOfType(Reflect.getProperty(getInstance(), group), FlxTypedGroup))
			{
				Reflect.getProperty(getInstance(), group).members[index].updateHitbox();
				return;
			}
			Reflect.getProperty(getInstance(), group)[index].updateHitbox();
		});

		set('close', function(printMessage:Bool):Void
		{
			if (!gonnaClose)
			{
				if (printMessage)
				{
					scriptTrace('Stopping script: $scriptName');
				}
			}
			gonnaClose = true;
		});

		#if FEATURE_DISCORD
		set('changePresence', (details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) ->
		{
			DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
		});
		#end

		#if (!FEATURE_LUA && hscript)
		interp.execute(program);
		#end

		call('onCreate', []);
	}

	public function get(variable:String):Dynamic
	{
		#if FEATURE_LUA
		if (lua != null)
		{
			Lua.getglobal(lua, variable);
			var result:Any = Convert.fromLua(lua, -1);
			Lua.pop(lua, 1);

			return result;
		}
		#elseif hscript
		if (interp != null)
		{
			return interp.variables.get(variable);
		}
		#end
		return null;
	}

	public function set(variable:String, data:Any):Void
	{
		#if FEATURE_LUA
		if (lua != null)
		{
			if (Reflect.isFunction(data))
			{
				Lua_helper.add_callback(lua, variable, data);
			}
			else
			{
				Convert.toLua(lua, data);
				Lua.setglobal(lua, variable);
			}
		}
		#elseif hscript
		if (interp != null)
		{
			interp.variables.set(variable, data);
		}
		#end
	}

	public function call(funcName:String, args:Array<Any>):Any
	{
		#if FEATURE_LUA
		if (lua != null)
		{
			Lua.getglobal(lua, funcName);

			for (arg in args)
			{
				Convert.toLua(lua, arg);
			}

			var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);
			var error:String = getLuaErrorMessage(lua);

			if (error != null)
			{
				if (error != 'attempt to call a nil value')
				{ // Makes it ignore warnings and not break stuff if you didn't put the functions in your script
					scriptTrace(error);
				}
			}
			if (result != null && resultIsAllowed(lua, result))
			{
				return Convert.fromLua(lua, result);
			}
		}
		#elseif hscript
		if (interp != null)
		{
			var possiblyFunc:Dynamic = get(funcName);
			if (Reflect.isFunction(possiblyFunc))
			{
				var func:Function = cast possiblyFunc;
				return Reflect.callMethod(null, func, args);
			}
		}
		#end
		return FUNCTION_CONTINUE;
	}

	public function stop():Void
	{
		#if FEATURE_LUA
		if (lua != null)
		{
			Lua.close(lua);
			lua = null;
		}
		#elseif hscript
		interp = null;
		#end
	}

	public function scriptTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false):Void
	{
		if (ignoreCheck || get('luaDebugMode'))
		{
			if (deprecated && !get('luaDeprecatedWarnings'))
			{
				return;
			}
			PlayState.instance.addTextToDebug(text);
			Debug.logTrace(text);
		}
	}

	#if FEATURE_LUA
	private function getLuaErrorMessage(lua:State):String
	{
		var error:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);
		return error;
	}

	private function resultIsAllowed(lua:State, ?result:Int):Bool
	{ // Makes it ignore warnings
		switch (Lua.type(lua, result))
		{
			case Lua.LUA_TNIL | Lua.LUA_TBOOLEAN | Lua.LUA_TNUMBER | Lua.LUA_TSTRING | Lua.LUA_TTABLE:
				return true;
		}
		return false;
	}
	#end

	private function getGroupStuff(group:Any, variable:String):Any
	{
		var qualifierArray:Array<String> = variable.split('.');
		if (qualifierArray.length > 1)
		{
			var object:Any = Reflect.getProperty(group, qualifierArray[0]);
			for (i in 1...qualifierArray.length - 1)
			{
				object = Reflect.getProperty(object, qualifierArray[i]);
			}
			return Reflect.getProperty(object, qualifierArray[qualifierArray.length - 1]);
		}
		return Reflect.getProperty(group, variable);
	}

	private function setGroupStuff(group:Any, variable:String, value:Any):Void
	{
		var qualifierArray:Array<String> = variable.split('.');
		if (qualifierArray.length > 1)
		{
			var object:Any = Reflect.getProperty(group, qualifierArray[0]);
			for (i in 1...qualifierArray.length - 1)
			{
				object = Reflect.getProperty(object, qualifierArray[i]);
			}
			Reflect.setProperty(object, qualifierArray[qualifierArray.length - 1], value);
			return;
		}
		Reflect.setProperty(group, variable, value);
	}

	private function getPropertyLoopThingWhatever(qualifierArray:Array<String>, ?checkForTextsToo:Bool = true):Any
	{
		var object:Any = getObjectDirectly(qualifierArray[0], checkForTextsToo);
		for (i in 1...qualifierArray.length - 1)
		{
			object = Reflect.getProperty(object, qualifierArray[i]);
		}
		return object;
	}

	private function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Any
	{
		return Reflect.getProperty(getInstance(), objectName);
	}

	private inline function getInstance():FlxState
	{
		return EditorPlayState.instance;
	}
}
#end
