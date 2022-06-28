package compat.chart;

using StringTools;

class KadeChartParser
{
	public static function convertToMock(song:KadeSong):Song // Convert old charts to newest format
	{
		updateFormat(song);

		var mockSong:Song = cast song;

		if (song.eventObjects != null)
		{
			for (i in song.eventObjects)
			{
				if (i.type == 'BPM Change')
				{
					i.type = 'Change BPM';
				}

				var strumTime:Float = TimingStruct.getTimeFromBeat(i.position); // I added this part to convert the beat positioning to strum positioning

				mockSong.events.push({strumTime: strumTime, beat: i.position, events: [{type: i.type, value1: i.value}]});
			}
		}

		Reflect.deleteField(mockSong, 'eventObjects');
		Reflect.deleteField(mockSong, 'noteStyle');

		return mockSong;
	}

	public static function updateFormat(song:KadeSong):KadeSong // Convert old charts to newest format
	{
		if (song != null)
		{
			if (song.eventObjects == null)
				song.eventObjects = [
					{
						name: 'Init BPM',
						position: 0,
						value: song.bpm,
						type: 'BPM Change'
					}
				];

			// if (song.noteStyle == null)
			// 	song.noteStyle = 'normal';

			// Redundant because of the defaults in Song.updateFormat()
			// if (song.gfVersion == null)
			// 	song.gfVersion = 'gf';

			TimingStruct.clearTimings();

			var currentIndex:Int = 0;
			for (i in song.eventObjects)
			{
				if (i.type == 'BPM Change')
				{
					var beat:Float = i.position;

					var endBeat:Float = Math.POSITIVE_INFINITY;

					TimingStruct.addTiming(beat, i.value, endBeat, 0); // offset in this case = start time since we don't have a offset

					if (currentIndex != 0)
					{
						var data:TimingStruct = TimingStruct.allTimings[currentIndex - 1];
						data.endBeat = beat;
						data.length = (data.endBeat - data.startBeat) / (data.bpm / TimingConstants.SECONDS_PER_MINUTE);
						var step:Float = Conductor.calculateSemiquaverLength(data.bpm);
						TimingStruct.allTimings[currentIndex].startStep = Math.floor(((data.endBeat / (data.bpm / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / step);
						TimingStruct.allTimings[currentIndex].startTime = data.startTime + data.length;
					}

					currentIndex++;
				}
			}

			var ba:Float = song.bpm;

			var index:Int = 0;
			for (section in song.notes)
			{
				// if (section.altAnim)
				// 	section.CPUAltAnim = section.altAnim;

				var currentBeat:Int = index * Conductor.CROTCHETS_PER_MEASURE;

				var currentSeg:TimingStruct = TimingStruct.getTimingAtBeat(currentBeat);

				if (currentSeg == null)
					continue;

				var beat:Float = currentSeg.startBeat + (currentBeat - currentSeg.startBeat);

				if (section.changeBPM && section.bpm != ba)
				{
					ba = section.bpm;
					song.eventObjects.push({
						name: 'FNF BPM Change $index',
						position: beat,
						value: section.bpm,
						type: 'BPM Change'
					});
				}

				/*
					for (note in section.sectionNotes)
					{
						if (song.chartVersion == null)
						{
							note.isAlt = false;
							note.beat = TimingStruct.getBeatFromTime(note.strumTime);
						}

						if (note.isAlt == 0)
							note.isAlt == false;
					}
				 */

				index++;
			}

			// song.chartVersion = LATEST_CHART;
		}

		return song;
	}
}

typedef KadeSongWrapper =
{
	var song:KadeSong;
}

typedef KadeSong =
{
	@:deprecated
	var song:String;

	/**
	 * The readable name of the song, as displayed to the user.
	 		* Can be any string.
	 */
	var songName:String;

	/**
	 * The internal name of the song, as used in the file system.
	 */
	var songId:String;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var noteStyle:String;
	var bpm:Float;
	var speed:Float;
	var needsVoices:Bool;
	var validScore:Bool;
	var notes:Array<KadeSection>;
	var eventObjects:Array<KadeEvent>;
	var offset:Int;
	var chartVersion:String;
}

typedef KadeSection =
{
	var startTime:Float;
	var endTime:Float;
	var sectionNotes:Array<KadeNote>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	var CPUAltAnim:Bool;
	var playerAltAnim:Bool;
}

abstract KadeNote(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_NOTE_DATA:Int = 1;
	public static inline final INDEX_SUSTAIN_LENGTH:Int = 2;
	public static inline final INDEX_ALT:Int = 3;
	public static inline final INDEX_BEAT:Int = 4;

	public var strumTime(get, set):Float;
	public var noteData(get, set):Int;
	public var sustainLength(get, set):Null<Float>;
	public var isAlt(get, set):Null<Bool>;
	public var beat(get, set):Null<Float>;

	public inline function new(array:Array<Dynamic>)
	{
		this = array;
	}

	private function get_strumTime():Float
	{
		return this[INDEX_STRUM_TIME];
	}

	private function set_strumTime(value:Float):Float
	{
		return this[INDEX_STRUM_TIME] = value;
	}

	private function get_noteData():Int
	{
		return this[INDEX_NOTE_DATA];
	}

	private function set_noteData(value:Int):Int
	{
		return this[INDEX_NOTE_DATA] = value;
	}

	private function get_sustainLength():Null<Float>
	{
		return this[INDEX_SUSTAIN_LENGTH];
	}

	private function set_sustainLength(value:Null<Float>):Null<Float>
	{
		return this[INDEX_SUSTAIN_LENGTH] = value;
	}

	private function get_isAlt():Null<Bool>
	{
		return this[INDEX_ALT];
	}

	private function set_isAlt(value:Null<Bool>):Null<Bool>
	{
		return this[INDEX_ALT] = value;
	}

	private function get_beat():Null<Float>
	{
		return this[INDEX_BEAT];
	}

	private function set_beat(value:Null<Float>):Null<Float>
	{
		return this[INDEX_BEAT] = value;
	}
}

// class KadeEvent
// {
// 	public var name:String;
// 	public var position:Float;
// 	public var value:Float;
// 	public var type:String;
// 	public function new(name:String, pos:Float, value:Float, type:String)
// 	{
// 		this.name = name;
// 		this.position = pos;
// 		this.value = value;
// 		this.type = type;
// 	}
// }

typedef KadeEvent =
{
	var name:String;
	var position:Float;
	var value:Float;
	var type:String;
}
