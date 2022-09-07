package funkin;

import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxGraphicAsset;
import funkin.NoteKey.NoteColor;
import funkin.shader.ColorSwap;
import funkin.states.PlayState;
import haxe.io.Path;

using StringTools;

// TODO Note type JSON files for some minor configuration?
class Note extends FlxSprite
{
	public static final STRUM_WIDTH:Float = 160 * 0.7;

	public var strumTime:Float = 0;
	public var noteData:Int = 0;
	public var sustainLength:Float = 0;
	public var noteType(default, set):String;
	public var beat:Float = 0;

	public var unModifiedStrumTime:Float = 0;
	public var noteDataModulo(get, never):Int;

	public var mustPress:Bool = false;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;

	public var isSustainNote:Bool = false;

	// TODO Implement Kade's sustain fix
	public var isParent:Bool = false;
	public var parent:Note = null;
	public var spotInLine:Int = 0;
	public var sustainActive:Bool = true;
	public var children:Array<Note> = [];

	// TODO Make the event note sprite a separate class
	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var colorSwap:ColorSwap;
	public var inEditor:Bool = false;
	public var gfNote:Bool = false;

	private var earlyHitMult:Float = 0.5;

	// Script API shit
	public var noteSplashDisabled:Bool = false;
	public var noteSplashForced:Bool = false;
	public var noteSplashTexture:String;
	public var noteSplashHue:Float = 0;
	public var noteSplashSat:Float = 0;
	public var noteSplashBrt:Float = 0;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; // 9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String;

	public var noAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; // plan on doing scroll directions soon -bb

	public var hitSoundDisabled:Bool = false;

	// TODO So it turns out that the correct word for this might be "postfix" instead of "suffix"
	public var animSuffix(default, set):String = '';

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, isSustainNote:Bool = false, inEditor:Bool = false, beat:Float)
	{
		super((Options.profile.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50, -2000);

		this.prevNote = prevNote == null ? this : prevNote;
		this.isSustainNote = isSustainNote;
		this.inEditor = inEditor;
		this.beat = beat;

		// x += (Options.profile.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// // MAKE SURE ITS DEFINITELY OFF SCREEN?
		// y -= 2000;
		this.unModifiedStrumTime = strumTime;
		this.strumTime = strumTime;
		if (!inEditor)
			this.strumTime += Options.profile.noteOffset;

		this.noteData = Std.int(Math.abs(noteData));

		if (this.noteData > -1)
		{
			texture = '';
			colorSwap = new ColorSwap();
			shader = colorSwap.shader;

			x += STRUM_WIDTH * noteDataModulo;
			if (!isSustainNote)
			{ // Doing this 'if' check to fix the warnings on Senpai songs
				var animToPlay:String = NoteColor.createByIndex(noteDataModulo).getName();
				animation.play('${animToPlay}Scroll');
			}
		}

		if (isSustainNote && prevNote != null)
		{
			alpha = 0.6;
			multAlpha = 0.6;
			hitSoundDisabled = true;
			if (Options.profile.downScroll)
				flipY = true;

			offsetX += width / 2;
			copyAngle = false;

			var animToPlay:String = NoteColor.createByIndex(noteDataModulo).getName();
			animation.play('${animToPlay}holdend');

			updateHitbox();

			offsetX -= width / 2;

			if (PlayState.isPixelStage)
				offsetX += 30;

			if (prevNote.isSustainNote)
			{
				var animToPlay:String = NoteColor.createByIndex(prevNote.noteDataModulo).getName();
				prevNote.animation.play('${animToPlay}hold');

				prevNote.scale.y *= Conductor.stepLength / 100 * 1.05;
				if (PlayState.instance != null)
				{
					prevNote.scale.y *= PlayState.instance.scrollSpeed;
				}

				if (PlayState.isPixelStage)
				{
					prevNote.scale.y *= 1.19;
					prevNote.scale.y *= (6 / height); // Auto adjust note size
				}
				prevNote.updateHitbox();
			}

			if (PlayState.isPixelStage)
			{
				scale.y *= PlayState.PIXEL_ZOOM;
				updateHitbox();
			}
		}
		else if (!isSustainNote)
		{
			earlyHitMult = 1;
		}
		x += offsetX;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (mustPress)
		{
			// ok river
			if (strumTime > Conductor.songPosition - Conductor.safeZoneOffset
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				canBeHit = true;
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if ((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (!inEditor && tooLate)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	private var lastNoteOffsetX:Float = 0;
	private var lastNoteScale:Float = 1;

	public var originalHeightForCalcs:Float = 6;

	private function reloadNote(prefix:String = '', texture:String = '', suffix:String = ''):Void
	{
		if (texture.length < 1)
		{
			var songSkin:String = PlayState.song.noteSkin;
			if (songSkin == null || songSkin.length < 1)
			{
				texture = 'NOTE_assets';
			}
			else
			{
				texture = songSkin;
			}
		}
		texture = Path.join([Path.directory(texture), prefix + Path.withoutDirectory(texture) + suffix]);

		var animName:Null<String> = null;
		if (animation.curAnim != null)
		{
			animName = animation.name;
		}

		var lastScaleY:Float = scale.y;

		if (PlayState.isPixelStage)
		{
			if (isSustainNote)
			{
				var path:String = Paths.image(Path.join(['ui', 'notes', '${texture}-pixel-ends']));
				if (!Paths.exists(path))
				{
					path = Paths.image(Path.join(['ui', 'notes', 'NOTE_assets-pixel-ends']));
				}
				var graphic:FlxGraphicAsset = Paths.getGraphicDirect(path);
				loadGraphic(graphic);
				width = width / 4;
				height = height / 2;
				originalHeightForCalcs = height;
				loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
			}
			else
			{
				var path:String = Paths.image(Path.join(['ui', 'notes', '${texture}-pixel']));
				if (!Paths.exists(path))
				{
					path = Paths.image(Path.join(['ui', 'notes', 'NOTE_assets-pixel']));
				}
				var graphic:FlxGraphicAsset = Paths.getGraphicDirect(path);
				loadGraphic(graphic);
				width = width / 4;
				height = height / 5;
				loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
			}
			scale.set(PlayState.PIXEL_ZOOM, PlayState.PIXEL_ZOOM);
			loadPixelNoteAnims();
			antialiasing = false;

			if (isSustainNote)
			{
				offsetX += lastNoteOffsetX;
				lastNoteOffsetX = (width - 7) * (PlayState.PIXEL_ZOOM / 2);
				offsetX -= lastNoteOffsetX;

				/*
					if (animName != null && !animName.endsWith('end'))
					{
						lastScaleY /= lastNoteScale;
						lastNoteScale = PlayState.PIXEL_ZOOM / height;
						lastScaleY *= lastNoteScale;
					}
				 */
			}
		}
		else
		{
			if (!Paths.exists(Paths.image(Path.join(['ui', 'notes', texture]))))
			{
				texture = 'NOTE_assets';
			}
			frames = Paths.getFrames(Path.join(['ui', 'notes', texture]));
			loadNoteAnims();
			antialiasing = Options.profile.globalAntialiasing;
		}
		if (isSustainNote)
		{
			scale.y = lastScaleY;
		}
		updateHitbox();

		if (animName != null)
			animation.play(animName, true);
	}

	private function loadNoteAnims():Void
	{
		for (color in NoteColor.createAll())
		{
			if (isSustainNote)
			{
				animation.addByPrefix('${color}holdend', '${color} tail'); // Tails
				animation.addByPrefix('${color}hold', '${color} hold'); // Holds
			}
			else
			{
				animation.addByPrefix('${color}Scroll', '${color} alone'); // Normal notes
			}
		}

		scale.set(0.7, 0.7);
		updateHitbox();
	}

	private function loadPixelNoteAnims():Void
	{
		for (color in NoteColor.createAll())
		{
			if (isSustainNote)
			{
				animation.add('${color.getName()}holdend', [color.getIndex() + 4]); // Tails
				animation.add('${color.getName()}hold', [color.getIndex()]); // Holds
			}
			else
			{
				animation.add('${color.getName()}Scroll', [color.getIndex() + 4]); // Normal notes
			}
		}
	}

	private function set_noteType(value:String):String
	{
		if (noteType != value)
		{
			noteType = value;

			noteSplashTexture = PlayState.song.splashSkin;
			colorSwap.hue = Options.profile.arrowHSV[noteDataModulo][0] / 360;
			colorSwap.saturation = Options.profile.arrowHSV[noteDataModulo][1] / 100;
			colorSwap.brightness = Options.profile.arrowHSV[noteDataModulo][2] / 100;

			if (noteData > -1)
			{
				switch (value)
				{
					case 'Hurt Note':
						ignoreNote = mustPress;
						reloadNote('HURT');
						noteSplashTexture = 'HURTnoteSplashes';
						colorSwap.hue = 0;
						colorSwap.saturation = 0;
						colorSwap.brightness = 0;
						if (isSustainNote)
						{
							missHealth = 0.1;
						}
						else
						{
							missHealth = 0.3;
						}
						hitCausesMiss = true;
					case 'No Animation':
						noAnimation = true;
					case 'GF Sing':
						gfNote = true;
					case 'Alt Animation':
						animSuffix = '-alt';
				}
			}
			noteSplashHue = colorSwap.hue;
			noteSplashSat = colorSwap.saturation;
			noteSplashBrt = colorSwap.brightness;
		}
		return value;
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
			reloadNote(null, value);
		}
		return value;
	}

	private function set_animSuffix(value:String):String
	{
		animSuffix = value;
		for (sustainNote in children)
		{
			sustainNote.animSuffix = value;
		}
		return value;
	}
}
