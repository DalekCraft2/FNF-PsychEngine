package;

import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import openfl.utils.Assets;
#if FEATURE_MODS
import sys.FileSystem;
#end

using StringTools;

typedef CharacterData =
{
	var animations:Array<AnimationData>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;
	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var ?cam_movement_mult:Float;
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

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Float>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	// TODO Figure out what the below variable is
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimationData> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var camMovementMult:Float = 1;

	public var hasMissAnimations:Bool = false;

	// Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static final DEFAULT_CHARACTER:String = 'bf'; // In case a character is missing, it will use BF on its place

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = [];
		curCharacter = character;
		this.isPlayer = isPlayer;
		antialiasing = Options.save.data.globalAntialiasing;
		switch (curCharacter)
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

		if (animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss'))
			hasMissAnimations = true;
		recalculateDanceIdle();
		dance();

		if (isPlayer)
		{
			flipX = !flipX;
		}
	}

	function parseDataFile():Void
	{
		var characterPath:String = 'characters/$curCharacter';

		var characterData:CharacterData = Paths.getJson(characterPath);
		if (characterData == null)
		{
			Debug.logError('Could not find character data for character "$curCharacter"; using default');
			characterData = Paths.getJson('characters/$DEFAULT_CHARACTER');
		}

		var spriteType:String = "sparrow";
		// sparrow
		// packer
		// texture
		var txtToFind:String = Paths.getPath('images/${characterData.image}.txt', TEXT);
		#if FEATURE_MODS
		if (FileSystem.exists(txtToFind) || Assets.exists(txtToFind))
		#else
		if (Assets.exists(txtToFind))
		#end
		{
			spriteType = "packer";
		}

		var animToFind:String = Paths.getPath('images/${characterData.image}/Animation.json', TEXT);
		#if FEATURE_MODS
		if (FileSystem.exists(animToFind) || Assets.exists(animToFind))
		#else
		if (Assets.exists(animToFind))
		#end
		{
			spriteType = "texture";
		}

		switch (spriteType)
		{
			case "packer":
				frames = Paths.getPackerAtlas(characterData.image);

			case "sparrow":
				frames = Paths.getSparrowAtlas(characterData.image);

			case "texture":
				frames = AtlasFrameMaker.construct(characterData.image);
		}
		imageFile = characterData.image;

		if (characterData.scale != 1)
		{
			jsonScale = characterData.scale;
			setGraphicSize(Std.int(width * jsonScale));
			updateHitbox();
		}

		positionArray = characterData.position;
		cameraPosition = characterData.camera_position;
		if (characterData.cam_movement_mult != null)
			camMovementMult = characterData.cam_movement_mult;

		healthIcon = characterData.healthicon;
		singDuration = characterData.sing_duration;
		flipX = characterData.flip_x;
		if (characterData.no_antialiasing)
		{
			antialiasing = false;
			noAntialiasing = true;
		}

		if (characterData.healthbar_colors != null && characterData.healthbar_colors.length > 2)
			healthColorArray = characterData.healthbar_colors;

		antialiasing = !noAntialiasing;
		if (!Options.save.data.globalAntialiasing)
			antialiasing = false;

		animationsArray = characterData.animations;
		if (animationsArray != null && animationsArray.length > 0)
		{
			for (anim in animationsArray)
			{
				var animAnim:String = anim.anim;
				var animName:String = anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = anim.loop;
				var animIndices:Array<Int> = anim.indices;
				if (animIndices != null && animIndices.length > 0)
				{
					animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
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
		}
		else
		{
			quickAnimAdd('idle', 'BF idle dance');
		}
		Debug.logTrace('Loaded data file for character "$curCharacter"');
	}

	override function update(elapsed:Float):Void
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

			switch (curCharacter)
			{
				case 'pico-speaker':
					if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
					{
						var shootAnim = 1;

						if (animationNotes[0][1] >= 2)
							shootAnim = 3;

						shootAnim += FlxG.random.int(0, 1);
						playAnim("shoot" + shootAnim, true);

						animationNotes.shift();
					}
			}

			if (animation.curAnim.finished && animation.getByName(animation.curAnim.name + '-loop') != null)
			{
				playAnim(animation.curAnim.name + '-loop');
			}
		}
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
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if (animation.getByName('idle' + idleSuffix) != null)
			{
				playAnim('idle' + idleSuffix);
			}
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset:Array<Float> = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (curCharacter.startsWith('gf'))
		{
			if (AnimName == 'singLEFT')
			{
				danced = true;
			}
			else if (AnimName == 'singRIGHT')
			{
				danced = false;
			}

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
			{
				danced = !danced;
			}
		}
	}

	public function loadMappedAnims()
	{
		var pico = Song.loadFromJson("pico-speaker", "", "stress");
		var notes = pico.notes;

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

	function sortAnims(val1:Array<Dynamic>, val2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, val1[0], val2[0]);
	}

	public var danceEveryNumBeats:Int = 2;

	private var settingCharacterUp:Bool = true;

	public function recalculateDanceIdle():Void
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

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

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String):Void
	{
		animation.addByPrefix(name, anim, 24, false);
	}
}
