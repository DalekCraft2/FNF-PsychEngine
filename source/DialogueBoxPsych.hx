package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import haxe.io.Path;

using StringTools;

// TODO Attempt to remove the need for two DialogueBox classes by adding any features from the vanilla one to this one

typedef DialogueCharacterData =
{
	var image:String;
	var dialogue_pos:String;
	var noAntialiasing:Bool;

	var animations:Array<DialogueAnimationData>;
	var position:Array<Float>;
	var scale:Float;
}

typedef DialogueAnimationData =
{
	var anim:String;
	var loop_name:String;
	var loop_offsets:Array<Int>;
	var idle_name:String;
	var idle_offsets:Array<Int>;
}

// Gonna try to kind of make it compatible to Forever Engine,
// love u Shubs no homo :flushedh4:
typedef DialogueData =
{
	var dialogue:Array<DialogueLine>;
}

typedef DialogueLine =
{
	var ?portrait:String;
	var ?expression:String;
	var ?text:String;
	var ?boxState:String;
	var ?speed:Float;
	var ?sound:String;
}

class DialogueCharacter extends FlxSprite
{
	private static final IDLE_SUFFIX:String = '-IDLE';
	public static inline final DEFAULT_CHARACTER:String = 'bf';
	public static final DEFAULT_SCALE:Float = 0.7;

	public var jsonFile:DialogueCharacterData;
	public var dialogueAnimations:Map<String, DialogueAnimationData> = [];

	public var startingPos:Float = 0; // For center characters, it works as the starting Y, for everything else it works as starting X
	public var isGhost:Bool = false; // For the editor
	public var id:String;

	public function new(x:Float = 0, y:Float = 0, id:String = DEFAULT_CHARACTER)
	{
		super(x, y);

		if (id == null)
			id = DEFAULT_CHARACTER;
		this.id = id;

		reloadCharacterJson(id);
		frames = Paths.getSparrowAtlas('dialogue/${jsonFile.image}');
		reloadAnimations();

		antialiasing = Options.save.data.globalAntialiasing;
		if (jsonFile.noAntialiasing)
			antialiasing = false;
	}

	public function reloadCharacterJson(character:String):Void
	{
		var characterData:DialogueCharacterData = Paths.getJson(Path.join(['dialogue', character]));
		if (characterData == null)
		{
			Debug.logError('Could not find dialogue character data for character "$character"; using default');
			characterData = Paths.getJson(Path.join(['dialogue', DEFAULT_CHARACTER]));
		}

		jsonFile = characterData;
	}

	public function reloadAnimations():Void
	{
		dialogueAnimations.clear();
		if (jsonFile.animations != null && jsonFile.animations.length > 0)
		{
			for (anim in jsonFile.animations)
			{
				animation.addByPrefix(anim.anim, anim.loop_name, 24, isGhost);
				animation.addByPrefix(anim.anim + IDLE_SUFFIX, anim.idle_name, 24, true);
				dialogueAnimations.set(anim.anim, anim);
			}
		}
	}

	public function playAnim(?animName:String, playIdle:Bool = false):Void
	{
		var leAnim:String = animName;
		if (animName == null || !dialogueAnimations.exists(animName))
		{ // Anim is null, get a random animation
			var arrayAnims:Array<String> = [];
			for (anim in dialogueAnimations)
			{
				arrayAnims.push(anim.anim);
			}
			if (arrayAnims.length > 0)
			{
				leAnim = arrayAnims[FlxG.random.int(0, arrayAnims.length - 1)];
			}
		}

		if (dialogueAnimations.exists(leAnim)
			&& (dialogueAnimations.get(leAnim).loop_name == null
				|| dialogueAnimations.get(leAnim).loop_name.length < 1
				|| dialogueAnimations.get(leAnim).loop_name == dialogueAnimations.get(leAnim).idle_name))
		{
			playIdle = true;
		}
		animation.play(playIdle ? leAnim + IDLE_SUFFIX : leAnim, false);

		if (dialogueAnimations.exists(leAnim))
		{
			var anim:DialogueAnimationData = dialogueAnimations.get(leAnim);
			if (playIdle)
			{
				offset.set(anim.idle_offsets[0], anim.idle_offsets[1]);
				Debug.logTrace('Setting idle offsets: ${anim.idle_offsets}');
			}
			else
			{
				offset.set(anim.loop_offsets[0], anim.loop_offsets[1]);
				Debug.logTrace('Setting loop offsets: ${anim.loop_offsets}');
			}
		}
		else
		{
			offset.set(0, 0);
			Debug.logWarn('Offsets not found! Dialogue character is badly formatted, anim: $leAnim, ${playIdle ? 'idle anim' : 'loop anim'}');
		}
	}

	public function animationIsLoop():Bool
	{
		if (animation.curAnim == null)
			return false;
		return !animation.curAnim.name.endsWith(IDLE_SUFFIX);
	}
}

// TODO: Clean code? Maybe? idk
class DialogueBoxPsych extends FlxSpriteGroup
{
	private var dialogue:Alphabet;
	private var dialogueList:DialogueData;

	public var finishThing:() -> Void;
	public var nextDialogueThing:() -> Void;
	public var skipDialogueThing:() -> Void;

	private var bgFade:FlxSprite;
	private var box:FlxSprite;
	private var textToType:String = '';

	private var arrayCharacters:Array<DialogueCharacter> = [];

	private var currentText:Int = 0;

	private static final OFFSET:Float = -600;

	private var textBoxTypes:Array<String> = ['normal', 'angry'];

	public function new(dialogueList:DialogueData, ?song:String)
	{
		super();

		if (song != null && song != '')
		{
			FlxG.sound.playMusic(Paths.getMusic(song), 0);
			FlxG.sound.music.fadeIn(2, 0, 1);
		}

		bgFade = new FlxSprite(-500, -500).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.WHITE);
		bgFade.scrollFactor.set();
		bgFade.visible = true;
		bgFade.alpha = 0;
		add(bgFade);

		this.dialogueList = dialogueList;
		spawnCharacters();

		box = new FlxSprite(70, 370);
		box.frames = Paths.getSparrowAtlas('speech_bubble');
		box.scrollFactor.set();
		box.antialiasing = Options.save.data.globalAntialiasing;
		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('normalOpen', 'Speech Bubble Normal Open', 24, false);
		box.animation.addByPrefix('angry', 'AHH speech bubble', 24);
		box.animation.addByPrefix('angryOpen', 'speech bubble loud open', 24, false);
		box.animation.addByPrefix('center-normal', 'speech bubble middle', 24);
		box.animation.addByPrefix('center-normalOpen', 'Speech Bubble Middle Open', 24, false);
		box.animation.addByPrefix('center-angry', 'AHH Speech Bubble middle', 24);
		box.animation.addByPrefix('center-angryOpen', 'speech bubble Middle loud open', 24, false);
		box.animation.play('normal', true);
		box.visible = false;
		box.setGraphicSize(Std.int(box.width * 0.9));
		box.updateHitbox();
		add(box);

		startNextDialog();
	}

	public static final DEFAULT_TEXT_X:Float = 90;
	public static final DEFAULT_TEXT_Y:Float = 430;

	private var scrollSpeed:Float = 4500;
	private var daText:Alphabet;
	private var ignoreThisFrame:Bool = true; // First frame is reserved for loading dialogue images

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (ignoreThisFrame)
		{
			ignoreThisFrame = false;
			return;
		}

		if (!dialogueEnded)
		{
			bgFade.alpha += 0.5 * elapsed;
			if (bgFade.alpha > 0.5)
				bgFade.alpha = 0.5;

			if (PlayerSettings.player1.controls.ACCEPT)
			{
				if (!daText.finishedText)
				{
					if (daText != null)
					{
						daText.killTheTimer();
						daText.kill();
						remove(daText);
						daText.destroy();
					}
					daText = new Alphabet(DEFAULT_TEXT_X, DEFAULT_TEXT_Y, textToType, false, true, 0.0, 0.7);
					add(daText);

					if (skipDialogueThing != null)
					{
						skipDialogueThing();
					}
				}
				else if (currentText >= dialogueList.dialogue.length)
				{
					dialogueEnded = true;
					for (textBoxType in textBoxTypes)
					{
						var checkArray:Array<String> = ['', 'center-'];
						var animName:String = box.animation.curAnim.name;
						for (prefix in checkArray)
						{
							if (animName == prefix + textBoxType || animName == '$prefix${textBoxType}Open')
							{
								box.animation.play('$prefix${textBoxType}Open', true);
							}
						}
					}

					box.animation.curAnim.curFrame = box.animation.curAnim.frames.length - 1;
					box.animation.curAnim.reverse();
					daText.kill();
					remove(daText);
					daText.destroy();
					daText = null;
					updateBoxOffsets(box);
					FlxG.sound.music.fadeOut(1, 0);
				}
				else
				{
					startNextDialog();
				}
				FlxG.sound.play(Paths.getSound('dialogueClose'));
			}
			else if (daText.finishedText)
			{
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if (char != null && char.animation.curAnim != null && char.animationIsLoop() && char.animation.finished)
				{
					char.playAnim(char.animation.curAnim.name, true);
				}
			}
			else
			{
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if (char != null && char.animation.curAnim != null && char.animation.finished)
				{
					char.animation.curAnim.restart();
				}
			}

			if (box.animation.curAnim.finished)
			{
				for (textBoxType in textBoxTypes)
				{
					var checkArray:Array<String> = ['', 'center-'];
					var animName:String = box.animation.curAnim.name;
					for (prefix in checkArray)
					{
						if (animName == prefix + textBoxType || animName == '$prefix${textBoxType}Open')
						{
							box.animation.play('$prefix$textBoxType', true);
						}
					}
				}
				updateBoxOffsets(box);
			}

			if (lastCharacter != -1 && arrayCharacters.length > 0)
			{
				for (i in 0...arrayCharacters.length)
				{
					var char:DialogueCharacter = arrayCharacters[i];
					if (char != null)
					{
						if (i != lastCharacter)
						{
							switch (char.jsonFile.dialogue_pos)
							{
								case 'left':
									char.x -= scrollSpeed * elapsed;
									if (char.x < char.startingPos + OFFSET)
										char.x = char.startingPos + OFFSET;
								case 'center':
									char.y += scrollSpeed * elapsed;
									if (char.y > char.startingPos + FlxG.height)
										char.y = char.startingPos + FlxG.height;
								case 'right':
									char.x += scrollSpeed * elapsed;
									if (char.x > char.startingPos - OFFSET)
										char.x = char.startingPos - OFFSET;
							}
							char.alpha -= 3 * elapsed;
							if (char.alpha < 0.00001)
								char.alpha = 0.00001;
						}
						else
						{
							switch (char.jsonFile.dialogue_pos)
							{
								case 'left':
									char.x += scrollSpeed * elapsed;
									if (char.x > char.startingPos)
										char.x = char.startingPos;
								case 'center':
									char.y -= scrollSpeed * elapsed;
									if (char.y < char.startingPos)
										char.y = char.startingPos;
								case 'right':
									char.x -= scrollSpeed * elapsed;
									if (char.x < char.startingPos)
										char.x = char.startingPos;
							}
							char.alpha += 3 * elapsed;
							if (char.alpha > 1)
								char.alpha = 1;
						}
					}
				}
			}
		}
		else
		{ // Dialogue ending
			if (box != null && box.animation.curAnim.curFrame <= 0)
			{
				box.kill();
				remove(box);
				box.destroy();
				box = null;
			}

			if (bgFade != null)
			{
				bgFade.alpha -= 0.5 * elapsed;
				if (bgFade.alpha <= 0)
				{
					bgFade.kill();
					remove(bgFade);
					bgFade.destroy();
					bgFade = null;
				}
			}

			for (character in arrayCharacters)
			{
				if (character != null)
				{
					switch (character.jsonFile.dialogue_pos)
					{
						case 'left':
							character.x -= scrollSpeed * elapsed;
						case 'center':
							character.y += scrollSpeed * elapsed;
						case 'right':
							character.x += scrollSpeed * elapsed;
					}
					character.alpha -= elapsed * 10;
				}
			}

			if (box == null && bgFade == null)
			{
				for (i in 0...arrayCharacters.length)
				{
					var leChar:DialogueCharacter = arrayCharacters[0];
					if (leChar != null)
					{
						arrayCharacters.remove(leChar);
						leChar.kill();
						remove(leChar);
						leChar.destroy();
					}
				}
				finishThing();
				kill();
			}
		}
	}

	private var dialogueStarted:Bool = false;
	private var dialogueEnded:Bool = false;

	public static final LEFT_CHAR_X:Float = -60;
	public static final RIGHT_CHAR_X:Float = -100;
	public static final DEFAULT_CHAR_Y:Float = 60;

	private function spawnCharacters():Void
	{
		var charsMap:Map<String, Bool> = [];
		for (dialogueLine in dialogueList.dialogue)
		{
			if (dialogueLine != null)
			{
				var charToAdd:String = dialogueLine.portrait;
				if (!charsMap.exists(charToAdd) || !charsMap.get(charToAdd))
				{
					charsMap.set(charToAdd, true);
				}
			}
		}

		for (individualChar in charsMap.keys())
		{
			var x:Float = LEFT_CHAR_X;
			var y:Float = DEFAULT_CHAR_Y;
			var char:DialogueCharacter = new DialogueCharacter(x + OFFSET, y, individualChar);
			char.setGraphicSize(Std.int(char.width * DialogueCharacter.DEFAULT_SCALE * char.jsonFile.scale));
			char.updateHitbox();
			char.scrollFactor.set();
			char.alpha = 0.00001;
			add(char);

			var saveY:Bool = false;
			switch (char.jsonFile.dialogue_pos)
			{
				case 'center':
					char.x = FlxG.width / 2;
					char.x -= char.width / 2;
					y = char.y;
					char.y = FlxG.height + 50;
					saveY = true;
				case 'right':
					x = FlxG.width - char.width + RIGHT_CHAR_X;
					char.x = x - OFFSET;
			}
			x += char.jsonFile.position[0];
			y += char.jsonFile.position[1];
			char.x += char.jsonFile.position[0];
			char.y += char.jsonFile.position[1];
			char.startingPos = (saveY ? y : x);
			arrayCharacters.push(char);
		}
	}

	private var lastCharacter:Int = -1;
	private var lastBoxType:String = '';

	private function startNextDialog():Void
	{
		var curDialogue:DialogueLine;
		do
		{
			curDialogue = dialogueList.dialogue[currentText];
		}
		while (curDialogue == null);

		if (curDialogue.text == null || curDialogue.text.length < 1)
			curDialogue.text = ' ';
		if (curDialogue.boxState == null)
			curDialogue.boxState = 'normal';
		if (curDialogue.speed == null || Math.isNaN(curDialogue.speed))
			curDialogue.speed = 0.05;

		var animName:String = curDialogue.boxState;
		var boxType:String = textBoxTypes[0];
		for (textBoxType in textBoxTypes)
		{
			if (textBoxType == animName)
			{
				boxType = animName;
			}
		}

		var character:Int = 0;
		box.visible = true;
		for (i in 0...arrayCharacters.length)
		{
			var char:DialogueCharacter = arrayCharacters[i];
			if (char.id == curDialogue.portrait)
			{
				character = i;
				break;
			}
		}
		var centerPrefix:String = '';
		var lePosition:String = arrayCharacters[character].jsonFile.dialogue_pos;
		if (lePosition == 'center')
			centerPrefix = 'center-';

		if (character != lastCharacter)
		{
			box.animation.play('$centerPrefix${boxType}Open', true);
			updateBoxOffsets(box);
			box.flipX = (lePosition == 'left');
		}
		else if (boxType != lastBoxType)
		{
			box.animation.play(centerPrefix + boxType, true);
			updateBoxOffsets(box);
		}
		lastCharacter = character;
		lastBoxType = boxType;

		if (daText != null)
		{
			daText.killTheTimer();
			daText.kill();
			remove(daText);
			daText.destroy();
		}

		textToType = curDialogue.text;
		Alphabet.setDialogueSound(curDialogue.sound);
		daText = new Alphabet(DEFAULT_TEXT_X, DEFAULT_TEXT_Y, textToType, false, true, curDialogue.speed, 0.7);
		add(daText);

		var char:DialogueCharacter = arrayCharacters[character];
		if (char != null)
		{
			char.playAnim(curDialogue.expression, daText.finishedText);
			if (char.animation.curAnim != null)
			{
				var rate:Float = 24 - (((curDialogue.speed - 0.05) / 5) * 480);
				if (rate < 12)
					rate = 12;
				else if (rate > 48)
					rate = 48;
				char.animation.curAnim.frameRate = rate;
			}
		}
		currentText++;

		if (nextDialogueThing != null)
		{
			nextDialogueThing();
		}
	}

	public static function updateBoxOffsets(box:FlxSprite):Void
	{ // Had to make it static because of the editors
		box.centerOffsets();
		box.updateHitbox();
		if (box.animation.curAnim.name.startsWith('angry'))
		{
			box.offset.set(50, 65);
		}
		else if (box.animation.curAnim.name.startsWith('center-angry'))
		{
			box.offset.set(50, 30);
		}
		else
		{
			box.offset.set(10, 0);
		}

		if (!box.flipX)
			box.offset.y += 10;
	}
}
