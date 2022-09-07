package funkin.sm;

#if FEATURE_STEPMANIA
import funkin.chart.io.KadeChart;
import haxe.Exception;
import haxe.Json;
import openfl.Lib;
#if sys
import sys.io.File;
#end

class SMFile
{
	public static function loadFile(path:String):SMFile
	{
		return new SMFile(Paths.getTextDirect(path).split('\n'));
	}

	private var _fileData:Array<String>;

	public var isDouble:Bool = false;

	public var isValid:Bool = true;

	public var _readTime:Float = 0;

	public var header:SMHeader;
	public var measures:Array<SMMeasure> = [];

	public function new(data:Array<String>)
	{
		try
		{
			_fileData = data;

			// Gather header data
			var headerData:String = "";
			var inc:Int = 0;
			while (!StringTools.contains(data[inc + 1], "//"))
			{
				headerData += data[inc];
				inc++;
			}

			header = new SMHeader(headerData.split(';'));

			if (_fileData.toString().split("#NOTES").length > 2)
			{
				Lib.application.window.alert("The chart must only have 1 difficulty, this one has "
					+ (_fileData.toString().split("#NOTES").length - 1),
					"SM File loading ("
					+ header.TITLE
					+ ")");
				isValid = false;
				return;
			}

			if (!StringTools.contains(header.MUSIC.toLowerCase(), "ogg"))
			{
				Lib.application.window.alert("The music MUST be an OGG File, make sure the sm file has the right music property.",
					"SM File loading (" + header.TITLE + ")");
				isValid = false;
				return;
			}

			// check if this is a valid file, it should be a dance double file.
			inc += 3; // skip three lines down
			if (!StringTools.contains(data[inc], "dance-double:") && !StringTools.contains(data[inc], "dance-single"))
			{
				Lib.application.window.alert("The file you are loading is neither a Dance Double chart or a Dance Single chart",
					"SM File loading (" + header.TITLE + ")");
				isValid = false;
				return;
			}
			if (StringTools.contains(data[inc], "dance-double:"))
				isDouble = true;

			inc += 5; // skip 5 down to where da notes @

			var measure:String = "";

			for (ii in inc...data.length)
			{
				var i:String = data[ii];
				if (StringTools.contains(i, ",") || StringTools.contains(i, ";"))
				{
					measures.push(new SMMeasure(measure.split('\n')));
					measure = "";
					continue;
				}
				measure += i + "\n";
			}
		}
		catch (e:Exception)
		{
			Lib.application.window.alert("Failure to load file.\n" + e, "SM File loading");
		}
	}

	public function convertToFNF(saveTo:String):String
	{
		// array's for helds
		var heldNotes:Array<KadeNote>;

		if (isDouble) // held storage lanes
			heldNotes = [
				new KadeNote([]),
				new KadeNote([]),
				new KadeNote([]),
				new KadeNote([]),
				new KadeNote([]),
				new KadeNote([]),
				new KadeNote([]),
				new KadeNote([])
			];
		else
			heldNotes = [new KadeNote([]), new KadeNote([]), new KadeNote([]), new KadeNote([])];

		// variables

		var measureIndex:Int = 0;
		var currentBeat:Float = 0;

		// init a fnf song

		var song:KadeSong = {
			songId: Paths.formatToSongPath(header.TITLE),
			songName: header.TITLE,
			notes: [],
			eventObjects: [],
			bpm: header.getBPM(0),
			needsVoices: true,
			player1: 'bf',
			player2: 'gf',
			gfVersion: 'gf',
			noteStyle: 'normal',
			stage: 'stage',
			speed: 1.0,
			validScore: false,
			chartVersion: "",
		};

		#if sys
		// lets check if the sm loading was valid

		if (!isValid)
		{
			var json:KadeSongWrapper = {
				song: song
			};

			var data:String = Json.stringify(json, null, Constants.JSON_SPACE);
			File.saveContent(saveTo, data);
			return data;
		}
		#end

		// aight time to convert da measures

		for (measure in measures)
		{
			// private access since _measure is private
			@:privateAccess
			var lengthInRows:Float = 192 / (measure._measure.length - 1);

			var rowIndex:Int = 0;

			// section declaration

			var section:KadeSection = {
				sectionNotes: [],
				lengthInSteps: 16,
				typeOfSection: 0,
				startTime: 0.0,
				endTime: 0.0,
				mustHitSection: false,
				bpm: header.getBPM(0),
				changeBPM: false,
				altAnim: false,
				playerAltAnim: false,
				CPUAltAnim: false
			};

			// if it's not a double always set this to true

			if (!isDouble)
				section.mustHitSection = true;

			@:privateAccess
			for (i in 0...measure._measure.length - 1)
			{
				var noteRow:Float = (measureIndex * 192) + (lengthInRows * rowIndex);

				var notes:Array<String> = [];

				for (note in measure._measure[i].split(''))
				{
					notes.push(note);
				}

				currentBeat = noteRow / 48;

				if (currentBeat % 4 == 0)
				{
					// ok new section time
					song.notes.push(section);
					section = {
						sectionNotes: [],
						lengthInSteps: 16,
						typeOfSection: 0,
						startTime: 0.0,
						endTime: 0.0,
						mustHitSection: false,
						bpm: header.getBPM(0),
						changeBPM: false,
						altAnim: false,
						playerAltAnim: false,
						CPUAltAnim: false
					};
					if (!isDouble)
						section.mustHitSection = true;
				}

				var seg:TimingSegment = TimingSegment.getTimingAtBeat(header.timings, currentBeat);

				var timeInSec:Float = (seg.startTime + ((currentBeat - seg.startBeat) / (seg.tempo / TimingConstants.SECONDS_PER_MINUTE)));

				var rowTime:Float = timeInSec * TimingConstants.MILLISECONDS_PER_SECOND;

				var index:Int = 0;

				for (i in notes)
				{
					// if its a mine lets skip (maybe add mines in the future??)
					if (i == "M")
					{
						index++;
						continue;
					}

					// get the lane and note type
					var lane:Int = index;
					var numba:Int = Std.parseInt(i);

					// switch through the type and add the note

					switch (numba)
					{
						case 1: // normal
							section.sectionNotes.push(new KadeNote([rowTime, lane, 0, 0, currentBeat]));
						case 2: // held head
							heldNotes[lane] = new KadeNote([rowTime, lane, 0, 0, currentBeat]);
						case 3: // held tail
							var data:KadeNote = heldNotes[lane];
							var timeDiff:Float = rowTime - data.strumTime;
							section.sectionNotes.push(new KadeNote([data.strumTime, lane, timeDiff, 0, data.beat]));
							heldNotes[index] = new KadeNote([]);
						case 4: // roll head
							heldNotes[lane] = new KadeNote([rowTime, lane, 0, 0, currentBeat]);
					}
					index++;
				}

				rowIndex++;
			}

			// push the section

			song.notes.push(section);

			measureIndex++;
		}

		for (i in 0...song.notes.length) // loops through sections
		{
			var section:KadeSection = song.notes[i];

			var currentBeat:Float = Conductor.BEATS_PER_BAR * i;

			var currentSeg:TimingSegment = TimingSegment.getTimingAtBeat(header.timings, currentBeat);

			var start:Float = (currentBeat - currentSeg.startBeat) / (currentSeg.tempo / TimingConstants.SECONDS_PER_MINUTE);

			section.startTime = (currentSeg.startTime + start) * TimingConstants.MILLISECONDS_PER_SECOND;

			if (i != 0)
				song.notes[i - 1].endTime = section.startTime;
			section.endTime = Math.POSITIVE_INFINITY;
		}

		if (header.changeEvents.length != 0)
		{
			song.eventObjects = header.changeEvents;
		}

		// save da song

		song.chartVersion = KadeChart.LATEST_CHART;

		var json:KadeSongWrapper = {
			song: song
		};

		var data:String = Json.stringify(json, null, " ");
		File.saveContent(saveTo, data);
		return data;
	}
}
#end
