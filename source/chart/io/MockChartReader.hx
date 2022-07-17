package chart.io;

import chart.container.BasicNote;
import chart.container.Event.EventGroup;
import chart.container.Section;
import chart.container.Song;

using StringTools;

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
		// if (songDef.bpm != null)
		song.bpm = songDef.bpm;
		// if (songDef.speed != null)
		song.speed = songDef.speed;
		if (songDef.needsVoices != null)
			song.needsVoices = songDef.needsVoices;
		if (songDef.validScore != null)
			song.validScore = songDef.validScore;

		song.events.push({
			beat: 0,
			events: [
				{
					type: 'Change BPM',
					value1: song.bpm
				}
			]
		});

		for (sectionDef in songDef.notes)
		{
			var section:Section = new Section();
			var sectionNotes:Array<BasicNote> = [
				for (noteDef in sectionDef.sectionNotes)
					new BasicNote(/*noteDef.strumTime*/ 0, noteDef.data, noteDef.sustainLength, noteDef.type, noteDef.beat)
			];
			section.sectionNotes = sectionNotes;
			section.lengthInSteps = sectionDef.lengthInSteps;
			section.mustHitSection = sectionDef.mustHitSection;
			section.altAnim = sectionDef.altAnim;

			song.notes.push(section);
		}

		song.events = songDef.events;

		return song;
	}
}

typedef MockSongWrapper =
{
	var song:MockSong;
}

typedef MockSong =
{
	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var noteSkin:String;
	var splashSkin:String;
	var ?bpm:Float;
	var ?speed:Float;
	var ?needsVoices:Bool;
	var ?validScore:Bool;
	var notes:Array<MockSection>;
	var ?events:Array<EventGroup>;
	var chartVersion:String;
}

typedef MockSection =
{
	var sectionNotes:Array<MockNote>;
	var lengthInSteps:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var altAnim:Bool;
}

typedef MockNote =
{
	var beat:Float;
	var data:Int;
	var sustainLength:Float;
	var type:String;
}
