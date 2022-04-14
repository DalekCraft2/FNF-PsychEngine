package;

import Section.SectionData;
import Song.SongData;
import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import haxe.io.Path;

using StringTools;

typedef CharacterData =
{
	var animations:Array<AnimationData>;
	var image:String;
	var ?scale:Float;
	var ?singDuration:Float;
	var healthIcon:String;
	var ?position:Array<Float>;
	var ?cameraPosition:Array<Float>;
	var ?flipX:Bool;
	var ?noAntialiasing:Bool;
	var ?healthBarColors:Array<Int>;
	var ?cameraMotionFactor:Float;
	var ?initialAnimation:String;
}

typedef AnimationData =
{
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

// TODO Automatically correct offsets when character is flipped (One way may be to insert the offsets directly into the XMLs)
class Character extends FlxSprite
{
	/**
	 * The character ID used in case the requested character is missing.
	 */
	public static inline final DEFAULT_CHARACTER:String = 'bf';

	/**
	 * The internal name of the character, as used in the file system.
	 */
	public var id:String;

	public var animOffsets:Map<String, Array<Float>>;
	public var debugMode:Bool = false;

	public var isPlayer(default, set):Bool = false;
	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;

	/**
	 * This is used for Pico's animations in Stress; the TankmenBG class functions similarly
	 */
	public var animationNotes:Array<Array<Dynamic>> = [];

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
	public var animationsArray:Array<AnimationData> = [];

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
	public var initialAnimation:String = 'idle';

	public static function createTemplateCharacterData():CharacterData
	{
		var characterData:CharacterData = {
			animations: [
				{
					loop: false,
					offsets: [0, 0],
					fps: 24,
					anim: 'idle',
					indices: [],
					name: 'Dad idle dance'
				},
				{
					offsets: [0, 0],
					indices: [],
					fps: 24,
					anim: 'singLEFT',
					loop: false,
					name: 'Dad Sing Note LEFT'
				},
				{
					offsets: [0, 0],
					indices: [],
					fps: 24,
					anim: 'singDOWN',
					loop: false,
					name: 'Dad Sing Note DOWN'
				},
				{
					offsets: [0, 0],
					indices: [],
					fps: 24,
					anim: 'singUP',
					loop: false,
					name: 'Dad Sing Note UP'
				},
				{
					offsets: [0, 0],
					indices: [],
					fps: 24,
					anim: 'singRIGHT',
					loop: false,
					name: 'Dad Sing Note RIGHT'
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
		return characterData;
	}

	public function new(x:Float, y:Float, ?character:String = DEFAULT_CHARACTER, ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = [];
		id = character;
		antialiasing = Options.save.data.globalAntialiasing;
		switch (id)
		{
			// TODO Add configuration in order to avoid hardcoding Pico things in Week 7
			// case 'your character name in case you want to hardcode them instead':
			case 'pico-speaker':
				parseDataFile();
				loadMappedAnims();
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
		dance();
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

				if (holdTimer >= Conductor.stepCrochet * 0.001 * singDuration)
				{
					dance();
					holdTimer = 0;
				}
			}

			switch (id)
			{
				case 'pico-speaker':
					if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
					{
						var shootAnim:Int = 1;

						if (animationNotes[0][1] >= 2)
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

	private function parseDataFile():Void
	{
		var characterData:CharacterData = Paths.getJson(Path.join(['characters', id]));
		if (characterData == null)
		{
			Debug.logError('Could not find character data for character "$id"; using default');
			characterData = Paths.getJson(Path.join(['characters', DEFAULT_CHARACTER]));
		}

		if (characterData.image != null)
		{
			imageFile = characterData.image;
		}

		// sparrow
		var spriteType:String = 'sparrow';

		// packer
		var txtToFind:String = Paths.file('images/characters/$imageFile.txt', TEXT);
		if (Paths.exists(txtToFind))
		{
			spriteType = 'packer';
		}

		// texture
		var animToFind:String = Paths.file('images/characters/$imageFile/Animation.json', TEXT);
		if (Paths.exists(animToFind))
		{
			spriteType = 'texture';
		}

		switch (spriteType)
		{
			case 'packer':
				frames = Paths.getPackerAtlas('characters/$imageFile');

			case 'sparrow':
				frames = Paths.getSparrowAtlas('characters/$imageFile');

			case 'texture':
				frames = AtlasFrameMaker.construct('characters/$imageFile');
		}

		if (characterData.animations != null)
		{
			animationsArray = characterData.animations;
		}

		for (anim in animationsArray)
		{
			var animAnim:String = anim.anim;
			var animName:String = anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = anim.loop;
			var animIndices:Array<Int> = anim.indices;
			if (animIndices != null && animIndices.length > 0)
			{
				animation.addByIndices(animAnim, animName, animIndices, '', animFps, animLoop);
			}
			else
			{
				animation.addByPrefix(animAnim, animName, animFps, animLoop);
			}

			if (anim.offsets != null && anim.offsets.length > 1)
			{
				addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			}
		}

		if (animationsArray.length <= 0)
		{
			quickAnimAdd('idle', 'BF idle dance');
		}

		if (characterData.scale != null)
		{
			jsonScale = characterData.scale;
			setGraphicSize(Std.int(width * jsonScale));
			updateHitbox();
		}

		if (characterData.position != null)
		{
			positionArray = characterData.position;
		}

		if (characterData.cameraPosition != null)
		{
			cameraPosition = characterData.cameraPosition;
		}

		if (characterData.healthIcon != null)
		{
			healthIcon = characterData.healthIcon;
		}

		if (characterData.singDuration != null)
		{
			singDuration = characterData.singDuration;
		}

		if (characterData.flipX != null)
		{
			flipX = characterData.flipX;
		}

		if (characterData.noAntialiasing != null)
		{
			noAntialiasing = characterData.noAntialiasing;
		}

		if (!Options.save.data.globalAntialiasing)
		{
			antialiasing = false;
		}
		else
		{
			antialiasing = !noAntialiasing;
		}

		if (characterData.healthBarColors != null && characterData.healthBarColors.length > 2)
		{
			healthBarColors = characterData.healthBarColors;
		}

		if (characterData.cameraMotionFactor != null)
		{
			cameraMotionFactor = characterData.cameraMotionFactor;
		}

		if (characterData.initialAnimation != null)
		{
			initialAnimation = characterData.initialAnimation;
		}

		Debug.logTrace('Loaded data file for character "$id"');
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance():Void
	{
		if (!debugMode && !specialAnim)
		{
			if (danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight$idleSuffix');
				else
					playAnim('danceLeft$idleSuffix');
			}
			else if (animation.exists('idle$idleSuffix'))
			{
				playAnim('idle$idleSuffix');
			}
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

	public function loadMappedAnims():Void
	{
		var pico:SongData = Song.loadFromJson('pico-speaker', '', 'stress');

		var notes:Array<SectionData> = pico.notes;

		for (section in notes)
		{
			for (note in section.sectionNotes)
			{
				animationNotes.push(note);
			}
		}

		TankmenBG.animationNotes = animationNotes;

		animationNotes.sort(sortAnims);
	}

	private function sortAnims(val1:Array<Dynamic>, val2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, val1[0], val2[0]);
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
		swapAnimations('singRIGHT', 'singLEFT');
		swapAnimations('singRIGHTmiss', 'singLEFTmiss');
		swapAnimations('singRIGHT-loop', 'singLEFT-loop');
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
		return isPlayer;
	}
}
