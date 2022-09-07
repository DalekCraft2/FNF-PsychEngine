package funkin;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.text.FlxTypeText;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.states.PlayState;
import haxe.io.Path;

using StringTools;

class DialogueBox extends FlxSpriteGroup
{
	public var finishThing:() -> Void;
	public var nextDialogueThing:() -> Void;
	public var skipDialogueThing:() -> Void;

	private var songId:String;
	private var box:FlxSprite;
	private var curCharacter:String = '';
	private var dialogueList:Array<String> = [];
	private var dialogue:FlxTypeText;
	private var dropText:FlxText;
	private var portraitLeft:FlxSprite;
	private var portraitRight:FlxSprite;
	private var handSelect:FlxSprite;
	private var bgFade:FlxSprite;

	public function new(songId:String, ?dialogueList:Array<String>)
	{
		super();

		this.songId = songId;
		this.dialogueList = dialogueList;

		switch (songId)
		{
			case 'senpai':
				FlxG.sound.playMusic(Paths.getMusic('Lunchbox'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
			case 'thorns':
				FlxG.sound.playMusic(Paths.getMusic('LunchboxScary'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
		}

		bgFade = new FlxSprite(-200, -200).makeGraphic(Std.int(FlxG.width * 1.3), Std.int(FlxG.height * 1.3), 0xFFB3DFD8);
		bgFade.scrollFactor.set();
		bgFade.alpha = 0;
		add(bgFade);

		new FlxTimer().start(0.83, (tmr:FlxTimer) ->
		{
			bgFade.alpha += (1 / 5) * 0.7;
			if (bgFade.alpha > 0.7)
				bgFade.alpha = 0.7;
		}, 5);

		box = new FlxSprite(-20, 45);

		var hasDialog:Bool = false;
		switch (songId)
		{
			case 'senpai':
				hasDialog = true;
				box.frames = Paths.getFrames(Path.join(['dialogue', 'boxes', 'dialogueBox-pixel']));
				box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
				box.animation.addByIndices('normal', 'Text Box Appear instance 1', [4], '', 24);
			case 'roses':
				hasDialog = true;
				box.frames = Paths.getFrames(Path.join(['dialogue', 'boxes', 'dialogueBox-senpaiMad']));
				box.animation.addByPrefix('normalOpen', 'SENPAI ANGRY IMPACT SPEECH', 24, false);
				box.animation.addByIndices('normal', 'SENPAI ANGRY IMPACT SPEECH instance 1', [4], '', 24);

				FlxG.sound.play(Paths.getSound('ANGRY_TEXT_BOX'));
			case 'thorns':
				hasDialog = true;
				box.frames = Paths.getFrames(Path.join(['dialogue', 'boxes', 'dialogueBox-evil']));
				box.animation.addByPrefix('normalOpen', 'Spirit Textbox spawn', 24, false);
				box.animation.addByIndices('normal', 'Spirit Textbox spawn instance 1', [11], '', 24);
		}

		if (!hasDialog)
			return;

		if (songId == 'thorns')
		{
			portraitLeft = new FlxSprite(200, -90).loadGraphic(Paths.getGraphic(Path.join(['dialogue', 'portraits', 'spiritFaceForward'])));
			portraitLeft.scale.set(PlayState.PIXEL_ZOOM, PlayState.PIXEL_ZOOM);
			portraitLeft.updateHitbox();
			portraitLeft.scrollFactor.set();
		}
		else
		{
			portraitLeft = new FlxSprite(0, 40);
			portraitLeft.frames = Paths.getFrames(Path.join(['dialogue', 'portraits', 'senpaiPortrait']));
			portraitLeft.animation.addByPrefix('enter', 'Senpai Portrait Enter', 24, false);
			portraitLeft.scale.set(PlayState.PIXEL_ZOOM * 0.9, PlayState.PIXEL_ZOOM * 0.9);
			portraitLeft.updateHitbox();
			portraitLeft.scrollFactor.set();
			portraitLeft.visible = false;
			portraitLeft.screenCenter(X);
		}
		add(portraitLeft);

		portraitRight = new FlxSprite(0, 40);
		portraitRight.frames = Paths.getFrames(Path.join(['dialogue', 'portraits', 'bfPortrait']));
		portraitRight.animation.addByPrefix('enter', 'Boyfriend portrait enter', 24, false);
		portraitRight.scale.set(PlayState.PIXEL_ZOOM * 0.9, PlayState.PIXEL_ZOOM * 0.9);
		portraitRight.updateHitbox();
		portraitRight.scrollFactor.set();
		portraitRight.visible = false;
		add(portraitRight);

		box.animation.play('normalOpen');
		box.scale.set(PlayState.PIXEL_ZOOM * 0.9, PlayState.PIXEL_ZOOM * 0.9);
		box.updateHitbox();
		box.screenCenter(X);
		add(box);

		handSelect = new FlxSprite(1042, 590).loadGraphic(Paths.getGraphic(Path.join(['dialogue', 'boxes', 'hand_textbox'])));
		handSelect.scale.set(PlayState.PIXEL_ZOOM * 0.9, PlayState.PIXEL_ZOOM * 0.9);
		handSelect.updateHitbox();
		handSelect.visible = false;
		add(handSelect);

		dropText = new FlxText(242, 502, FlxG.width * 0.6, 32);
		dropText.setFormat('Pixel Arial 11 Bold', dropText.size, 0xFFD89494);
		add(dropText);

		dialogue = new FlxTypeText(240, 500, Std.int(FlxG.width * 0.6), '', 32);
		dialogue.setFormat('Pixel Arial 11 Bold', dialogue.size, 0xFF3F2021);
		dialogue.sounds = [FlxG.sound.load(Paths.getSound('pixelText'), 0.6)];
		add(dialogue);

		if (songId == 'roses')
			portraitLeft.visible = false;
		else if (songId == 'thorns')
		{
			dialogue.color = FlxColor.WHITE;
			dropText.color = FlxColor.BLACK;
		}
	}

	private var dialogueOpened:Bool = false;
	private var dialogueStarted:Bool = false;
	private var dialogueEnded:Bool = false;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		dropText.text = dialogue.text;

		if (box.animation.curAnim != null)
		{
			if (box.animation.name == 'normalOpen' && box.animation.finished)
			{
				box.animation.play('normal');
				dialogueOpened = true;
			}
		}

		if (dialogueOpened && !dialogueStarted)
		{
			startDialogue();
			dialogueStarted = true;
		}

		if (PlayerSettings.player1.controls.ACCEPT)
		{
			if (dialogueEnded)
			{
				if (dialogueList[1] == null && dialogueList[0] != null)
				{
					if (!isEnding)
					{
						isEnding = true;
						FlxG.sound.play(Paths.getSound('clickText'), 0.8);

						if (songId == 'senpai' || songId == 'thorns')
							FlxG.sound.music.fadeOut(1.5, 0);

						new FlxTimer().start(0.2, (tmr:FlxTimer) ->
						{
							box.alpha -= 1 / 5;
							bgFade.alpha -= 1 / 5 * 0.7;
							portraitLeft.alpha -= 1 / 5;
							portraitRight.alpha -= 1 / 5;
							dialogue.alpha -= 1 / 5;
							handSelect.alpha -= 1 / 5;
							dropText.alpha = dialogue.alpha;
						}, 5);

						new FlxTimer().start(1.5, (tmr:FlxTimer) ->
						{
							if (finishThing != null)
								finishThing();
							kill();
						});
					}
				}
				else
				{
					dialogueList.shift();
					startDialogue();
					FlxG.sound.play(Paths.getSound('clickText'), 0.8);
				}
			}
			else if (dialogueStarted)
			{
				FlxG.sound.play(Paths.getSound('clickText'), 0.8);
				dialogue.skip();

				if (skipDialogueThing != null)
				{
					skipDialogueThing();
				}
			}
		}
	}

	private var isEnding:Bool = false;

	private function startDialogue():Void
	{
		cleanDialog();

		dialogue.resetText(dialogueList[0]);
		dialogue.start(0.04, true);
		dialogue.completeCallback = () ->
		{
			handSelect.visible = true;
			dialogueEnded = true;
		};

		handSelect.visible = false;
		dialogueEnded = false;
		switch (curCharacter)
		{
			case 'dad' | 'opponent':
				portraitRight.visible = false;
				if (!portraitLeft.visible)
				{
					if (songId == 'senpai' || songId == 'thorns')
					{
						portraitLeft.visible = true;
						if (songId == 'senpai')
							portraitLeft.animation.play('enter');
					}
				}
			case 'bf':
				portraitLeft.visible = false;
				if (!portraitRight.visible)
				{
					portraitRight.visible = true;
					portraitRight.animation.play('enter');
				}
		}
		if (nextDialogueThing != null)
		{
			nextDialogueThing();
		}
	}

	private function cleanDialog():Void
	{
		var splitName:Array<String> = dialogueList[0].split(':');
		curCharacter = splitName[1];
		dialogueList[0] = dialogueList[0].substr(splitName[1].length + 2).trim();
	}
}
