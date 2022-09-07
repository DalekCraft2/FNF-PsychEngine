package funkin.chart.io;

import funkin.chart.container.Bar;
import funkin.chart.container.BasicNote;
import funkin.chart.container.Song;
import funkin.chart.io.VanillaChart;

using StringTools;

class VanillaChartReader implements ChartReader
{
	private final songDef:VanillaSong;

	public function new(songDef:VanillaSong)
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
		// if (songDef.bpm != null)
		song.tempo = songDef.bpm;
		// if (songDef.speed != null)
		song.scrollSpeed = songDef.speed;
		if (songDef.needsVoices != null)
			song.needsVoices = songDef.needsVoices;
		if (songDef.validScore != null)
			song.validScore = songDef.validScore;

		song.stage = switch (Paths.formatToSongPath(songDef.song))
		{
			case 'spookeez' | 'south' | 'monster':
				'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice':
				'philly';
			case 'milf' | 'satin-panties' | 'high':
				'limo';
			case 'cocoa' | 'eggnog':
				'mall';
			case 'winter-horrorland':
				'mallEvil';
			case 'senpai' | 'roses':
				'school';
			case 'thorns':
				'schoolEvil';
			case 'ugh' | 'guns' | 'stress':
				'tank';
			default:
				'stage';
		}
		song.gfVersion = switch (song.stage)
		{
			case 'limo':
				'gf-car';
			case 'mall' | 'mallEvil':
				'gf-christmas';
			case 'school' | 'schoolEvil':
				'gf-pixel';
			case 'tank':
				'gf-tankmen';
			default:
				'gf';
		}

		song.clearTimings();
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
				var beat:Float = song.getBeatFromTime(noteDef.strumTime);
				var sustainLength:Float = song.getBeatFromTime(noteDef.strumTime + noteDef.sustainLength) - beat;
				notes.push(new BasicNote(noteDef.data, sustainLength, noteDef.isAlt ? 'Alt Animation' : null, beat));
			}
			bar.notes = notes;
			bar.lengthInSteps = sectionDef.lengthInSteps;
			bar.mustHit = sectionDef.mustHitSection;
			bar.altAnim = sectionDef.altAnim;
			bar.startBeat = startBeat;
			bar.endBeat = endBeat;

			song.bars.push(bar);

			startStep = endStep;
		}

		return song;
	}
}
