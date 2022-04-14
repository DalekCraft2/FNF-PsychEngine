package;

import NoteKey.NoteColor;
import flixel.FlxG;
import flixel.FlxSprite;

class StrumNote extends FlxSprite
{
	private var colorSwap:ColorSwap;

	public var resetAnim:Float = 0;

	private var noteData:Int = 0;

	public var direction:Float = 90; // plan on doing scroll directions soon -bb
	public var downScroll:Bool = false; // plan on doing scroll directions soon -bb
	public var sustainReduce:Bool = true;

	private var player:Int;

	public var texture(default, set):String;

	public function new(x:Float, y:Float, noteData:Int, player:Int)
	{
		super(x, y);

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;
		this.player = player;
		this.noteData = Std.int(Math.abs(noteData));

		var skin:String = 'NOTE_assets';
		if (PlayState.song.arrowSkin != null && PlayState.song.arrowSkin.length > 1)
			skin = PlayState.song.arrowSkin;
		texture = skin; // Load texture and anims

		scrollFactor.set();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (resetAnim > 0)
		{
			resetAnim -= elapsed;
			if (resetAnim <= 0)
			{
				playAnim('static');
				resetAnim = 0;
			}
		}
		// TODO This causes an NPE if, after playing a song with a custom noteskin, the chart editor is loaded with a mod directory other than the one containing that song
		// if(animation.curAnim != null){ //my bad i was upset
		if (animation.curAnim.name == 'confirm' && !PlayState.isPixelStage)
		{
			centerOrigin();
		}
		// }
	}

	public function reloadNote():Void
	{
		var lastAnim:Null<String> = null;
		if (animation.curAnim != null)
			lastAnim = animation.curAnim.name;

		if (PlayState.isPixelStage)
		{
			loadGraphic(Paths.getGraphic('weeb/pixelUI/$texture', 'week6'));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.getGraphic('weeb/pixelUI/$texture', 'week6'), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.PIXEL_ZOOM));

			for (color in NoteColor.createAll())
			{
				animation.add(color.getName(), [4 + color.getIndex()]);
			}

			var color:NoteColor = NoteColor.createByIndex(noteData);

			animation.add('static', [color.getIndex()]);
			animation.add('pressed', [color.getIndex() + 4, color.getIndex() + 8], 12, false);
			animation.add('confirm', [color.getIndex() + 12, color.getIndex() + 16], 24, false);
		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			for (color in NoteColor.createAll())
			{
				animation.addByPrefix(color.getName(), 'arrow${NoteKey.createByIndex(color.getIndex())}');
			}

			antialiasing = Options.save.data.globalAntialiasing;
			setGraphicSize(Std.int(width * 0.7));

			switch (noteData)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		}
		updateHitbox();

		if (lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}

	public function postAddedToGroup():Void
	{
		playAnim('static');
		x += Note.STRUM_WIDTH * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
		ID = noteData;
	}

	public function playAnim(anim:String, ?force:Bool = false):Void
	{
		animation.play(anim, force);
		centerOffsets();
		centerOrigin();
		if (animation.curAnim == null || animation.curAnim.name == 'static')
		{
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		}
		else
		{
			colorSwap.hue = Options.save.data.arrowHSV[noteData % 4][0] / 360;
			colorSwap.saturation = Options.save.data.arrowHSV[noteData % 4][1] / 100;
			colorSwap.brightness = Options.save.data.arrowHSV[noteData % 4][2] / 100;

			if (animation.curAnim.name == 'confirm' && !PlayState.isPixelStage)
			{
				centerOrigin();
			}
		}
	}

	private function set_texture(value:String):String
	{
		if (texture != value)
		{
			texture = value;
			reloadNote();
		}
		return value;
	}
}
