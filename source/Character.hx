package;

import animateatlas.AtlasFrameMaker;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import openfl.utils.Assets;
import options.Options.OptionUtils;
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
		antialiasing = OptionUtils.options.globalAntialiasing;
		switch (curCharacter)
		{
			// case 'your character name in case you want to hardcode them instead':

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

		var rawJson:Dynamic = Paths.loadJson(characterPath);
		if (rawJson == null)
		{
			rawJson = Paths.loadJson('characters/$DEFAULT_CHARACTER');
		}

		var characterData:CharacterData = cast rawJson;
		var spriteType:String = "sparrow";
		// sparrow
		// packer
		// texture
		#if FEATURE_MODS
		var modTxtToFind:String = Paths.modsTxt(characterData.image);
		var txtToFind:String = Paths.getPath('images/${characterData.image}.txt', TEXT);

		// var modTextureToFind:String = Paths.modFolders('images/${characterData.image}');
		// var textureToFind:String = Paths.getPath('images/${characterData.image}', new AssetType());

		if (FileSystem.exists(modTxtToFind) || FileSystem.exists(txtToFind) || Assets.exists(txtToFind))
		#else
		if (Assets.exists(Paths.getPath('images/${characterData.image}.txt', TEXT)))
		#end
		{
			spriteType = "packer";
		}

		#if FEATURE_MODS
		var modAnimToFind:String = Paths.modFolders('images/${characterData.image}/Animation.json');
		var animToFind:String = Paths.getPath('images/${characterData.image}/Animation.json', TEXT);

		// var modTextureToFind:String = Paths.modFolders('images/${characterData.image}');
		// var textureToFind:String = Paths.getPath('images/${characterData.image}', new AssetType());

		if (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind))
		#else
		if (Assets.exists(Paths.getPath('images/${characterData.image}/Animation.json', TEXT)))
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
		if (!OptionUtils.options.globalAntialiasing)
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

		// I'm frickin' cheating.
		if (PlayState.instance != null)
			PlayState.instance.updateDirectionalCamera();
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
