package funkin;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.tweens.FlxEase;
import funkin.states.PlayState;
import funkin.states.substates.GameOverSubState;
import openfl.display.BlendMode;

using StringTools;

#if FEATURE_SCRIPTS
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import funkin.Character.CharacterRole;
import funkin.Character.CharacterRoleTools;
import funkin.DialogueBoxPsych.DialogueDef;
import funkin.chart.container.Song;
import funkin.states.FreeplayState;
import funkin.states.LoadingState;
import funkin.states.StoryMenuState;
import haxe.io.Path;
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
import funkin.Discord.DiscordClient;
#end
#end
// TODO Possibly switch to hScript
// TODO Add a "callMethod" function to the script API
// TODO Make a custom exception to be thrown in some of the lua callbacks so the script instances can catch them and print the info
class FunkinScript
{
	#if FEATURE_SCRIPTS
	public static final FUNCTION_CONTINUE:Any = 0;
	public static final FUNCTION_STOP:Any = 1;
	public static final FUNCTION_STOP_LUA:Any = 2;

	#if FEATURE_LUA
	public var lua:State;
	#elseif hscript
	public var interp:Interp = new Interp();
	#end
	public var scriptName:String = '';

	private var closed:Bool = false;
	#end

	public static function getPropertyLoop(qualifierArray:Array<String>, checkForTextsToo:Bool = true, noGameOver:Bool = false):Any
	{
		var object:Any = getObjectDirectly(qualifierArray[0], checkForTextsToo, noGameOver);
		for (i in 1...qualifierArray.length - 1)
		{
			object = getVarInArray(object, qualifierArray[i]);
			if (object == null)
				return null;
		}
		return object;
	}

	// TODO Study how Psych uses these two functions
	public static function getVarInArray(instance:Dynamic, variable:String):Any
	{
		var arraySplit:Array<String> = variable.split('[');
		if (arraySplit.length > 1)
		{
			var object:Dynamic = Reflect.getProperty(instance, arraySplit[0]);
			for (i in 1...arraySplit.length)
			{
				var key:Dynamic = arraySplit[i].substr(0, arraySplit[i].length - 1); // Minus 1 to remove the second bracket
				object = object[key];
			}
			return object;
		}
		return Reflect.getProperty(instance, variable);
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
	{
		var arraySplit:Array<String> = variable.split('[');
		if (arraySplit.length > 1)
		{
			var object:Dynamic = Reflect.getProperty(instance, arraySplit[0]);
			for (i in 1...arraySplit.length)
			{
				var key:Dynamic = arraySplit[i].substr(0, arraySplit[i].length - 1); // Minus 1 to remove the second bracket
				if (i >= arraySplit.length - 1) // Last array
					object[key] = value;
				else // Anything else
					object = object[key];
			}
			return object;
		}
		Reflect.setProperty(instance, variable, value);
		return true;
	}

	private static function getPropertyFromGroup(group:Any, variable:String):Any
	{
		var qualifierArray:Array<String> = variable.split('.');
		if (qualifierArray.length > 1)
		{
			var object:Any = Reflect.getProperty(group, qualifierArray[0]);
			for (i in 1...qualifierArray.length - 1)
			{
				object = Reflect.getProperty(object, qualifierArray[i]);
				if (object == null)
					return null;
			}
			return Reflect.getProperty(object, qualifierArray[qualifierArray.length - 1]);
		}
		return Reflect.getProperty(group, variable);
	}

	private static function setPropertyFromGroup(group:Any, variable:String, value:Any):Void
	{
		var qualifierArray:Array<String> = variable.split('.');
		if (qualifierArray.length > 1)
		{
			var object:Any = Reflect.getProperty(group, qualifierArray[0]);
			for (i in 1...qualifierArray.length - 1)
			{
				object = Reflect.getProperty(object, qualifierArray[i]);
				if (object == null)
					return;
			}
			Reflect.setProperty(object, qualifierArray[qualifierArray.length - 1], value);
			return;
		}
		Reflect.setProperty(group, variable, value);
	}

	public static function getObjectDirectly(objectName:String, checkForTextsToo:Bool = true, noGameOver:Bool = false):Any
	{
		#if FEATURE_SCRIPTS
		if (PlayState.instance.scriptSprites.exists(objectName))
		{
			return PlayState.instance.scriptSprites.get(objectName);
		}
		else if (PlayState.stage.layers.exists(objectName))
		{
			return PlayState.stage.layers.get(objectName);
		}
		else if (checkForTextsToo && PlayState.instance.scriptTexts.exists(objectName))
		{
			return PlayState.instance.scriptTexts.get(objectName);
		}
		else
		#end
		{
			return getVarInArray(noGameOver ? PlayState.instance : getInstance(), objectName);
		}
	}

	private static function loadFrames(spr:FlxSprite, image:String, spriteType:String):Void
	{
		switch (spriteType.toLowerCase().trim())
		{
			case 'texture' | 'textureatlas' | 'tex':
				spr.frames = Paths.getFrames(image, TEXTURE_ATLAS);
			case 'texture_noaa' | 'textureatlas_noaa' | 'tex_noaa':
				spr.frames = Paths.getTextureAtlasFrames(image, false);
			case 'packer' | 'packeratlas' | 'pac':
				spr.frames = Paths.getFrames(image, SPRITE_SHEET_PACKER);
			default:
				spr.frames = Paths.getFrames(image);
		}
	}

	// Better optimized than using some getProperty shit or idk
	private static function getFlxEaseByString(ease:String = ''):(t:Float) -> Float
	{
		return switch (ease.toLowerCase().trim())
		{
			case 'backin':
				FlxEase.backIn;
			case 'backinout':
				FlxEase.backInOut;
			case 'backout':
				FlxEase.backOut;
			case 'bouncein':
				FlxEase.bounceIn;
			case 'bounceinout':
				FlxEase.bounceInOut;
			case 'bounceout':
				FlxEase.bounceOut;
			case 'circin':
				FlxEase.circIn;
			case 'circinout':
				FlxEase.circInOut;
			case 'circout':
				FlxEase.circOut;
			case 'cubein':
				FlxEase.cubeIn;
			case 'cubeinout':
				FlxEase.cubeInOut;
			case 'cubeout':
				FlxEase.cubeOut;
			case 'elasticin':
				FlxEase.elasticIn;
			case 'elasticinout':
				FlxEase.elasticInOut;
			case 'elasticout':
				FlxEase.elasticOut;
			case 'expoin':
				FlxEase.expoIn;
			case 'expoinout':
				FlxEase.expoInOut;
			case 'expoout':
				FlxEase.expoOut;
			case 'quadin':
				FlxEase.quadIn;
			case 'quadinout':
				FlxEase.quadInOut;
			case 'quadout':
				FlxEase.quadOut;
			case 'quartin':
				FlxEase.quartIn;
			case 'quartinout':
				FlxEase.quartInOut;
			case 'quartout':
				FlxEase.quartOut;
			case 'quintin':
				FlxEase.quintIn;
			case 'quintinout':
				FlxEase.quintInOut;
			case 'quintout':
				FlxEase.quintOut;
			case 'sinein':
				FlxEase.sineIn;
			case 'sineinout':
				FlxEase.sineInOut;
			case 'sineout':
				FlxEase.sineOut;
			case 'smoothstepin':
				FlxEase.smoothStepIn;
			case 'smoothstepinout':
				FlxEase.smoothStepInOut;
			case 'smoothstepout':
				FlxEase.smoothStepInOut;
			case 'smootherstepin':
				FlxEase.smootherStepIn;
			case 'smootherstepinout':
				FlxEase.smootherStepInOut;
			case 'smootherstepout':
				FlxEase.smootherStepOut;
			default:
				FlxEase.linear;
		}
	}

	private static function getBlendModeFromString(blend:String):BlendMode
	{
		return switch (blend.toLowerCase().trim())
		{
			case 'add':
				ADD;
			case 'alpha':
				ALPHA;
			case 'darken':
				DARKEN;
			case 'difference':
				DIFFERENCE;
			case 'erase':
				ERASE;
			case 'hardlight':
				HARDLIGHT;
			case 'invert':
				INVERT;
			case 'layer':
				LAYER;
			case 'lighten':
				LIGHTEN;
			case 'multiply':
				MULTIPLY;
			case 'overlay':
				OVERLAY;
			case 'screen':
				SCREEN;
			case 'shader':
				SHADER;
			case 'subtract':
				SUBTRACT;
			default:
				NORMAL;
		}
	}

	private static function getCameraFromString(cam:String):FlxCamera
	{
		return switch (cam.toLowerCase())
		{
			case 'camhud' | 'hud':
				PlayState.instance.camHUD;
			case 'camother' | 'other':
				PlayState.instance.camOther;
			default:
				PlayState.instance.camGame;
		}
	}

	private static inline function getInstance():FlxState
	{
		return PlayState.instance.isDead ? GameOverSubState.instance : PlayState.instance;
	}

	#if FEATURE_SCRIPTS
	private static inline function getTextObject(name:String):FlxText
	{
		return PlayState.instance.scriptTexts.exists(name) ? PlayState.instance.scriptTexts.get(name) : Reflect.getProperty(PlayState.instance, name);
	}

	private static function resetTextTag(tag:String):Void
	{
		if (PlayState.instance.scriptTexts.exists(tag))
		{
			var text:ScriptText = PlayState.instance.scriptTexts.get(tag);
			PlayState.instance.scriptTexts.remove(tag);
			text.kill();
			if (getInstance().members.contains(text))
			{
				getInstance().remove(text, true);
			}
			text.destroy();
		}
	}

	private static function resetSpriteTag(tag:String):Void
	{
		if (PlayState.instance.scriptSprites.exists(tag))
		{
			var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
			PlayState.instance.scriptSprites.remove(tag);
			sprite.kill();
			if (getInstance().members.contains(sprite))
			{
				getInstance().remove(sprite, true);
			}
			sprite.destroy();
		}
	}

	private static function cancelTween(tag:String):Void
	{
		if (PlayState.instance.scriptTweens.exists(tag))
		{
			var tween:FlxTween = PlayState.instance.scriptTweens.get(tag);
			PlayState.instance.scriptTweens.remove(tag);
			tween.cancel();
			tween.destroy();
		}
	}

	private static function cancelTimer(tag:String):Void
	{
		if (PlayState.instance.scriptTimers.exists(tag))
		{
			var timer:FlxTimer = PlayState.instance.scriptTimers.get(tag);
			PlayState.instance.scriptTimers.remove(tag);
			timer.cancel();
			timer.destroy();
		}
	}

	private static function getObjectToTween(tag:String, vars:String):Any
	{
		cancelTween(tag);
		var qualifierArray:Array<String> = vars.split('.');
		var object:Any = Reflect.getProperty(getInstance(), qualifierArray[0]);
		if (PlayState.instance.scriptSprites.exists(qualifierArray[0]))
		{
			object = PlayState.instance.scriptSprites.get(qualifierArray[0]);
		}
		else if (PlayState.stage.layers.exists(qualifierArray[0]))
		{
			object = PlayState.stage.layers.get(qualifierArray[0]);
		}
		if (PlayState.instance.scriptTexts.exists(qualifierArray[0]))
		{
			object = PlayState.instance.scriptTexts.get(qualifierArray[0]);
		}

		for (i in 1...qualifierArray.length)
		{
			object = Reflect.getProperty(object, qualifierArray[i]);
			if (object == null)
				return null;
		}
		return object;
	}

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

		var result:Int = LuaL.dostring(lua, script);
		var resultStr:String = Lua.tostring(lua, result);
		if (resultStr != null && result != 0)
		{
			scriptError('Error loading script "$path": $resultStr', true, false);
			Debug.displayAlert('Error loading script', resultStr);
			lua = null;
			return;
		}
		#elseif hscript
		var parser:Parser = new Parser();
		var program:Expr = parser.parseString(script);
		if (program == null)
		{
			scriptError('Error loading script "$path"', true, false);
			// Debug.displayAlert('Error loading script');
			interp = null;
			return;
		}
		#end
		scriptName = path;
		Debug.logTrace('Script loaded succesfully: $path');

		// Script variables
		set('FUNCTION_CONTINUE', FUNCTION_CONTINUE);
		set('FUNCTION_STOP', FUNCTION_STOP);
		set('FUNCTION_STOP_LUA', FUNCTION_STOP_LUA);

		// These two are for legacy support
		set('Function_Continue', FUNCTION_CONTINUE);
		set('Function_Stop', FUNCTION_STOP);
		set('Function_StopLua', FUNCTION_STOP_LUA);

		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);

		// Song/Week variables
		set('curTempo', Conductor.tempo);
		set('tempo', PlayState.song.tempo);
		set('scrollSpeed', PlayState.song.scrollSpeed);
		set('beatLength', Conductor.beatLength);
		set('stepLength', Conductor.stepLength);
		set('songLength', PlayState.song.inst.length);
		set('songId', PlayState.song.id);
		set('songName', PlayState.song.name);
		set('song', PlayState.song.id);
		set('startedCountdown', false);

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);
		set('difficultyName', Difficulty.difficulties[PlayState.storyDifficulty]);
		set('weekRaw', PlayState.storyWeek);
		set('week', Week.weekList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);

		// Block require and os, Should probably have a proper function but this should be good enough for now until someone smarter comes along and recreates a safe version of the OS library
		// set('require', false);

		// Camera variables
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen variables
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState variables
		set('curBar', 0);
		set('curBeat', 0);
		set('curStep', 0);
		set('curDecimalBeat', 0);
		set('curDecimalStep', 0);

		set('score', 0);
		set('misses', 0);
		set('hits', 0);

		set('rating', 0);
		set('ratingName', '');
		set('ratingFC', '');
		set('version', EngineData.ENGINE_VERSION.trim());

		set('inGameOver', false);
		set('mustHit', false);
		set('altAnim', false);
		set('gfSings', false);

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

		// Default character positions
		// TODO I'll fix this later to use constants
		set('defaultBoyfriendX', Stage.DEFAULT_PLAYER_POSITION.x);
		set('defaultBoyfriendY', Stage.DEFAULT_PLAYER_POSITION.y);
		set('defaultOpponentX', Stage.DEFAULT_OPPONENT_POSITION.x);
		set('defaultOpponentY', Stage.DEFAULT_OPPONENT_POSITION.x);
		set('defaultGirlfriendX', Stage.DEFAULT_GIRLFRIEND_POSITION.x);
		set('defaultGirlfriendY', Stage.DEFAULT_GIRLFRIEND_POSITION.x);

		// Character variables
		set('boyfriendName', PlayState.song.player1);
		set('opponentName', PlayState.song.player2);
		set('gfName', PlayState.song.gfVersion);

		// Some settings
		set('downScroll', Options.profile.downScroll);
		set('middleScroll', Options.profile.middleScroll);
		set('frameRate', Options.profile.frameRate);
		set('ghostTapping', Options.profile.ghostTapping);
		set('hideHUD', Options.profile.hideHUD);
		set('timeBarType', Options.profile.timeBarType);
		set('scoreZoom', Options.profile.scoreZoom);
		set('cameraZoomOnBeat', Options.profile.camZooms);
		set('flashingLights', Options.profile.flashing);
		set('noteOffset', Options.profile.noteOffset);
		set('healthBarAlpha', Options.profile.healthBarAlpha);
		set('resetButton', Options.profile.resetKey);
		set('lowQuality', Options.profile.lowQuality);

		set('buildTarget', haxe.macro.Compiler.getDefine('target'));

		set('getRunningScripts', function():Array<String>
		{
			var runningScripts:Array<String> = [];
			for (script in PlayState.instance.scriptArray)
				runningScripts.push(script.scriptName);
			return runningScripts;
		});

		set('callOnScripts', function(?funcName:String, ?args:Array<Dynamic>, ignoreStops = false, ignoreSelf = true, ?exclusions:Array<String>):Void
		{
			if (funcName == null)
			{
				#if (linc_luajit >= '0.0.6')
				LuaL.error(lua, "bad argument #1 to 'callOnScripts' (string expected, got nil)");
				#end
				return;
			}
			if (args == null)
				args = [];

			if (exclusions == null)
				exclusions = [];

			Lua.getglobal(lua, 'scriptName');
			var scriptName:String = Lua.tostring(lua, -1);
			Lua.pop(lua, 1);
			if (ignoreSelf && !exclusions.contains(scriptName))
				exclusions.push(scriptName);
			PlayState.instance.callOnScripts(funcName, args, ignoreStops, exclusions);
		});

		set('callScript', function(?key:String, ?funcName:String, ?args:Array<Dynamic>):Void
		{
			if (key == null)
			{
				#if (linc_luajit >= '0.0.6')
				LuaL.error(lua, "bad argument #1 to 'callScript' (string expected, got nil)");
				#end
				return;
			}
			if (funcName == null)
			{
				#if (linc_luajit >= '0.0.6')
				LuaL.error(lua, "bad argument #2 to 'callScript' (string expected, got nil)");
				#end
				return;
			}
			if (args == null)
			{
				args = [];
			}
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				for (script in PlayState.instance.scriptArray)
				{
					if (script.scriptName == path)
					{
						script.call(funcName, args);

						return;
					}
				}
			}
			Lua.pushnil(lua);
		});

		set('getGlobalFromScript', function(?key:String, ?global:String):Any
		{ // returns the global from a script
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				for (script in PlayState.instance.scriptArray)
				{
					if (script.scriptName == path)
					{
						return script.get(global);
					}
				}
			}
			return null;
		});
		set('setGlobalFromScript', function(key:String, global:String, val:Dynamic):Void
		{ // returns the global from a script
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				for (script in PlayState.instance.scriptArray)
				{
					if (script.scriptName == path)
					{
						script.set(global, val);
					}
				}
			}
		});
		// /*
		set('getGlobals', function(key:String):Void
		{ // returns a copy of the specified file's globals
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				for (script in PlayState.instance.scriptArray)
				{
					if (script.scriptName == path)
					{
						Lua.newtable(lua);
						var tableIdx:Int = Lua.gettop(lua);
						Lua.pushvalue(script.lua, Lua.LUA_GLOBALSINDEX);
						Lua.pushnil(script.lua);
						while (Lua.next(script.lua, -2) != 0)
						{
							// key = -2
							// value = -1
							var pop:Int = 0;
							// Manual conversion
							// first we convert the key
							if (Lua.isnumber(script.lua, -2))
							{
								Lua.pushnumber(lua, Lua.tonumber(script.lua, -2));
								pop++;
							}
							else if (Lua.isstring(script.lua, -2))
							{
								Lua.pushstring(lua, Lua.tostring(script.lua, -2));
								pop++;
							}
							else if (Lua.isboolean(script.lua, -2) == 1)
							{
								Lua.pushboolean(lua, Lua.toboolean(script.lua, -2));
								pop++;
							}
							// TODO: table
							// then the value
							if (Lua.isnumber(script.lua, -1))
							{
								Lua.pushnumber(lua, Lua.tonumber(script.lua, -1));
								pop++;
							}
							else if (Lua.isstring(script.lua, -1))
							{
								Lua.pushstring(lua, Lua.tostring(script.lua, -1));
								pop++;
							}
							else if (Lua.isboolean(script.lua, -1) == 1)
							{
								Lua.pushboolean(lua, Lua.toboolean(script.lua, -1));
								pop++;
							}
							// TODO: table
							if (pop == 2)
								Lua.rawset(lua, tableIdx); // then set it
							Lua.pop(script.lua, 1); // for the loop
						}
						Lua.pop(script.lua, 1); // end the loop entirely
						Lua.pushvalue(lua, tableIdx); // push the table onto the stack so it gets returned
						return;
					}
				}
			}
			Lua.pushnil(lua);
		});
		// */
		set('isRunning', function(key:String):Bool
		{
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				for (script in PlayState.instance.scriptArray)
				{
					if (script.scriptName == path)
						return true;
				}
			}
			return false;
		});
		set('addScript', function(key:String, ignoreAlreadyRunning:Bool = false):Void
		{
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				if (!ignoreAlreadyRunning)
				{
					for (script in PlayState.instance.scriptArray)
					{
						if (script.scriptName == path)
						{
							scriptWarn('The script "$path" is already running!');
							return;
						}
					}
				}
				PlayState.instance.scriptArray.push(new FunkinScript(path));
				return;
			}

			scriptWarn('The script "$path" doesn\'t exist!');
		});
		set('removeScript', function(key:String, ignoreAlreadyRunning:Bool = false):Void
		{
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				if (!ignoreAlreadyRunning)
				{
					for (script in PlayState.instance.scriptArray)
					{
						if (script.scriptName == path)
						{
							PlayState.instance.scriptArray.remove(script);
							return;
						}
					}
				}
				return;
			}

			scriptWarn('The script "$path" doesn\'t exist!');
		});

		set('getProperty', function(variable:String):Any
		{
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				return getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			return getVarInArray(getInstance(), variable);
		});
		set('setProperty', function(variable:String, value:Any):Void
		{
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				setVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1], value);
				return;
			}
			setVarInArray(getInstance(), variable, value);
		});
		set('getPropertyFromGroup', function(obj:String, index:Int, variable:Dynamic):Dynamic
		{
			var group:Dynamic = Reflect.getProperty(getInstance(), obj);
			if (Std.isOfType(group, FlxTypedGroup))
			{
				var group:FlxTypedGroup<Dynamic> = group;
				return getPropertyFromGroup(group.members[index], variable);
			}

			var groupEntry:Dynamic = group[index];
			if (groupEntry != null)
			{
				if (variable is Int)
				{
					return groupEntry[variable];
				}
				return getPropertyFromGroup(groupEntry, variable);
			}
			scriptWarn('Object #$index from group: $obj doesn\'t exist!');
			return null;
		});
		set('setPropertyFromGroup', function(obj:String, index:Int, variable:Dynamic, value:Dynamic):Bool
		{
			var group:Dynamic = Reflect.getProperty(getInstance(), obj);
			if (Std.isOfType(group, FlxTypedGroup))
			{
				var group:FlxTypedGroup<Dynamic> = group;
				setPropertyFromGroup(group.members[index], variable, value);
				return true;
			}

			var groupEntry:Dynamic = group[index];
			if (groupEntry != null)
			{
				if (variable is Int)
				{
					groupEntry[variable] = value;
					return true;
				}
				setPropertyFromGroup(groupEntry, variable, value);
				return true;
			}
			return false;
		});
		set('removeFromGroup', function(obj:String, index:Int, dontDestroy:Bool = false):Void
		{
			var group:Dynamic = Reflect.getProperty(getInstance(), obj);
			if (Std.isOfType(group, FlxTypedGroup))
			{
				var group:FlxTypedGroup<Dynamic> = group;
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
		set('getPropertyFromClass', function(classVar:String, variable:String):Any
		{
			var qualifiedClass:Class<Any> = Type.resolveClass(classVar);
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				var object:Any = getVarInArray(qualifiedClass, qualifierArray[0]);
				for (i in 1...qualifierArray.length - 1)
				{
					object = getVarInArray(object, qualifierArray[i]);
				}
				return getVarInArray(object, qualifierArray[qualifierArray.length - 1]);
			}
			return getVarInArray(qualifiedClass, variable);
		});
		set('setPropertyFromClass', function(classVar:String, variable:String, value:Any):Void
		{
			var qualifiedClass:Class<Any> = Type.resolveClass(classVar);
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				var object:Any = getVarInArray(qualifiedClass, qualifierArray[0]);
				for (i in 1...qualifierArray.length - 1)
				{
					object = getVarInArray(object, qualifierArray[i]);
				}
				setVarInArray(object, qualifierArray[qualifierArray.length - 1], value);
				return;
			}
			setVarInArray(qualifiedClass, variable, value);
		});

		set('getObjectOrder', function(obj:String):Int
		{
			var object:FlxBasic;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				object = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				object = PlayState.stage.layers.get(obj);
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				object = PlayState.instance.scriptTexts.get(obj);
			}
			else
			{
				object = Reflect.getProperty(getInstance(), obj);
			}
			if (object != null)
			{
				return getInstance().members.indexOf(object);
			}
			scriptWarn('Object $obj doesn\'t exist!');
			return -1;
		});
		set('setObjectOrder', function(obj:String, position:Int):Void
		{
			var object:FlxBasic;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				object = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				object = PlayState.stage.layers.get(obj);
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				object = PlayState.instance.scriptTexts.get(obj);
			}
			else
			{
				object = Reflect.getProperty(getInstance(), obj);
			}

			if (object != null)
			{
				if (getInstance().members.contains(object))
				{
					getInstance().remove(object, true);
				}
				getInstance().insert(position, object);
				return;
			}
			scriptWarn('Object $obj doesn\'t exist!');
		});

		// tweens
		set('doTweenX', function(tag:String, vars:String, value:Float, duration:Float, ease:String):Void
		{
			var objectToTween:Any = getObjectToTween(tag, vars);
			if (objectToTween != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(objectToTween, {x: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
			else
			{
				scriptWarn('Couldn\'t find object: $vars');
			}
		});
		set('doTweenY', function(tag:String, vars:String, value:Float, duration:Float, ease:String):Void
		{
			var objectToTween:Any = getObjectToTween(tag, vars);
			if (objectToTween != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(objectToTween, {y: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
			else
			{
				scriptWarn('Couldn\'t find object: $vars');
			}
		});
		set('doTweenAngle', function(tag:String, vars:String, value:Float, duration:Float, ease:String):Void
		{
			var objectToTween:Any = getObjectToTween(tag, vars);
			if (objectToTween != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(objectToTween, {angle: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
			else
			{
				scriptWarn('Couldn\'t find object: $vars');
			}
		});
		set('doTweenAlpha', function(tag:String, vars:String, value:Float, duration:Float, ease:String):Void
		{
			var objectToTween:Any = getObjectToTween(tag, vars);
			if (objectToTween != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(objectToTween, {alpha: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
			else
			{
				scriptWarn('Couldn\'t find object: $vars');
			}
		});
		set('doTweenZoom', function(tag:String, vars:String, value:Float, duration:Float, ease:String):Void
		{
			var objectToTween:Any = getObjectToTween(tag, vars);
			if (objectToTween != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(objectToTween, {zoom: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
			else
			{
				scriptWarn('Couldn\'t find object: $vars');
			}
		});
		set('doTweenColor', function(tag:String, vars:String, targetColor:String, duration:Float, ease:String):Void
		{
			var objectToTween:Dynamic = getObjectToTween(tag, vars);
			if (objectToTween != null)
			{
				var color:FlxColor = FlxColor.fromString(targetColor);

				var curColor:FlxColor = objectToTween.color;
				curColor.alphaFloat = objectToTween.alpha;
				PlayState.instance.scriptTweens.set(tag, FlxTween.color(objectToTween, duration, curColor, color, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
			else
			{
				scriptWarn('Couldn\'t find object: $vars');
			}
		});
		set('cancelTween', function(tag:String):Void
		{
			cancelTween(tag);
		});

		// Tween shit, but for strums
		set('noteTweenX', function(tag:String, note:Int, value:Float, duration:Float, ease:String):Void
		{
			cancelTween(tag);
			if (note < 0)
				note = 0;
			var strum:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if (strum != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(strum, {x: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
		});
		set('noteTweenY', function(tag:String, note:Int, value:Float, duration:Float, ease:String):Void
		{
			cancelTween(tag);
			if (note < 0)
				note = 0;
			var strum:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if (strum != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(strum, {y: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
		});
		set('noteTweenAngle', function(tag:String, note:Int, value:Float, duration:Float, ease:String):Void
		{
			cancelTween(tag);
			if (note < 0)
				note = 0;
			var strum:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if (strum != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(strum, {angle: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
		});
		set('noteTweenAlpha', function(tag:String, note:Int, value:Float, duration:Float, ease:String):Void
		{
			cancelTween(tag);
			if (note < 0)
				note = 0;
			var strum:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if (strum != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(strum, {alpha: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
		});
		// TODO Figure out what this does
		set('noteTweenDirection', function(tag:String, note:Int, value:Float, duration:Float, ease:String):Void
		{
			cancelTween(tag);
			if (note < 0)
				note = 0;
			var strum:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if (strum != null)
			{
				PlayState.instance.scriptTweens.set(tag, FlxTween.tween(strum, {direction: value}, duration, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
						PlayState.instance.scriptTweens.remove(tag);
					}
				}));
			}
		});

		set('mouseClicked', function(button:String):Bool
		{
			var clicked:Bool = FlxG.mouse.justPressed;
			switch (button)
			{
				case 'middle':
					clicked = FlxG.mouse.justPressedMiddle;
				case 'right':
					clicked = FlxG.mouse.justPressedRight;
			}

			return clicked;
		});
		set('mousePressed', function(button:String):Bool
		{
			var pressed:Bool = FlxG.mouse.pressed;
			switch (button)
			{
				case 'middle':
					pressed = FlxG.mouse.pressedMiddle;
				case 'right':
					pressed = FlxG.mouse.pressedRight;
			}
			return pressed;
		});
		set('mouseReleased', function(button:String):Bool
		{
			var released:Bool = FlxG.mouse.justReleased;
			switch (button)
			{
				case 'middle':
					released = FlxG.mouse.justReleasedMiddle;
				case 'right':
					released = FlxG.mouse.justReleasedRight;
			}
			return released;
		});

		set('runTimer', function(tag:String, time:Float = 1, loops:Int = 1):Void
		{
			cancelTimer(tag);
			PlayState.instance.scriptTimers.set(tag, new FlxTimer().start(time, (tmr:FlxTimer) ->
			{
				if (tmr.finished)
				{
					PlayState.instance.scriptTimers.remove(tag);
				}
				PlayState.instance.callOnScripts('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
				scriptTrace('Timer Completed: $tag');
			}, loops));
		});
		set('cancelTimer', function(tag:String):Void
		{
			cancelTimer(tag);
		});

		set('addScore', function(value:Int = 0):Void
		{
			PlayState.instance.score += value;
			PlayState.instance.recalculateRating();
		});
		set('addMisses', function(value:Int = 0):Void
		{
			PlayState.instance.misses += value;
			PlayState.instance.recalculateRating();
		});
		set('addHits', function(value:Int = 0):Void
		{
			PlayState.instance.hits += value;
			PlayState.instance.recalculateRating();
		});
		set('setScore', function(value:Int = 0):Void
		{
			PlayState.instance.score = value;
			PlayState.instance.recalculateRating();
		});
		set('setMisses', function(value:Int = 0):Void
		{
			PlayState.instance.misses = value;
			PlayState.instance.recalculateRating();
		});
		set('setHits', function(value:Int = 0):Void
		{
			PlayState.instance.hits = value;
			PlayState.instance.recalculateRating();
		});

		set('setHealth', function(value:Float = 0):Void
		{
			PlayState.instance.health = value;
		});
		set('addHealth', function(value:Float = 0):Void
		{
			PlayState.instance.health += value;
		});
		set('getHealth', function():Float
		{
			return PlayState.instance.health;
		});

		set('getColorFromString', function(color:String):FlxColor
		{
			return FlxColor.fromString(color);
		});
		set('keyJustPressed', function(name:String):Bool
		{
			var key:Bool = false;
			switch (name)
			{
				case 'left':
					key = PlayState.instance.getControl('NOTE_LEFT_P');
				case 'down':
					key = PlayState.instance.getControl('NOTE_DOWN_P');
				case 'up':
					key = PlayState.instance.getControl('NOTE_UP_P');
				case 'right':
					key = PlayState.instance.getControl('NOTE_RIGHT_P');
				case 'accept':
					key = PlayState.instance.getControl('ACCEPT');
				case 'back':
					key = PlayState.instance.getControl('BACK');
				case 'pause':
					key = PlayState.instance.getControl('PAUSE');
				case 'reset':
					key = PlayState.instance.getControl('RESET');
				case 'space':
					key = FlxG.keys.justPressed.SPACE; // an extra key for convinience
			}
			return key;
		});
		set('keyPressed', function(name:String):Bool
		{
			var key:Bool = false;
			switch (name)
			{
				case 'left':
					key = PlayState.instance.getControl('NOTE_LEFT');
				case 'down':
					key = PlayState.instance.getControl('NOTE_DOWN');
				case 'up':
					key = PlayState.instance.getControl('NOTE_UP');
				case 'right':
					key = PlayState.instance.getControl('NOTE_RIGHT');
				case 'space':
					key = FlxG.keys.pressed.SPACE; // an extra key for convinience
			}
			return key;
		});
		set('keyReleased', function(name:String):Bool
		{
			var key:Bool = false;
			switch (name)
			{
				case 'left':
					key = PlayState.instance.getControl('NOTE_LEFT_R');
				case 'down':
					key = PlayState.instance.getControl('NOTE_DOWN_R');
				case 'up':
					key = PlayState.instance.getControl('NOTE_UP_R');
				case 'right':
					key = PlayState.instance.getControl('NOTE_RIGHT_R');
				case 'space':
					key = FlxG.keys.justReleased.SPACE; // an extra key for convinience
			}
			return key;
		});
		set('addCharacterToList', function(name:String, roleName:String):Void
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			PlayState.instance.addCharacterToList(name, role);
		});
		set('precacheImage', function(name:String):Void
		{
			Paths.precacheGraphic(name);
		});
		set('precacheSound', function(name:String):Void
		{
			Paths.precacheSound(name);
		});
		set('precacheMusic', function(name:String):Void
		{
			Paths.precacheMusic(name);
		});
		set('triggerEvent', function(type:String, arg1:Any, arg2:Any):Void
		{
			var args:Array<Dynamic> = [arg1, arg2];
			PlayState.instance.triggerEvent(type, args);
			// scriptTrace('Triggered event: $type, $args');
		});

		set('loadSong', function(?name:String, difficultyNum:Int = -1):Void
		{
			if (name == null || name.length < 1)
				name = PlayState.song.id;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			var difficulty:String = Difficulty.getDifficultyFilePath(difficultyNum);
			PlayState.song = Song.loadSong(name, difficulty);
			PlayState.storyDifficulty = difficultyNum;
			getInstance().persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState());

			PlayState.song.inst.pause();
			PlayState.song.inst.stop();
			if (PlayState.song.vocals != null)
			{
				PlayState.song.vocals.pause();
				PlayState.song.vocals.stop();
			}
		});
		set('startCountdown', function():Void
		{
			PlayState.instance.startCountdown();
		});
		set('endSong', function():Void
		{
			PlayState.instance.killNotes();
			PlayState.instance.endSong();
		});
		set('restartSong', function(skipTransition:Bool):Void
		{
			getInstance().persistentUpdate = false;
			PlayState.instance.restartSong(skipTransition);
		});
		set('exitSong', function(skipTransition:Bool):Void
		{
			if (skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			PlayState.cancelMusicFadeTween();

			if (PlayState.isStoryMode)
				FlxG.switchState(new StoryMenuState());
			else
				FlxG.switchState(new FreeplayState());

			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			PlayState.instance.transitioning = true;
		});
		set('getSongPosition', function():Float
		{
			return Conductor.songPosition;
		});

		set('getCharacterX', function(roleName:String):Float
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					return PlayState.instance.opponentGroup.x;
				case GIRLFRIEND:
					return PlayState.instance.gfGroup.x;
				default:
					return PlayState.instance.boyfriendGroup.x;
			}
		});
		set('setCharacterX', function(roleName:String, value:Float):Void
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					PlayState.instance.opponentGroup.x = value;
				case GIRLFRIEND:
					PlayState.instance.gfGroup.x = value;
				default:
					PlayState.instance.boyfriendGroup.x = value;
			}
		});
		set('getCharacterY', function(roleName:String):Float
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					return PlayState.instance.opponentGroup.y;
				case GIRLFRIEND:
					return PlayState.instance.gfGroup.y;
				default:
					return PlayState.instance.boyfriendGroup.y;
			}
		});
		set('setCharacterY', function(roleName:String, value:Float):Void
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					PlayState.instance.opponentGroup.y = value;
				case GIRLFRIEND:
					PlayState.instance.gfGroup.y = value;
				default:
					PlayState.instance.boyfriendGroup.y = value;
			}
		});
		set('getCharacterAngle', function(roleName:String):Float
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					return PlayState.instance.opponentGroup.angle;
				case GIRLFRIEND:
					return PlayState.instance.gfGroup.angle;
				default:
					return PlayState.instance.boyfriendGroup.angle;
			}
		});
		set('setCharacterAngle', function(roleName:String, value:Float):Void
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					PlayState.instance.opponentGroup.angle = value;
				case GIRLFRIEND:
					PlayState.instance.gfGroup.angle = value;
				default:
					PlayState.instance.boyfriendGroup.angle = value;
			}
		});

		set('cameraSetTarget', function(target:String):Void
		{
			var role:CharacterRole = CharacterRoleTools.createByString(target.toLowerCase());
			PlayState.instance.moveCamera(role);
		});
		set('cameraShake', function(camera:String, intensity:Float, duration:Float):Void
		{
			getCameraFromString(camera).shake(intensity, duration);
		});

		set('cameraFlash', function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			var colorNum:FlxColor = FlxColor.fromString(color);
			getCameraFromString(camera).flash(colorNum, duration, null, forced);
		});
		set('cameraFade', function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			var colorNum:FlxColor = FlxColor.fromString(color);
			getCameraFromString(camera).fade(colorNum, duration, false, null, forced);
		});

		set('setRatingPercent', function(value:Float):Void
		{
			PlayState.instance.ratingPercent = value;
		});
		set('setRatingName', function(value:String):Void
		{
			PlayState.instance.ratingName = value;
		});
		set('setRatingFC', function(value:String):Void
		{
			PlayState.instance.ratingFC = value;
		});

		set('getMouseX', function(camera:String):Float
		{
			var cam:FlxCamera = getCameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		set('getMouseY', function(camera:String):Float
		{
			var cam:FlxCamera = getCameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		set('getMidpointX', function(variable:String):Float
		{
			var qualifierArray:Array<String> = variable.split('.');
			var obj:FlxObject = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				obj = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (obj != null)
				return obj.getMidpoint().x;

			return 0;
		});
		set('getMidpointY', function(variable:String):Float
		{
			var qualifierArray:Array<String> = variable.split('.');
			var obj:FlxObject = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				obj = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (obj != null)
				return obj.getMidpoint().y;

			return 0;
		});
		set('getGraphicMidpointX', function(variable:String):Float
		{
			var qualifierArray:Array<String> = variable.split('.');
			var obj:FlxSprite = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				obj = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (obj != null)
				return obj.getGraphicMidpoint().x;

			return 0;
		});
		set('getGraphicMidpointY', function(variable:String):Float
		{
			var qualifierArray:Array<String> = variable.split('.');
			var obj:FlxSprite = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				obj = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (obj != null)
				return obj.getGraphicMidpoint().y;

			return 0;
		});
		set('getScreenPositionX', function(variable:String):Float
		{
			var qualifierArray:Array<String> = variable.split('.');
			var obj:FlxObject = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				obj = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (obj != null)
				return obj.getScreenPosition().x;

			return 0;
		});
		set('getScreenPositionY', function(variable:String):Float
		{
			var qualifierArray:Array<String> = variable.split('.');
			var obj:FlxObject = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				obj = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (obj != null)
				return obj.getScreenPosition().y;

			return 0;
		});
		set('characterPlayAnim', function(roleName:String, anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					if (PlayState.instance.opponent.animOffsets.exists(anim))
						PlayState.instance.opponent.playAnim(anim, forced, reversed, frame);
				case GIRLFRIEND:
					if (PlayState.instance.gf != null && PlayState.instance.gf.animOffsets.exists(anim))
						PlayState.instance.gf.playAnim(anim, forced, reversed, frame);
				default:
					if (PlayState.instance.boyfriend.animOffsets.exists(anim))
						PlayState.instance.boyfriend.playAnim(anim, forced, reversed, frame);
			}
		});
		set('characterDance', function(roleName:String):Void
		{
			var role:CharacterRole = CharacterRoleTools.createByString(roleName.toLowerCase());
			switch (role)
			{
				case OPPONENT:
					PlayState.instance.opponent.dance();
				case GIRLFRIEND:
					if (PlayState.instance.gf != null)
						PlayState.instance.gf.dance();
				default:
					PlayState.instance.boyfriend.dance();
			}
		});

		set('makeLuaSprite', function(tag:String, image:String, x:Float, y:Float):Void
		{
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var sprite:ScriptSprite = new ScriptSprite(x, y);
			if (image != null && image.length > 0)
			{
				sprite.loadGraphic(Paths.getGraphic(image));
			}
			sprite.antialiasing = Options.profile.globalAntialiasing;
			PlayState.instance.scriptSprites.set(tag, sprite);
			sprite.active = false;
		});
		set('makeAnimatedLuaSprite', function(tag:String, image:String, x:Float, y:Float, spriteType:String = 'sparrow'):Void
		{
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var sprite:ScriptSprite = new ScriptSprite(x, y);

			loadFrames(sprite, image, spriteType);
			sprite.antialiasing = Options.profile.globalAntialiasing;
			PlayState.instance.scriptSprites.set(tag, sprite);
		});

		set('makeGraphic', function(obj:String, width:Int, height:Int, color:String):Void
		{
			var colorNum:FlxColor = FlxColor.fromString(color);
			var sprite:FlxSprite = getObjectDirectly(obj);
			// if (PlayState.instance.scriptSprites.exists(obj))
			// {
			// 	sprite = PlayState.instance.scriptSprites.get(obj);
			// }
			// else
			// {
			// 	sprite = Reflect.getProperty(getInstance(), obj);
			// }
			if (sprite != null)
			{
				sprite.makeGraphic(width, height, colorNum);
			}
		});
		set('loadGraphic', function(variable:String, image:String)
		{
			var qualifierArray:Array<String> = variable.split('.');
			var sprite:FlxSprite = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (sprite != null && image != null && image.length > 0)
			{
				sprite.loadGraphic(Paths.getGraphic(image));
			}
		});
		set('loadFrames', function(variable:String, image:String, spriteType:String = 'sparrow'):Void
		{
			var qualifierArray:Array<String> = variable.split('.');
			var sprite:FlxSprite = getVarInArray(getInstance(), qualifierArray[0]);
			if (qualifierArray.length > 1)
			{
				sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
			}
			if (sprite != null && image != null && image.length > 0)
			{
				loadFrames(sprite, image, spriteType);
			}
		});

		set('addAnimationByPrefix', function(obj:String, name:String, prefix:String, frameRate:Int = 24, loop:Bool = true):Void
		{
			var sprite:FlxSprite = getObjectDirectly(obj);
			// if (PlayState.instance.scriptSprites.exists(obj))
			// {
			// 	sprite = PlayState.instance.scriptSprites.get(obj);
			// }
			// else
			// {
			// 	sprite = Reflect.getProperty(getInstance(), obj);
			// }
			if (sprite != null)
			{
				sprite.animation.addByPrefix(name, prefix, frameRate, loop);
				if (sprite.animation.curAnim == null && sprite.animation.exists(name))
				{
					sprite.animation.play(name, true);
				}
			}
		});
		set('addAnimationByIndices', function(obj:String, name:String, prefix:String, indices:String, frameRate:Int = 24):Void
		{
			var strIndices:Array<String> = indices.trim().split(',');
			var intIndices:Array<Int> = [for (index in strIndices) Std.parseInt(index)];

			var sprite:FlxSprite = getObjectDirectly(obj);
			// if (PlayState.instance.scriptSprites.exists(obj))
			// {
			// 	sprite = PlayState.instance.scriptSprites.get(obj);
			// }
			// else
			// {
			// 	sprite = Reflect.getProperty(getInstance(), obj);
			// }
			if (sprite != null)
			{
				sprite.animation.addByIndices(name, prefix, intIndices, '', frameRate, false);
				if (sprite.animation.curAnim == null && sprite.animation.exists(name))
				{
					sprite.animation.play(name, true);
				}
			}
		});
		set('objectPlayAnimation', function(obj:String, name:String, forced:Bool = false, startFrame:Int = 0):Void
		{
			var sprite:FlxSprite = getObjectDirectly(obj);
			// if (PlayState.instance.scriptSprites.exists(obj))
			// {
			// 	sprite = PlayState.instance.scriptSprites.get(obj);
			// }
			// else
			// {
			// 	sprite = Reflect.getProperty(getInstance(), obj);
			// }
			if (sprite != null)
			{
				sprite.animation.play(name, forced, false, startFrame);
				return;
			}
			scriptWarn('Couldn\'t find object: $obj');
		});

		set('setScrollFactor', function(obj:String, scrollX:Float, scrollY:Float):Void
		{
			var object:FlxSprite;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				object = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				object = PlayState.stage.layers.get(obj);
			}
			else
			{
				object = Reflect.getProperty(getInstance(), obj);
			}

			if (object != null)
			{
				object.scrollFactor.set(scrollX, scrollY);
				return;
			}
			scriptWarn('Couldn\'t find object: $obj');
		});
		set('addLuaSprite', function(tag:String, front:Bool = false):Void
		{
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
				if (!getInstance().members.contains(sprite))
				{
					if (front)
					{
						getInstance().add(sprite);
					}
					else
					{
						if (PlayState.instance.isDead)
						{
							getInstance().insert(getInstance().members.indexOf(GameOverSubState.instance.boyfriend), sprite);
						}
						else
						{
							var position:Int = getInstance().members.indexOf(PlayState.instance.gfGroup);
							if (getInstance().members.indexOf(PlayState.instance.boyfriendGroup) < position)
							{
								position = getInstance().members.indexOf(PlayState.instance.boyfriendGroup);
							}
							else if (getInstance().members.indexOf(PlayState.instance.opponentGroup) < position)
							{
								position = getInstance().members.indexOf(PlayState.instance.opponentGroup);
							}
							getInstance().insert(position, sprite);
						}
					}
					scriptTrace('Added a sprite with tag: $tag');
				}
			}
		});
		set('setGraphicSize', function(obj:String, x:Int, y:Int = 0, updateHitbox:Bool = true):Void
		{
			var sprite:FlxSprite;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				sprite = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				sprite = PlayState.stage.layers.get(obj);
			}
			else
			{
				var qualifierArray:Array<String> = obj.split('.');
				sprite = getVarInArray(getInstance(), qualifierArray[0]);
				if (qualifierArray.length > 1)
				{
					sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
				}
			}
			if (sprite != null)
			{
				sprite.setGraphicSize(x, y);
				if (updateHitbox)
					sprite.updateHitbox();
				return;
			}
			scriptWarn('Couldn\'t find object: $obj');
		});
		set('scaleObject', function(obj:String, x:Float, y:Float, updateHitbox:Bool = true):Void
		{
			var sprite:FlxSprite;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				sprite = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				sprite = PlayState.stage.layers.get(obj);
			}
			else
			{
				var qualifierArray:Array<String> = obj.split('.');
				sprite = getVarInArray(getInstance(), qualifierArray[0]);
				if (qualifierArray.length > 1)
				{
					sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
				}
			}
			if (sprite != null)
			{
				sprite.scale.set(x, y);
				if (updateHitbox)
					sprite.updateHitbox();
				return;
			}
			scriptWarn('Couldn\'t find object: $obj');
		});
		set('updateHitbox', function(obj:String):Void
		{
			var sprite:FlxSprite;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				sprite = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				sprite = PlayState.stage.layers.get(obj);
			}
			else
			{
				var qualifierArray:Array<String> = obj.split('.');
				sprite = getVarInArray(getInstance(), qualifierArray[0]);
				if (qualifierArray.length > 1)
				{
					sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
				}
			}
			if (sprite != null)
			{
				sprite.updateHitbox();
				return;
			}
			scriptWarn('Couldn\'t find object: $obj');
		});
		set('updateHitboxFromGroup', function(group:String, index:Int):Void
		{
			var groupObj:Dynamic = Reflect.getProperty(getInstance(), group);
			if (Std.isOfType(groupObj, FlxTypedGroup))
			{
				var groupObj:FlxTypedGroup<FlxSprite> = groupObj;
				groupObj.members[index].updateHitbox();
				return;
			}
			Reflect.getProperty(getInstance(), group)[index].updateHitbox();
		});
		set('removeLuaSprite', function(tag:String, destroy:Bool = true):Void
		{
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
				if (destroy)
				{
					sprite.kill();
				}

				if (getInstance().members.contains(sprite))
				{
					getInstance().remove(sprite, true);
				}

				if (destroy)
				{
					sprite.destroy();
					PlayState.instance.scriptSprites.remove(tag);
				}
			}
		});

		set('setObjectCamera', function(obj:String, camera:String = ''):Bool
		{
			var object:FlxBasic = null;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				object = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				object = PlayState.stage.layers.get(obj);
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				object = PlayState.instance.scriptTexts.get(obj);
			}
			else
			{
				var qualifierArray:Array<String> = obj.split('.');
				var object:FlxObject = getVarInArray(getInstance(), qualifierArray[0]);
				if (qualifierArray.length > 1)
				{
					object = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
				}
			}

			if (object != null)
			{
				object.cameras = [getCameraFromString(camera)];
				return true;
			}
			scriptWarn('Object $obj doesn\'t exist!');
			return false;
		});
		set('setBlendMode', function(obj:String, blend:String = ''):Bool
		{
			var sprite:FlxSprite = null;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				sprite = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.stage.layers.exists(obj))
			{
				sprite = PlayState.stage.layers.get(obj);
			}
			else
			{
				var qualifierArray:Array<String> = obj.split('.');
				sprite = getVarInArray(getInstance(), qualifierArray[0]);
				if (qualifierArray.length > 1)
				{
					sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
				}
			}
			if (sprite != null)
			{
				sprite.blend = getBlendModeFromString(blend);
				return true;
			}
			scriptWarn('Object $obj doesn\'t exist!');
			return false;
		});
		set('screenCenter', function(obj:String, pos:String = 'xy'):Void
		{
			var sprite:FlxSprite = null;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				sprite = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				sprite = PlayState.instance.scriptTexts.get(obj);
			}
			else
			{
				var qualifierArray:Array<String> = obj.split('.');
				sprite = getVarInArray(getInstance(), qualifierArray[0]);
				if (qualifierArray.length > 1)
				{
					sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
				}
			}

			if (sprite != null)
			{
				switch (pos.trim().toLowerCase())
				{
					case 'x':
						sprite.screenCenter(X);
						return;
					case 'y':
						sprite.screenCenter(Y);
						return;
					default:
						sprite.screenCenter(XY);
						return;
				}
			}
			scriptWarn('Object $obj doesn\'t exist!');
		});
		set('objectsOverlap', function(obj1:String, obj2:String):Bool
		{
			var namesArray:Array<String> = [obj1, obj2];
			var objectsArray:Array<FlxSprite> = [];
			for (name in namesArray)
			{
				if (PlayState.instance.scriptSprites.exists(name))
				{
					objectsArray.push(PlayState.instance.scriptSprites.get(name));
				}
				else if (PlayState.stage.layers.exists(name))
				{
					objectsArray.push(PlayState.stage.layers.get(name));
				}
				else if (PlayState.instance.scriptTexts.exists(name))
				{
					objectsArray.push(PlayState.instance.scriptTexts.get(name));
				}
				else
				{
					objectsArray.push(Reflect.getProperty(getInstance(), name));
				}
			}

			return !objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]);
		});
		set('getPixelColor', function(obj:String, x:Int, y:Int):Int
		{
			var sprite:FlxSprite;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				sprite = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				sprite = PlayState.instance.scriptTexts.get(obj);
			}
			else
			{
				var qualifierArray:Array<String> = obj.split('.');
				sprite = getVarInArray(getInstance(), qualifierArray[0]);
				if (qualifierArray.length > 1)
				{
					sprite = getVarInArray(getPropertyLoop(qualifierArray), qualifierArray[qualifierArray.length - 1]);
				}
			}

			if (sprite != null)
			{
				if (sprite.framePixels != null)
					sprite.framePixels.getPixel32(x, y);
				return sprite.pixels.getPixel32(x, y);
			}
			return 0;
		});
		set('getRandomInt', function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = ''):Int
		{
			var excludeArray:Array<Int> = exclude.split(',').map((f:String) -> Std.parseInt(f.trim()));
			return FlxG.random.int(min, max, excludeArray);
		});
		set('getRandomFloat', function(min:Float, max:Float = 1, exclude:String = ''):Float
		{
			var excludeArray:Array<Float> = exclude.split(',').map((f:String) -> Std.parseFloat(f.trim()));
			return FlxG.random.float(min, max, excludeArray);
		});
		set('getRandomBool', function(chance:Float = 50):Bool
		{
			return FlxG.random.bool(chance);
		});
		set('startDialogue', function(dialogueFile:String, ?music:String):Void
		{
			var path:String = Paths.json(Path.join(['songs', PlayState.song.id, dialogueFile]));
			scriptTrace('Trying to load dialogue from: $path');

			if (Paths.exists(path))
			{
				var dialogueDef:DialogueDef = Paths.getJsonDirect(path);
				if (dialogueDef.dialogue.length > 0)
				{
					PlayState.instance.startDialogue(dialogueDef, music);
					scriptTrace('Successfully loaded dialogue');
				}
				else
				{
					scriptWarn('Your dialogue file is badly formatted!');
				}
			}
			else
			{
				scriptTrace('Dialogue file not found');
				if (PlayState.instance.endingSong)
				{
					PlayState.instance.endSong();
				}
				else
				{
					PlayState.instance.startCountdown();
				}
			}
		});
		set('startVideo', function(videoFile:String):Void
		{
			#if FEATURE_VIDEOS
			if (Paths.exists(Paths.video(videoFile), BINARY))
			{
				PlayState.instance.startVideo(videoFile);
			}
			else
			{
				scriptWarn('Video file not found: $videoFile');
			}
			#else
			if (PlayState.instance.endingSong)
			{
				PlayState.instance.endSong();
			}
			else
			{
				PlayState.instance.startCountdown();
			}
			#end
		});

		set('playMusic', function(sound:String, volume:Float = 1, loop:Bool = false):Void
		{
			// FIXME Wait, wouldn't this override the song's instrumental?
			FlxG.sound.playMusic(Paths.getMusic(sound), volume, loop);
		});
		set('playSound', function(sound:String, volume:Float = 1, ?tag:String):Void
		{
			if (tag != null && tag.length > 0)
			{
				tag = tag.replace('.', '');
				if (PlayState.instance.scriptSounds.exists(tag))
				{
					PlayState.instance.scriptSounds.get(tag).stop();
				}
				PlayState.instance.scriptSounds.set(tag, FlxG.sound.play(Paths.getSound(sound), volume, false, true, () ->
				{
					PlayState.instance.scriptSounds.remove(tag);
					PlayState.instance.callOnScripts('onSoundFinished', [tag]);
				}));
				return;
			}
			FlxG.sound.play(Paths.getSound(sound), volume);
		});
		set('stopSound', function(tag:String):Void
		{
			if (tag != null && tag.length > 1 && PlayState.instance.scriptSounds.exists(tag))
			{
				PlayState.instance.scriptSounds.get(tag).stop();
				PlayState.instance.scriptSounds.remove(tag);
			}
		});
		set('pauseSound', function(tag:String):Void
		{
			if (tag != null && tag.length > 1 && PlayState.instance.scriptSounds.exists(tag))
			{
				PlayState.instance.scriptSounds.get(tag).pause();
			}
		});
		set('resumeSound', function(tag:String):Void
		{
			if (tag != null && tag.length > 1 && PlayState.instance.scriptSounds.exists(tag))
			{
				PlayState.instance.scriptSounds.get(tag).play();
			}
		});
		set('soundFadeIn', function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1):Void
		{
			if (tag == null || tag.length < 1)
			{
				PlayState.song.inst.fadeIn(duration, fromValue, toValue);
			}
			else if (PlayState.instance.scriptSounds.exists(tag))
			{
				PlayState.instance.scriptSounds.get(tag).fadeIn(duration, fromValue, toValue);
			}
		});
		set('soundFadeOut', function(tag:String, duration:Float, toValue:Float = 0):Void
		{
			if (tag == null || tag.length < 1)
			{
				PlayState.song.inst.fadeOut(duration, toValue);
			}
			else if (PlayState.instance.scriptSounds.exists(tag))
			{
				PlayState.instance.scriptSounds.get(tag).fadeOut(duration, toValue);
			}
		});
		set('soundFadeCancel', function(tag:String):Void
		{
			if (tag == null || tag.length < 1)
			{
				if (PlayState.song.inst.fadeTween != null)
				{
					PlayState.song.inst.fadeTween.cancel();
				}
			}
			else if (PlayState.instance.scriptSounds.exists(tag))
			{
				var sound:FlxSound = PlayState.instance.scriptSounds.get(tag);
				if (sound.fadeTween != null)
				{
					sound.fadeTween.cancel();
					PlayState.instance.scriptSounds.remove(tag);
				}
			}
		});
		set('getSoundVolume', function(tag:String):Float
		{
			if (tag == null || tag.length < 1)
			{
				if (PlayState.song.inst != null)
				{
					return PlayState.song.inst.volume;
				}
			}
			else if (PlayState.instance.scriptSounds.exists(tag))
			{
				return PlayState.instance.scriptSounds.get(tag).volume;
			}
			return 0;
		});
		set('setSoundVolume', function(tag:String, value:Float):Void
		{
			if (tag == null || tag.length < 1)
			{
				if (PlayState.song.inst != null)
				{
					PlayState.song.inst.volume = value;
				}
			}
			else if (PlayState.instance.scriptSounds.exists(tag))
			{
				PlayState.instance.scriptSounds.get(tag).volume = value;
			}
		});
		set('getSoundTime', function(tag:String):Float
		{
			if (tag != null && tag.length > 0 && PlayState.instance.scriptSounds.exists(tag))
			{
				return PlayState.instance.scriptSounds.get(tag).time;
			}
			return 0;
		});
		set('setSoundTime', function(tag:String, value:Float):Void
		{
			if (tag != null && tag.length > 0 && PlayState.instance.scriptSounds.exists(tag))
			{
				var sound:FlxSound = PlayState.instance.scriptSounds.get(tag);
				if (sound != null)
				{
					var wasResumed:Bool = sound.playing;
					sound.pause();
					sound.time = value;
					if (wasResumed)
						sound.play();
				}
			}
		});

		set('debugPrint', function(text1:Dynamic = '', text2:Dynamic = '', text3:Dynamic = '', text4:Dynamic = '', text5:Dynamic = ''):Void
		{
			scriptTrace('$text1$text2$text3$text4$text5', true, false);
		});
		set('close', function():Bool
		{
			closed = true;
			// stop();
			return closed;
		});

		// SCRIPT TEXTS
		set('makeLuaText', function(tag:String, text:String, width:Int, x:Float, y:Float):Void
		{
			tag = tag.replace('.', '');
			resetTextTag(tag);
			var text:ScriptText = new ScriptText(x, y, text, width);
			PlayState.instance.scriptTexts.set(tag, text);
		});

		set('setTextString', function(tag:String, text:String):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				obj.text = text;
			}
		});
		set('setTextSize', function(tag:String, size:Int):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				obj.size = size;
			}
		});
		set('setTextWidth', function(tag:String, width:Float):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				obj.fieldWidth = width;
			}
		});
		set('setTextBorder', function(tag:String, size:Int, color:String):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				var colorNum:FlxColor = FlxColor.fromString(color);

				obj.borderSize = size;
				obj.borderColor = colorNum;
			}
		});
		set('setTextColor', function(tag:String, color:String):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				var colorNum:FlxColor = FlxColor.fromString(color);

				obj.color = colorNum;
			}
		});
		set('setTextFont', function(tag:String, newFont:String):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				obj.font = Paths.font(newFont);
			}
		});
		set('setTextItalic', function(tag:String, italic:Bool):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				obj.italic = italic;
			}
		});
		set('setTextAlignment', function(tag:String, alignment:String = 'left'):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				obj.alignment = LEFT;
				switch (alignment.trim().toLowerCase())
				{
					case 'right':
						obj.alignment = RIGHT;
					case 'center':
						obj.alignment = CENTER;
				}
			}
		});

		set('getTextString', function(tag:String):String
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				return obj.text;
			}
			return null;
		});
		set('getTextSize', function(tag:String):Int
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				return obj.size;
			}
			return -1;
		});
		set('getTextFont', function(tag:String):String
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				return obj.font;
			}
			return null;
		});
		set('getTextWidth', function(tag:String):Float
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				return obj.fieldWidth;
			}
			return 0;
		});

		set('addLuaText', function(tag:String):Void
		{
			if (PlayState.instance.scriptTexts.exists(tag))
			{
				var text:ScriptText = PlayState.instance.scriptTexts.get(tag);
				if (!getInstance().members.contains(text))
				{
					getInstance().add(text);
					scriptTrace('Added text with tag: $tag');
				}
			}
		});
		set('removeLuaText', function(tag:String, destroy:Bool = true):Void
		{
			if (PlayState.instance.scriptTexts.exists(tag))
			{
				var text:ScriptText = PlayState.instance.scriptTexts.get(tag);
				if (destroy)
				{
					text.kill();
				}

				if (getInstance().members.contains(text))
				{
					getInstance().remove(text, true);
				}

				if (destroy)
				{
					text.destroy();
					PlayState.instance.scriptTexts.remove(tag);
				}
			}
		});

		set('initSaveData', function(name:String, folder:String = 'psychenginemods'):Void
		{
			if (!PlayState.instance.scriptSaves.exists(name))
			{
				var save:FlxSave = new FlxSave();
				save.bind(name, folder);
				PlayState.instance.scriptSaves.set(name, save);
				return;
			}
			scriptWarn('Save file already initialized: $name');
		});
		set('flushSaveData', function(name:String):Void
		{
			if (PlayState.instance.scriptSaves.exists(name))
			{
				PlayState.instance.scriptSaves.get(name).flush();
				return;
			}
			scriptWarn('Save file not initialized: $name');
		});
		set('getDataFromSave', function(name:String, field:String):Any
		{
			if (PlayState.instance.scriptSaves.exists(name))
			{
				return Reflect.field(PlayState.instance.scriptSaves.get(name).data, field);
			}
			scriptWarn('Save file not initialized: $name');
			return null;
		});
		set('setDataFromSave', function(name:String, field:String, value:Any):Void
		{
			if (PlayState.instance.scriptSaves.exists(name))
			{
				Reflect.setField(PlayState.instance.scriptSaves.get(name).data, field, value);
				return;
			}
			scriptWarn('Save file not initialized: $name');
		});

		set('getText', function(path:String, ignoreModFolders:Bool = false):String
		{
			return Paths.getText(path, ignoreModFolders);
		});

		// DEPRECATED, DONT MESS WITH THESE SHITS, ITS JUST THERE FOR BACKWARD COMPATIBILITY
		set('luaSpriteMakeGraphic', function(tag:String, width:Int, height:Int, color:String):Void
		{
			scriptWarn('luaSpriteMakeGraphic is deprecated! Use makeGraphic instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var colorNum:FlxColor = FlxColor.fromString(color);

				PlayState.instance.scriptSprites.get(tag).makeGraphic(width, height, colorNum);
			}
		});
		set('luaSpriteAddAnimationByPrefix', function(tag:String, name:String, prefix:String, frameRate:Int = 24, loop:Bool = true):Void
		{
			scriptWarn('luaSpriteAddAnimationByPrefix is deprecated! Use addAnimationByPrefix instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
				sprite.animation.addByPrefix(name, prefix, frameRate, loop);
				if (sprite.animation.curAnim == null)
				{
					sprite.animation.play(name, true);
				}
			}
		});
		set('luaSpriteAddAnimationByIndices', function(tag:String, name:String, prefix:String, indices:String, frameRate:Int = 24):Void
		{
			scriptWarn('luaSpriteAddAnimationByIndices is deprecated! Use addAnimationByIndices instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var intIndices:Array<Int> = indices.trim().split(',').map((f:String) -> Std.parseInt(f));
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
				sprite.animation.addByIndices(name, prefix, intIndices, '', frameRate, false);
				if (sprite.animation.curAnim == null)
				{
					sprite.animation.play(name, true);
				}
			}
		});
		set('luaSpritePlayAnimation', function(tag:String, name:String, forced:Bool = false):Void
		{
			scriptWarn('luaSpritePlayAnimation is deprecated! Use objectPlayAnimation instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				PlayState.instance.scriptSprites.get(tag).animation.play(name, forced);
			}
		});
		set('setLuaSpriteCamera', function(tag:String, camera:String = ''):Bool
		{
			scriptWarn('setLuaSpriteCamera is deprecated! Use setObjectCamera instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				PlayState.instance.scriptSprites.get(tag).cameras = [getCameraFromString(camera)];
				return true;
			}
			scriptWarn('Lua sprite with tag: $tag doesn\'t exist!');
			return false;
		});
		set('setLuaSpriteScrollFactor', function(tag:String, scrollX:Float, scrollY:Float):Void
		{
			scriptWarn('setLuaSpriteScrollFactor is deprecated! Use setScrollFactor instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				PlayState.instance.scriptSprites.get(tag).scrollFactor.set(scrollX, scrollY);
			}
		});
		set('scaleLuaSprite', function(tag:String, x:Float, y:Float):Void
		{
			scriptWarn('scaleLuaSprite is deprecated! Use scaleObject instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
				sprite.scale.set(x, y);
				sprite.updateHitbox();
			}
		});
		set('getPropertyLuaSprite', function(tag:String, variable:String):Any
		{
			scriptWarn('getPropertyLuaSprite is deprecated! Use getProperty instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var qualifierArray:Array<String> = variable.split('.');
				if (qualifierArray.length > 1)
				{
					var object:Any = Reflect.getProperty(PlayState.instance.scriptSprites.get(tag), qualifierArray[0]);
					for (i in 1...qualifierArray.length - 1)
					{
						object = Reflect.getProperty(object, qualifierArray[i]);
					}
					return Reflect.getProperty(object, qualifierArray[qualifierArray.length - 1]);
				}
				return Reflect.getProperty(PlayState.instance.scriptSprites.get(tag), variable);
			}
			return null;
		});
		set('setPropertyLuaSprite', function(tag:String, variable:String, value:Any):Void
		{
			scriptWarn('setPropertyLuaSprite is deprecated! Use setProperty instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var qualifierArray:Array<String> = variable.split('.');
				if (qualifierArray.length > 1)
				{
					var object:Any = Reflect.getProperty(PlayState.instance.scriptSprites.get(tag), qualifierArray[0]);
					for (i in 1...qualifierArray.length - 1)
					{
						object = Reflect.getProperty(object, qualifierArray[i]);
					}
					Reflect.setProperty(object, qualifierArray[qualifierArray.length - 1], value);
					return;
				}
				Reflect.setProperty(PlayState.instance.scriptSprites.get(tag), variable, value);
				return;
			}
			scriptWarn('Lua sprite with tag: $tag doesn\'t exist!');
		});
		set('musicFadeIn', function(duration:Float, fromValue:Float = 0, toValue:Float = 1):Void
		{
			scriptWarn('musicFadeIn is deprecated! Use soundFadeIn instead.', false, true);
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
		});
		set('musicFadeOut', function(duration:Float, toValue:Float = 0):Void
		{
			scriptWarn('musicFadeOut is deprecated! Use soundFadeOut instead.', false, true);
			FlxG.sound.music.fadeOut(duration, toValue);
		});

		#if FEATURE_DISCORD
		set('changePresence', DiscordClient.changePresence);
		#end

		#if (!FEATURE_LUA && hscript)
		interp.execute(program);
		#end

		call('onCreate', []);
	}

	public function get(variable:String):Dynamic
	{
		if (closed)
		{
			return null;
		}

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
		if (closed)
		{
			return;
		}

		// Debug.logTrace('Setting $variable to $data');

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
		if (closed)
		{
			return FUNCTION_CONTINUE;
		}

		#if FEATURE_LUA
		if (lua != null)
		{
			Lua.getglobal(lua, funcName);

			for (arg in args)
			{
				Convert.toLua(lua, arg);
			}

			var result:Int = Lua.pcall(lua, args.length, 1, 0);
			var error:String = getLuaErrorMessage(lua);

			if (isResultAllowed(lua, result))
			{
				var converted:Any = Convert.fromLua(lua, result);
				Lua.pop(lua, 1);
				if (converted == null)
					converted = FUNCTION_CONTINUE;
				return converted;
			}
			else if (isErrorAllowed(error))
			{
				Lua.pop(lua, 1);
				scriptError('ERROR: $funcName($args): $error');
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
		closed = true;
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
			PlayState.instance.addTextToDebug(text, FlxColor.WHITE);
			Debug.logTrace('$scriptName: $text'); // FIXME This always uses the last loaded script's name for some reason?
		}
	}

	public function scriptWarn(text:String, ignoreCheck:Bool = false, deprecated:Bool = false):Void
	{
		if (ignoreCheck || get('luaDebugMode'))
		{
			if (deprecated && !get('luaDeprecatedWarnings'))
			{
				return;
			}
			PlayState.instance.addTextToDebug(text, FlxColor.YELLOW);
			Debug.logWarn('$scriptName: $text');
		}
	}

	public function scriptError(text:String, ignoreCheck:Bool = false, deprecated:Bool = false):Void
	{
		if (ignoreCheck || get('luaDebugMode'))
		{
			if (deprecated && !get('luaDeprecatedWarnings'))
			{
				return;
			}
			PlayState.instance.addTextToDebug(text, FlxColor.RED);
			Debug.logError('$scriptName: $text');
		}
	}

	#if FEATURE_LUA
	private function getLuaErrorMessage(lua:State):String
	{
		if (Lua.type(lua, -1) == Lua.LUA_TSTRING)
		{
			var error:String = Lua.tostring(lua, -1);
			return error;
		}
		return null;
	}

	private function isResultAllowed(lua:State, ?result:Int):Bool
	{ // Makes it ignore warnings
		return Lua.type(lua, result) > Lua.LUA_TNONE;
	}

	private function isErrorAllowed(error:String):Bool
	{ // Makes it ignore warnings and not break stuff if you didn't put the functions in your script
		return switch (error)
		{
			case null | 'attempt to call a nil value' /*| 'C++ exception'*/:
				false;
			default: true;
		}
	}
	#end
	#end
}

#if FEATURE_SCRIPTS
class ScriptSprite extends FlxSprite
{
	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		antialiasing = Options.profile.globalAntialiasing;
	}
}

class ScriptText extends FlxText
{
	public function new(x:Float, y:Float, text:String, width:Float)
	{
		super(x, y, width, text, 16);

		setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		cameras = [PlayState.instance.camHUD];
		scrollFactor.set();
		borderSize = 2;
	}
}

class DebugScriptText extends FlxText
{
	private var disableTime:Float = 6;

	public var parentGroup:FlxTypedGroup<DebugScriptText>;

	public function new(text:String, parentGroup:FlxTypedGroup<DebugScriptText>, color:FlxColor)
	{
		super(10, 10, 0, text, 20);

		this.parentGroup = parentGroup;
		setFormat(Paths.font('vcr.ttf'), size, color, LEFT, OUTLINE, FlxColor.BLACK);
		scrollFactor.set();
		borderSize = 1;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		disableTime -= elapsed;
		if (disableTime <= 0)
		{
			kill();
			parentGroup.remove(this);
			destroy();
		}
		else if (disableTime < 1)
			alpha = disableTime;
	}
}
#end
