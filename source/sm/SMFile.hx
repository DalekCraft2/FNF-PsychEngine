package sm;

#if FEATURE_STEPMANIA
import chart.container.Bar;
import chart.container.BasicNote;
import chart.container.Song.SongWrapper;
import chart.container.Song;
import haxe.Exception;
import haxe.Json;

using StringTools;

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
			var headerData:String = '';
			var inc:Int = 0;
			while (!data[inc + 1].contains('//'))
			{
				headerData += data[inc];
				inc++;
			}

			header = new SMHeader(headerData.split(';'));

			if (_fileData.toString().split('#NOTES').length > 2)
			{
				Debug.displayAlert('The chart must only have 1 difficulty, this one has ${(_fileData.toString().split('#NOTES').length - 1)}',
					'SM File loading (${header.TITLE})');
				isValid = false;
				return;
			}

			if (!header.MUSIC.toLowerCase().contains('ogg'))
			{
				Debug.displayAlert('The music MUST be an OGG File, make sure the sm file has the right music property.', 'SM File loading (${header.TITLE})');
				isValid = false;
				return;
			}

			// check if this is a valid file, it should be a dance double file.
			inc += 3; // skip three lines down
			if (!data[inc].contains('dance-double:') && !data[inc].contains('dance-single'))
			{
				Debug.displayAlert('The file you are loading is neither a Dance Double chart or a Dance Single chart', 'SM File loading (${header.TITLE})');
				isValid = false;
				return;
			}
			if (data[inc].contains('dance-double:'))
				isDouble = true;
			if (isDouble)
				Debug.logTrace('this is dance double');

			inc += 5; // skip 5 down to where da notes @

			var measure:String = '';

			for (ii in inc...data.length)
			{
				var i:String = data[ii];
				if (i.contains(',') || i.contains(';'))
				{
					measures.push(new SMMeasure(measure.split('\n')));
					measure = '';
					continue;
				}
				measure += '$i\n';
			}
		}
		catch (e:Exception)
		{
			Debug.displayAlert('Failure to load file:\n$e', 'SM File loading');
		}
	}

	public function convertToFNF(saveTo:String):String
	{
		// array's for helds
		var heldNotes:Array<BasicNote>;

		if (isDouble) // held storage lanes
			heldNotes = [
				new BasicNote(),
				new BasicNote(),
				new BasicNote(),
				new BasicNote(),
				new BasicNote(),
				new BasicNote(),
				new BasicNote(),
				new BasicNote()
			];
		else
			heldNotes = [new BasicNote(), new BasicNote(), new BasicNote(), new BasicNote()];

		// variables

		var measureIndex:Int = 0;
		var currentBeat:Float = 0;

		// init a fnf song

		var song:Song = new Song();
		song.id = Paths.formatToSongPath(header.TITLE);
		song.name = header.TITLE;
		song.tempo = header.getBPM(0);
		song.validScore = false;
		song.chartVersion = Song.LATEST_CHART;

		// lets check if the sm loading was valid

		if (!isValid)
		{
			var json:SongWrapper = {
				song: Song.toSongDef(song)
			};

			var data:String = Json.stringify(json, Constants.JSON_SPACE);
			#if sys
			File.saveContent(saveTo, data);
			#end
			return data;
		}

		// aight time to convert da measures

		Debug.logTrace('Converting measures');

		for (measure in measures)
		{
			// private access since _measure is private
			@:privateAccess
			var lengthInRows:Float = 192 / (measure._measure.length - 1);

			var rowIndex:Int = 0;

			// section declaration

			var section:Bar = new Bar();
			section.bpm = header.getBPM(0);

			// if it's not a double always set this to true

			if (!isDouble)
				section.mustHit = true;

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

				if (currentBeat % Conductor.BEATS_PER_BAR == 0)
				{
					// ok new section time
					song.bars.push(section);
					section = new Bar();
					section.bpm = header.getBPM(0);
					if (!isDouble)
						section.mustHit = true;
				}

				var seg:TimingSegment = TimingSegment.getTimingAtBeat(currentBeat);

				var timeInSec:Float = (seg.startTime + ((currentBeat - seg.startBeat) / (seg.bpm / TimingConstants.SECONDS_PER_MINUTE)));

				var rowTime:Float = timeInSec * TimingConstants.MILLISECONDS_PER_SECOND;

				var index:Int = 0;

				for (i in notes)
				{
					// if its a mine lets skip (maybe add mines in the future??)
					if (i == 'M')
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
							section.notes.push(new NoteDef([rowTime, lane, 0, 0, currentBeat]));
						case 2: // held head
							heldNotes[lane] = new NoteDef([rowTime, lane, 0, 0, currentBeat]);
						case 3: // held tail
							var data:NoteDef = heldNotes[lane];
							var timeDiff:Float = rowTime - data.strumTime;
							section.notes.push(new NoteDef([data.strumTime, lane, timeDiff, 0 /*, data[4]*/]));
							heldNotes[index] = new NoteDef([]);
						case 4: // roll head
							heldNotes[lane] = new NoteDef([rowTime, lane, 0, 0, currentBeat]);
					}
					index++;
				}

				rowIndex++;
			}

			// push the section

			song.bars.push(section);

			measureIndex++;
		}

		song.recalculateAllBarTimes();

		if (header.changeEvents.length != 0)
		{
			for (headerEvent in header.changeEvents)
			{
				song.events.push({
					strumTime: headerEvent.strumTime,
					beat: headerEvent.beat,
					events: [
						{
							type: headerEvent.type,
							value1: headerEvent.value1,
							value2: headerEvent.value2
						}
					]
				});
			}
		}

		var json:SongWrapper = {
			song: Song.toSongDef(song)
		};

		var data:String = Json.stringify(json, Constants.JSON_SPACE);
		#if sys
		File.saveContent(saveTo, data);
		#end
		return data;
	}
}
#end
