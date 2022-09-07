package funkin;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import funkin.chart.container.Bar;
import funkin.chart.container.BasicNote;
import funkin.chart.container.Song;
import haxe.io.Path;

using StringTools;

typedef CharacterDef =
{
	animations:Array<AnimationDef>,
	image:String,
	?scale:Float,
	?singDuration:Float,
	healthIcon:String,
	?position:Array<Float>,
	?cameraPosition:Array<Float>,
	?flipX:Bool,
	?noAntialiasing:Bool,
	?healthBarColors:Array<Int>,
	?cameraMotionFactor:Float,
	?initialAnimation:String
}

typedef AnimationDef =
{
	name:String,
	prefix:String,
	indices:Array<Int>,
	frameRate:Int,
	loop:Bool,
	offsets:Array<Float>
}

// TODO Test positioning with the "facing" variable
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
	public var animationNotes:Array<BasicNote> = [];

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

	public var skipDance:Bool = false;
	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimationDef> = [];

	public var position:FlxPoint = FlxPoint.get();
	public var cameraPosition:FlxPoint = FlxPoint.get();

	public var hasMissAnimations:Bool = false;

	// Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;

	/**
	 * Characters which are designed to be on the right side of the screen (in other words, intended as player) will have this as "true".
	 * Examples of this type of character are Boyfriend, Pico, and Tankman.
	 */
	#if FACING_TEST
	public var originalFlipX(default, set):Bool = false;
	#else
	public var originalFlipX:Bool = false;
	#end

	// #end
	public var healthBarColor:FlxColor = FlxColor.RED;
	public var cameraMotionFactor:Float = 1;
	public var initialAnimation:String;

	public var danced:Bool = false;

	private var originalWidth:Float;

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

	public function new(?x:Float = 0, ?y:Float = 0, character:String = DEFAULT_CHARACTER, isPlayer:Bool = false)
	{
		super(x, y);

		id = character;
		antialiasing = Options.profile.globalAntialiasing;
		switch (id)
		{
			// case 'your character name in case you want to hardcode them instead':
			default:
				parseDataFile();
		}
		#if FACING_TEST
		// facing = originalFlipX ? LEFT : RIGHT;
		// setFacingFlip(LEFT, !originalFlipX, false);
		// setFacingFlip(RIGHT, originalFlipX, false);
		if (facing == LEFT)
		#else
		flipX = originalFlipX;
		if (flipX)
		#end
		{
			leftToRight();
		}

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
		originalWidth = frameWidth;

		if (animation.name != null)
		{
			// Correct offsets if character was flipped
			playAnim(animation.name);
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
					if (specialAnim && animation.name == 'hey' || animation.name == 'cheer')
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			}
			else if (specialAnim && animation.finished)
			{
				specialAnim = false;
				dance();
			}

			if (!isPlayer)
			{
				if (animation.name.startsWith('sing'))
				{
					holdTimer += elapsed;
				}

				if (holdTimer >= Conductor.stepLength * 0.0011 * singDuration)
				{
					dance();
					holdTimer = 0;
				}
			}

			switch (id)
			{
				// TODO Add configuration in order to avoid hardcoding Pico things in Week 7
				case 'pico-speaker':
					if (animationNotes.length > 0 && Conductor.songPosition > Conductor.getTimeFromBeat(animationNotes[0].beat))
					{
						var shootAnim:Int = 1;

						if (animationNotes[0].data >= 2)
							shootAnim = 3;

						shootAnim += FlxG.random.int(0, 1);
						playAnim('shoot$shootAnim', true);

						animationNotes.shift();
					}
			}

			if (animation.finished && animation.exists('${animation.name}-loop'))
			{
				playAnim('${animation.name}-loop');
			}
		}
	}

	// Overriding this lets us safely call updateHitbox() when the character is doing an animation besides its initial one
	// override public function updateHitbox():Void
	// {
	// 	var animBeforeUpdate:String = animation.name;
	// 	var frameBeforeUpdate:Int = animation.frameIndex;
	// 	if (initialAnimation != null)
	// 	{
	// 		playAnim(initialAnimation);
	// 	}
	// 	else
	// 	{
	// 		dance();
	// 	}
	// 	super.updateHitbox();
	// 	if (animBeforeUpdate != null)
	// 	{
	// 		playAnim(animBeforeUpdate, false, false, frameBeforeUpdate);
	// 	}
	// }

	public function dance(force:Bool = false):Void
	{
		if (!debugMode && !skipDance && !specialAnim)
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

		frames = Paths.getFrames(Path.join(['characters', imageFile]), AUTO);

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
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		if (characterDef.position != null)
		{
			position = FlxPoint.get(characterDef.position[0], characterDef.position[1]);
		}

		if (characterDef.cameraPosition != null)
		{
			cameraPosition = FlxPoint.get(characterDef.cameraPosition[0], characterDef.cameraPosition[1]);
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
			originalFlipX = characterDef.flipX;
		}

		if (characterDef.noAntialiasing != null)
		{
			noAntialiasing = characterDef.noAntialiasing;
		}

		if (Options.profile.globalAntialiasing)
		{
			antialiasing = !noAntialiasing;
		}
		else
		{
			antialiasing = false;
		}

		if (characterDef.healthBarColors != null && characterDef.healthBarColors.length >= 3)
		{
			healthBarColor = FlxColor.fromRGB(characterDef.healthBarColors[0], characterDef.healthBarColors[1], characterDef.healthBarColors[2]);
		}

		if (characterDef.cameraMotionFactor != null)
		{
			cameraMotionFactor = characterDef.cameraMotionFactor;
		}

		if (characterDef.initialAnimation != null)
		{
			initialAnimation = characterDef.initialAnimation;
		}
	}

	public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		specialAnim = false;
		animation.play(animName, force, reversed, frame);

		// /*
		offset.set();
		if (animOffsets.exists(animName))
		{
			var animOffset:Array<Float> = animOffsets.get(animName);
			offset.add(animOffset[0], animOffset[1]);

			var hasSwappedRole:Bool = isPlayer != originalFlipX;

			if (hasSwappedRole)
			{
				offset.x = frameWidth - offset.x - originalWidth;
			}
		}
		//  */

		// The below method also fixes the offsets but also affects where the camera points at the character, due to updating the hitbox
		/*
			updateHitbox();
			centerOffsets();
			if (animOffsets.exists(animName))
			{
				var animOffset:Array<Float> = animOffsets.get(animName);
				offset.add(animOffset[0], animOffset[1]);
				if (flipX)
				{
					offset.x = frameWidth - offset.x - originalWidth;
				}
			}
		 */

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
		var songDef:Song = Song.loadSong(id, difficulty, folder);

		var bars:Array<Bar> = songDef.bars;

		for (bar in bars)
		{
			for (note in bar.notes)
			{
				animationNotes.push(note);
			}
		}
		animationNotes.sort(sortAnims);
	}

	private function sortAnims(val1:BasicNote, val2:BasicNote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, val1.beat, val2.beat);
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

	// TODO Make this not do anything in the character editor to avoid confusion
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

	public function quickAnimAdd(name:String, prefix:String):Void
	{
		animation.addByPrefix(name, prefix, 24, false);
	}

	private function set_isPlayer(value:Bool):Bool
	{
		if (isPlayer != value)
		{
			isPlayer = value;
			#if FACING_TEST
			if (isPlayer)
			{
				facing = originalFlipX ? LEFT : RIGHT;
			}
			else
			{
				facing = originalFlipX ? RIGHT : LEFT;
			}
			// if (facing == LEFT)
			// 	facing = RIGHT;
			// else if (facing == RIGHT)
			// 	facing = LEFT;
			facing = facing;
			#else
			flipX = !flipX;
			#end
			leftToRight();
		}
		return value;
	}

	#if FACING_TEST
	private function set_originalFlipX(value:Bool):Bool
	{
		originalFlipX = value;
		setFacingFlip(LEFT, !value, false);
		setFacingFlip(RIGHT, value, false);
		facing = facing;
		return value;
	}
	#end
}

enum CharacterRole
{
	PLAYER;
	OPPONENT;
	GIRLFRIEND;
}

class CharacterRoleTools
{
	public static function createByString(value1:String):CharacterRole
	{
		var charRole:CharacterRole = PLAYER;
		switch (value1.toLowerCase().trim())
		{
			case 'bf' | 'boyfriend' | 'player':
				charRole = PLAYER;
			case 'dad' | 'opponent':
				charRole = OPPONENT;
			case 'gf' | 'girlfriend':
				charRole = GIRLFRIEND;
			default:
				var index:Null<Int> = Std.parseInt(value1);
				if (index != null && index < CharacterRole.createAll().length)
				{
					charRole = CharacterRole.createByIndex(index);
				}
		}
		return charRole;
	}
}
