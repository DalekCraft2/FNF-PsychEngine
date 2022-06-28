package compat.chart;

import Event.EventGroup;

class ChartParser
{
	public static function convertToMock(song:Dynamic):Song
	{
		song = KadeChartParser.convertToMock(song); // This is for doing the BPM event creation. I'll clean up this later.

		var chartFormat:ChartFormat = getChartFormat(song);
		Debug.logTrace('Format: $chartFormat');
		switch (chartFormat)
		{
			case MOCK:
				return song;
			case KADE:
				// return KadeChartParser.convertToMock(song);
				return song;
			case MYTH:
				// return KadeChartParser.convertToMock(song);
				return song;
			case PSYCH:
				// song = KadeChartParser.convertToMock(song);
				return PsychChartParser.convertToMock(song);
			case VANILLA:
				// return KadeChartParser.convertToMock(song);
				return song;
			case UNKNOWN:
				// return KadeChartParser.convertToMock(song);
				return song;
		}

		return song;
	}

	public static function getChartFormat(song:Dynamic):ChartFormat
	{
		switch (song.chartVersion)
		{
			case "MOCK 1.0":
				return MOCK;
			case "KE1":
				return KADE;
			case "MYTH 1.0":
				return MYTH;
			default: // Please, guys, put a chartVersion tag in your chart JSONs.
				// Some Psych-exclusive JSON tags:
				if (/*Reflect.hasField(song, 'stage') || Reflect.hasField(song, 'gfVersion') ||*/ Reflect.hasField(song, 'player3')
					|| Reflect.hasField(song, 'arrowSkin') || Reflect.hasField(song, 'splashSkin'))
				{
					return PSYCH;
				}

				if (song.song != null && song.notes != null && song.bpm != null && song.speed != null && song.player1 != null && song.player2 != null)
				{
					return VANILLA;
				}

				return UNKNOWN;
		}
	}
	/*
		public static function updateFormat(song:Song):Array<EventGroup> // Convert old charts to newest format
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

			TimingStruct.clearTimings();

			var currentIndex:Int = 0;
			for (eventObject in song.eventObjects)
			{
				if (eventObject.type == 'BPM Change')
				{
					var beat:Float = eventObject.position;

					var endBeat:Float = Math.POSITIVE_INFINITY;

					TimingStruct.addTiming(beat, eventObject.value, endBeat, 0); // offset in this case = start time since we don't have a offset

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
				if (section.altAnim)
					section.CPUAltAnim = section.altAnim;

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

				for (note in section.sectionNotes)
				{
					if (song.chartVersion == null)
					{
						note.beat = TimingStruct.getBeatFromTime(note.strumTime);
					}
				}

				index++;
			}

			return song;
		}
	 */
}

enum ChartFormat
{
	MOCK;
	PSYCH;
	KADE;
	MYTH;
	VANILLA;
	UNKNOWN;
}
