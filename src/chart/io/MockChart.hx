package chart.io;

// I have abandoned reverse compatibility. The future is now.

/**
 * For versions 1.0 to 1.1
 */
typedef MockSongWrapper =
{
	song:MockSong
}

typedef MockSong =
{
	player1:String,
	player2:String,
	gfVersion:String,
	stage:String,
	noteSkin:String,
	splashSkin:String,
	?tempo:Float,
	?scrollSpeed:Float,
	?needsVoices:Bool,
	?validScore:Bool,
	bars:Array<MockBar>,
	?events:Array<MockEventGroup>,
	?offset:Float,
	chartVersion:String
}

typedef MockBar =
{
	notes:Array<MockNote>,
	lengthInSteps:Int,
	mustHit:Bool,
	gfSings:Bool,
	altAnim:Bool,
}

typedef MockNote =
{
	beat:Float,
	data:Int,
	sustainLength:Float,
	type:String
}

typedef MockEventGroup = chart.container.Event.EventGroup;
