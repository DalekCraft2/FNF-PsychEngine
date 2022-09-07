package funkin.sm;

import flixel.util.FlxArrayUtil;
import flixel.math.FlxMath;
import funkin.chart.io.KadeChart;

#if FEATURE_STEPMANIA
class SMHeader
{
	private var _header:Array<String>;

	public var TITLE:String = "";
	public var SUBTITLE:String = "";
	public var ARTIST:String = "";
	public var GENRE:String = "";
	public var CREDIT:String = "";
	public var MUSIC:String = "";
	public var BANNER:String = "";
	public var BACKGROUND:String = "";
	public var CDTITLE:String = "";
	public var OFFSET:String = "";
	public var BPMS:String = ""; // time=bpm

	public var changeEvents:Array<KadeEvent> = [];

	public var timings:Array<TimingSegment> = [];

	public function new(headerData:Array<String>)
	{
		_header = headerData;

		for (i in headerData)
		{
			readHeaderLine(i);
		}

		MUSIC = StringTools.replace(MUSIC, " ", "_");

		getBPM(0, true);
	}

	public function getBeatFromBPMIndex(index:Int):Float
	{
		var bpmSplit:Array<String> = BPMS.split(',');
		for (ii in 0...bpmSplit.length)
		{
			if (ii == index)
				return Std.parseFloat(StringTools.replace(bpmSplit[ii].split('=')[0], ",", ""));
		}
		return 0.0;
	}

	public function getBPM(beat:Float, printAllBpms:Bool = false):Float
	{
		var bpmSplit:Array<String> = BPMS.split(',');
		if (printAllBpms)
		{
			FlxArrayUtil.clearArray(timings);
			var currentIndex:Int = 0;
			for (i in bpmSplit)
			{
				var bpm:Float = Std.parseFloat(i.split('=')[1]);
				var beat:Float = Std.parseFloat(StringTools.replace(i.split('=')[0], ",", ""));

				var endBeat:Float = Math.POSITIVE_INFINITY;

				timings.push(new TimingSegment(beat, bpm, endBeat, -Std.parseFloat(OFFSET)));

				if (changeEvents.length != 0)
				{
					var data:TimingSegment = timings[currentIndex - 1];
					data.endBeat = beat;
					data.length = (data.endBeat - data.startBeat) / (data.tempo / TimingConstants.SECONDS_PER_MINUTE);
					var step:Float = ((TimingConstants.SECONDS_PER_MINUTE / data.tempo) * TimingConstants.MILLISECONDS_PER_SECOND) / Conductor.STEPS_PER_BEAT;
					timings[currentIndex].startStep = Math.floor(((data.endBeat / (data.tempo / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / step);
					timings[currentIndex].startTime = data.startTime + data.length;
				}

				changeEvents.push({
					name: FlxMath.roundDecimal(beat, 0) + "SM",
					position: beat,
					value: bpm,
					type: KadeChart.TEMPO_CHANGE_EVENT
				});

				if (bpmSplit.length == 1)
					break;
				currentIndex++;
			}

			return 0.0;
		}
		var returningBPM:Float = Std.parseFloat(bpmSplit[0].split('=')[1]);
		for (i in bpmSplit)
		{
			var bpm:Float = Std.parseFloat(i.split('=')[1]);
			var beatt:Float = Std.parseFloat(StringTools.replace(i.split('=')[0], ",", ""));
			if (beatt <= beat)
				returningBPM = bpm;
		}
		return returningBPM;
	}

	private function readHeaderLine(line:String):Void
	{
		var propName:String = line.split('#')[1].split(':')[0];
		var value:String = line.split(':')[1].split(';')[0];
		var prop:Any = Reflect.getProperty(this, propName);

		if (prop != null)
		{
			Reflect.setProperty(this, propName, value);
		}
	}
}
#end
