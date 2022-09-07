package funkin;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.debug.log.LogStyle;
import flixel.system.debug.watch.Tracker.TrackerProfile;
import flixel.util.FlxStringUtil;
import funkin.chart.container.Song;
import funkin.states.PlayState;
import funkin.ui.HealthIcon;
import haxe.Log;
import haxe.PosInfos;
import openfl.Lib;

using StringTools;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
#end

// TODO Make a common method for logging called log() and have each of the other methods call that
// TODO So, I just discovered FlxG.log.redirectTraces, which could make a lot of this class much simpler...

/**
 * Hey you, developer!
 * This class contains lots of utility functions for logging and debugging.
 * The goal is to integrate development more heavily with the HaxeFlixel debugger.
 * Use these methods to the fullest to produce mods efficiently!
 * 
 * @see https://haxeflixel.com/documentation/debugger/
 */
class Debug
{
	private static final LOG_STYLE_ERROR:LogStyle = new LogStyle('[ERROR] ', 'FF8888', 12, true, false, false, 'flixel/sounds/beep', true);
	private static final LOG_STYLE_WARN:LogStyle = new LogStyle('[WARN ] ', 'D9F85C', 12, true, false, false, 'flixel/sounds/beep', true);
	private static final LOG_STYLE_INFO:LogStyle = new LogStyle('[INFO ] ', '5CF878', 12, false);
	// TODO Java (or, at least, Apache Log4j 2) has a log level in between these two called "Debug" (as well as a level above Error called "Fatal"), and I'm a sucker for Java, so...
	private static final LOG_STYLE_TRACE:LogStyle = new LogStyle('[TRACE] ', '5CF878', 12, false);

	private static var logFileWriter:DebugLogWriter;

	/**
	 * Log an error message to the game's console.
	 * Plays a beep to the user and forces the console open if this is a debug build.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logError(input:Any, ?pos:PosInfos):Void
	{
		if (input == null)
			return;
		var output:Array<Any> = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_ERROR);
		writeToLogFile(output, 'ERROR');
	}

	/**
	 * Log an warning message to the game's console.
	 * Plays a beep to the user and forces the console open if this is a debug build.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logWarn(input:Any, ?pos:PosInfos):Void
	{
		if (input == null)
			return;
		var output:Array<Any> = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_WARN);
		writeToLogFile(output, 'WARN');
	}

	/**
	 * Log an info message to the game's console. Only visible in debug builds.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logInfo(input:Any, ?pos:PosInfos):Void
	{
		if (input == null)
			return;
		var output:Array<Any> = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_INFO);
		writeToLogFile(output, 'INFO');
	}

	/**
	 * Log a debug message to the game's console. Only visible in debug builds.
	 * NOTE: We redirect all Haxe `trace()` calls to this function.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logTrace(input:Any, ?pos:PosInfos):Void
	{
		if (input == null)
			return;
		var output:Array<Any> = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_TRACE);
		writeToLogFile(output, 'TRACE');
	}

	/**
	 * Displays a popup with the provided text.
	 * This interrupts the game, so make sure it's REALLY important.
	 * @param title The title of the popup.
	 * @param description The description of the popup.
	 */
	public static inline function displayAlert(title:String, description:String):Void
	{
		Lib.application.window.alert(description, title);
	}

	/**
	 * Display the value of a particular field of a given object
	 * in the Debug watch window, labelled with the specified name.
	 * Updates continuously.
	 * @param object The object to watch.
	 * @param field The string name of a field of the above object.
	 * @param name
	 */
	public static inline function watchVariable(object:Any, field:String, name:String):Void
	{
		#if debug
		if (object == null)
		{
			Debug.logError('Tried to watch a variable on a null object!');
			return;
		}
		FlxG.watch.add(object, field, name == null ? field : name);
		#end
		// Else, do nothing outside of debug mode.
	}

	/**
	 * Adds the specified value to the Debug Watch window under the current name.
	 * A lightweight alternative to watchVariable, since it doesn't update until you call it again.
	 * 
	 * @param name
	 * @param value
	 */
	public static inline function quickWatch(name:String, value:Any):Void
	{
		#if debug
		FlxG.watch.addQuick(name == null ? 'QuickWatch' : name, value);
		#end
		// Else, do nothing outside of debug mode.
	}

	/**
	 * The Console window already supports most hScript, meaning you can do most things you could already do in Haxe.
	 * However, you can also add custom commands using this function.
	 */
	public static inline function addConsoleCommand(name:String, callbackFn:Any):Void
	{
		FlxG.console.registerFunction(name, callbackFn);
	}

	/**
	 * Add an object with a custom alias so that it can be accessed via the console.
	 */
	public static inline function addObject(name:String, object:Any):Void
	{
		FlxG.console.registerObject(name, object);
	}

	/**
	 * Create a tracker window for an object.
	 * This will display the properties of that object in
	 * a fancy little Debug window you can minimize and drag around.
	 * 
	 * @param obj The object to display.
	 */
	public static inline function trackObject(obj:Any):Void
	{
		if (obj == null)
		{
			Debug.logError('Tried to track a null object!');
			return;
		}
		FlxG.debugger.track(obj);
	}

	/**
	 * The game runs this function immediately when it starts.
	 * Use onGameStart() if it can wait until a little later.
	 */
	public static function onInitProgram():Void
	{
		// Initialize logging tools.
		trace('Initializing Debug tools...');

		// Getting the original trace() function before overriding it.
		var traceFunction:(v:Any, ?infos:PosInfos) -> Void = Log.trace;

		// Override Haxe's vanilla trace() calls to use the Flixel console.
		Log.trace = (data:Any, ?info:PosInfos) ->
		{
			var paramArray:Array<Any> = [data];

			if (info != null)
			{
				if (info.customParams != null)
				{
					for (param in info.customParams)
					{
						paramArray.push(param);
					}
				}
			}

			logTrace(paramArray, info);
		};

		// Start the log file writer.
		// We have to set it to TRACE for now.
		// We also set the log file writer's trace() calls to be directed to the original trace() function.
		logFileWriter = new DebugLogWriter('TRACE', traceFunction);

		logInfo('Debug logging initialized. Hello, developer.');

		#if debug
		logInfo('This is a DEBUG build.');
		#else
		logInfo('This is a RELEASE build.');
		#end
		logInfo('HaxeFlixel version: ${Std.string(FlxG.VERSION)}');
		logInfo('Friday Night Funkin\' version: ${Lib.application.meta.get('version')}');
		logInfo('Psych Engine version: ${EngineData.ENGINE_VERSION}');
	}

	/**
	 * The game runs this function when it starts, but after Flixel is initialized.
	 */
	public static function onGameStart():Void
	{
		// Add the mouse position to the debug Watch window.
		FlxG.watch.addMouse();

		defineTrackerProfiles();
		defineConsoleCommands();

		// Now we can remember the log level.
		if (EngineData.save.data.debugLogLevel == null)
			EngineData.save.data.debugLogLevel = 'TRACE';

		logFileWriter.setLogLevel(EngineData.save.data.debugLogLevel);
	}

	private static function writeToFlxGLog(data:Array<Any>, logStyle:LogStyle):Void
	{
		if (FlxG != null && FlxG.game != null && FlxG.log != null)
		{
			FlxG.log.advanced(data, logStyle);
		}
	}

	private static function writeToLogFile(data:Array<Any>, logLevel:String = 'TRACE'):Void
	{
		if (logFileWriter != null && logFileWriter.isActive())
		{
			logFileWriter.write(data, logLevel);
		}
	}

	/**
	 * Defines what properties will be displayed in tracker windows for all these classes.
	 */
	private static function defineTrackerProfiles():Void
	{
		// Example: This will display all the properties that FlxSprite does, along with curCharacter and barColor.
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Character, ['id', 'isPlayer', 'barColor'], [FlxSprite]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(HealthIcon, ['char', 'isPlayer', 'isOldIcon'], [FlxSprite]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Note, ['x', 'y', 'strumTime', 'mustPress', 'noteData', 'sustainLength'], []));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Song, ['id', 'scrollSpeed', 'player1', 'player2', 'gfVersion', 'noteSkin', 'stage'], []));
	}

	/**
	 * Defines some commands you can run in the console for easy use of important debugging functions.
	 * Feel free to add your own!
	 */
	private static inline function defineConsoleCommands():Void
	{
		// Example: This will display Boyfriend's sprite properties in a debug window.
		addConsoleCommand('trackBoyfriend', () ->
		{
			if (PlayState.instance == null)
			{
				Debug.logWarn('CONSOLE: PlayState.instance is null!');
			}
			else
			{
				Debug.logInfo('CONSOLE: Begin tracking Boyfriend...');
				trackObject(PlayState.instance.boyfriend);
			}
		});
		addConsoleCommand('trackGirlfriend', () ->
		{
			if (PlayState.instance == null)
			{
				Debug.logWarn('CONSOLE: PlayState.instance is null!');
			}
			else
			{
				Debug.logInfo('CONSOLE: Begin tracking Girlfriend...');
				trackObject(PlayState.instance.gf);
			}
		});
		addConsoleCommand('trackOpponent', () ->
		{
			if (PlayState.instance == null)
			{
				Debug.logWarn('CONSOLE: PlayState.instance is null!');
			}
			else
			{
				Debug.logInfo('CONSOLE: Begin tracking Opponent...');
				trackObject(PlayState.instance.opponent);
			}
		});

		addConsoleCommand('setLogLevel', (logLevel:String) ->
		{
			if (DebugLogWriter.LOG_LEVELS.contains(logLevel))
			{
				Debug.logInfo('CONSOLE: Setting log level to $logLevel...');
				logFileWriter.setLogLevel(logLevel);
			}
			else
			{
				Debug.logWarn('CONSOLE: Invalid log level $logLevel!');
				Debug.logWarn('  Expected: ${DebugLogWriter.LOG_LEVELS.join(', ')}');
			}
		});

		// Console commands let you do WHATEVER you want.
		addConsoleCommand('playSong', (songName:String, difficulty:Int = 1) ->
		{
			Debug.logInfo('CONSOLE: Opening song $songName ($difficulty) in Free Play...');
			// TODO Reimplement these commands (Note: This might be hard, because these relied on the fact that Kade Engine preloaded every song JSON, which would be really laggy)
			// FreeplayState.loadSongInFreePlay(songName, difficulty, false);
		});
		addConsoleCommand('chartSong', (songName:String, difficulty:Int = 1) ->
		{
			Debug.logInfo('CONSOLE: Opening song $songName ($difficulty) in Chart Editor...');
			// FreeplayState.loadSongInFreePlay(songName, difficulty, true, true);
		});
	}

	private static function formatOutput(input:Any, pos:PosInfos):Array<Any>
	{
		// This code is junk but I kept getting Null Function References.
		var inArray:Array<Any>;
		if (input == null)
		{
			inArray = ['<NULL>'];
		}
		else if (Std.isOfType(input, Array))
		{
			inArray = input;
		}
		else
		{
			inArray = [input];
		}

		if (pos == null)
			return inArray;

		// Format the position ourselves.
		var output:Array<Any> = ['(${pos.className}/${pos.methodName}#${pos.lineNumber}): '];

		return output.concat(inArray);
	}
}

class DebugLogWriter
{
	private static final LOG_FOLDER:String = 'logs';
	public static final LOG_LEVELS:Array<String> = ['ERROR', 'WARN', 'INFO', 'TRACE'];

	public var traceFunction:(v:Any, ?infos:PosInfos) -> Void;

	/**
	 * Set this to the current timestamp that the game started.
	 */
	private var startTime:Float = 0;

	private var logLevel:Int;

	private var active:Bool = false;
	#if sys
	private var file:FileOutput;
	#end

	public function new(logLevelParam:String, traceFunction:(v:Any, ?infos:PosInfos) -> Void)
	{
		logLevel = LOG_LEVELS.indexOf(logLevelParam);
		this.traceFunction = traceFunction;

		#if sys
		printDebug('Initializing log file...');

		var logFilePath:String = Path.join([LOG_FOLDER, Path.withExtension(Std.string(getTime(true)), 'log')]);

		// Make sure that the path exists
		if (logFilePath.contains('/'))
		{
			var lastIndex:Int = logFilePath.lastIndexOf('/');
			var logFolderPath:String = logFilePath.substr(0, lastIndex);
			printDebug('Creating log folder $logFolderPath');
			FileSystem.createDirectory(logFolderPath);
		}
		// Open the file
		printDebug('Creating log file $logFilePath');
		file = File.write(logFilePath, false);
		active = true;
		#else
		printDebug('Won\'t create log file; no file system access.');
		active = true;
		#end

		// Get the absolute time in seconds. This lets us show relative time in log, which is more readable.
		startTime = getTime(true);
	}

	public function isActive():Bool
	{
		return active;
	}

	/**
	 * Get the time in seconds.
	 * @param abs Whether the timestamp is absolute or relative to the start time.
	 */
	public inline function getTime(abs:Bool = false):Float
	{
		#if sys
		// Use this one on CPP and Neko since it's more accurate.
		return abs ? Sys.time() : (Sys.time() - startTime);
		#else
		// This one is more accurate on non-CPP platforms.
		return abs ? Date.now().getTime() : (Date.now().getTime() - startTime);
		#end
	}

	private function shouldLog(input:String):Bool
	{
		var levelIndex:Int = LOG_LEVELS.indexOf(input);
		// Could not find this log level.
		if (levelIndex == -1)
			return false;
		return levelIndex <= logLevel;
	}

	public function setLogLevel(input:String):Void
	{
		var levelIndex:Int = LOG_LEVELS.indexOf(input);
		// Could not find this log level.
		if (levelIndex == -1)
			return;

		logLevel = levelIndex;
		EngineData.save.data.debugLogLevel = logLevel;
	}

	/**
	 * Output text to the log file.
	 */
	public function write(input:Array<Any>, logLevel:String = 'TRACE'):Void
	{
		var ts:String = FlxStringUtil.formatTime(getTime(), true);
		var msg:String = '$ts [${logLevel.rpad(' ', 5)}] ${input.join('')}';

		#if sys
		if (active && file != null)
		{
			if (shouldLog(logLevel))
			{
				file.writeString('$msg\n');
				file.flush();
				file.flush();
			}
		}
		#end

		// Output text to the debug console directly.
		if (shouldLog(logLevel))
		{
			printDebug(msg);
		}
	}

	private function printDebug(msg:String):Void
	{
		// Pass no argument for the PosInfos to exclude the position.
		traceFunction(msg);
	}
}
