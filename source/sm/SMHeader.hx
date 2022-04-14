package sm;

using StringTools;

#if FEATURE_STEPMANIA
class SMHeader
{
	private var _header:Array<String>;

	public var TITLE:String = '';
	public var SUBTITLE:String = '';
	public var ARTIST:String = '';
	public var GENRE:String = '';
	public var CREDIT:String = '';
	public var MUSIC:String = '';
	public var BANNER:String = '';
	public var BACKGROUND:String = '';
	public var CDTITLE:String = '';
	public var OFFSET:String = '';
	public var BPMS:String = ''; // time=bpm

	// public var changeEvents:Array<Song.Event>;
	public var changeEvents:Array<Array<Dynamic>>;

	public function new(headerData:Array<String>)
	{
		_header = headerData;

		for (i in headerData)
		{
			readHeaderLine(i);
		}

		Debug.logTrace(BPMS);

		MUSIC = MUSIC.replace(' ', '_');

		changeEvents = [];

		getBPM(0, true);
	}

	public function getBeatFromBPMIndex(index):Float
	{
		var bpmSplit:Array<String> = BPMS.split(',');
		for (ii in 0...bpmSplit.length)
		{
			if (ii == index)
				return Std.parseFloat(bpmSplit[ii].split('=')[0].replace(',', ''));
		}
		return 0.0;
	}

	public function getBPM(beat:Float, printAllBpms:Bool = false):Float
	{
		var bpmSplit:Array<String> = BPMS.split(',');
		if (printAllBpms)
		{
			TimingStruct.clearTimings();
			var currentIndex:Int = 0;
			for (i in bpmSplit)
			{
				var bpm:Float = Std.parseFloat(i.split('=')[1]);
				var beat:Float = Std.parseFloat(i.split('=')[0].replace(',', ''));

				var endBeat:Float = Math.POSITIVE_INFINITY;

				TimingStruct.addTiming(beat, bpm, endBeat, -Std.parseFloat(OFFSET));

				if (changeEvents.length != 0)
				{
					var data:TimingStruct = TimingStruct.allTimings[currentIndex - 1];
					data.endBeat = beat;
					data.length = (data.endBeat - data.startBeat) / (data.bpm / 60);
					var step:Float = ((60 / data.bpm) * 1000) / 4;
					TimingStruct.allTimings[currentIndex].startStep = Math.floor(((data.endBeat / (data.bpm / 60)) * 1000) / step);
					TimingStruct.allTimings[currentIndex].startTime = data.startTime + data.length;
				}

				// TODO Maybe make an Event object so it's easier to do stuff like this
				// changeEvents.push(new Song.Event('${FlxMath.roundDecimal(beat, 0)}SM', beat, bpm, 'BPM Change'));

				if (bpmSplit.length == 1)
					break;
				currentIndex++;
			}

			Debug.logTrace('${changeEvents.length} - BPM CHANGES');
			return 0.0;
		}
		var returningBPM:Float = Std.parseFloat(bpmSplit[0].split('=')[1]);
		for (i in bpmSplit)
		{
			var bpm:Float = Std.parseFloat(i.split('=')[1]);
			var beatt:Float = Std.parseFloat(i.split('=')[0].replace(',', ''));
			if (beatt <= beat)
				returningBPM = bpm;
		}
		return returningBPM;
	}

	private function readHeaderLine(line:String):Void
	{
		var propName:String = line.split('#')[1].split(':')[0];
		var value:String = line.split(':')[1].split(';')[0];
		var prop:Dynamic = Reflect.getProperty(this, propName);

		if (prop != null)
		{
			Reflect.setProperty(this, propName, value);
		}
	}
}
#end
