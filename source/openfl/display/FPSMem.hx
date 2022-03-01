package openfl.display;

import haxe.Timer;
import openfl.display.Bitmap;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end
#if flash
import openfl.events.Event;
#end
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;
import options.Options.OptionUtils;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPSMem extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	public var currentMem:Float;

	public var highestMem:Float;

	// public var bitmap:Bitmap;
	public static var showFPS:Bool = true;
	public static var showMem:Bool = true;
	public static var showMemPeak:Bool = true;

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;

	var lastUpdate:Float = 0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		// defaultTextFormat = new TextFormat(Paths.font("vcr.ttf"), 12, color);
		defaultTextFormat = new TextFormat("_sans", 14, color);
		width = 1280;
		height = 720;

		text = "FPS: ";

		cacheCount = 0;
		currentTime = 0;
		highestMem = 0;
		times = [];

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e)
		{
			__enterFrame(Timer.stamp() - lastUpdate);
		});
		#end

		// bitmap = ImageOutline.renderImage(this, 1, 0x000000, 1, true);
		// (cast(Lib.current.getChildAt(0), Main)).addChild(bitmap);
	}

	// Event Handlers
	@:noCompletion
	private #if !flash override #end function __enterFrame(d:Float):Void
	{
		currentTime = Timer.stamp();
		lastUpdate = currentTime;
		times.push(currentTime);
		while (times[0] < currentTime - 1)
			times.shift();

		var currentCount = times.length;
		currentFPS = currentCount;
		currentMem = Math.abs(Math.round(System.totalMemory / (1e+6)));

		if (currentMem > highestMem)
			highestMem = currentMem;
		if (currentCount != cacheCount /*&& visible*/)
		{
			text = "";
			if (showFPS)
				text += "FPS: " + currentFPS + "\n";
			if (showMem)
			{
				if (currentMem < 0)
				{
					text += "Memory: Leaking " + Math.abs(currentMem) + " MB\n";
				}
				else
				{
					text += "Memory: " + currentMem + " MB\n";
				}
			}
			if (showMemPeak)
				text += "Mem Peak: " + highestMem + " MB\n";

			textColor = 0xFFFFFFFF;
			if (currentMem > 3000 || currentFPS <= OptionUtils.options.framerate / 2)
			{
				textColor = 0xFFFF0000;
			}
		}

		// visible = true;

		// Main.instance.removeChild(bitmap);

		// bitmap = ImageOutline.renderImage(this, 2, 0x000000, 1);

		// Main.instance.addChild(bitmap);

		// visible = false;

		cacheCount = currentCount;
	}
}
