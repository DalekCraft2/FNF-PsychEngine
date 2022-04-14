package sm;

import Section.SectionData;
import Song.SongData;
import Song.SongWrapper;
import haxe.Exception;
import haxe.Json;
import lime.app.Application;

using StringTools;

#if sys
import sys.io.File;
#end

#if FEATURE_STEPMANIA
class SMFile
{
	public static function loadFile(path):SMFile
	{
		return new SMFile(Paths.getTextDirect(path).split('\n'));
	}

	private var _fileData:Array<String>;

	public var isDouble:Bool = false;

	public var isValid:Bool = true;

	public var _readTime:Float = 0;

	public var header:SMHeader;
	public var measures:Array<SMMeasure>;

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
				// Debug.logTrace(data[inc]);
			}

			header = new SMHeader(headerData.split(';'));

			if (_fileData.toString().split('#NOTES').length > 2)
			{
				Application.current.window.alert('The chart must only have 1 difficulty, this one has ${(_fileData.toString().split('#NOTES').length - 1)}',
					'SM File loading (${header.TITLE})');
				isValid = false;
				return;
			}

			if (!header.MUSIC.toLowerCase().contains('ogg'))
			{
				Application.current.window.alert('The music MUST be an OGG File, make sure the sm file has the right music property.',
					'SM File loading (${header.TITLE})');
				isValid = false;
				return;
			}

			// check if this is a valid file, it should be a dance double file.
			inc += 3; // skip three lines down
			if (!data[inc].contains('dance-double:') && !data[inc].contains('dance-single'))
			{
				Application.current.window.alert('The file you are loading is neither a Dance Double chart or a Dance Single chart',
					'SM File loading (${header.TITLE})');
				isValid = false;
				return;
			}
			if (data[inc].contains('dance-double:'))
				isDouble = true;
			if (isDouble)
				Debug.logTrace('this is dance double');

			inc += 5; // skip 5 down to where da notes @

			measures = [];

			var measure:String = '';

			Debug.logTrace(data[inc - 1]);

			for (ii in inc...data.length)
			{
				var i:String = data[ii];
				if (i.contains(',') || i.contains(';'))
				{
					measures.push(new SMMeasure(measure.split('\n')));
					// Debug.logTrace(measures.length);
					measure = '';
					continue;
				}
				measure += '$i\n';
			}
			Debug.logTrace('${measures.length} Measures');
		}
		catch (e:Exception)
		{
			Application.current.window.alert('Failure to load file.\n$e', 'SM File loading');
		}
	}

	public function convertToFNF(saveTo:String):String
	{
		// array's for helds
		var heldNotes:Array<Array<Dynamic>>;

		if (isDouble) // held storage lanes
			heldNotes = [[], [], [], [], [], [], [], []];
		else
			heldNotes = [[], [], [], []];

		// variables

		var measureIndex:Int = 0;
		var currentBeat:Float = 0;

		// init a fnf song

		var song:SongData = {
			songId: Paths.formatToSongPath(header.TITLE),
			songName: header.TITLE,
			player1: 'bf',
			player2: 'gf',
			gfVersion: 'gf',
			stage: 'stage',
			bpm: header.getBPM(0),
			speed: 1.0,
			needsVoices: true,
			arrowSkin: '',
			splashSkin: 'noteSplashes',
			validScore: false,
			notes: [],
			events: []
		};

		// lets check if the sm loading was valid

		if (!isValid)
		{
			var json:SongWrapper = {
				song: song
			};

			var data:String = Json.stringify(json, '\t');
			File.saveContent(saveTo, data);
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

			var section:SectionData = {
				sectionNotes: [],
				lengthInSteps: 16,
				typeOfSection: 0,
				mustHitSection: false,
				gfSection: false,
				bpm: header.getBPM(0),
				changeBPM: false,
				altAnim: false
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
						mustHitSection: false,
						gfSection: false,
						bpm: header.getBPM(0),
						changeBPM: false,
						altAnim: false
					};
					if (!isDouble)
						section.mustHitSection = true;
				}

				var seg:TimingStruct = TimingStruct.getTimingAtBeat(currentBeat);

				var timeInSec:Float = (seg.startTime + ((currentBeat - seg.startBeat) / (seg.bpm / 60)));

				var rowTime:Float = timeInSec * 1000;

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
							section.sectionNotes.push([rowTime, lane, 0, 0, currentBeat]);
						case 2: // held head
							heldNotes[lane] = [rowTime, lane, 0, 0, currentBeat];
						case 3: // held tail
							var data:Array<Dynamic> = heldNotes[lane];
							var timeDiff:Float = rowTime - data[0];
							section.sectionNotes.push([data[0], lane, timeDiff, 0, data[4]]);
							heldNotes[index] = [];
						case 4: // roll head
							heldNotes[lane] = [rowTime, lane, 0, 0, currentBeat];
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
			// TODO Figure out how to do this in Psych, or adapt Psych to be more like Kade (yet again)
			// var section:SectionData = song.notes[i];

			// var currentBeat:Int = 4 * i;

			// var currentSeg:TimingStruct = TimingStruct.getTimingAtBeat(currentBeat);

			// var start:Float = (currentBeat - currentSeg.startBeat) / (currentSeg.bpm / 60);

			// section.startTime = (currentSeg.startTime + start) * 1000;

			// if (i != 0)
			// 	song.notes[i - 1].endTime = section.startTime;
			// section.endTime = Math.POSITIVE_INFINITY;
		}

		if (header.changeEvents.length != 0)
		{
			song.events = header.changeEvents;
		}
		/*var newSections:Array<SectionData> = [];

			for(s in 0...song.notes.length) // lets go ahead and make sure each note is actually in their own section haha
			{
				var sec:SectionData = {
					startTime: song.notes[s].startTime,
					endTime: song.notes[s].endTime,
					lengthInSteps: 16,
					bpm: song.bpm,
					changeBPM: false,
					mustHitSection: song.notes[s].mustHitSection,
					sectionNotes: [],
					typeOfSection: 0,
					altAnim: song.notes[s].altAnim
				};
				for(i in song.notes)
				{
					for(ii in i.sectionNotes)
					{
						if (ii[0] >= sec.startTime && ii[0] < sec.endTime)
							sec.sectionNotes.push(ii);
					}
				}
				newSections.push(sec);
		}*/

		// WE ALREADY DO THIS

		// song.notes = newSections;

		// save da song

		// song.chartVersion = Song.latestChart;

		var json:SongWrapper = {
			song: song
		};

		var data:String = Json.stringify(json, '\t');
		File.saveContent(saveTo, data);
		return data;
	}
}
#end
