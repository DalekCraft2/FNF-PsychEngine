package;

import Song.SongData;

/**
 * @author
 */
typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
}

class Conductor
{
	public static var bpm:Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var lastSongPos:Float;
	public static var offset:Float = 0;

	// safeFrames in milliseconds
	// Must be initialized in a method, otherwise it will try to use Options.save before it is loaded and cause an NPE
	public static var safeZoneOffset:Float;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	public static function initializeSafeZoneOffset():Void
	{
		safeZoneOffset = (Options.save.data.safeFrames / 60) * 1000;
	}

	public static function judgeNote(note:Note,
			diff:Float = 0):String // STOLEN FROM KADE ENGINE (bbpanzu) - I had to rewrite it later anyway after i added the custom hit windows lmao (Shadow Mario)
	{
		// tryna do MS based judgment due to popular demand
		var timingWindows:Array<Int> = [
			Options.save.data.sickWindow,
			Options.save.data.goodWindow,
			Options.save.data.badWindow
		];
		var windowNames:Array<String> = ['sick', 'good', 'bad'];

		for (i in 0...timingWindows.length) // based on 4 timing windows, will break with anything else
		{
			if (diff <= timingWindows[Math.round(Math.min(i, timingWindows.length - 1))])
			{
				return windowNames[i];
			}
		}
		return 'shit';
	}

	public static function mapBPMChanges(song:SongData):Void
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (section in song.notes)
		{
			if (section.changeBPM && section.bpm != curBPM)
			{
				curBPM = section.bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = section.lengthInSteps;
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
		// Debug.logTrace('Created BPM map: $bpmChangeMap');
	}

	public static function changeBPM(newBpm:Float):Void
	{
		bpm = newBpm;

		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / 4;
	}
}
