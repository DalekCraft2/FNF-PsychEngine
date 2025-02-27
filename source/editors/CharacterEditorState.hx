package editors;

import Character.AnimationDef;
import Character.CharacterDef;
import animateatlas.AtlasFrameMaker;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.animation.FlxAnimation;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

/**
 * DEBUG MODE
 */
class CharacterEditorState extends MusicBeatState
{
	private static final TIP_TEXT:String = 'E/Q - Camera Zoom In/Out\nR - Reset Camera Zoom\nJKLI - Move Camera\nW/S - Previous/Next Animation\nSpace - Play Animation\nArrow Keys - Move Character OffsetnT - Reset Current Offset\nHold Shift to Move 10x faster';

	private static final OFFSET_X:Float = 300;

	private var char:Character;
	private var ghostChar:Character;
	private var textAnim:FlxText;
	private var bgLayer:FlxTypedGroup<FlxSprite>;
	private var charLayer:FlxTypedGroup<Character>;
	private var dumbTexts:FlxTypedGroup<FlxText>;
	private var animList:Array<String> = [];
	private var curAnim:Int = 0;
	private var charId:String;
	private var goToPlayState:Bool;
	private var camFollow:FlxObject;

	public function new(charId:String = Character.DEFAULT_CHARACTER, goToPlayState:Bool = true)
	{
		super();

		this.charId = charId;
		this.goToPlayState = goToPlayState;
	}

	private var uiBox:FlxUITabMenu;
	private var uiCharacterBox:FlxUITabMenu;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;
	private var camMenu:FlxCamera;

	private var changeBGbutton:FlxButton;
	private var healthIcon:HealthIcon;
	private var characterList:Array<String> = [];

	private var cameraFollowPointer:FlxSprite;
	private var healthBarBG:FlxSprite;

	override public function create():Void
	{
		super.create();

		camEditor = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camMenu = new FlxCamera();
		camMenu.bgColor.alpha = 0;

		FlxG.cameras.reset(camEditor);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camMenu, false);

		bgLayer = new FlxTypedGroup();
		add(bgLayer);
		charLayer = new FlxTypedGroup();
		add(charLayer);

		var pointer:FlxGraphicAsset = FlxGraphic.fromClass(GraphicCursorCross);
		cameraFollowPointer = new FlxSprite().loadGraphic(pointer);
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		cameraFollowPointer.color = FlxColor.WHITE;
		add(cameraFollowPointer);

		changeBGbutton = new FlxButton(FlxG.width - 360, 25, () ->
		{
			onPixelBG = !onPixelBG;
			reloadBGs();
		});
		changeBGbutton.cameras = [camMenu];

		loadChar(charId.startsWith('bf'), false);

		healthBarBG = new FlxSprite(30, FlxG.height - 75).loadGraphic(Paths.getGraphic('healthBar'));
		healthBarBG.scrollFactor.set();
		add(healthBarBG);
		healthBarBG.cameras = [camHUD];

		healthIcon = new HealthIcon(char.healthIcon, false);
		healthIcon.y = FlxG.height - 150;
		add(healthIcon);
		healthIcon.cameras = [camHUD];

		dumbTexts = new FlxTypedGroup();
		add(dumbTexts);
		dumbTexts.cameras = [camHUD];

		textAnim = new FlxText(300, 16, 0, 16);
		textAnim.setFormat(Paths.font('vcr.ttf'), textAnim.size, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		textAnim.borderSize = 1;
		textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);

		genBoyOffsets();

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);

		var tipText:FlxText = new FlxText(FlxG.width - 320, FlxG.height - 15 - 16 * TIP_TEXT.split('\n').length, 300, TIP_TEXT, 12);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, tipText.size, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		add(tipText);

		FlxG.camera.follow(camFollow);

		var tabs:Array<{name:String, label:String}> = [{name: 'Offsets', label: 'Offsets'}, {name: 'Settings', label: 'Settings'},];

		uiBox = new FlxUITabMenu(null, tabs, true);
		uiBox.cameras = [camMenu];

		uiBox.resize(250, 120);
		uiBox.x = FlxG.width - 275;
		uiBox.y = 25;
		uiBox.scrollFactor.set();

		var tabs:Array<{name:String, label:String}> = [
			{name: 'Character', label: 'Character'},
			{name: 'Animations', label: 'Animations'},
		];
		uiCharacterBox = new FlxUITabMenu(null, tabs, true);
		uiCharacterBox.cameras = [camMenu];

		uiCharacterBox.resize(350, 250);
		uiCharacterBox.x = uiBox.x - 100;
		uiCharacterBox.y = uiBox.y + uiBox.height;
		uiCharacterBox.scrollFactor.set();
		add(uiCharacterBox);
		add(uiBox);
		add(changeBGbutton);

		addOffsetsUI();
		addSettingsUI();

		addCharacterUI();
		addAnimationsUI();
		uiCharacterBox.selected_tab_id = 'Character';

		FlxG.mouse.visible = true;
		reloadCharacterOptions();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (char.animationsArray[curAnim] != null)
		{
			textAnim.text = char.animationsArray[curAnim].name;

			var curAnim:FlxAnimation = char.animation.getByName(char.animationsArray[curAnim].name);
			if (curAnim == null || curAnim.frames.length < 1)
			{
				textAnim.text += ' (ERROR!)';
			}
		}
		else
		{
			textAnim.text = '';
		}

		var inputTexts:Array<FlxUIInputText> = [
			animationInputText,
			imageInputText,
			healthIconInputText,
			animationNameInputText,
			animationIndicesInputText
		];
		for (inputText in inputTexts)
		{
			if (inputText.hasFocus)
			{
				if (FlxG.keys.pressed.CONTROL
					&& FlxG.keys.justPressed.V
					&& Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT) != null)
				{ // Copy paste
					inputText.text = clipboardAdd(inputText.text);
					inputText.caretIndex = inputText.text.length;
					getEvent(FlxUIInputText.CHANGE_EVENT, inputText, null, []);
				}
				if (FlxG.keys.justPressed.ENTER)
				{
					inputText.hasFocus = false;
				}
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				return;
			}
		}
		FlxG.sound.muteKeys = InitState.muteKeys;
		FlxG.sound.volumeDownKeys = InitState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = InitState.volumeUpKeys;

		if (!charDropDown.dropPanel.visible)
		{
			if (FlxG.keys.justPressed.ESCAPE)
			{
				if (goToPlayState)
				{
					FlxG.switchState(new PlayState());
				}
				else
				{
					FlxG.switchState(new MasterEditorMenuState());
				}
				FlxG.mouse.visible = false;
				return;
			}

			if (FlxG.keys.justPressed.R)
			{
				FlxG.camera.zoom = 1;
			}

			if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3)
			{
				FlxG.camera.zoom += elapsed * FlxG.camera.zoom;
				if (FlxG.camera.zoom > 3)
					FlxG.camera.zoom = 3;
			}
			if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1)
			{
				FlxG.camera.zoom -= elapsed * FlxG.camera.zoom;
				if (FlxG.camera.zoom < 0.1)
					FlxG.camera.zoom = 0.1;
			}

			if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L)
			{
				var addToCam:Float = 500 * elapsed;
				if (FlxG.keys.pressed.SHIFT)
					addToCam *= 4;

				if (FlxG.keys.pressed.I)
					camFollow.y -= addToCam;
				else if (FlxG.keys.pressed.K)
					camFollow.y += addToCam;

				if (FlxG.keys.pressed.J)
					camFollow.x -= addToCam;
				else if (FlxG.keys.pressed.L)
					camFollow.x += addToCam;
			}

			if (char.animationsArray.length > 0)
			{
				if (FlxG.keys.justPressed.W)
				{
					curAnim -= 1;
				}

				if (FlxG.keys.justPressed.S)
				{
					curAnim += 1;
				}

				if (curAnim < 0)
					curAnim = char.animationsArray.length - 1;

				if (curAnim >= char.animationsArray.length)
					curAnim = 0;

				if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
				{
					char.playAnim(char.animationsArray[curAnim].name, true);
					genBoyOffsets();
				}
				if (FlxG.keys.justPressed.T)
				{
					char.animationsArray[curAnim].offsets = [0, 0];

					char.addOffset(char.animationsArray[curAnim].name, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
					ghostChar.addOffset(char.animationsArray[curAnim].name, char.animationsArray[curAnim].offsets[0],
						char.animationsArray[curAnim].offsets[1]);
					genBoyOffsets();
				}

				var controlArray:Array<Bool> = [
					FlxG.keys.justPressed.LEFT,
					FlxG.keys.justPressed.RIGHT,
					FlxG.keys.justPressed.UP,
					FlxG.keys.justPressed.DOWN
				];

				for (i in 0...controlArray.length)
				{
					if (controlArray[i])
					{
						var holdShift:Bool = FlxG.keys.pressed.SHIFT;
						var multiplier:Int = 1;
						if (holdShift)
							multiplier = 10;

						var arrayVal:Int = 0;
						if (i > 1)
							arrayVal = 1;

						var negaMult:Int = 1;
						if (i % 2 == 1)
							negaMult = -1;
						char.animationsArray[curAnim].offsets[arrayVal] += negaMult * multiplier;

						char.addOffset(char.animationsArray[curAnim].name, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
						ghostChar.addOffset(char.animationsArray[curAnim].name, char.animationsArray[curAnim].offsets[0],
							char.animationsArray[curAnim].offsets[1]);

						char.playAnim(char.animationsArray[curAnim].name, false);
						if (ghostChar.animation.curAnim != null
							&& char.animation.curAnim != null
							&& char.animation.curAnim.name == ghostChar.animation.curAnim.name)
						{
							ghostChar.playAnim(char.animation.curAnim.name, false);
						}
						genBoyOffsets();
					}
				}
			}
		}
		// camMenu.zoom = FlxG.camera.zoom;
		ghostChar.setPosition(char.x, char.y);
	}

	override public function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == healthIconInputText)
			{
				healthIcon.changeIcon(healthIconInputText.text);
				char.healthIcon = healthIconInputText.text;
				updatePresence();
			}
			else if (sender == imageInputText)
			{
				char.imageFile = imageInputText.text;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			if (sender == scaleStepper)
			{
				reloadCharacterImage();
				char.jsonScale = sender.value;
				char.setGraphicSize(Std.int(char.width * char.jsonScale));
				char.updateHitbox();
				reloadGhost();
				updatePointerPos();

				if (char.animation.curAnim != null)
				{
					char.playAnim(char.animation.curAnim.name, true);
				}
			}
			else if (sender == positionXStepper)
			{
				char.positionArray[0] = positionXStepper.value;
				char.x = char.positionArray[0] + OFFSET_X + 100;
				updatePointerPos();
			}
			else if (sender == singDurationStepper)
			{
				char.singDuration = singDurationStepper.value; // ermm you forgot this??
			}
			else if (sender == positionYStepper)
			{
				char.positionArray[1] = positionYStepper.value;
				char.y = char.positionArray[1];
				updatePointerPos();
			}
			else if (sender == positionCameraXStepper)
			{
				char.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
			}
			else if (sender == positionCameraYStepper)
			{
				char.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
			}
			else if (sender == healthColorStepperR)
			{
				char.healthBarColors[0] = Math.round(healthColorStepperR.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthBarColors[0], char.healthBarColors[1], char.healthBarColors[2]);
			}
			else if (sender == healthColorStepperG)
			{
				char.healthBarColors[1] = Math.round(healthColorStepperG.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthBarColors[0], char.healthBarColors[1], char.healthBarColors[2]);
			}
			else if (sender == healthColorStepperB)
			{
				char.healthBarColors[2] = Math.round(healthColorStepperB.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthBarColors[0], char.healthBarColors[1], char.healthBarColors[2]);
			}
		}
	}

	private var onPixelBG:Bool = false;

	private function reloadBGs():Void
	{
		var i:Int = bgLayer.members.length - 1;
		while (i >= 0)
		{
			var memb:FlxSprite = bgLayer.members[i];
			if (memb != null)
			{
				memb.kill();
				bgLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		bgLayer.clear();
		var playerXDifference:Float = 0;
		if (char.isPlayer)
			playerXDifference = 670;

		if (onPixelBG)
		{
			var playerYDifference:Float = 0;
			if (char.isPlayer)
			{
				playerXDifference += 200;
				playerYDifference = 220;
			}

			var bgSky:BGSprite = new BGSprite('weeb/weebSky', 'week6', OFFSET_X - (playerXDifference / 2), -playerYDifference, 0.1, 0.1);
			bgLayer.add(bgSky);
			bgSky.antialiasing = false;

			var repositionShit:Float = -200 + OFFSET_X - playerXDifference;

			var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', 'week6', repositionShit, -playerYDifference, 0.6, 0.90);
			bgLayer.add(bgSchool);
			bgSchool.antialiasing = false;

			var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', 'week6', repositionShit, -playerYDifference, 0.95, 0.95);
			bgLayer.add(bgStreet);
			bgStreet.antialiasing = false;

			var widShit:Int = Std.int(bgSky.width * 6);
			var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800 - playerYDifference);
			bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees', 'week6');
			bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
			bgTrees.animation.play('treeLoop');
			bgTrees.scrollFactor.set(0.85, 0.85);
			bgLayer.add(bgTrees);
			bgTrees.antialiasing = false;

			bgSky.setGraphicSize(widShit);
			bgSchool.setGraphicSize(widShit);
			bgStreet.setGraphicSize(widShit);
			bgTrees.setGraphicSize(Std.int(widShit * 1.4));

			bgSky.updateHitbox();
			bgSchool.updateHitbox();
			bgStreet.updateHitbox();
			bgTrees.updateHitbox();
			changeBGbutton.text = 'Regular BG';
		}
		else
		{
			var bg:BGSprite = new BGSprite('stageback', -600 + OFFSET_X - playerXDifference, -300, 0.9, 0.9);
			bgLayer.add(bg);

			var stageFront:BGSprite = new BGSprite('stagefront', -650 + OFFSET_X - playerXDifference, 500, 0.9, 0.9);
			stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
			stageFront.updateHitbox();
			bgLayer.add(stageFront);
			changeBGbutton.text = 'Pixel BG';
		}
	}

	private function addOffsetsUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, uiBox);
		tabGroup.name = 'Offsets';

		animationInputText = new FlxUIInputText(15, 30, 100, 'idle', 8);

		var addButton:FlxButton = new FlxButton(animationInputText.x + animationInputText.width + 23, animationInputText.y - 2, 'Add', () ->
		{
			var theText:String = animationInputText.text;
			if (theText != '')
			{
				var alreadyExists:Bool = false;
				for (anim in animList)
				{
					if (anim == theText)
					{
						alreadyExists = true;
						break;
					}
				}

				if (!alreadyExists)
				{
					char.animOffsets.set(theText, [0, 0]);
					animList.push(theText);
				}
			}
		});

		var removeButton:FlxButton = new FlxButton(animationInputText.x + animationInputText.width + 23, animationInputText.y + 20, 'Remove', () ->
		{
			var theText:String = animationInputText.text;
			if (theText != '')
			{
				for (anim in animList)
				{
					if (anim == theText)
					{
						if (char.animOffsets.exists(theText))
						{
							char.animOffsets.remove(theText);
						}

						animList.remove(theText);
						if (char.animation.curAnim.name == theText && animList.length > 0)
						{
							char.playAnim(animList[0], true);
						}
						break;
					}
				}
			}
		});

		var saveButton:FlxButton = new FlxButton(animationInputText.x, animationInputText.y + 35, 'Save Offsets', () ->
		{
			offsetsFileSaveDialog();
		});

		tabGroup.add(new FlxText(10, animationInputText.y - 18, 0, 'Add/Remove Animation:'));
		tabGroup.add(addButton);
		tabGroup.add(removeButton);
		tabGroup.add(saveButton);
		tabGroup.add(animationInputText);
		uiBox.addGroup(tabGroup);
	}

	private var playerCheckBox:FlxUICheckBox;
	private var charDropDown:FlxUIDropDownMenu;

	private function addSettingsUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, uiBox);
		tabGroup.name = 'Settings';

		playerCheckBox = new FlxUICheckBox(10, 60, null, null, 'Playable Character', 100);
		playerCheckBox.checked = charId.startsWith('bf');
		playerCheckBox.callback = () ->
		{
			char.isPlayer = !char.isPlayer;
			updatePointerPos();
			reloadBGs();
			ghostChar.flipX = char.flipX;
		};

		// TODO Maybe replace this with a file chooser, like the other editors
		charDropDown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), (character:String) ->
		{
			charId = characterList[Std.parseInt(character)];
			playerCheckBox.checked = charId.startsWith('bf');
			loadChar(playerCheckBox.checked);
			updatePresence();
			reloadCharacterDropDown();
		});
		charDropDown.selectedLabel = charId;
		reloadCharacterDropDown();

		var reloadCharacterButton:FlxButton = new FlxButton(140, 20, 'Reload Char', () ->
		{
			loadChar(playerCheckBox.checked);
			reloadCharacterDropDown();
		});

		var templateCharacterButton:FlxButton = new FlxButton(140, 50, 'Load Template', () ->
		{
			var parsedJson:CharacterDef = Character.createTemplateCharacterDef();
			var characters:Array<Character> = [char, ghostChar];
			for (character in characters)
			{
				character.animOffsets.clear();
				character.animationsArray = parsedJson.animations;
				for (anim in character.animationsArray)
				{
					character.addOffset(anim.name, anim.offsets[0], anim.offsets[1]);
				}
				if (character.animationsArray[0] != null)
				{
					character.playAnim(character.animationsArray[0].name, true);
				}

				character.singDuration = parsedJson.singDuration;
				character.positionArray = parsedJson.position;
				character.cameraPosition = parsedJson.cameraPosition;

				character.imageFile = parsedJson.image;
				character.jsonScale = parsedJson.scale;
				character.noAntialiasing = parsedJson.noAntialiasing;
				character.originalFlipX = parsedJson.flipX;
				character.healthIcon = parsedJson.healthIcon;
				character.healthBarColors = parsedJson.healthBarColors;
				character.setPosition(character.positionArray[0] + OFFSET_X + 100, character.positionArray[1]);
			}

			reloadCharacterImage();
			reloadCharacterDropDown();
			reloadCharacterOptions();
			resetHealthBarColor();
			updatePointerPos();
			genBoyOffsets();
		});
		templateCharacterButton.color = FlxColor.RED;
		templateCharacterButton.label.color = FlxColor.WHITE;

		tabGroup.add(new FlxText(charDropDown.x, charDropDown.y - 18, 0, 'Character:'));
		tabGroup.add(playerCheckBox);
		tabGroup.add(reloadCharacterButton);
		tabGroup.add(charDropDown);
		tabGroup.add(reloadCharacterButton);
		tabGroup.add(templateCharacterButton);
		uiBox.addGroup(tabGroup);
	}

	private var imageInputText:FlxUIInputText;
	private var healthIconInputText:FlxUIInputText;

	private var singDurationStepper:FlxUINumericStepper;
	private var scaleStepper:FlxUINumericStepper;
	private var positionXStepper:FlxUINumericStepper;
	private var positionYStepper:FlxUINumericStepper;
	private var positionCameraXStepper:FlxUINumericStepper;
	private var positionCameraYStepper:FlxUINumericStepper;

	private var flipXCheckBox:FlxUICheckBox;
	private var noAntialiasingCheckBox:FlxUICheckBox;

	private var healthColorStepperR:FlxUINumericStepper;
	private var healthColorStepperG:FlxUINumericStepper;
	private var healthColorStepperB:FlxUINumericStepper;

	private function addCharacterUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, uiBox);
		tabGroup.name = 'Character';

		imageInputText = new FlxUIInputText(15, 30, 200, 'BOYFRIEND', 8);
		var reloadImageButton:FlxButton = new FlxButton(imageInputText.x + 210, imageInputText.y - 3, 'Reload Image', () ->
		{
			char.imageFile = imageInputText.text;
			reloadCharacterImage();
			if (char.animation.curAnim != null)
			{
				char.playAnim(char.animation.curAnim.name, true);
			}
		});

		var decideIconColorButton:FlxButton = new FlxButton(reloadImageButton.x, reloadImageButton.y + 30, 'Get Icon Color', () ->
		{
			var coolColor:FlxColor = FlxColor.fromInt(CoolUtil.dominantColor(healthIcon));
			healthColorStepperR.value = coolColor.red;
			healthColorStepperG.value = coolColor.green;
			healthColorStepperB.value = coolColor.blue;
			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperR, null);
			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperG, null);
			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperB, null);
			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperB, null);
			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperB, null);
		});

		healthIconInputText = new FlxUIInputText(15, imageInputText.y + 35, 75, healthIcon.getCharacter(), 8);

		singDurationStepper = new FlxUINumericStepper(15, healthIconInputText.y + 45, 0.1, 4, 0, 999, 1);

		scaleStepper = new FlxUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);

		flipXCheckBox = new FlxUICheckBox(singDurationStepper.x + 80, singDurationStepper.y, null, null, 'Flip X', 50);
		flipXCheckBox.checked = char.flipX;
		if (char.isPlayer)
			flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.callback = () ->
		{
			char.originalFlipX = !char.originalFlipX;
			char.flipX = char.originalFlipX;
			if (char.isPlayer)
				char.flipX = !char.flipX;

			ghostChar.flipX = char.flipX;
		};

		noAntialiasingCheckBox = new FlxUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, null, null, 'No Antialiasing', 80);
		noAntialiasingCheckBox.checked = char.noAntialiasing;
		noAntialiasingCheckBox.callback = () ->
		{
			char.antialiasing = false;
			if (!noAntialiasingCheckBox.checked && Options.save.data.globalAntialiasing)
			{
				char.antialiasing = true;
			}
			char.noAntialiasing = noAntialiasingCheckBox.checked;
			ghostChar.antialiasing = char.antialiasing;
		};

		positionXStepper = new FlxUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y, 10, char.positionArray[0], -9000, 9000, 0);
		positionYStepper = new FlxUINumericStepper(positionXStepper.x + 60, positionXStepper.y, 10, char.positionArray[1], -9000, 9000, 0);

		positionCameraXStepper = new FlxUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, char.cameraPosition[0], -9000, 9000, 0);
		positionCameraYStepper = new FlxUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, char.cameraPosition[1], -9000, 9000, 0);

		var saveCharacterButton:FlxButton = new FlxButton(reloadImageButton.x, noAntialiasingCheckBox.y + 40, 'Save Character', () ->
		{
			fileSaveDialog();
		});

		healthColorStepperR = new FlxUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, char.healthBarColors[0], 0, 255, 0);
		healthColorStepperG = new FlxUINumericStepper(singDurationStepper.x + 65, saveCharacterButton.y, 20, char.healthBarColors[1], 0, 255, 0);
		healthColorStepperB = new FlxUINumericStepper(singDurationStepper.x + 130, saveCharacterButton.y, 20, char.healthBarColors[2], 0, 255, 0);

		tabGroup.add(new FlxText(15, imageInputText.y - 18, 0, 'Image file name:'));
		tabGroup.add(new FlxText(15, healthIconInputText.y - 18, 0, 'Health icon name:'));
		tabGroup.add(new FlxText(15, singDurationStepper.y - 18, 0, 'Sing Animation length:'));
		tabGroup.add(new FlxText(15, scaleStepper.y - 18, 0, 'Scale:'));
		tabGroup.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Character X/Y:'));
		tabGroup.add(new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 0, 'Camera X/Y:'));
		tabGroup.add(new FlxText(healthColorStepperR.x, healthColorStepperR.y - 18, 0, 'Health bar R/G/B:'));
		tabGroup.add(imageInputText);
		tabGroup.add(reloadImageButton);
		tabGroup.add(decideIconColorButton);
		tabGroup.add(healthIconInputText);
		tabGroup.add(singDurationStepper);
		tabGroup.add(scaleStepper);
		tabGroup.add(flipXCheckBox);
		tabGroup.add(noAntialiasingCheckBox);
		tabGroup.add(positionXStepper);
		tabGroup.add(positionYStepper);
		tabGroup.add(positionCameraXStepper);
		tabGroup.add(positionCameraYStepper);
		tabGroup.add(healthColorStepperR);
		tabGroup.add(healthColorStepperG);
		tabGroup.add(healthColorStepperB);
		tabGroup.add(saveCharacterButton);
		uiCharacterBox.addGroup(tabGroup);
	}

	private var ghostDropDown:FlxUIDropDownMenu;
	private var animationDropDown:FlxUIDropDownMenu;
	private var animationInputText:FlxUIInputText;
	private var animationNameInputText:FlxUIInputText;
	private var animationIndicesInputText:FlxUIInputText;
	private var animationNameFramerate:FlxUINumericStepper;
	private var animationLoopCheckBox:FlxUICheckBox;

	private function addAnimationsUI():Void
	{
		var tabGroup:FlxUI = new FlxUI(null, uiBox);
		tabGroup.name = 'Animations';

		animationInputText = new FlxUIInputText(15, 85, 80, 8);
		animationNameInputText = new FlxUIInputText(animationInputText.x, animationInputText.y + 35, 150, 8);
		animationIndicesInputText = new FlxUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, 8);
		animationNameFramerate = new FlxUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new FlxUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, null, null, 'Should it Loop?', 100);

		animationDropDown = new FlxUIDropDownMenu(15, animationInputText.y - 55, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), (pressed:String) ->
		{
			var selectedAnimation:Int = Std.parseInt(pressed);
			var anim:AnimationDef = char.animationsArray[selectedAnimation];
			animationInputText.text = anim.name;
			animationNameInputText.text = anim.prefix;
			animationLoopCheckBox.checked = anim.loop;
			animationNameFramerate.value = anim.frameRate;

			var indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
		});

		ghostDropDown = new FlxUIDropDownMenu(animationDropDown.x + 150, animationDropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray([''], true),
			(pressed:String) ->
			{
				var selectedAnimation:Int = Std.parseInt(pressed);
				ghostChar.visible = false;
				char.alpha = 1;
				if (selectedAnimation > 0)
				{
					ghostChar.visible = true;
					ghostChar.playAnim(ghostChar.animationsArray[selectedAnimation - 1].name, true);
					char.alpha = 0.85;
				}
			});

		var addUpdateButton:FlxButton = new FlxButton(70, animationIndicesInputText.y + 30, 'Add/Update', () ->
		{
			var indices:Array<Int> = [];
			var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
			if (indicesStr.length > 1)
			{
				for (indexString in indicesStr)
				{
					var index:Int = Std.parseInt(indexString);
					if (indexString != null && indexString != '' && !Math.isNaN(index) && index > -1)
					{
						indices.push(index);
					}
				}
			}

			var lastAnim:String = '';
			if (char.animationsArray[curAnim] != null)
			{
				lastAnim = char.animationsArray[curAnim].name;
			}

			var lastOffsets:Array<Int> = [0, 0];
			for (anim in char.animationsArray)
			{
				if (animationInputText.text == anim.name)
				{
					lastOffsets = anim.offsets;
					if (char.animation.getByName(animationInputText.text) != null)
					{
						char.animation.remove(animationInputText.text);
					}
					char.animationsArray.remove(anim);
				}
			}

			var newAnim:AnimationDef = {
				name: animationInputText.text,
				prefix: animationNameInputText.text,
				indices: indices,
				frameRate: Math.round(animationNameFramerate.value),
				loop: animationLoopCheckBox.checked,
				offsets: lastOffsets
			};
			if (indices != null && indices.length > 0)
			{
				char.animation.addByIndices(newAnim.name, newAnim.prefix, newAnim.indices, '', newAnim.frameRate, newAnim.loop);
			}
			else
			{
				char.animation.addByPrefix(newAnim.name, newAnim.prefix, newAnim.frameRate, newAnim.loop);
			}

			if (!char.animOffsets.exists(newAnim.name))
			{
				char.addOffset(newAnim.name, 0, 0);
			}
			char.animationsArray.push(newAnim);

			if (lastAnim == animationInputText.text)
			{
				var animation:FlxAnimation = char.animation.getByName(lastAnim);
				if (animation != null && animation.frames.length > 0)
				{
					char.playAnim(lastAnim, true);
				}
				else
				{
					for (i in 0...char.animationsArray.length)
					{
						if (char.animationsArray[i] != null)
						{
							animation = char.animation.getByName(char.animationsArray[i].name);
							if (animation != null && animation.frames.length > 0)
							{
								char.playAnim(char.animationsArray[i].name, true);
								curAnim = i;
								break;
							}
						}
					}
				}
			}

			reloadAnimationDropDown();
			genBoyOffsets();
			Debug.logTrace('Added/Updated animation: ${animationInputText.text}');
		});

		var removeButton:FlxButton = new FlxButton(180, animationIndicesInputText.y + 30, 'Remove', () ->
		{
			for (anim in char.animationsArray)
			{
				if (animationInputText.text == anim.name)
				{
					var resetAnim:Bool = false;
					if (char.animation.curAnim != null && anim.name == char.animation.curAnim.name)
						resetAnim = true;

					if (char.animation.getByName(anim.name) != null)
					{
						char.animation.remove(anim.name);
					}
					if (char.animOffsets.exists(anim.name))
					{
						char.animOffsets.remove(anim.name);
					}
					char.animationsArray.remove(anim);

					if (resetAnim && char.animationsArray.length > 0)
					{
						char.playAnim(char.animationsArray[0].name, true);
					}
					reloadAnimationDropDown();
					genBoyOffsets();
					Debug.logTrace('Removed animation: ${animationInputText.text}');
					break;
				}
			}
		});

		tabGroup.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tabGroup.add(new FlxText(ghostDropDown.x, ghostDropDown.y - 18, 0, 'Animation Ghost:'));
		tabGroup.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tabGroup.add(new FlxText(animationNameFramerate.x, animationNameFramerate.y - 18, 0, 'Framerate:'));
		tabGroup.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation on .XML/.TXT file:'));
		tabGroup.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));

		tabGroup.add(animationInputText);
		tabGroup.add(animationNameInputText);
		tabGroup.add(animationIndicesInputText);
		tabGroup.add(animationNameFramerate);
		tabGroup.add(animationLoopCheckBox);
		tabGroup.add(addUpdateButton);
		tabGroup.add(removeButton);
		tabGroup.add(ghostDropDown);
		tabGroup.add(animationDropDown);
		uiCharacterBox.addGroup(tabGroup);
	}

	private function reloadCharacterImage():Void
	{
		var lastAnim:String = '';
		if (char.animation.curAnim != null)
		{
			lastAnim = char.animation.curAnim.name;
		}
		if (Paths.exists(Paths.file(Path.join(['images', char.imageFile, Path.withExtension('Animation', Paths.JSON_EXT)]))))
		{
			char.frames = AtlasFrameMaker.construct(char.imageFile);
		}
		else if (Paths.exists(Paths.file(Path.join(['images', Path.withExtension(char.imageFile, Paths.TEXT_EXT)]))))
		{
			char.frames = Paths.getPackerAtlas(char.imageFile);
		}
		else
		{
			char.frames = Paths.getSparrowAtlas(char.imageFile);
		}

		if (char.animationsArray != null && char.animationsArray.length > 0)
		{
			for (anim in char.animationsArray)
			{
				var animName:String = anim.name;
				var animPrefix:String = anim.prefix;
				var animFrameRate:Int = anim.frameRate;
				var animLoop:Bool = anim.loop;
				var animIndices:Array<Int> = anim.indices;
				if (animIndices != null && animIndices.length > 0)
				{
					char.animation.addByIndices(animName, animPrefix, animIndices, '', animFrameRate, animLoop);
				}
				else
				{
					char.animation.addByPrefix(animName, animPrefix, animFrameRate, animLoop);
				}
			}
		}
		else
		{
			char.quickAnimAdd('idle', 'BF idle dance');
		}

		if (lastAnim != '')
		{
			char.playAnim(lastAnim, true);
		}
		else
		{
			char.dance();
		}
		ghostDropDown.selectedLabel = '';
		reloadGhost();
	}

	private function genBoyOffsets():Void
	{
		var loopsDone:Int = 0;

		var i:Int = dumbTexts.members.length - 1;
		while (i >= 0)
		{
			var memb:FlxText = dumbTexts.members[i];
			if (memb != null)
			{
				memb.kill();
				dumbTexts.remove(memb);
				memb.destroy();
			}
			--i;
		}
		dumbTexts.clear();

		for (anim => offsets in char.animOffsets)
		{
			var text:FlxText = new FlxText(10, 20 + (18 * loopsDone), 0, '$anim: $offsets', 16);
			text.setFormat(null, text.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 1;
			text.cameras = [camHUD];
			dumbTexts.add(text);

			loopsDone++;
		}

		textAnim.visible = true;
		if (dumbTexts.length < 1)
		{
			var text:FlxText = new FlxText(10, 38, 0, 'ERROR! No animations found.', 16);
			text.scrollFactor.set();
			text.borderSize = 1;
			textAnim.visible = false;
			dumbTexts.add(text);
		}
	}

	private function loadChar(isPlayer:Bool, blahBlahBlah:Bool = true):Void
	{
		var i:Int = charLayer.members.length - 1;
		while (i >= 0)
		{
			var memb:Character = charLayer.members[i];
			if (memb != null)
			{
				memb.kill();
				charLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		charLayer.clear();
		ghostChar = new Character(0, 0, charId, isPlayer);
		ghostChar.debugMode = true;
		ghostChar.alpha = 0.6;

		char = new Character(0, 0, charId, isPlayer);
		if (char.animationsArray[0] != null)
		{
			char.playAnim(char.animationsArray[0].name, true);
		}
		char.debugMode = true;

		charLayer.add(ghostChar);
		charLayer.add(char);

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);

		/*
			// THIS FUNCTION WAS USED TO PUT THE .TXT OFFSETS INTO THE .JSON
			for (anim => offset in char.animOffsets)
			{
				var animation:AnimationDef = findAnimationByName(anim);
				if (animation != null)
				{
					animation.offsets = [offset[0], offset[1]];
				}
			}
		 */

		if (blahBlahBlah)
		{
			genBoyOffsets();
		}
		reloadCharacterOptions();
		reloadBGs();
		updatePointerPos();
	}

	private function updatePointerPos():Void
	{
		var x:Float = char.getMidpoint().x;
		var y:Float = char.getMidpoint().y;
		if (char.isPlayer)
		{
			x -= 100 + char.cameraPosition[0];
		}
		else
		{
			x += 150 + char.cameraPosition[0];
		}
		y -= 100 - char.cameraPosition[1];

		x -= cameraFollowPointer.width / 2;
		y -= cameraFollowPointer.height / 2;
		cameraFollowPointer.setPosition(x, y);
	}

	private function findAnimationByName(name:String):AnimationDef
	{
		for (anim in char.animationsArray)
		{
			if (anim.name == name)
			{
				return anim;
			}
		}
		return null;
	}

	private function reloadCharacterOptions():Void
	{
		if (uiCharacterBox != null)
		{
			imageInputText.text = char.imageFile;
			healthIconInputText.text = char.healthIcon;
			singDurationStepper.value = char.singDuration;
			scaleStepper.value = char.jsonScale;
			flipXCheckBox.checked = char.originalFlipX;
			noAntialiasingCheckBox.checked = char.noAntialiasing;
			resetHealthBarColor();
			healthIcon.changeIcon(healthIconInputText.text);
			positionXStepper.value = char.positionArray[0];
			positionYStepper.value = char.positionArray[1];
			positionCameraXStepper.value = char.cameraPosition[0];
			positionCameraYStepper.value = char.cameraPosition[1];
			reloadAnimationDropDown();
			updatePresence();
		}
	}

	private function reloadAnimationDropDown():Void
	{
		var anims:Array<String> = [];
		var ghostAnims:Array<String> = [''];
		for (anim in char.animationsArray)
		{
			anims.push(anim.name);
			ghostAnims.push(anim.name);
		}
		if (anims.length < 1)
			anims.push('NO ANIMATIONS'); // Prevents crash

		animationDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims, true));
		ghostDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(ghostAnims, true));
		reloadGhost();
	}

	private function reloadGhost():Void
	{
		ghostChar.frames = char.frames;
		for (anim in char.animationsArray)
		{
			var animName:String = anim.name;
			var animPrefix:String = anim.prefix;
			var animFrameRate:Int = anim.frameRate;
			var animLoop:Bool = anim.loop;
			var animIndices:Array<Int> = anim.indices;
			if (animIndices != null && animIndices.length > 0)
			{
				ghostChar.animation.addByIndices(animName, animPrefix, animIndices, '', animFrameRate, animLoop);
			}
			else
			{
				ghostChar.animation.addByPrefix(animName, animPrefix, animFrameRate, animLoop);
			}

			if (anim.offsets != null && anim.offsets.length > 1)
			{
				ghostChar.addOffset(anim.name, anim.offsets[0], anim.offsets[1]);
			}
		}

		char.alpha = 0.85;
		ghostChar.visible = true;
		if (ghostDropDown.selectedLabel == '')
		{
			ghostChar.visible = false;
			char.alpha = 1;
		}
		ghostChar.color = 0xFF666688;
		ghostChar.antialiasing = char.antialiasing;

		ghostChar.setGraphicSize(Std.int(ghostChar.width * char.jsonScale));
		ghostChar.updateHitbox();
	}

	private function reloadCharacterDropDown():Void
	{
		characterList = [];
		var charsLoaded:Map<String, Bool> = [];

		var directories:Array<String> = Paths.getDirectoryLoadOrder(true);

		for (directory in directories)
		{
			var characterDirectory:String = Path.join([directory, 'data/characters']);
			var characterListPath:String = Path.join([characterDirectory, Path.withExtension('characterList', Paths.TEXT_EXT)]);
			if (Paths.exists(characterListPath))
			{
				// Add characters from characterList.txt first
				var characterListFromDir:Array<String> = CoolUtil.listFromTextFile(characterListPath);
				for (characterId in characterListFromDir)
				{
					var path:String = Path.join([characterDirectory, Path.withExtension(characterId, Paths.JSON_EXT)]);
					if (Paths.exists(path))
					{
						if (!charsLoaded.exists(characterId))
						{
							characterList.push(characterId);
							charsLoaded.set(characterId, true);
						}
					}
				}
			}

			if (Paths.fileSystem.exists(characterDirectory))
			{
				// Add any characters what were not included in the list but were in the directory
				for (file in Paths.fileSystem.readDirectory(characterDirectory))
				{
					var path:String = Path.join([characterDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.JSON_EXT)
					{
						var characterId:String = Path.withoutExtension(file);
						if (!charsLoaded.exists(characterId))
						{
							characterList.push(characterId);
							charsLoaded.set(characterId, true);
						}
					}
				}
			}
		}

		charDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true));
		charDropDown.selectedLabel = charId;
	}

	private function resetHealthBarColor():Void
	{
		healthColorStepperR.value = char.healthBarColors[0];
		healthColorStepperG.value = char.healthBarColors[1];
		healthColorStepperB.value = char.healthBarColors[2];
		healthBarBG.color = FlxColor.fromRGB(char.healthBarColors[0], char.healthBarColors[1], char.healthBarColors[2]);
	}

	private function updatePresence():Void
	{
		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Character Editor', 'Character: $charId', healthIcon.getCharacter());
		#end
	}

	private function clipboardAdd(prefix:String = ''):String
	{
		if (prefix.toLowerCase().endsWith('v')) // probably copy paste attempt
		{
			prefix = prefix.substring(0, prefix.length - 1);
		}

		return prefix + Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT).replace('\n', '');
	}

	private var _file:FileReference;

	private function fileBrowseDialog():Void
	{
		var jsonFilter:FileFilter = new FileFilter('JSON', Paths.JSON_EXT);
		addLoadListeners();
		_file.browse([jsonFilter]);
	}

	private function addLoadListeners():Void
	{
		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadSelect);
		_file.addEventListener(Event.COMPLETE, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
	}

	private function removeLoadListeners():Void
	{
		_file.removeEventListener(Event.SELECT, onLoadSelect);
		_file.removeEventListener(Event.COMPLETE, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
	}

	/**
	 * Called when a file has been selected.
	 */
	private function onLoadSelect(e:Event):Void
	{
		try
		{
			_file.load();
		}
		catch (e:Exception)
		{
			removeLoadListeners();
			Debug.logError('Error loading file:\n${e.message}');
		}
	}

	/**
	 * Called when the file has finished loading.
	 */
	private function onLoadComplete(e:Event):Void
	{
		try
		{
			var jsonString:String = _file.data.toString();
			var loadedChar:CharacterDef = Json.parse(jsonString);
			if (loadedChar != null)
			{
				if (loadedChar.animations != null) // Make sure it's really a dialogue character
				{
					var charId:String = Path.withoutExtension(_file.name);
					playerCheckBox.checked = charId.startsWith('bf');
					loadChar(playerCheckBox.checked);
					updatePresence();
					reloadCharacterDropDown();
					Debug.logTrace('Successfully loaded file: ${_file.name}');
					removeLoadListeners();
					return;
				}
			}
		}
		catch (e:Exception)
		{
			removeLoadListeners();
			Debug.logError('Error loading file:\n${e.message}');
			return;
		}
		removeLoadListeners();
		Debug.logError('Could not load file');
	}

	/**
	 * Called when the load file dialog is cancelled.
	 */
	private function onLoadCancel(e:Event):Void
	{
		removeLoadListeners();
		Debug.logTrace('Cancelled file loading.');
	}

	/**
	 * Called if there is an error while loading the file.
	 */
	private function onLoadError(e:IOErrorEvent):Void
	{
		removeLoadListeners();
		Debug.logError('Error loading file: ${e.text}');
	}

	private function offsetsFileSaveDialog():Void
	{
		var data:String = '';
		for (anim => offsets in char.animOffsets)
		{
			data += '$anim ${offsets[0]} ${offsets[1]}\n';
		}

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, Path.withExtension('${charId}Offsets', Paths.TEXT_EXT));
		}
	}

	private function fileSaveDialog():Void
	{
		var json:CharacterDef = {
			animations: char.animationsArray,
			image: char.imageFile,
			scale: char.jsonScale,
			singDuration: char.singDuration,
			healthIcon: char.healthIcon,

			position: char.positionArray,
			cameraPosition: char.cameraPosition,

			flipX: char.originalFlipX,
			noAntialiasing: char.noAntialiasing,
			healthBarColors: char.healthBarColors,
			cameraMotionFactor: char.cameraMotionFactor
		};

		var data:String = Json.stringify(json, '\t');

		if (data.length > 0)
		{
			data += '\n'; // I like newlines at the ends of files.
			addSaveListeners();
			_file.save(data, Path.withExtension(charId, Paths.JSON_EXT));
		}
	}

	private function addSaveListeners():Void
	{
		_file = new FileReference();
		_file.addEventListener(Event.COMPLETE, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
	}

	private function removeSaveListeners():Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called when the file has finished saving.
	 */
	private function onSaveComplete(e:Event):Void
	{
		removeSaveListeners();
		Debug.logTrace('Successfully saved file.');
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	private function onSaveCancel(e:Event):Void
	{
		removeSaveListeners();
		Debug.logTrace('Cancelled file saving.');
	}

	/**
	 * Called if there is an error while saving the file.
	 */
	private function onSaveError(e:IOErrorEvent):Void
	{
		removeSaveListeners();
		Debug.logError('Error saving file: ${e.text}');
	}
}
