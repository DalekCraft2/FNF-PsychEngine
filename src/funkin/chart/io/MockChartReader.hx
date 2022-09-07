package funkin.chart.io;

import funkin.chart.container.Bar;
import funkin.chart.container.BasicNote;
import funkin.chart.container.Song;
import funkin.chart.io.MockChart;

using StringTools;

/**
 * For versions 1.0 to 1.1
 */
class MockChartReader implements ChartReader
{
	private final songDef:MockSong;

	public function new(songDef:MockSong)
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
		if (songDef.noteSkin != null)
			song.noteSkin = songDef.noteSkin;
		if (songDef.splashSkin != null)
			song.splashSkin = songDef.splashSkin;
		// if (songDef.tempo != null)
		song.tempo = songDef.tempo;
		// if (songDef.scrollSpeed != null)
		song.scrollSpeed = songDef.scrollSpeed;
		if (songDef.needsVoices != null)
			song.needsVoices = songDef.needsVoices;
		if (songDef.validScore != null)
			song.validScore = songDef.validScore;
		if (songDef.offset != null)
			song.offset = songDef.offset;

		song.events = songDef.events;

		song.generateTimings();

		for (barDef in songDef.bars)
		{
			var bar:Bar = new Bar();
			var notes:Array<BasicNote> = [];
			for (noteDef in barDef.notes)
			{
				var sustainLength:Float = 0;
				if (songDef.chartVersion == 'MOCK 1.0') // In MOCK 1.0, sustainLength was measured in milliseconds; now it is measured in beats
				{
					sustainLength = song.getBeatFromTime(song.getTimeFromBeat(noteDef.beat) + noteDef.sustainLength) - noteDef.beat;
				}
				else
				{
					sustainLength = noteDef.sustainLength;
				}
				notes.push(new BasicNote(noteDef.data, sustainLength, noteDef.type, noteDef.beat));
			}
			bar.notes = notes;
			bar.lengthInSteps = barDef.lengthInSteps;
			bar.mustHit = barDef.mustHit;
			bar.altAnim = barDef.altAnim;
			bar.gfSings = barDef.gfSings;

			song.bars.push(bar);
		}

		return song;
	}
}
