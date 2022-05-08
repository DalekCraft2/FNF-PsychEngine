package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;

class LatencyState extends FlxState
{
	private var offsetText:FlxText;
	private var noteGrp:FlxTypedGroup<Note>;
	private var strumLine:FlxSprite;

	override public function create():Void
	{
		super.create();

		FlxG.sound.playMusic(Paths.getSound('soundTest'));

		noteGrp = new FlxTypedGroup();
		add(noteGrp);

		for (i in 0...32)
		{
			var note:Note = new Note(Conductor.crochet * i, 1);
			noteGrp.add(note);
		}

		offsetText = new FlxText();
		offsetText.screenCenter();
		add(offsetText);

		strumLine = new FlxSprite(FlxG.width / 2, 100).makeGraphic(FlxG.width, 5);
		add(strumLine);

		Conductor.changeBPM(120);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		offsetText.text = 'Offset: ${Conductor.offset}ms';

		Conductor.songPosition = FlxG.sound.music.time - Conductor.offset;

		var multiply:Float = 1;

		if (FlxG.keys.pressed.SHIFT)
			multiply = 10;

		if (FlxG.keys.justPressed.RIGHT)
			Conductor.offset += 1 * multiply;
		if (FlxG.keys.justPressed.LEFT)
			Conductor.offset -= 1 * multiply;

		if (FlxG.keys.justPressed.SPACE)
		{
			FlxG.sound.music.stop();

			FlxG.resetState();
		}

		noteGrp.forEach((note:Note) ->
		{
			note.y = (strumLine.y - (Conductor.songPosition - note.strumTime) * 0.45);
			note.x = strumLine.x + 30;

			if (note.y < strumLine.y)
				note.kill();
		});
	}
}
