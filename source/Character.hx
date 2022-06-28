package;

import Note.NoteDef;
import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import haxe.io.Path;

using StringTools;

typedef CharacterDef =
{
	var animations:Array<AnimationDef>;
	var image:String;
	var ?scale:Float;
	var ?singDuration:Float;
	var healthIcon:String;
	var ?position:Array<Float>;
	var ?cameraPosition:Array<Float>;
	var ?flipX:Bool;
	var ?flipLR:Bool;
	var ?noAntialiasing:Bool;
	var ?healthBarColors:Array<Int>;
	var ?cameraMotionFactor:Float;
	var ?initialAnimation:String;
}

typedef AnimationDef =
{
	var name:String;
	var prefix:String;
	var indices:Array<Int>;
	var frameRate:Int;
	var loop:Bool;
	var offsets:Array<Int>;
}

// TODO Automatically correct offsets when character is flipped (One way may be to insert the offsets directly into the XMLs)
// Seriously, why haven't people been setting the offsets when creating the spritesheets? It would make things much easier.
class Character extends FlxSprite implements Danceable
{
	/**
	 * The character ID used in case the requested character is missing.
	 */
	public static inline final DEFAULT_CHARACTER:String = 'bf';

	/**
	 * The internal name of the character, as used in the file system.
	 */
	public var id:String;

	public var animOffsets:Map<String, Array<Float>> = [];
	public var debugMode:Bool = false;

	public var isPlayer(default, set):Bool = false;
	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;

	/**
	 * This is used for Pico's animations in Stress; the TankmenBG class functions similarly
	 */
	public var animationNotes:Array<NoteDef> = [];

	public var stunned:Bool = false;

	/**
	 * Multiplier of how long a character holds the sing pose
	 */
	public var singDuration:Float = 4;

	public var idleSuffix:String = '';

	/**
	 * Character uses "danceLeft" and "danceRight" instead of "idle"
	 */
	public var danceIdle:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimationDef> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	// Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthBarColors:Array<Int> = [255, 0, 0];
	public var cameraMotionFactor:Float = 1;
	public var initialAnimation:String;

	public var danced:Bool = false;

	public static function createTemplateCharacterDef():CharacterDef
	{
		var characterDef:CharacterDef = {
			animations: [
				{
					name: 'idle',
					prefix: 'Dad idle dance',
					indices: [],
					frameRate: 24,
					loop: false,
					offsets: [0, 0]
				},
				{
					name: 'singLEFT',
					prefix: 'Dad Sing Note LEFT',
					indices: [],
					frameRate: 24,
					loop: false,
					offsets: [0, 0]
				},
				{
					name: 'singDOWN',
					prefix: 'Dad Sing Note DOWN',
					indices: [],
					frameRate: 24,
					loop: false,
					offsets: [0, 0]
				},
				{
					name: 'singUP',
					prefix: 'Dad Sing Note UP',
					indices: [],
					frameRate: 24,
					loop: false,
					offsets: [0, 0]
				},
				{
					name: 'singRIGHT',
					prefix: 'Dad Sing Note RIGHT',
					indices: [],
					frameRate: 24,
					loop: false,
					offsets: [0, 0]
				}
			],
			image: 'DADDY_DEAREST',
			scale: 1,
			singDuration: 6.1,
			healthIcon: 'face',
			position: [0, 0],
			cameraPosition: [0, 0],
			flipX: false,
			noAntialiasing: false,
			healthBarColors: [161, 161, 161],
			cameraMotionFactor: 1
		};
		return characterDef;
	}

	public function new(x:Float, y:Float, character:String = DEFAULT_CHARACTER, isPlayer:Bool = false)
	{
		super(x, y);

		id = character;
		antialiasing = Options.save.data.globalAntialiasing;
		switch (id)
		{
			// case 'your character name in case you want to hardcode them instead':
			default:
				parseDataFile();
		}
		originalFlipX = flipX;
		this.isPlayer = isPlayer;

		for (noteKey in NoteKey.createAll())
		{
			if (animOffsets.exists('sing${noteKey}miss'))
			{
				hasMissAnimations = true;
				break;
			}
		}
		recalculateDanceIdle();

		if (initialAnimation != null)
		{
			playAnim(initialAnimation);
		}
		else
		{
			dance();
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!debugMode && animation.curAnim != null)
		{
			if (heyTimer > 0)
			{
				heyTimer -= elapsed;
				if (heyTimer <= 0)
				{
					if (specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer')
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			}
			else if (specialAnim && animation.curAnim.finished)
			{
				specialAnim = false;
				dance();
			}

			if (!isPlayer)
			{
				if (animation.curAnim.name.startsWith('sing'))
				{
					holdTimer += elapsed;
				}

				if (holdTimer >= Conductor.semiquaverLength * 0.001 * singDuration)
				{
					dance();
					holdTimer = 0;
				}
			}

			switch (id)
			{
				// TODO Add configuration in order to avoid hardcoding Pico things in Week 7
				case 'pico-speaker':
					if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0].strumTime)
					{
						var shootAnim:Int = 1;

						if (animationNotes[0].noteData >= 2)
							shootAnim = 3;

						shootAnim += FlxG.random.int(0, 1);
						playAnim('shoot$shootAnim', true);

						animationNotes.shift();
					}
			}

			if (animation.curAnim.finished && animation.exists('${animation.curAnim.name}-loop'))
			{
				playAnim('${animation.curAnim.name}-loop');
			}
		}
	}

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(force:Bool = false):Void
	{
		if (!debugMode && !specialAnim)
		{
			if (danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight$idleSuffix', force);
				else
					playAnim('danceLeft$idleSuffix', force);
			}
			else if (animation.exists('idle$idleSuffix'))
			{
				playAnim('idle$idleSuffix', force);
			}
		}
	}

	private function parseDataFile():Void
	{
		var characterDef:CharacterDef = Paths.getJson(Path.join(['characters', id]));
		if (characterDef == null)
		{
			Debug.logError('Could not find character data for character "$id"; using default');
			characterDef = Paths.getJson(Path.join(['characters', DEFAULT_CHARACTER]));
		}

		if (characterDef.image != null)
		{
			imageFile = characterDef.image;
		}

		// sparrow
		var spriteType:String = 'sparrow';

		// packer
		var txtToFind:String = Paths.file(Path.join(['images/characters', Path.withExtension(imageFile, Paths.TEXT_EXT)]), TEXT);
		if (Paths.exists(txtToFind))
		{
			spriteType = 'packer';
		}

		// texture
		var animToFind:String = Paths.file(Path.join(['images/characters', imageFile, Path.withExtension('Animation', Paths.JSON_EXT)]), TEXT);
		if (Paths.exists(animToFind))
		{
			spriteType = 'texture';
		}

		switch (spriteType)
		{
			case 'packer':
				frames = Paths.getPackerAtlas(Path.join(['characters', imageFile]));

			case 'sparrow':
				frames = Paths.getSparrowAtlas(Path.join(['characters', imageFile]));

			case 'texture':
				frames = AtlasFrameMaker.construct(Path.join(['characters', imageFile]));
		}

		if (characterDef.animations != null)
		{
			animationsArray = characterDef.animations;
		}

		for (anim in animationsArray)
		{
			var animName:String = anim.name;
			var animPrefix:String = anim.prefix;
			var animFrameRate:Int = anim.frameRate;
			var animLoop:Bool = anim.loop;
			var animIndices:Array<Int> = anim.indices;
			if (animIndices != null && animIndices.length > 0)
			{
				animation.addByIndices(animName, animPrefix, animIndices, '', animFrameRate, animLoop);
			}
			else
			{
				animation.addByPrefix(animName, animPrefix, animFrameRate, animLoop);
			}

			if (anim.offsets != null && anim.offsets.length > 1)
			{
				addOffset(anim.name, anim.offsets[0], anim.offsets[1]);
			}
		}

		if (animationsArray.length <= 0)
		{
			quickAnimAdd('idle', 'BF idle dance');
		}

		if (characterDef.scale != null)
		{
			jsonScale = characterDef.scale;
			setGraphicSize(Std.int(width * jsonScale));
			updateHitbox();
		}

		if (characterDef.position != null)
		{
			positionArray = characterDef.position;
		}

		if (characterDef.cameraPosition != null)
		{
			cameraPosition = characterDef.cameraPosition;
		}

		if (characterDef.healthIcon != null)
		{
			healthIcon = characterDef.healthIcon;
		}

		if (characterDef.singDuration != null)
		{
			singDuration = characterDef.singDuration;
		}

		if (characterDef.flipX != null)
		{
			flipX = characterDef.flipX;
		}

		if (characterDef.noAntialiasing != null)
		{
			noAntialiasing = characterDef.noAntialiasing;
		}

		if (Options.save.data.globalAntialiasing)
		{
			antialiasing = !noAntialiasing;
		}
		else
		{
			antialiasing = false;
		}

		if (characterDef.healthBarColors != null && characterDef.healthBarColors.length > 2)
		{
			healthBarColors = characterDef.healthBarColors;
		}

		if (characterDef.cameraMotionFactor != null)
		{
			cameraMotionFactor = characterDef.cameraMotionFactor;
		}

		if (characterDef.initialAnimation != null)
		{
			initialAnimation = characterDef.initialAnimation;
		}

		if (characterDef.flipLR != null && characterDef.flipLR)
		{
			leftToRight();
		}
	}

	public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		specialAnim = false;
		animation.play(animName, force, reversed, frame);

		if (animOffsets.exists(animName))
		{
			var animOffset:Array<Float> = animOffsets.get(animName);
			offset.set(animOffset[0], animOffset[1]);
		}
		else
		{
			offset.set(0, 0);
		}

		if (id.startsWith('gf'))
		{
			if (animName == 'singLEFT')
			{
				danced = true;
			}
			else if (animName == 'singRIGHT')
			{
				danced = false;
			}

			if (animName == 'singUP' || animName == 'singDOWN')
			{
				danced = !danced;
			}
		}
	}

	public function loadMappedAnims(id:String, difficulty:String, ?folder:String):Void
	{
		var songDef:Song = Song.getSongDef(id, difficulty, folder);

		var sections:Array<Section> = songDef.notes;

		for (section in sections)
		{
			for (note in section.sectionNotes)
			{
				animationNotes.push(note);
			}
		}
		animationNotes.sort(sortAnims);
	}

	private function sortAnims(val1:NoteDef, val2:NoteDef):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, val1.strumTime, val2.strumTime);
	}

	public var danceEveryNumBeats:Int = 2;

	private var settingCharacterUp:Bool = true;

	public function recalculateDanceIdle():Void
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.exists('danceLeft$idleSuffix') && animation.exists('danceRight$idleSuffix'));

		if (settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if (lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if (danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function leftToRight():Void
	{
		for (anim in animationsArray)
		{
			if (anim.name.startsWith('singRIGHT'))
			{
				var suffix:String = anim.name.substring('singRIGHT'.length);
				var leftAnim:String = 'singLEFT$suffix';
				if (animation.exists(leftAnim))
				{
					swapAnimations(anim.name, leftAnim);
				}
			}
		}
	}

	public function swapAnimations(anim1:String, anim2:String):Void
	{
		if (animation.exists(anim1) && animation.exists(anim2))
		{
			var oldFrames:Array<Int> = animation.getByName(anim1).frames;
			animation.getByName(anim1).frames = animation.getByName(anim2).frames;
			animation.getByName(anim2).frames = oldFrames;

			var oldOffsets:Array<Float> = animOffsets.get(anim1);
			animOffsets.set(anim1, animOffsets.get(anim2));
			animOffsets.set(anim2, oldOffsets);
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String):Void
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	private function set_isPlayer(value:Bool):Bool
	{
		if (isPlayer != value)
		{
			isPlayer = value;
			flipX = !flipX;

			leftToRight();
			// for (animOffset in animOffsets)
			// {
			// 	animOffset[0] = -animOffset[0];
			// }
			updateHitbox();
		}
		return value;
	}
}
