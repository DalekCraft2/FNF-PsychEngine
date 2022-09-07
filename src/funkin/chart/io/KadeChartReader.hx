package funkin.chart.io;

import funkin.chart.container.Bar;
import funkin.chart.container.BasicNote;
import funkin.chart.container.Song;
import funkin.chart.io.KadeChart;

using StringTools;

class KadeChartReader implements ChartReader
{
	private final songDef:KadeSong;

	public function new(songDef:KadeSong)
	{
		this.songDef = songDef;
	}

	public function read():Song
	{
		var song:Song = new Song();
		if (songDef.player1 != null)
			song.player1 = songDef.player1;
		if (songDef.player2 != null)
			song.player2 = songDef.player2;
		if (songDef.gfVersion != null)
			song.gfVersion = songDef.gfVersion;
		if (songDef.stage != null)
			song.stage = songDef.stage;
		// if (songDef.bpm != null)
		song.tempo = songDef.bpm;
		// if (songDef.speed != null)
		song.scrollSpeed = songDef.speed;
		// if (songDef.needsVoices != null)
		song.needsVoices = songDef.needsVoices;
		// if (songDef.validScore != null)
		song.validScore = songDef.validScore;

		song.addTiming(0, song.tempo, Math.POSITIVE_INFINITY, 0);
		for (eventObject in songDef.eventObjects)
		{
			if (eventObject.type == KadeChart.TEMPO_CHANGE_EVENT)
			{
				var startBeat:Float = eventObject.position;
				var endBeat:Float = Math.POSITIVE_INFINITY;
				var previousSeg:TimingSegment = song.timings[song.timings.length - 1];
				var currentSeg:TimingSegment = song.addTiming(startBeat, eventObject.value, endBeat,
					0); // offset in this case = start time since we don't have a offset
				previousSeg.endBeat = startBeat;
				previousSeg.length = (previousSeg.endBeat - previousSeg.startBeat) / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE);
				var stepLength:Float = Conductor.calculateStepLength(previousSeg.tempo);
				currentSeg.startStep = Math.floor(((previousSeg.endBeat / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / stepLength);
				currentSeg.startTime = previousSeg.startTime + previousSeg.length;
			}
		}

		for (sectionDef in songDef.notes)
		{
			var bar:Bar = new Bar();
			var notes:Array<BasicNote> = [];
			for (noteDef in sectionDef.sectionNotes)
			{
				var beat:Float = song.getBeatFromTime(noteDef.strumTime);
				var sustainLength:Float = song.getBeatFromTime(noteDef.strumTime + noteDef.sustainLength) - beat;
				notes.push(new BasicNote(noteDef.data, sustainLength, noteDef.isAlt ? 'Alt Animation' : null, beat));
			}
			bar.notes = notes;
			bar.lengthInSteps = sectionDef.lengthInSteps;
			bar.mustHit = sectionDef.mustHitSection;
			bar.altAnim = sectionDef.altAnim || sectionDef.CPUAltAnim;

			song.bars.push(bar);
		}

		if (songDef.eventObjects != null)
		{
			for (eventObject in songDef.eventObjects)
			{
				if (eventObject.type == KadeChart.TEMPO_CHANGE_EVENT)
				{
					eventObject.type = 'Change Tempo';
				}

				song.events.push({beat: eventObject.position, events: [{type: eventObject.type, args: [eventObject.value]}]});
			}
		}

		return song;
	}
}
