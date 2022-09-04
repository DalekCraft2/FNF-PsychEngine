package chart.io;

import chart.container.Song;
import chart.io.MockChart;

/**
 * For versions 1.0 to 1.1
 */
class MockChartWriter implements ChartWriter
{
	private final song:Song;

	public function new(song:Song)
	{
		this.song = song;
	}

	public function write():MockSong
	{
		var songDef:MockSong = {
			player1: song.player1,
			player2: song.player2,
			gfVersion: song.gfVersion,
			stage: song.stage,
			noteSkin: song.noteSkin,
			splashSkin: song.splashSkin,
			tempo: song.tempo,
			scrollSpeed: song.scrollSpeed,
			needsVoices: song.needsVoices,
			validScore: song.validScore,
			bars: [],
			events: song.events,
			offset: song.offset,
			chartVersion: Song.LATEST_CHART
		}

		for (bar in song.bars)
		{
			var notes:Array<MockNote> = [
				for (note in bar.notes)
					{
						beat: note.beat,
						data: note.data,
						sustainLength: note.sustainLength,
						type: note.type
					}
			];
			var barDef:MockBar = {
				notes: notes,
				lengthInSteps: bar.lengthInSteps,
				mustHit: bar.mustHit,
				gfSings: bar.gfSings,
				altAnim: bar.altAnim
			}
			songDef.bars.push(barDef);
		}

		return songDef;
	}
}
