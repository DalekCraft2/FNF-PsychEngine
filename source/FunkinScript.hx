package;

#if FEATURE_SCRIPTS
import DialogueBoxPsych.DialogueDef;
import animateatlas.AtlasFrameMaker;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import haxe.io.Path;
import openfl.display.BlendMode;

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
class FunkinScript
{
	public static inline final FUNCTION_STOP:Int = 1;
	public static inline final FUNCTION_CONTINUE:Int = 0;

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
			Debug.displayAlert('Error loading script', resultStr);
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
		scriptName = path;
		Debug.logTrace('Script loaded succesfully: $path');

		// Script variables
		set('FUNCTION_STOP', FUNCTION_STOP);
		set('FUNCTION_CONTINUE', FUNCTION_CONTINUE);

		// These two are for legacy support
		set('Function_Stop', FUNCTION_STOP);
		set('Function_Continue', FUNCTION_CONTINUE);

		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);

		// Song/Week variables
		set('curBpm', Conductor.tempo);
		set('bpm', PlayState.song.bpm);
		set('scrollSpeed', PlayState.song.speed);
		set('crotchetLength', Conductor.crotchetLength);
		set('stepCrotchet', Conductor.semiquaverLength);
		set('songLength', FlxG.sound.music.length);
		set('songId', PlayState.song.songId);
		set('songName', PlayState.song.songName);
		set('song', PlayState.song.songId);
		set('startedCountdown', false);

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);
		set('difficultyName', Difficulty.difficulties[PlayState.storyDifficulty]);
		set('weekRaw', PlayState.storyWeek);
		set('week', Week.weekList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);

		// Block require and os, Should probably have a proper function but this should be good enough for now until someone smarter comes along and recreates a safe version of the OS library
		set('require', false);

		// Camera variables
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen variables
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState variables
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

		// Default character positions
		set('defaultBoyfriendX', PlayState.instance.BF_X);
		set('defaultBoyfriendY', PlayState.instance.BF_Y);
		set('defaultOpponentX', PlayState.instance.OPPONENT_X);
		set('defaultOpponentY', PlayState.instance.OPPONENT_Y);
		set('defaultGirlfriendX', PlayState.instance.GF_X);
		set('defaultGirlfriendY', PlayState.instance.GF_Y);

		// Character variables
		set('boyfriendName', PlayState.song.player1);
		set('dadName', PlayState.song.player2);
		set('gfName', PlayState.song.gfVersion);

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
		set('buildTarget', 'html5');
		#elseif android
		set('buildTarget', 'android');
		#else
		set('buildTarget', 'unknown');
		#end

		set('addScript', function(key:String, ignoreAlreadyRunning:Bool = false):Void
		{ // would be dope asf.
			var path:String = Paths.script(key);
			if (Paths.exists(path))
			{
				if (!ignoreAlreadyRunning)
				{
					for (script in PlayState.instance.scriptArray)
					{
						if (script.scriptName == path)
						{
							scriptTrace('The script "$path" is already running!');
							return;
						}
					}
				}
				PlayState.instance.scriptArray.push(new FunkinScript(path));
				return;
			}

			scriptTrace('The script "$path" doesn\'t exist!');
		});
		set('removeScript', function(key:String, ignoreAlreadyRunning:Bool = false):Void
		{ // would be dope asf.
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

			scriptTrace('The script "$path" doesn\'t exist!');
		});

		set('loadSong', function(?name:String, difficultyNum:Int = -1):Void
		{
			if (name == null || name.length < 1)
				name = PlayState.song.songId;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			var difficulty:String = Difficulty.getDifficultyFilePath(difficultyNum);
			PlayState.song = Song.loadSong(name, difficulty);
			PlayState.storyDifficulty = difficultyNum;
			PlayState.instance.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.stop();
			if (PlayState.instance.vocals != null)
			{
				PlayState.instance.vocals.pause();
				PlayState.instance.vocals.stop();
			}
		});
		set('loadFrames', function(variable:String, image:String, spriteType:String = 'sparrow'):Void
		{
			var spr:FlxSprite = getObjectDirectly(variable);
			if (spr != null && image != null && image.length > 0)
			{
				loadFrames(spr, image, spriteType);
			}
		});

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
				var group:FlxTypedGroup<Dynamic> = group;
				return getGroupStuff(group.members[index], variable);
			}

			var groupEntry:Dynamic = group[index];
			if (groupEntry != null)
			{
				if (variable is Int)
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
				var group:FlxTypedGroup<Dynamic> = group;
				setGroupStuff(group.members[index], variable, value);
				return;
			}

			var groupEntry:Dynamic = group[index];
			if (groupEntry != null)
			{
				if (variable is Int)
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
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				var object:Any = Reflect.getProperty(Type.resolveClass(classVar), qualifierArray[0]);
				for (i in 1...qualifierArray.length - 1)
				{
					object = Reflect.getProperty(object, qualifierArray[i]);
				}
				return Reflect.getProperty(object, qualifierArray[qualifierArray.length - 1]);
			}
			return Reflect.getProperty(Type.resolveClass(classVar), variable);
		});
		set('setPropertyFromClass', function(classVar:String, variable:String, value:Any):Void
		{
			var qualifierArray:Array<String> = variable.split('.');
			if (qualifierArray.length > 1)
			{
				var object:Any = Reflect.getProperty(Type.resolveClass(classVar), qualifierArray[0]);
				for (i in 1...qualifierArray.length - 1)
				{
					object = Reflect.getProperty(object, qualifierArray[i]);
				}
				Reflect.setProperty(object, qualifierArray[qualifierArray.length - 1], value);
				return;
			}
			Reflect.setProperty(Type.resolveClass(classVar), variable, value);
		});

		set('getObjectOrder', function(obj:String):Int
		{
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				return getInstance().members.indexOf(PlayState.instance.scriptSprites.get(obj));
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				return getInstance().members.indexOf(PlayState.instance.scriptTexts.get(obj));
			}

			var object:FlxBasic = Reflect.getProperty(getInstance(), obj);
			if (object != null)
			{
				return getInstance().members.indexOf(object);
			}
			scriptTrace('Object $obj doesn\'t exist!');
			return -1;
		});
		set('setObjectOrder', function(obj:String, position:Int):Void
		{
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				var spr:ScriptSprite = PlayState.instance.scriptSprites.get(obj);
				if (spr.wasAdded)
				{
					getInstance().remove(spr, true);
				}
				getInstance().insert(position, spr);
				return;
			}
			if (PlayState.instance.scriptTexts.exists(obj))
			{
				var text:ScriptText = PlayState.instance.scriptTexts.get(obj);
				if (text.wasAdded)
				{
					getInstance().remove(text, true);
				}
				getInstance().insert(position, text);
				return;
			}

			var object:FlxBasic = Reflect.getProperty(getInstance(), obj);
			if (object != null)
			{
				getInstance().remove(object, true);
				getInstance().insert(position, object);
				return;
			}
			scriptTrace('Object $obj doesn\'t exist!');
		});

		// tweens
		set('doTweenX', function(tag:String, vars:String, value:Any, duration:Float, ease:String):Void
		{
			var objectToTween:Any = tweenShit(tag, vars);
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
				scriptTrace('Couldn\'t find object: $vars');
			}
		});
		set('doTweenY', function(tag:String, vars:String, value:Any, duration:Float, ease:String):Void
		{
			var objectToTween:Any = tweenShit(tag, vars);
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
				scriptTrace('Couldn\'t find object: $vars');
			}
		});
		set('doTweenAngle', function(tag:String, vars:String, value:Any, duration:Float, ease:String):Void
		{
			var objectToTween:Any = tweenShit(tag, vars);
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
				scriptTrace('Couldn\'t find object: $vars');
			}
		});
		set('doTweenAlpha', function(tag:String, vars:String, value:Any, duration:Float, ease:String):Void
		{
			var objectToTween:Any = tweenShit(tag, vars);
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
				scriptTrace('Couldn\'t find object: $vars');
			}
		});
		set('doTweenZoom', function(tag:String, vars:String, value:Any, duration:Float, ease:String):Void
		{
			var objectToTween:Any = tweenShit(tag, vars);
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
				scriptTrace('Couldn\'t find object: $vars');
			}
		});
		set('doTweenColor', function(tag:String, vars:String, targetColor:String, duration:Float, ease:String):Void
		{
			var objectToTween:Dynamic = tweenShit(tag, vars);
			if (objectToTween != null)
			{
				var color:Int = Std.parseInt(targetColor);
				if (!targetColor.startsWith('0x'))
					color = Std.parseInt('0xFF$targetColor');

				var curColor:FlxColor = objectToTween.color;
				curColor.alphaFloat = objectToTween.alpha;
				PlayState.instance.scriptTweens.set(tag, FlxTween.color(objectToTween, duration, curColor, color, {
					ease: getFlxEaseByString(ease),
					onComplete: (twn:FlxTween) ->
					{
						PlayState.instance.scriptTweens.remove(tag);
						PlayState.instance.callOnScripts('onTweenCompleted', [tag]);
					}
				}));
			}
			else
			{
				scriptTrace('Couldn\'t find object: $vars');
			}
		});

		// Tween shit, but for strums
		set('noteTweenX', function(tag:String, note:Int, value:Any, duration:Float, ease:String):Void
		{
			cancelTween(tag);
			if (note < 0)
				note = 0;
			// TODO Should the index be modulo the length of NoteKey.createAll()?
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
		set('noteTweenY', function(tag:String, note:Int, value:Any, duration:Float, ease:String):Void
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
		set('noteTweenAngle', function(tag:String, note:Int, value:Any, duration:Float, ease:String):Void
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
		set('noteTweenAlpha', function(tag:String, note:Int, value:Any, duration:Float, ease:String):Void
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
		set('noteTweenDirection', function(tag:String, note:Int, value:Any, duration:Float, ease:String):Void
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

		set('cancelTween', function(tag:String):Void
		{
			cancelTween(tag);
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

		set('getColorFromHex', function(color:String):Int
		{
			if (!color.startsWith('0x'))
				color = '0xFF$color';
			return Std.parseInt(color);
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
		set('addCharacterToList', function(name:String, type:String):Void
		{
			var charType:Int = 0;
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent':
					charType = 1;
				case 'gf' | 'girlfriend':
					charType = 2;
			}
			PlayState.instance.addCharacterToList(name, charType);
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
		set('triggerEvent', function(name:String, arg1:Any, arg2:Any):Void
		{
			var value1:String = arg1;
			var value2:String = arg2;
			PlayState.instance.triggerEvent(name, value1, value2);
			scriptTrace('Triggered event: $name, $value1, $value2');
		});

		set('startCountdown', function(variable:String):Void
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
			PlayState.instance.persistentUpdate = false;
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

		set('getCharacterX', function(type:String):Float
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent':
					return PlayState.instance.opponentGroup.x;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.x;
				default:
					return PlayState.instance.boyfriendGroup.x;
			}
		});
		set('setCharacterX', function(type:String, value:Float):Void
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent':
					PlayState.instance.opponentGroup.x = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.x = value;
				default:
					PlayState.instance.boyfriendGroup.x = value;
			}
		});
		set('getCharacterY', function(type:String):Float
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent':
					return PlayState.instance.opponentGroup.y;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.y;
				default:
					return PlayState.instance.boyfriendGroup.y;
			}
		});
		set('setCharacterY', function(type:String, value:Float):Void
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent':
					PlayState.instance.opponentGroup.y = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.y = value;
				default:
					PlayState.instance.boyfriendGroup.y = value;
			}
		});
		set('getCharacterAngle', function(type:String):Float
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent':
					return PlayState.instance.opponentGroup.angle;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.angle;
				default:
					return PlayState.instance.boyfriendGroup.angle;
			}
		});
		set('setCharacterAngle', function(type:String, value:Float):Void
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent':
					PlayState.instance.opponentGroup.angle = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.angle = value;
				default:
					PlayState.instance.boyfriendGroup.angle = value;
			}
		});
		set('cameraSetTarget', function(target:String):Void
		{
			var isDad:Bool = false;
			if (target == 'dad' || target == 'opponent')
			{
				isDad = true;
			}
			PlayState.instance.moveCamera(isDad);
		});
		set('cameraShake', function(camera:String, intensity:Float, duration:Float):Void
		{
			cameraFromString(camera).shake(intensity, duration);
		});

		set('cameraFlash', function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			var colorNum:Int = Std.parseInt(color);
			if (!color.startsWith('0x'))
				colorNum = Std.parseInt('0xFF$color');
			cameraFromString(camera).flash(colorNum, duration, null, forced);
		});
		set('cameraFade', function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			var colorNum:Int = Std.parseInt(color);
			if (!color.startsWith('0x'))
				colorNum = Std.parseInt('0xFF$color');
			cameraFromString(camera).fade(colorNum, duration, false, null, forced);
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
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		set('getMouseY', function(camera:String):Float
		{
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		set('getMidpointX', function(variable:String):Float
		{
			var obj:FlxObject = getObjectDirectly(variable);
			if (obj != null)
				return obj.getMidpoint().x;

			return 0;
		});
		set('getMidpointY', function(variable:String):Float
		{
			var obj:FlxObject = getObjectDirectly(variable);
			if (obj != null)
				return obj.getMidpoint().y;

			return 0;
		});
		set('getGraphicMidpointX', function(variable:String):Float
		{
			var obj:FlxSprite = getObjectDirectly(variable);
			if (obj != null)
				return obj.getGraphicMidpoint().x;

			return 0;
		});
		set('getGraphicMidpointY', function(variable:String):Float
		{
			var obj:FlxSprite = getObjectDirectly(variable);
			if (obj != null)
				return obj.getGraphicMidpoint().y;

			return 0;
		});
		set('getScreenPositionX', function(variable:String):Float
		{
			var obj:FlxObject = getObjectDirectly(variable);
			if (obj != null)
				return obj.getScreenPosition().x;

			return 0;
		});
		set('getScreenPositionY', function(variable:String):Float
		{
			var obj:FlxObject = getObjectDirectly(variable);
			if (obj != null)
				return obj.getScreenPosition().y;

			return 0;
		});
		set('characterPlayAnim', function(character:String, anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void
		{
			switch (character.toLowerCase())
			{
				case 'dad' | 'opponent':
					if (PlayState.instance.opponent.animOffsets.exists(anim))
						PlayState.instance.opponent.playAnim(anim, forced, reversed, frame);
				case 'gf' | 'girlfriend':
					if (PlayState.instance.gf != null && PlayState.instance.gf.animOffsets.exists(anim))
						PlayState.instance.gf.playAnim(anim, forced, reversed, frame);
				default:
					if (PlayState.instance.boyfriend.animOffsets.exists(anim))
						PlayState.instance.boyfriend.playAnim(anim, forced, reversed, frame);
			}
		});
		set('characterDance', function(character:String):Void
		{
			switch (character.toLowerCase())
			{
				case 'dad' | 'opponent':
					PlayState.instance.opponent.dance();
				case 'gf' | 'girlfriend':
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
			sprite.antialiasing = Options.save.data.globalAntialiasing;
			PlayState.instance.scriptSprites.set(tag, sprite);
			sprite.active = true; // TODO Is this supposed to be false?
		});
		set('makeAnimatedLuaSprite', function(tag:String, image:String, x:Float, y:Float, spriteType:String = 'sparrow'):Void
		{
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var sprite:ScriptSprite = new ScriptSprite(x, y);

			loadFrames(sprite, image, spriteType);
			sprite.antialiasing = Options.save.data.globalAntialiasing;
			PlayState.instance.scriptSprites.set(tag, sprite);
		});

		set('makeGraphic', function(obj:String, width:Int, height:Int, color:String):Void
		{
			var colorNum:Int = Std.parseInt(color);
			if (!color.startsWith('0x'))
				colorNum = Std.parseInt('0xFF$color');

			if (PlayState.instance.scriptSprites.exists(obj))
			{
				PlayState.instance.scriptSprites.get(obj).makeGraphic(width, height, colorNum);
				return;
			}

			var sprite:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (sprite != null)
			{
				sprite.makeGraphic(width, height, colorNum);
			}
		});
		set('addAnimationByPrefix', function(obj:String, name:String, prefix:String, frameRate:Int = 24, loop:Bool = true):Void
		{
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(obj);
				sprite.animation.addByPrefix(name, prefix, frameRate, loop);
				if (sprite.animation.curAnim == null)
				{
					sprite.animation.play(name, true);
				}
				return;
			}

			var sprite:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (sprite != null)
			{
				sprite.animation.addByPrefix(name, prefix, frameRate, loop);
				if (sprite.animation.curAnim == null)
				{
					sprite.animation.play(name, true);
				}
			}
		});
		set('addAnimationByIndices', function(obj:String, name:String, prefix:String, indices:String, frameRate:Int = 24):Void
		{
			var strIndices:Array<String> = indices.trim().split(',');
			var intIndices:Array<Int> = [for (index in strIndices) Std.parseInt(index)];

			if (PlayState.instance.scriptSprites.exists(obj))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(obj);
				sprite.animation.addByIndices(name, prefix, intIndices, '', frameRate, false);
				if (sprite.animation.curAnim == null)
				{
					sprite.animation.play(name, true);
				}
				return;
			}

			var sprite:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (sprite != null)
			{
				sprite.animation.addByIndices(name, prefix, intIndices, '', frameRate, false);
				if (sprite.animation.curAnim == null)
				{
					sprite.animation.play(name, true);
				}
			}
		});
		set('objectPlayAnimation', function(obj:String, name:String, forced:Bool = false, startFrame:Int = 0):Void
		{
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				PlayState.instance.scriptSprites.get(obj).animation.play(name, forced, false, startFrame);
				return;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (spr != null)
			{
				spr.animation.play(name, forced);
			}
		});

		set('setScrollFactor', function(obj:String, scrollX:Float, scrollY:Float):Void
		{
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				PlayState.instance.scriptSprites.get(obj).scrollFactor.set(scrollX, scrollY);
				return;
			}

			var object:FlxObject = Reflect.getProperty(getInstance(), obj);
			if (object != null)
			{
				object.scrollFactor.set(scrollX, scrollY);
			}
		});
		set('addLuaSprite', function(tag:String, front:Bool = false):Void
		{
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
				if (!sprite.wasAdded)
				{
					if (front)
					{
						getInstance().add(sprite);
					}
					else
					{
						if (PlayState.instance.isDead)
						{
							GameOverSubState.instance.insert(GameOverSubState.instance.members.indexOf(GameOverSubState.instance.boyfriend), sprite);
						}
						else
						{
							var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gfGroup);
							if (PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup) < position)
							{
								position = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
							}
							else if (PlayState.instance.members.indexOf(PlayState.instance.opponentGroup) < position)
							{
								position = PlayState.instance.members.indexOf(PlayState.instance.opponentGroup);
							}
							PlayState.instance.insert(position, sprite);
						}
					}
					sprite.wasAdded = true;
					scriptTrace('Added a sprite with tag: $tag');
				}
			}
		});
		set('setGraphicSize', function(obj:String, x:Int, y:Int = 0):Void
		{
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(obj);
				sprite.setGraphicSize(x, y);
				sprite.updateHitbox();
				return;
			}

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
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(obj);
				sprite.scale.set(x, y);
				sprite.updateHitbox();
				return;
			}

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
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(obj);
				sprite.updateHitbox();
				return;
			}

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

				if (sprite.wasAdded)
				{
					getInstance().remove(sprite, true);
					sprite.wasAdded = false;
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
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				PlayState.instance.scriptSprites.get(obj).cameras = [cameraFromString(camera)];
				return true;
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				PlayState.instance.scriptTexts.get(obj).cameras = [cameraFromString(camera)];
				return true;
			}

			var object:FlxObject = Reflect.getProperty(getInstance(), obj);
			if (object != null)
			{
				object.cameras = [cameraFromString(camera)];
				return true;
			}
			scriptTrace('Object $obj doesn\'t exist!');
			return false;
		});
		set('setBlendMode', function(obj:String, blend:String = ''):Bool
		{
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				PlayState.instance.scriptSprites.get(obj).blend = blendModeFromString(blend);
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if (spr != null)
			{
				spr.blend = blendModeFromString(blend);
				return true;
			}
			scriptTrace('Object $obj doesn\'t exist!');
			return false;
		});
		set('screenCenter', function(obj:String, pos:String = 'xy'):Void
		{
			var spr:FlxSprite;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				spr = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				spr = PlayState.instance.scriptTexts.get(obj);
			}
			else
			{
				spr = Reflect.getProperty(getInstance(), obj);
			}

			if (spr != null)
			{
				switch (pos.trim().toLowerCase())
				{
					case 'x':
						spr.screenCenter(X);
						return;
					case 'y':
						spr.screenCenter(Y);
						return;
					default:
						spr.screenCenter(XY);
						return;
				}
			}
			scriptTrace('Object $obj doesn\'t exist!');
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
			var spr:FlxSprite;
			if (PlayState.instance.scriptSprites.exists(obj))
			{
				spr = PlayState.instance.scriptSprites.get(obj);
			}
			else if (PlayState.instance.scriptTexts.exists(obj))
			{
				spr = PlayState.instance.scriptTexts.get(obj);
			}
			else
			{
				spr = Reflect.getProperty(getInstance(), obj);
			}

			if (spr != null)
			{
				if (spr.framePixels != null)
					spr.framePixels.getPixel32(x, y);
				return spr.pixels.getPixel32(x, y);
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
			var path:String = Paths.json(Path.join(['songs', PlayState.song.songId, dialogueFile]));
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
					scriptTrace('Your dialogue file is badly formatted!');
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
				scriptTrace('Video file not found: $videoFile');
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
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
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
				FlxG.sound.music.fadeOut(duration, toValue);
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
				if (FlxG.sound.music.fadeTween != null)
				{
					FlxG.sound.music.fadeTween.cancel();
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
				if (FlxG.sound.music != null)
				{
					return FlxG.sound.music.volume;
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
				if (FlxG.sound.music != null)
				{
					FlxG.sound.music.volume = value;
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
		set('close', function(printMessage:Bool):Void
		{
			if (!gonnaClose)
			{
				if (printMessage)
				{
					scriptTrace('Stopping script: $scriptName');
				}
				PlayState.instance.scriptsToClose.push(this);
			}
			gonnaClose = true;
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
				var colorNum:Int = Std.parseInt(color);
				if (!color.startsWith('0x'))
					colorNum = Std.parseInt('0xFF$color');

				obj.borderSize = size;
				obj.borderColor = colorNum;
			}
		});
		set('setTextColor', function(tag:String, color:String):Void
		{
			var obj:FlxText = getTextObject(tag);
			if (obj != null)
			{
				var colorNum:Int = Std.parseInt(color);
				if (!color.startsWith('0x'))
					colorNum = Std.parseInt('0xFF$color');

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
				if (!text.wasAdded)
				{
					getInstance().add(text);
					text.wasAdded = true;
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

				if (text.wasAdded)
				{
					getInstance().remove(text, true);
					text.wasAdded = false;
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
			scriptTrace('Save file already initialized: $name');
		});
		set('flushSaveData', function(name:String):Void
		{
			if (PlayState.instance.scriptSaves.exists(name))
			{
				PlayState.instance.scriptSaves.get(name).flush();
				return;
			}
			scriptTrace('Save file not initialized: $name');
		});
		set('getDataFromSave', function(name:String, field:String):Any
		{
			if (PlayState.instance.scriptSaves.exists(name))
			{
				return Reflect.field(PlayState.instance.scriptSaves.get(name).data, field);
			}
			scriptTrace('Save file not initialized: $name');
			return null;
		});
		set('setDataFromSave', function(name:String, field:String, value:Any):Void
		{
			if (PlayState.instance.scriptSaves.exists(name))
			{
				Reflect.setField(PlayState.instance.scriptSaves.get(name).data, field, value);
				return;
			}
			scriptTrace('Save file not initialized: $name');
		});

		set('getText', function(path:String, ignoreModFolders:Bool = false):String
		{
			return Paths.getText(path, ignoreModFolders);
		});

		// DEPRECATED, DONT MESS WITH THESE SHITS, ITS JUST THERE FOR BACKWARD COMPATIBILITY
		set('luaSpriteMakeGraphic', function(tag:String, width:Int, height:Int, color:String):Void
		{
			scriptTrace('luaSpriteMakeGraphic is deprecated! Use makeGraphic instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var colorNum:Int = Std.parseInt(color);
				if (!color.startsWith('0x'))
					colorNum = Std.parseInt('0xFF$color');

				PlayState.instance.scriptSprites.get(tag).makeGraphic(width, height, colorNum);
			}
		});
		set('luaSpriteAddAnimationByPrefix', function(tag:String, name:String, prefix:String, frameRate:Int = 24, loop:Bool = true):Void
		{
			scriptTrace('luaSpriteAddAnimationByPrefix is deprecated! Use addAnimationByPrefix instead', false, true);
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
			scriptTrace('luaSpriteAddAnimationByIndices is deprecated! Use addAnimationByIndices instead', false, true);
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
			scriptTrace('luaSpritePlayAnimation is deprecated! Use objectPlayAnimation instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				PlayState.instance.scriptSprites.get(tag).animation.play(name, forced);
			}
		});
		set('setLuaSpriteCamera', function(tag:String, camera:String = ''):Bool
		{
			scriptTrace('setLuaSpriteCamera is deprecated! Use setObjectCamera instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				PlayState.instance.scriptSprites.get(tag).cameras = [cameraFromString(camera)];
				return true;
			}
			scriptTrace('Lua sprite with tag: $tag doesn\'t exist!');
			return false;
		});
		set('setLuaSpriteScrollFactor', function(tag:String, scrollX:Float, scrollY:Float):Void
		{
			scriptTrace('setLuaSpriteScrollFactor is deprecated! Use setScrollFactor instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				PlayState.instance.scriptSprites.get(tag).scrollFactor.set(scrollX, scrollY);
			}
		});
		set('scaleLuaSprite', function(tag:String, x:Float, y:Float):Void
		{
			scriptTrace('scaleLuaSprite is deprecated! Use scaleObject instead', false, true);
			if (PlayState.instance.scriptSprites.exists(tag))
			{
				var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
				sprite.scale.set(x, y);
				sprite.updateHitbox();
			}
		});
		set('getPropertyLuaSprite', function(tag:String, variable:String):Any
		{
			scriptTrace('getPropertyLuaSprite is deprecated! Use getProperty instead', false, true);
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
			scriptTrace('setPropertyLuaSprite is deprecated! Use setProperty instead', false, true);
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
			scriptTrace('Lua sprite with tag: $tag doesn\'t exist!');
		});
		set('musicFadeIn', function(duration:Float, fromValue:Float = 0, toValue:Float = 1):Void
		{
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			scriptTrace('musicFadeIn is deprecated! Use soundFadeIn instead.', false, true);
		});
		set('musicFadeOut', function(duration:Float, toValue:Float = 0):Void
		{
			FlxG.sound.music.fadeOut(duration, toValue);
			scriptTrace('musicFadeOut is deprecated! Use soundFadeOut instead.', false, true);
		});

		#if FEATURE_DISCORD
		// set('changePresence', (details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) ->
		// {
		// 	DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
		// });
		set('changePresence', DiscordClient.changePresence);
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
				if (error == 'attempt to call a nil value')
				{ // Makes it ignore warnings and not break stuff if you didn't put the functions in your script
					return FUNCTION_CONTINUE;
				}
				else
				{
					Debug.logError(error);
					scriptTrace(error);
				}
			}

			if (result != null && resultIsAllowed(lua, result))
			{
				var converted:Any = Convert.fromLua(lua, result);
				Lua.pop(lua, 1);
				return converted;
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
		if (Lua.type(lua, -1) == Lua.LUA_TSTRING)
		{
			var error:String = Lua.tostring(lua, -1);
			Lua.pop(lua, 1);
			return error;
		}
		return null;
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

	private static inline function getTextObject(name:String):FlxText
	{
		return PlayState.instance.scriptTexts.exists(name) ? PlayState.instance.scriptTexts.get(name) : Reflect.getProperty(PlayState.instance, name);
	}

	private static function getGroupStuff(group:Any, variable:String):Any
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

	private static function setGroupStuff(group:Any, variable:String, value:Any):Void
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

	private static function loadFrames(spr:FlxSprite, image:String, spriteType:String):Void
	{
		switch (spriteType.toLowerCase().trim())
		{
			case 'texture' | 'textureatlas' | 'tex':
				spr.frames = AtlasFrameMaker.construct(image);
			case 'texture_noaa' | 'textureatlas_noaa' | 'tex_noaa':
				spr.frames = AtlasFrameMaker.construct(image, null, true);
			case 'packer' | 'packeratlas' | 'pac':
				spr.frames = Paths.getPackerAtlas(image);
			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	private static function resetTextTag(tag:String):Void
	{
		if (PlayState.instance.scriptTexts.exists(tag))
		{
			var text:ScriptText = PlayState.instance.scriptTexts.get(tag);
			text.kill();
			if (text.wasAdded)
			{
				PlayState.instance.remove(text, true);
			}
			text.destroy();
			PlayState.instance.scriptTexts.remove(tag);
		}
	}

	private static function resetSpriteTag(tag:String):Void
	{
		if (PlayState.instance.scriptSprites.exists(tag))
		{
			var sprite:ScriptSprite = PlayState.instance.scriptSprites.get(tag);
			sprite.kill();
			if (sprite.wasAdded)
			{
				PlayState.instance.remove(sprite, true);
			}
			sprite.destroy();
			PlayState.instance.scriptSprites.remove(tag);
		}
	}

	private static function cancelTween(tag:String):Void
	{
		if (PlayState.instance.scriptTweens.exists(tag))
		{
			var tween:FlxTween = PlayState.instance.scriptTweens.get(tag);
			tween.cancel();
			tween.destroy();
			PlayState.instance.scriptTweens.remove(tag);
		}
	}

	private static function tweenShit(tag:String, vars:String):Any
	{
		cancelTween(tag);
		var variables:Array<String> = vars.replace(' ', '').split('.');
		var object:Any = Reflect.getProperty(getInstance(), variables[0]);
		if (PlayState.instance.scriptSprites.exists(variables[0]))
		{
			object = PlayState.instance.scriptSprites.get(variables[0]);
		}
		if (PlayState.instance.scriptTexts.exists(variables[0]))
		{
			object = PlayState.instance.scriptTexts.get(variables[0]);
		}

		for (i in 1...variables.length)
		{
			object = Reflect.getProperty(object, variables[i]);
		}
		return object;
	}

	private static function cancelTimer(tag:String):Void
	{
		if (PlayState.instance.scriptTimers.exists(tag))
		{
			var timer:FlxTimer = PlayState.instance.scriptTimers.get(tag);
			timer.cancel();
			timer.destroy();
			PlayState.instance.scriptTimers.remove(tag);
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

	private static function blendModeFromString(blend:String):BlendMode
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

	private static function cameraFromString(cam:String):FlxCamera
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

	private static function getPropertyLoopThingWhatever(qualifierArray:Array<String>, checkForTextsToo:Bool = true):Any
	{
		var object:Any = getObjectDirectly(qualifierArray[0], checkForTextsToo);
		for (i in 1...qualifierArray.length - 1)
		{
			object = Reflect.getProperty(object, qualifierArray[i]);
		}
		return object;
	}

	private static function getObjectDirectly(objectName:String, checkForTextsToo:Bool = true):Any
	{
		if (PlayState.instance.scriptSprites.exists(objectName))
		{
			return PlayState.instance.scriptSprites.get(objectName);
		}
		else if (checkForTextsToo && PlayState.instance.scriptTexts.exists(objectName))
		{
			return PlayState.instance.scriptTexts.get(objectName);
		}
		else
		{
			return Reflect.getProperty(getInstance(), objectName);
		}
	}

	private static inline function getInstance():FlxState
	{
		return PlayState.instance.isDead ? GameOverSubState.instance : PlayState.instance;
	}
}

class ScriptSprite extends FlxSprite
{
	public var wasAdded:Bool = false;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		antialiasing = Options.save.data.globalAntialiasing;
	}
}

class ScriptText extends FlxText
{
	public var wasAdded:Bool = false;

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

	public function new(text:String, parentGroup:FlxTypedGroup<DebugScriptText>)
	{
		super(10, 10, 0, text, 20);

		this.parentGroup = parentGroup;
		setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
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
