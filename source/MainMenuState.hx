package;

import editors.MasterEditorMenuState;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.io.Path;
import openfl.Lib;
import options.OptionsState;
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class MainMenuState extends MusicBeatState
{
	private static var curSelected:Int = 0;

	private var menuItems:FlxTypedGroup<FlxSprite>;
	private var camGame:FlxCamera;
	private var camAchievement:FlxCamera;

	private var menuOptions:Array<String> = [
		'story_mode',
		'freeplay',
		#if FEATURE_MODS
		'mods',
		#end
		#if FEATURE_ACHIEVEMENTS
		'awards',
		#end
		'credits',
		#if !switch
		'donate',
		#end
		'options'
	];

	private var magenta:FlxSprite;
	private var camFollow:FlxObject;
	private var camFollowPos:FlxObject;
	private var debugKeys:Array<FlxKey>;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('In the Menus');
		#end

		Week.loadTheFirstEnabledMod();

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.tempo = TitleState.titleDef.bpm;
		}

		debugKeys = Options.copyKey(Options.save.data.keyBinds.get('debug_1'));

		camGame = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);

		var yScroll:Float = Math.max(0.25 - (0.05 * (menuOptions.length - 4)), 0.1);
		// var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuDesat'));
		// bg.color = 0xFFFFEA72; // Tint used to get menuBG from menuDesat (or, at least, it is close to what the tint is)
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuBG'));
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);

		magenta = new FlxSprite(-80).loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuDesat'));
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.antialiasing = Options.save.data.globalAntialiasing;
		magenta.color = 0xFFFD719B;
		add(magenta);

		menuItems = new FlxTypedGroup();
		add(menuItems);

		var scale:Float = 1;

		for (i => menuOption in menuOptions)
		{
			var offset:Float = 108 - (Math.max(menuOptions.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
			menuItem.scale.x = scale;
			menuItem.scale.y = scale;
			menuItem.frames = Paths.getSparrowAtlas(Path.join(['ui/main/options', menuOption]));
			menuItem.animation.addByPrefix('idle', '$menuOption basic', 24);
			menuItem.animation.addByPrefix('selected', '$menuOption white', 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItems.add(menuItem);
			var scr:Float = (menuOptions.length - 4) * 0.135;
			if (menuOptions.length < 6)
				scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.antialiasing = Options.save.data.globalAntialiasing;
			menuItem.updateHitbox();
		}

		FlxG.camera.follow(camFollowPos, null, 1);

		var versionShit:FlxText = new FlxText(12, FlxG.height - 44, 0,
			'Psych Engine (Mock) v${EngineData.ENGINE_VERSION}\nFriday Night Funkin\' v${Lib.application.meta.get('version')}\n', 16);
		versionShit.scrollFactor.set();
		versionShit.setFormat(Paths.font('vcr.ttf'), versionShit.size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		add(versionShit);

		changeSelection();

		#if FEATURE_ACHIEVEMENTS
		Achievement.loadAchievements();
		var date:Date = Date.now();
		if (date.getDay() == 5 && date.getHours() >= 18)
		{
			var achievementId:String = 'friday_night_play';
			if (!Achievement.isAchievementUnlocked(achievementId))
			{ // It's a friday night. WEEEEEEEEEEEEEEEEEE
				// Unlocks "Freaky on a Friday Night" achievement
				giveAchievement(achievementId);
			}
		}
		#end
	}

	private var selectedSomethin:Bool = false;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
		}

		var lerpVal:Float = FlxMath.bound(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
			{
				FlxG.sound.play(Paths.getSound('scrollMenu'));
				changeSelection(-1);
			}

			if (controls.UI_DOWN_P)
			{
				FlxG.sound.play(Paths.getSound('scrollMenu'));
				changeSelection(1);
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.getSound('cancelMenu'));
				FlxG.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				if (menuOptions[curSelected] == 'donate')
				{
					FlxG.openURL('https://ninja-muffin24.itch.io/funkin');
				}
				else
				{
					selectedSomethin = true;
					FlxG.sound.play(Paths.getSound('confirmMenu'));

					if (Options.save.data.flashing)
						FlxFlicker.flicker(magenta, 1.1, 0.15, false);

					menuItems.forEach((spr:FlxSprite) ->
					{
						if (curSelected != spr.ID)
						{
							FlxTween.tween(spr, {alpha: 0}, 0.4, {
								ease: FlxEase.quadOut,
								onComplete: (twn:FlxTween) ->
								{
									spr.kill();
								}
							});
						}
						else
						{
							FlxFlicker.flicker(spr, 1, 0.06, false, false, (flick:FlxFlicker) ->
							{
								var selectedOption:String = menuOptions[curSelected];

								switch (selectedOption)
								{
									case 'story_mode':
										FlxG.switchState(new StoryMenuState());
									case 'freeplay':
										FlxG.switchState(new FreeplayState());
									#if FEATURE_MODS
									case 'mods':
										FlxG.switchState(new ModsMenuState());
									#end
									#if FEATURE_ACHIEVEMENTS
									case 'awards':
										FlxG.switchState(new AchievementsMenuState());
									#end
									case 'credits':
										FlxG.switchState(new CreditsState());
									case 'options':
										FlxG.switchState(new OptionsState());
								}
							});
						}
					});
				}
			}
			// TODO These editors actually work in HTML5, but they can't access our own JSON files without using ChartEditorState's approach, so I want to somehow make them all easy to use in HTML5
			else if (FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				FlxG.switchState(new MasterEditorMenuState());
			}
		}

		menuItems.forEach((spr:FlxSprite) ->
		{
			spr.screenCenter(X);
		});
	}

	#if FEATURE_ACHIEVEMENTS
	private function giveAchievement(id:String):Void
	{
		var achievement:Achievement = new Achievement(id);
		achievement.cameras = [camAchievement];
		add(achievement);
		Achievement.unlockAchievement(id);
	}
	#end

	private function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);

		menuItems.forEach((spr:FlxSprite) ->
		{
			spr.animation.play('idle');
			spr.updateHitbox();

			if (spr.ID == curSelected)
			{
				spr.animation.play('selected');
				var add:Float = 0;
				if (menuItems.length > 4)
				{
					add = menuItems.length * 8;
				}
				camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
				spr.centerOffsets();
			}
		});
	}
}
