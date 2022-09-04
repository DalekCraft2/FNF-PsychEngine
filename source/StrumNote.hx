package;

import states.PlayState;
import NoteKey.NoteColor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxGraphicAsset;
import haxe.io.Path;
import shader.ColorSwap;

class StrumNote extends FlxSprite
{
	private var colorSwap:ColorSwap;

	public var resetAnim:Float = 0;

	private var noteData:Int = 0;

	private var noteDataModulo(get, never):Int;

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
		if (PlayState.song.noteSkin != null && PlayState.song.noteSkin.length > 1)
			skin = PlayState.song.noteSkin;
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
		if (!PlayState.isPixelStage && animation.name == 'confirm')
		{
			centerOrigin();
		}
	}

	public function reloadNote():Void
	{
		var lastAnim:Null<String> = null;
		if (animation.curAnim != null)
			lastAnim = animation.name;

		if (PlayState.isPixelStage)
		{
			var path:String = Paths.image(Path.join(['ui', 'notes', '${texture}-pixel']));
			if (!Paths.exists(path))
			{
				path = Paths.image(Path.join(['ui', 'notes', 'NOTE_assets-pixel']));
			}
			var graphic:FlxGraphicAsset = Paths.getGraphicDirect(path);
			loadGraphic(graphic);
			width /= 4;
			height /= 5;
			loadGraphic(graphic, true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			scale.set(PlayState.PIXEL_ZOOM, PlayState.PIXEL_ZOOM);

			for (color in NoteColor.createAll())
			{
				animation.add(color.getName(), [4 + color.getIndex()]);
			}

			animation.add('static', [noteData]);
			animation.add('pressed', [noteData + 4, noteData + 8], 12, false);
			animation.add('confirm', [noteData + 12, noteData + 16], 24, false);
		}
		else
		{
			if (!Paths.exists(Paths.image(Path.join(['ui', 'notes', texture]))))
			{
				texture = 'NOTE_assets';
			}
			frames = Paths.getFrames(Path.join(['ui', 'notes', texture]));
			for (color in NoteColor.createAll())
			{
				animation.addByPrefix(color.getName(), 'arrow${NoteKey.createByIndex(color.getIndex())}');
			}

			antialiasing = Options.save.data.globalAntialiasing;
			scale.set(0.7, 0.7);

			var noteKey:NoteKey = NoteKey.createByIndex(noteData);

			animation.addByPrefix('static', 'arrow${noteKey.getName()}');
			animation.addByPrefix('pressed', '${noteKey.getName().toLowerCase()} press', 24, false);
			animation.addByPrefix('confirm', '${noteKey.getName().toLowerCase()} confirm', 24, false);
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

	public function playAnim(anim:String, force:Bool = false):Void
	{
		animation.play(anim, force);
		centerOffsets();
		centerOrigin();
		if (animation.curAnim == null || animation.name == 'static')
		{
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		}
		else
		{
			colorSwap.hue = Options.save.data.arrowHSV[noteDataModulo][0] / 360;
			colorSwap.saturation = Options.save.data.arrowHSV[noteDataModulo][1] / 100;
			colorSwap.brightness = Options.save.data.arrowHSV[noteDataModulo][2] / 100;

			if (animation.name == 'confirm' && !PlayState.isPixelStage)
			{
				centerOrigin();
			}
		}
	}

	private function get_noteDataModulo():Int
	{
		return noteData % NoteKey.createAll().length;
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
