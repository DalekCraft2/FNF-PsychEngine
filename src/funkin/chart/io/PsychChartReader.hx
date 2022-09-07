package funkin.chart.io;

import funkin.chart.container.Bar;
import funkin.chart.container.BasicNote;
import funkin.chart.container.Event.EventEntry;
import funkin.chart.container.Event.EventGroup;
import funkin.chart.container.Song;
import funkin.chart.io.PsychChart;

using StringTools;

class PsychChartReader implements ChartReader
{
	private static final NOTE_TYPES:Array<String> = ['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation'];

	private final songDef:PsychSong;

	public function new(songDef:PsychSong)
	{
		this.songDef = songDef;
	}

	public function read():Song
	{
		updateFormat();

		var song:Song = new Song();
		if (songDef.player1 != null)
			song.player1 = songDef.player1;
		if (songDef.player2 != null)
			song.player2 = songDef.player2;
		if (songDef.gfVersion != null)
			song.gfVersion = songDef.gfVersion;
		if (songDef.stage != null)
			song.stage = songDef.stage;
		if (songDef.arrowSkin != null)
			song.noteSkin = songDef.arrowSkin;
		if (songDef.splashSkin != null)
			song.splashSkin = songDef.splashSkin;
		// if (songDef.bpm != null)
		song.tempo = songDef.bpm;
		// if (songDef.speed != null)
		song.scrollSpeed = songDef.speed;
		if (songDef.needsVoices != null)
			song.needsVoices = songDef.needsVoices;
		if (songDef.validScore != null)
			song.validScore = songDef.validScore;
		song.offset = songDef.offset;

		song.addTiming(0, song.tempo, Math.POSITIVE_INFINITY, 0);

		var startStep:Int = 0;
		var currentTempo:Float = song.tempo;
		for (sectionDef in songDef.notes)
		{
			var endStep:Int = startStep + sectionDef.lengthInSteps;

			var startBeat:Float = startStep / Conductor.STEPS_PER_BEAT;
			var endBeat:Float = endStep / Conductor.STEPS_PER_BEAT;

			var previousSeg:TimingSegment = song.getTimingAtBeat(startBeat);

			if (previousSeg == null)
				continue;

			if (sectionDef.changeBPM && sectionDef.bpm != currentTempo)
			{
				currentTempo = sectionDef.bpm;
				song.events.push({
					beat: startBeat,
					events: [
						{
							type: 'Change Tempo',
							args: [currentTempo]
						}
					]
				});

				var endBeat:Float = Math.POSITIVE_INFINITY;

				var currentSeg:TimingSegment = song.addTiming(startBeat, currentTempo, endBeat, 0);

				previousSeg.endBeat = startBeat;
				previousSeg.length = (previousSeg.endBeat - previousSeg.startBeat) / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE);
				var stepLength:Float = Conductor.calculateStepLength(previousSeg.tempo);
				currentSeg.startStep = Math.floor(((previousSeg.endBeat / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / stepLength);
				currentSeg.startTime = previousSeg.startTime + previousSeg.length;
			}

			var bar:Bar = new Bar();
			var notes:Array<BasicNote> = [];
			for (noteDef in sectionDef.sectionNotes)
			{
				var noteDef:PsychNote = noteDef;
				var beat:Float = song.getBeatFromTime(noteDef.strumTime);
				var sustainLength:Float = song.getBeatFromTime(noteDef.strumTime + noteDef.sustainLength) - beat;
				var type:String;
				if (Std.isOfType(noteDef.type, Int)) // Convert old note type to new note type format
				{
					var index:Int = Std.int(noteDef.type);
					type = NOTE_TYPES[index];
				}
				else if (Std.isOfType(noteDef.type, Bool) && cast(noteDef.type, Bool))
				{
					type = 'Alt Animation';
				}
				else
				{
					type = noteDef.type;
				}

				notes.push(new BasicNote(noteDef.data, sustainLength, type, beat));
			}
			bar.notes = notes;
			bar.lengthInSteps = sectionDef.lengthInSteps;
			bar.mustHit = sectionDef.mustHitSection;
			bar.altAnim = sectionDef.altAnim;
			bar.gfSings = sectionDef.gfSection;
			bar.startBeat = startBeat;
			bar.endBeat = endBeat;

			song.bars.push(bar);

			startStep = endStep;
		}

		for (eventSection in songDef.events)
		{
			if (eventSection is Array)
			{
				var eventArray:Array<EventEntry> = [];
				for (eventNote in eventSection.events)
				{
					var eventEntry:EventEntry = {type: eventNote.type, args: [eventNote.value1, eventNote.value2]};
					eventArray.push(eventEntry);
				}
				var eventGroup:EventGroup = {
					beat: song.getBeatFromTime(eventSection.strumTime),
					events: eventArray
				};
				song.events.push(eventGroup);
			}
		}

		return song;
	}

	/**
	 * Converts old charts to newest format.
	 */
	public function updateFormat():PsychSong
	{
		if (songDef.events == null)
		{
			songDef.events = [];
			for (section in songDef.notes)
			{
				var i:Int = 0;
				var notes:Array<PsychSectionEntry> = section.sectionNotes;
				var len:Int = notes.length;
				while (i < len)
				{
					var sectionEntry:PsychSectionEntry = notes[i];
					if (PsychSection.isEvent(sectionEntry))
					{
						var sectionEntry:PsychLegacyEvent = sectionEntry;

						var eventDef:PsychEvent = new PsychEvent([sectionEntry.type, sectionEntry.value1, sectionEntry.value2]);
						var eventSection:PsychEventSection = new PsychEventSection([sectionEntry.strumTime, [eventDef]]);
						songDef.events.push(eventSection);
						notes.remove(sectionEntry);
						len = notes.length;
					}
					else
						i++;
				}
			}
		}

		if (songDef.player3 != null)
		{
			songDef.gfVersion = songDef.player3;
		}

		return songDef;
	}
}
