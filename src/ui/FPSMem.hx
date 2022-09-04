package ui;

import openfl.Lib;
import openfl.display.Bitmap;
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;
#if flash
import openfl.events.Event;
#end
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

/**
 * The FPS class provides an easy-to-use monitor to display
 * the current frame rate of an OpenFL project
 */
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPSMem extends TextField
{
	/**
	 * 	The current frame rate, expressed using frames-per-second
	 */
	public var currentFPS(default, null):Int;

	public var currentMem:Float;

	public var highestMem:Float = 0;

	public var bitmap:Bitmap;

	@:noCompletion private var cacheCount:Int = 0;
	@:noCompletion private var currentTime:Float = 0;
	@:noCompletion private var times:Array<Float> = [];

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat('_sans', 14, color);
		text = 'FPS: $currentFPS\n';
		width += 200;

		#if flash
		addEventListener(Event.ENTER_FRAME, (e:Event) ->
		{
			var time:Int = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end
	}

	// Event Handlers
	@:noCompletion
	#if !flash override #end private function __enterFrame(deltaTime:Float):Void
	{
		currentTime += deltaTime;
		times.push(currentTime);
		while (times[0] < currentTime - 1000)
			times.shift();

		var currentCount:Int = times.length;
		currentFPS = Math.round((currentCount + cacheCount) / 2);
		currentMem = Math.round(System.totalMemory / (1e+6));

		if (currentMem > highestMem)
			highestMem = currentMem;
		if (currentCount != cacheCount /*&& visible*/)
		{
			text = '';

			if (Options.save.data.showFPS)
				text += 'FPS: $currentFPS\n';

			if (Options.save.data.showMem)
			{
				if (currentMem < 0)
					text += 'RAM: Leaking ${Math.abs(currentMem)} MB\n';
				else
					text += 'RAM: $currentMem MB\n';
			}
			if (Options.save.data.showMemPeak)
				text += 'RAM Peak: $highestMem MB\n';

			textColor = 0xFFFFFF;
			if (currentMem > 3000 || currentFPS <= Options.save.data.frameRate / 2)
			{
				textColor = 0xFF0000;
			}

			#if (gl_stats && !disable_cffi && (!html5 || !canvas))
			text += 'totalDC: ${Context3DStats.totalDrawCalls()}\n';

			text += 'stageDC: ${Context3DStats.contextDrawCalls(DrawCallContext.STAGE)}\n';
			text += 'stage3DDC: ${Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D)}\n';
			#end
		}
		var main:Main = cast(Lib.current.getChildAt(0), Main);
		main.removeChild(bitmap);
		bitmap = ImageOutline.renderImage(this, 2, 0x000000, 1);
		bitmap.smoothing = true;
		main.addChild(bitmap);

		cacheCount = currentCount;
	}
}
