package chart.io;

import chart.container.Song;

class ChartUtils
{
	public static function read(songDef:Dynamic):Song
	{
		var chartFormat:ChartFormat = getChartFormat(songDef);
		Debug.logTrace('Format: $chartFormat');
		switch (chartFormat)
		{
			case UNKNOWN:
				return new VanillaChartReader(songDef).read();
			// return null;
			case VANILLA:
				return new VanillaChartReader(songDef).read();
			case KADE:
				return new KadeChartReader(songDef).read();
			case MYTH:
				return new MythChartReader(songDef).read();
			case MYTH_HF:
				return new MythHfChartReader(songDef).read();
			case PSYCH:
				return new PsychChartReader(songDef).read();
			case MOCK:
				return new MockChartReader(songDef).read();
		}

		return null;
	}

	public static function write(song:Song, chartFormat:ChartFormat):Dynamic
	{
		return new MockChartWriter(song).write();
		// TODO Add writers for each format
		// switch (chartFormat)
		// {
		// 	case UNKNOWN:
		// 		return new VanillaChartReader(songDef).read();
		// 	// return null;
		// 	case VANILLA:
		// 		return new VanillaChartReader(songDef).read();
		// 	case KADE:
		// 		return new KadeChartReader(songDef).read();
		// 	case MYTH:
		// 		return new MythChartReader(songDef).read();
		// 	case MYTH_HF:
		// 		return new MythHfChartReader(songDef).read();
		// 	case PSYCH:
		// 		return new PsychChartReader(songDef).read();
		// 	case MOCK:
		// 		return new MockChartWriter(song).write();
		// }
		// return null;
	}

	public static function getChartFormat(song:Dynamic):ChartFormat
	{
		switch (song.chartVersion)
		{
			case 'KE1':
				return KADE;
			case 'MYTH 1.0':
				return MYTH;
			case 'MOCK 1.0' | 'MOCK 1.1':
				return MOCK;
			default: // Please, guys, put a chartVersion tag in your chart JSONs.
				// Some HoloFunk Myth-exclusive JSON tags:
				if (Reflect.hasField(song, 'startingHealth') || Reflect.hasField(song, 'opponentHealth'))
				{
					return MYTH_HF;
				}

				// Some Psych-exclusive JSON tags (and a commonly used one, "stage"):
				if (Reflect.hasField(song, 'player3')
					|| Reflect.hasField(song, 'arrowSkin')
					|| Reflect.hasField(song, 'splashSkin')
					|| Reflect.hasField(song, 'stage')
					|| Reflect.hasField(song, 'gfVersion'))
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
}

enum ChartFormat
{
	/**
	 * An unknown chart format
	 */
	UNKNOWN;

	/**
	 * The chart format used by vanilla FNF	
	 */
	VANILLA;

	/**
	 * The chart format used by Kade Engine
	 */
	KADE;

	/**
	 * The chart format used by Myth Engine, a fork of Kade Engine
	 */
	MYTH;

	/**
	 * The chart format used by HoloFunk 5.0.0's Myth Engine build
	 */
	MYTH_HF;

	/**
	 * The chart format used by Psych Engine
	 */
	PSYCH;

	/**
	 * The chart format used by Mock Engine, a fork of Psych Engine
	 */
	MOCK;
}
