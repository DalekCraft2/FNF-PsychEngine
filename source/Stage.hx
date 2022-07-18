package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import haxe.io.Path;

using StringTools;

typedef StageDef =
{
	var defaultZoom:Float;
	var isPixelStage:Bool;
	var boyfriend:Array<Float>;
	var girlfriend:Array<Float>;
	var opponent:Array<Float>;
	var hideGirlfriend:Bool;
	var cameraBoyfriend:Array<Float>;
	var cameraOpponent:Array<Float>;
	var cameraGirlfriend:Array<Float>;
	var ?cameraSpeed:Float;
	// var background:Array<Dynamic>;
	// var groups:Array<Dynamic>;
	// var foreground:Array<Dynamic>;
	// var objectOrder:Array<Dynamic>;
	// var playerPosition:CoordStruct;
	// var gfPosition:CoordStruct;
	// var opponentPosition:CoordStruct;
	// var playerCameraPos:CoordStruct;
	// var gfCameraPos:CoordStruct;
	// var opponentCameraPos:CoordStruct;
	// var ?hideGirlfriend:Bool;
	// var ?cameraZoom:Float;
	// var ?cameraSpeed:Float;
	// var ?hasLightning:Bool;
	// var ?isPixelStage:Bool;
}

// TODO Add layers to Stage JSON file, like Myth?
// TODO Make this an FlxGroup, like Andromeda
class Stage
{
	/**
	 * The internal name of the stage, as used in the file system.
	 */
	public var id:String;

	public var directory:String;
	public var defaultZoom:Float;
	public var isPixelStage:Bool;
	public var boyfriend:Array<Float>;
	public var girlfriend:Array<Float>;
	public var opponent:Array<Float>;
	public var hideGirlfriend:Bool;
	public var cameraBoyfriend:Array<Float>;
	public var cameraOpponent:Array<Float>;
	public var cameraGirlfriend:Array<Float>;
	public var cameraSpeed:Null<Float>;

	/**
	 * True = hide last BGs and show ones from slowBacks on certain step, False = Toggle visibility of BGs from SlowBacks on certain step
	 * Use visible property to manage if BG would be visible or not at the start of the game
	 */
	public var hideLastBG:Bool = false;

	/**
	 * How long will it tween hiding/showing BGs, variable above must be set to True for tween to activate
	 */
	public var tweenDuration:Float = 2;

	/**
	 * Add BGs on stage startup, load BG in by using "backgrounds.push(bgVar);"
	 * Layering algorithm for noobs: Everything loads by the method of "On Top", example: You load wall first(Every other added BG layers on it), then you load road(comes on top of wall and doesn't clip through it), then loading street lights(comes on top of wall and road)
	 */
	public var backgrounds:Array<Dynamic> = [];

	/**
	 * Store BGs here to use them later (for example with slowBacks, using your custom stage event or to adjust position in stage debug menu(press 8 while in PlayState with debug build of the game))
	 */
	public var layers:Map<String, Dynamic> = [];

	/**
	 * Store Groups
	 */
	public var groups:Map<String, FlxTypedGroup<Dynamic>> = [];

	// TODO Make the sprites in this array start bopping before the song starts

	/**
	 * Store animated backgrounds and make them play animation(Animation must be named Idle!! Else use groups/layers and script it in stepHit/beatHit function of this file!!)
	 */
	public var animatedLayers:Array<FlxSprite> = [];

	/**
	 * BG layering, format: first [0] - in front of GF, second [1] - in front of opponent, third [2] - in front of boyfriend(and technically also opponent since Haxe layering moment)
	 */
	public var foregrounds:Array<Array<FlxSprite>> = [[], [], []];

	/**
	 * Change/add/remove backgrounds mid song! Format: "slowBacks[StepToBeActivated] = [Sprites,To,Be,Changed,Or,Added];"
	 */
	public var slowBacks:Map<Int, Array<FlxSprite>> = [];

	public function new(id:String)
	{
		this.id = id;
		var stageDef:StageDef = Paths.getJson(Path.join(['stages', id]));
		if (stageDef == null)
		{
			Debug.logError('Could not find stage data for stage "$id"; using default');
			// Stage couldn't be found, create a dummy stage for preventing a crash
			stageDef = {
				defaultZoom: 0.9,
				isPixelStage: false,

				boyfriend: [770, 100],
				girlfriend: [400, 130],
				opponent: [100, 100],
				hideGirlfriend: false,

				cameraBoyfriend: [0, 0],
				cameraOpponent: [0, 0],
				cameraGirlfriend: [0, 0],
				cameraSpeed: 1
			};
		}
		copyDataFields(stageDef);

		if (Options.save.data.noStage)
			return;

		switch (id)
		{
			case 'stage':
				var bg:BGSprite = new BGSprite('stages/stage/stageback', -600, -200, 0.9, 0.9);
				layers['bg'] = bg;
				backgrounds.push(bg);

				var stageFront:BGSprite = new BGSprite('stages/stage/stagefront', -650, 600, 0.9, 0.9);
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				layers['stageFront'] = stageFront;
				backgrounds.push(stageFront);

				if (!Options.save.data.lowQuality)
				{
					var stageLight:BGSprite = new BGSprite('stages/stage/stage_light', -125, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					layers['stageLight'] = stageLight;
					backgrounds.push(stageLight);

					var stageLight2:BGSprite = new BGSprite('stages/stage/stage_light', 1225, -100, 0.9, 0.9);
					stageLight2.setGraphicSize(Std.int(stageLight2.width * 1.1));
					stageLight2.updateHitbox();
					stageLight2.flipX = true;
					layers['stageLight2'] = stageLight2;
					backgrounds.push(stageLight2);

					var stageCurtains:BGSprite = new BGSprite('stages/stage/stagecurtains', -500, -300, 1.3, 1.3);
					stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
					stageCurtains.updateHitbox();
					layers['stageCurtains'] = stageCurtains;
					backgrounds.push(stageCurtains);
				}

			case 'halloween':
				var halloweenBG:BGSprite;
				if (!Options.save.data.lowQuality)
				{
					halloweenBG = new BGSprite('stages/halloween/halloween_bg', -200, -100);
					halloweenBG.active = true;
					halloweenBG.frames = Paths.getSparrowAtlas('stages/halloween/halloween_bg');
					halloweenBG.animation.addByPrefix('idle', 'halloween bg0');
					halloweenBG.animation.addByPrefix('lightning', 'halloween bg lightning strike', 24, false);
					halloweenBG.animation.play('idle');
				}
				else
				{
					halloweenBG = new BGSprite('stages/halloween/halloween_bg_low', -200, -100);
				}
				layers['halloweenBG'] = halloweenBG;
				backgrounds.push(halloweenBG);

				// PRECACHE SOUNDS
				Paths.precacheSound('thunder_1');
				Paths.precacheSound('thunder_2');

			case 'philly':
				if (!Options.save.data.lowQuality)
				{
					var bg:BGSprite = new BGSprite('stages/philly/sky', -100, 0, 0.1, 0.1);
					layers['bg'] = bg;
					backgrounds.push(bg);
				}

				var city:BGSprite = new BGSprite('stages/philly/city', -10, 0, 0.3, 0.3);
				city.setGraphicSize(Std.int(city.width * 0.85));
				city.updateHitbox();
				layers['city'] = city;
				backgrounds.push(city);

				var phillyCityLights:FlxTypedGroup<BGSprite> = new FlxTypedGroup();
				if (Options.save.data.distractions)
				{
					groups['phillyCityLights'] = phillyCityLights;
					backgrounds.push(phillyCityLights);
				}

				for (i in 0...5)
				{
					var light:BGSprite = new BGSprite('stages/philly/win$i', city.x, city.y, 0.3, 0.3);
					light.visible = false;
					light.setGraphicSize(Std.int(light.width * 0.85));
					light.updateHitbox();
					phillyCityLights.add(light);
				}

				var streetBehind:BGSprite = new BGSprite('stages/philly/behindTrain', -40, 50);
				if (!Options.save.data.lowQuality)
				{
					layers['streetBehind'] = streetBehind;
					backgrounds.push(streetBehind);
				}

				var phillyTrain:BGSprite = new BGSprite('stages/philly/train', 2000, 360);
				if (Options.save.data.distractions)
				{
					layers['phillyTrain'] = phillyTrain;
					backgrounds.push(phillyTrain);
				}

				trainSound = new FlxSound().loadEmbedded(Paths.getSound('train_passes'));
				Paths.getSound('train_passes');
				FlxG.sound.list.add(trainSound);

				var street:BGSprite = new BGSprite('stages/philly/street', -40, streetBehind.y);
				layers['street'] = street;
				backgrounds.push(street);

			case 'limo':
				var skyBG:BGSprite = new BGSprite('stages/limo/limoSunset', -120, -50, 0.1, 0.1);
				layers['skyBG'] = skyBG;
				backgrounds.push(skyBG);

				var bgLimo:BGSprite = new BGSprite('stages/limo/bgLimo', -200, 480, 0.4, 0.4, ['background limo pink'], true);
				if (!Options.save.data.lowQuality)
				{
					var limoMetalPole:BGSprite = new BGSprite('stages/limo/gore/metalPole', -500, 220, 0.4, 0.4);
					layers['limoMetalPole'] = limoMetalPole;
					backgrounds.push(limoMetalPole);

					layers['bgLimo'] = bgLimo;
					backgrounds.push(bgLimo);

					var limoCorpse:BGSprite = new BGSprite('stages/limo/gore/noooooo', -500, limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true);
					layers['limoCorpse'] = limoCorpse;
					backgrounds.push(limoCorpse);

					var limoCorpse2:BGSprite = new BGSprite('stages/limo/gore/noooooo', -500, limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true);
					layers['limoCorpse2'] = limoCorpse2;
					backgrounds.push(limoCorpse2);

					// var grpLimoDancers:FlxTypedGroup<BackgroundDancer> = new FlxTypedGroup();
					// groups['grpLimoDancers'] = grpLimoDancers;
					// backgrounds.push(grpLimoDancers);

					// for (i in 0...5)
					// {
					// 	var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + 130, bgLimo.y - 400);
					// 	dancer.scrollFactor.set(0.4, 0.4);
					// 	grpLimoDancers.add(dancer);
					// }

					var limoLight:BGSprite = new BGSprite('stages/limo/gore/coldHeartKiller', limoMetalPole.x - 180, limoMetalPole.y - 80, 0.4, 0.4);
					layers['limoLight'] = limoLight;
					backgrounds.push(limoLight);

					var grpLimoParticles:FlxTypedGroup<BGSprite> = new FlxTypedGroup();
					groups['grpLimoParticles'] = grpLimoParticles;
					backgrounds.push(grpLimoParticles);

					// PRECACHE BLOOD
					var particle:BGSprite = new BGSprite('stages/limo/gore/stupidBlood', -400, -400, 0.4, 0.4, ['blood'], false);
					particle.alpha = 0.01;
					grpLimoParticles.add(particle);
					resetLimoKill();

					// PRECACHE SOUND
					Paths.precacheSound('dancerdeath');
				}

				var fastCar:BGSprite = new BGSprite('stages/limo/fastCarLol', -300, 160);
				fastCar.active = true;
				fastCar.visible = false;

				if (Options.save.data.distractions)
				{
					var grpLimoDancers:FlxTypedGroup<BackgroundDancer> = new FlxTypedGroup();
					groups['grpLimoDancers'] = grpLimoDancers;
					backgrounds.push(grpLimoDancers);

					for (i in 0...5)
					{
						var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + 130, bgLimo.y - 400);
						dancer.scrollFactor.set(0.4, 0.4);
						grpLimoDancers.add(dancer);
						layers['dancer$i'] = dancer;
					}

					layers['fastCar'] = fastCar;
					foregrounds[2].push(fastCar);
					resetFastCar();
				}

				// var overlayShit:FlxSprite = new FlxSprite(-500, -600).loadGraphic(Paths.getGraphic('stages/limo/limoOverlay'));
				// overlayShit.alpha = 0.5;
				// add(overlayShit);
				// var shaderBullshit = new BlendModeEffect(new OverlayShader(), FlxColor.RED);
				// FlxG.camera.setFilters([new ShaderFilter(cast shaderBullshit.shader)]);
				// overlayShit.shader = shaderBullshit;

				var limo:BGSprite = new BGSprite('stages/limo/limoDrive', -120, 550, ['Limo stage']);
				foregrounds[0].push(limo);
				layers['limo'] = limo;

			// limoKillingState = 0;

			case 'mall':
				var bg:BGSprite = new BGSprite('stages/christmas/bgWalls', -1000, -500, 0.2, 0.2);
				bg.setGraphicSize(Std.int(bg.width * 0.8));
				bg.updateHitbox();
				layers['bg'] = bg;
				backgrounds.push(bg);

				if (!Options.save.data.lowQuality)
				{
					var upperBoppers:BGSprite = new BGSprite('stages/christmas/upperBop', -240, -90, 0.33, 0.33);
					upperBoppers.active = true;
					upperBoppers.frames = Paths.getSparrowAtlas('stages/christmas/upperBop');
					upperBoppers.animation.addByPrefix('idle', 'Upper Crowd Bob', 24, false);
					upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85));
					upperBoppers.updateHitbox();
					if (Options.save.data.distractions)
					{
						layers['upperBoppers'] = upperBoppers;
						backgrounds.push(upperBoppers);
						animatedLayers.push(upperBoppers);
					}

					var bgEscalator:BGSprite = new BGSprite('stages/christmas/bgEscalator', -1100, -600, 0.3, 0.3);
					bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
					bgEscalator.updateHitbox();
					layers['bgEscalator'] = bgEscalator;
					backgrounds.push(bgEscalator);
				}

				var tree:BGSprite = new BGSprite('stages/christmas/christmasTree', 370, -250, 0.40, 0.40);
				layers['tree'] = tree;
				backgrounds.push(tree);

				var bottomBoppers:BGSprite = new BGSprite('stages/christmas/bottomBop', -300, 140, 0.9, 0.9, ['Bottom Level Boppers Idle']);
				// bottomBoppers.active = true;
				// bottomBoppers.frames = Paths.getSparrowAtlas('stages/christmas/bottomBop');
				// bottomBoppers.animation.addByPrefix('idle', 'Bottom Level Boppers Idle', 24, false);
				bottomBoppers.animation.addByPrefix('hey', 'Bottom Level Boppers HEY', 24, false);
				if (Options.save.data.distractions)
				{
					layers['bottomBoppers'] = bottomBoppers;
					backgrounds.push(bottomBoppers);
					// animatedLayers.push(bottomBoppers);
				}

				var fgSnow:BGSprite = new BGSprite('stages/christmas/fgSnow', -600, 700);
				layers['fgSnow'] = fgSnow;
				backgrounds.push(fgSnow);

				var santa:BGSprite = new BGSprite('stages/christmas/santa', -840, 150);
				santa.active = true;
				santa.frames = Paths.getSparrowAtlas('stages/christmas/santa');
				santa.animation.addByPrefix('idle', 'santa idle in fear', 24, false);
				if (Options.save.data.distractions)
				{
					layers['santa'] = santa;
					foregrounds[2].push(santa);
					animatedLayers.push(santa);
				}
				Paths.getSound('Lights_Shut_Off');

			case 'mallEvil':
				var bg:BGSprite = new BGSprite('stages/christmas/evilBG', -400, -500, 0.2, 0.2);
				bg.setGraphicSize(Std.int(bg.width * 0.8));
				bg.updateHitbox();
				layers['bg'] = bg;
				backgrounds.push(bg);

				var evilTree:BGSprite = new BGSprite('stages/christmas/evilTree', 300, -300, 0.2, 0.2);
				layers['evilTree'] = evilTree;
				backgrounds.push(evilTree);

				var evilSnow:BGSprite = new BGSprite('stages/christmas/evilSnow', -200, 700);
				layers['evilSnow'] = evilSnow;
				backgrounds.push(evilSnow);

			case 'school':
				GameOverSubState.deathSoundName = 'fnf_loss_sfx-pixel';
				GameOverSubState.loopSoundName = 'gameOver-pixel';
				GameOverSubState.endSoundName = 'gameOverEnd-pixel';
				GameOverSubState.characterName = 'bf-pixel-dead';

				var bgSky:BGSprite = new BGSprite('stages/weeb/weebSky', 0, 0, 0.1, 0.1);
				bgSky.antialiasing = false;
				layers['bgSky'] = bgSky;
				backgrounds.push(bgSky);

				var repositionShit:Float = -200;

				var bgSchool:BGSprite = new BGSprite('stages/weeb/weebSchool', repositionShit, 0, 0.6, 0.9);
				bgSchool.antialiasing = false;
				layers['bgSchool'] = bgSchool;
				backgrounds.push(bgSchool);

				var bgStreet:BGSprite = new BGSprite('stages/weeb/weebStreet', repositionShit, 0, 0.95, 0.95);
				bgStreet.antialiasing = false;
				layers['bgStreet'] = bgStreet;
				backgrounds.push(bgStreet);

				var widShit:Int = Std.int(bgSky.width * 6);

				var fgTrees:BGSprite = new BGSprite('stages/weeb/weebTreesBack', repositionShit + 170, 130, 0.9, 0.9);
				if (!Options.save.data.lowQuality)
				{
					fgTrees.antialiasing = false;
					fgTrees.setGraphicSize(Std.int(widShit * 0.8));
					fgTrees.updateHitbox();
					layers['fgTrees'] = fgTrees;
					backgrounds.push(fgTrees);
				}

				var bgTrees:BGSprite = new BGSprite('stages/weeb/weebTrees', repositionShit - 380, -800, 0.85, 0.85);
				bgTrees.antialiasing = false;
				bgTrees.frames = Paths.getPackerAtlas('stages/weeb/weebTrees');
				bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
				bgTrees.animation.play('treeLoop');
				layers['bgTrees'] = bgTrees;
				backgrounds.push(bgTrees);

				var treeLeaves:BGSprite = new BGSprite('stages/weeb/petals', repositionShit, -40, 0.85, 0.85, ['PETALS ALL'], true);
				if (!Options.save.data.lowQuality)
				{
					treeLeaves.antialiasing = false;
					treeLeaves.setGraphicSize(widShit);
					treeLeaves.updateHitbox();
					layers['treeLeaves'] = treeLeaves;
					backgrounds.push(treeLeaves);
				}

				bgSky.setGraphicSize(widShit);
				bgSchool.setGraphicSize(widShit);
				bgStreet.setGraphicSize(widShit);
				bgTrees.setGraphicSize(Std.int(widShit * 1.4));
				fgTrees.setGraphicSize(Std.int(widShit * 0.8));
				treeLeaves.setGraphicSize(widShit);

				fgTrees.updateHitbox();
				bgSky.updateHitbox();
				bgSchool.updateHitbox();
				bgStreet.updateHitbox();
				bgTrees.updateHitbox();
				treeLeaves.updateHitbox();

				if (!Options.save.data.lowQuality)
				{
					var bgGirls:BackgroundGirls = new BackgroundGirls(-100, 190);
					bgGirls.scrollFactor.set(0.9, 0.9);
					bgGirls.setGraphicSize(Std.int(bgGirls.width * PlayState.PIXEL_ZOOM));
					bgGirls.updateHitbox();
					if (Options.save.data.distractions)
					{
						layers['bgGirls'] = bgGirls;
						backgrounds.push(bgGirls);
					}
				}

			case 'schoolEvil':
				GameOverSubState.deathSoundName = 'fnf_loss_sfx-pixel';
				GameOverSubState.loopSoundName = 'gameOver-pixel';
				GameOverSubState.endSoundName = 'gameOverEnd-pixel';
				GameOverSubState.characterName = 'bf-pixel-dead';

				var posX:Float = 400;
				var posY:Float = 200;

				if (!Options.save.data.lowQuality)
				{
					var bg:BGSprite = new BGSprite('stages/weeb/animatedEvilSchool', posX, posY, 0.8, 0.9, ['background 2'], true);
					bg.antialiasing = false;
					bg.scale.set(PlayState.PIXEL_ZOOM, PlayState.PIXEL_ZOOM);
					layers['bg'] = bg;
					backgrounds.push(bg);

					var bgGhouls:BGSprite = new BGSprite('stages/weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
					bgGhouls.antialiasing = false;
					bgGhouls.setGraphicSize(Std.int(bgGhouls.width * PlayState.PIXEL_ZOOM));
					bgGhouls.updateHitbox();
					bgGhouls.visible = false;
					layers['bgGhouls'] = bgGhouls;
					backgrounds.push(bgGhouls);
				}
				else
				{
					var bg:BGSprite = new BGSprite('stages/weeb/animatedEvilSchool_low', posX, posY, 0.8, 0.9);
					bg.antialiasing = false;
					bg.setGraphicSize(Std.int(bg.width * PlayState.PIXEL_ZOOM));
					bg.updateHitbox();
					layers['bg'] = bg;
					backgrounds.push(bg);
				}

			case 'tank':
				var tankSky:BGSprite = new BGSprite('stages/tank/tankSky', -400, -400, 0, 0);
				layers['tankSky'] = tankSky;
				backgrounds.push(tankSky);

				var tankClouds:BGSprite = new BGSprite('stages/tank/tankClouds', FlxG.random.int(-700, -100), FlxG.random.int(-20, 20), 0.1, 0.1, null, false);
				tankClouds.active = true;
				tankClouds.velocity.x = FlxG.random.float(5, 15);
				layers['tankClouds'] = tankClouds;
				backgrounds.push(tankClouds);

				var tankMountains:BGSprite = new BGSprite('stages/tank/tankMountains', -300, -20, 0.2, 0.2);
				tankMountains.setGraphicSize(Std.int(1.2 * tankMountains.width));
				tankMountains.updateHitbox();
				layers['tankMountains'] = tankMountains;
				backgrounds.push(tankMountains);

				var tankBuildings:BGSprite = new BGSprite('stages/tank/tankBuildings', -200, 0, 0.3, 0.3, false);
				tankBuildings.setGraphicSize(Std.int(1.1 * tankBuildings.width));
				tankBuildings.updateHitbox();
				layers['tankBuildings'] = tankBuildings;
				backgrounds.push(tankBuildings);

				var tankRuins:BGSprite = new BGSprite('stages/tank/tankRuins', -200, 0, 0.35, 0.35, false);
				tankRuins.setGraphicSize(Std.int(1.1 * tankRuins.width));
				tankRuins.updateHitbox();
				layers['tankRuins'] = tankRuins;
				backgrounds.push(tankRuins);

				var smokeLeft:BGSprite = new BGSprite('stages/tank/smokeLeft', -200, -100, 0.4, 0.4, ['SmokeBlurLeft'], true);
				layers['smokeLeft'] = smokeLeft;
				backgrounds.push(smokeLeft);

				var smokeRight:BGSprite = new BGSprite('stages/tank/smokeRight', 1100, -100, 0.4, 0.4, ['SmokeRight'], true);
				layers['smokeRight'] = smokeRight;
				backgrounds.push(smokeRight);

				var tankWatchtower:BGSprite = new BGSprite('stages/tank/tankWatchtower', 100, 50, 0.5, 0.5, ['watchtower gradient color']);
				if (Options.save.data.distractions)
				{
					layers['tankWatchtower'] = tankWatchtower;
					backgrounds.push(tankWatchtower);
				}

				var tankRolling:BGSprite = new BGSprite('stages/tank/tankRolling', 300, 300, 0.5, 0.5, ['BG tank w lighting'], true);
				layers['tankRolling'] = tankRolling;
				backgrounds.push(tankRolling);

				var tankmanRun:FlxTypedGroup<TankmenBG> = new FlxTypedGroup();
				groups['tankmanRun'] = tankmanRun;
				backgrounds.push(tankmanRun);

				var tankGround:BGSprite = new BGSprite('stages/tank/tankGround', -420, -150);
				tankGround.setGraphicSize(Std.int(1.15 * tankGround.width));
				tankGround.updateHitbox();
				layers['tankGround'] = tankGround;
				backgrounds.push(tankGround);

				moveTank();

				var tankheadGroup:FlxTypedGroup<BGSprite> = new FlxTypedGroup();

				var tank0:BGSprite = new BGSprite('stages/tank/tank0', -500, 650, 1.7, 1.5, ['fg tankhead far right instance']);
				foregrounds[2].push(tank0);
				tankheadGroup.add(tank0);

				var tank1:BGSprite = new BGSprite('stages/tank/tank1', -300, 750, 2, 0.2, ['fg tankhead 5 instance']);
				foregrounds[2].push(tank1);
				tankheadGroup.add(tank1);

				var tank2:BGSprite = new BGSprite('stages/tank/tank2', 450, 940, 1.5, 1.5, ['foreground man 3 instance']);
				foregrounds[2].push(tank2);
				tankheadGroup.add(tank2);

				var tank4:BGSprite = new BGSprite('stages/tank/tank4', 1300, 900, 1.5, 1.5, ['fg tankman bobbin 3 instance']);
				foregrounds[2].push(tank4);
				tankheadGroup.add(tank4);

				var tank5:BGSprite = new BGSprite('stages/tank/tank5', 1620, 700, 1.5, 1.5, ['fg tankhead far right instance']);
				foregrounds[2].push(tank5);
				tankheadGroup.add(tank5);

				var tank3:BGSprite = new BGSprite('stages/tank/tank3', 1300, 1200, 3.5, 2.5, ['fg tankhead 4 instance']);
				foregrounds[2].push(tank3);
				tankheadGroup.add(tank3);

				if (Options.save.data.distractions)
					groups['tankheadGroup'] = tankheadGroup;
		}
	}

	// For the mall boppers' "hey" animation
	public var heyTimer:Float;

	public function update(elapsed:Float):Void
	{
		if (!Options.save.data.noStage)
		{
			switch (id)
			{
				case 'philly':
					if (trainMoving)
					{
						trainFrameTiming += elapsed;

						if (trainFrameTiming >= 1 / 24)
						{
							updateTrainPos();
							trainFrameTiming = 0;
						}
					}
				// var phillyCityLights:FlxTypedGroup<BGSprite> = cast groups['phillyCityLights'];
				// phillyCityLights.members[curLight].alpha -= (Conductor.crotchetLength / TimingConstants.MILLISECONDS_PER_SECOND) * elapsed * 1.5;
				case 'limo':
					if (!Options.save.data.lowQuality)
					{
						var bgLimo:FlxSprite = layers['bgLimo'];
						var limoMetalPole:FlxSprite = layers['limoMetalPole'];
						var limoLight:FlxSprite = layers['limoLight'];
						var limoCorpse:FlxSprite = layers['limoCorpse'];
						var limoCorpse2:FlxSprite = layers['limoCorpse2'];
						var grpLimoParticles:FlxTypedGroup<BGSprite> = cast groups['grpLimoParticles'];
						var grpLimoDancers:FlxTypedGroup<BackgroundDancer> = cast groups['grpLimoDancers'];

						grpLimoParticles.forEach((spr:BGSprite) ->
						{
							if (spr.animation.curAnim.finished)
							{
								spr.kill();
								grpLimoParticles.remove(spr /*, true*/); // This has to set to null instead of removing from the members entirely so it doesn't mess up the iterator
								spr.destroy();
							}
						});

						switch (limoKillingState)
						{
							case 1:
								limoMetalPole.x += 5000 * elapsed;
								limoLight.x = limoMetalPole.x - 180;
								limoCorpse.x = limoLight.x - 50;
								limoCorpse2.x = limoLight.x + 35;

								for (i => dancer in grpLimoDancers.members)
								{
									if (dancer.x < FlxG.width * 1.5 && limoLight.x > (370 * i) + 130)
									{
										switch (i)
										{
											case 0 | 3:
												if (i == 0)
													FlxG.sound.play(Paths.getSound('dancerdeath'), 0.5);

												var diffStr:String = i == 3 ? ' 2 ' : ' ';
												var particle:BGSprite = new BGSprite('stages/limo/gore/noooooo', dancer.x + 200, dancer.y, 0.4, 0.4,
													['hench leg spin${diffStr}PINK'], false);
												grpLimoParticles.add(particle);
												var particle:BGSprite = new BGSprite('stages/limo/gore/noooooo', dancer.x + 160, dancer.y + 200, 0.4, 0.4,
													['hench arm spin${diffStr}PINK'], false);
												grpLimoParticles.add(particle);
												var particle:BGSprite = new BGSprite('stages/limo/gore/noooooo', dancer.x, dancer.y + 50, 0.4, 0.4,
													['hench head spin${diffStr}PINK'], false);
												grpLimoParticles.add(particle);

												var particle:BGSprite = new BGSprite('stages/limo/gore/stupidBlood', dancer.x - 110, dancer.y + 20, 0.4, 0.4,
													['blood'], false);
												particle.flipX = true;
												particle.angle = -57.5;
												grpLimoParticles.add(particle);
											case 1:
												limoCorpse.visible = true;
											case 2:
												limoCorpse2.visible = true;
										} // Note: Nobody cares about the fifth dancer because he is mostly hidden offscreen :(
										dancer.x += FlxG.width * 2;
									}
								}

								if (limoMetalPole.x > FlxG.width * 2)
								{
									resetLimoKill();
									limoSpeed = 800;
									limoKillingState = 2;
								}

							case 2:
								limoSpeed -= 4000 * elapsed;
								bgLimo.x -= limoSpeed * elapsed;
								if (bgLimo.x > FlxG.width * 1.5)
								{
									limoSpeed = 3000;
									limoKillingState = 3;
								}

							case 3:
								limoSpeed -= 2000 * elapsed;
								if (limoSpeed < 1000)
									limoSpeed = 1000;

								bgLimo.x -= limoSpeed * elapsed;
								if (bgLimo.x < -275)
								{
									limoKillingState = 4;
									limoSpeed = 800;
								}

							case 4:
								bgLimo.x = FlxMath.lerp(bgLimo.x, -150, FlxMath.bound(elapsed * 9, 0, 1));
								if (Math.round(bgLimo.x) == -150)
								{
									bgLimo.x = -150;
									limoKillingState = 0;
								}
						}

						if (limoKillingState > 2)
						{
							for (i => dancer in grpLimoDancers.members)
							{
								dancer.x = (370 * i) + bgLimo.x + 280;
							}
						}
					}
				case 'mall':
					var bottomBoppers:BGSprite = layers['bottomBoppers'];
					if (heyTimer > 0)
					{
						heyTimer -= elapsed;
						if (heyTimer <= 0)
						{
							bottomBoppers.dance(true);
							heyTimer = 0;
						}
					}
				case 'schoolEvil':
					var bgGhouls:FlxSprite = layers['bgGhouls'];
					if (!Options.save.data.lowQuality && bgGhouls.animation.curAnim.finished)
					{
						bgGhouls.visible = false;
					}
				case 'tank':
					moveTank();
			}
		}
	}

	public function stepHit(step:Int):Void
	{
		if (!Options.save.data.noStage)
		{
			var array:Array<FlxSprite> = slowBacks[step];
			if (array != null && array.length > 0)
			{
				if (hideLastBG)
				{
					for (bg in layers)
					{
						if (!array.contains(bg))
						{
							FlxTween.tween(bg, {alpha: 0}, tweenDuration, {
								onComplete: (tween:FlxTween) ->
								{
									bg.visible = false;
								}
							});
						}
					}
					for (bg in array)
					{
						bg.visible = true;
						FlxTween.tween(bg, {alpha: 1}, tweenDuration);
					}
				}
				else
				{
					for (bg in array)
						bg.visible = !bg.visible;
				}
			}
		}
	}

	public function beatHit(beat:Int):Void
	{
		if (Options.save.data.distractions && animatedLayers.length > 0)
		{
			for (bg in animatedLayers)
				bg.animation.play('idle', true);
		}

		if (!Options.save.data.noStage)
		{
			switch (id)
			{
				case 'halloween':
					if (FlxG.random.bool(Conductor.tempo > 320 ? 100 : 10) && beat > lightningStrikeBeat + lightningOffset)
					{
						if (Options.save.data.distractions)
						{
							lightningStrikeShit(beat);
						}
					}
				case 'school':
					if (Options.save.data.distractions)
					{
						layers['bgGirls'].dance();
					}
				case 'limo':
					if (Options.save.data.distractions)
					{
						groups['grpLimoDancers'].forEach((dancer:BackgroundDancer) ->
						{
							dancer.dance();
						});

						if (FlxG.random.bool(10) && fastCarCanDrive)
							fastCarDrive();
					}
				case 'philly':
					if (Options.save.data.distractions)
					{
						if (!trainMoving)
							trainCooldown += 1;

						if (beat % Conductor.CROTCHETS_PER_MEASURE == 0)
						{
							var phillyCityLights:FlxTypedGroup<FlxSprite> = cast groups['phillyCityLights'];
							phillyCityLights.forEach((light:FlxSprite) ->
							{
								light.visible = false;
							});

							curLight = FlxG.random.int(0, phillyCityLights.length - 1);

							phillyCityLights.members[curLight].visible = true;
						}
					}

					if (beat % 8 == 4 && FlxG.random.bool(Conductor.tempo > 320 ? 150 : 30) && !trainMoving && trainCooldown > 8)
					{
						if (Options.save.data.distractions)
						{
							trainCooldown = FlxG.random.int(-4, 0);
							trainStart();
						}
					}
				case 'mall':
					if (heyTimer <= 0)
						layers['bottomBoppers'].dance(true);
				case 'tank':
					if (Options.save.data.distractions)
					{
						if (beat % 2 == 0)
						{
							groups['tankheadGroup'].forEach((tankhead:BGSprite) ->
							{
								tankhead.dance();
							});
							layers['tankWatchtower'].dance();
						}
					}
			}
		}
	}

	private function copyDataFields(stageDef:StageDef):Void
	{
		defaultZoom = stageDef.defaultZoom;
		isPixelStage = stageDef.isPixelStage;
		boyfriend = stageDef.boyfriend;
		girlfriend = stageDef.girlfriend;
		opponent = stageDef.opponent;
		hideGirlfriend = stageDef.hideGirlfriend;
		cameraBoyfriend = stageDef.cameraBoyfriend;
		cameraOpponent = stageDef.cameraOpponent;
		cameraGirlfriend = stageDef.cameraGirlfriend;
		cameraSpeed = stageDef.cameraSpeed;
	}

	// Variables and Functions for Stages
	private var lightningStrikeBeat:Int = 0;
	private var lightningOffset:Int = 8;

	private function lightningStrikeShit(beat:Int):Void
	{
		FlxG.sound.play(Paths.getRandomSound('thunder_', 1, 2));
		layers['halloweenBG'].animation.play('lightning');

		lightningStrikeBeat = beat;
		lightningOffset = FlxG.random.int(8, 24);

		if (PlayState.instance.boyfriend != null)
		{
			PlayState.instance.boyfriend.playAnim('scared', true);
			PlayState.instance.gf.playAnim('scared', true);
		}
		else
		{
			// GameplayCustomizeState.boyfriend.playAnim('scared', true);
			// GameplayCustomizeState.gf.playAnim('scared', true);
		}
	}

	private var trainMoving:Bool = false;
	private var trainFrameTiming:Float = 0;

	private var trainCars:Int = 8;
	private var trainFinishing:Bool = false;
	private var trainCooldown:Int = 0;
	private var trainSound:FlxSound;

	private function trainStart():Void
	{
		if (Options.save.data.distractions)
		{
			trainMoving = true;
			trainSound.play(true);
		}
	}

	private var startedMoving:Bool = false;

	private function updateTrainPos():Void
	{
		if (Options.save.data.distractions)
		{
			if (trainSound.time >= 4700)
			{
				startedMoving = true;

				if (PlayState.instance.gf != null)
					PlayState.instance.gf.playAnim('hairBlow');
				// else
				// GameplayCustomizeState.gf.playAnim('hairBlow');
			}

			if (startedMoving)
			{
				var phillyTrain:BGSprite = layers['phillyTrain'];
				phillyTrain.x -= 400;

				if (phillyTrain.x < -2000 && !trainFinishing)
				{
					phillyTrain.x = -1150;
					trainCars -= 1;

					if (trainCars <= 0)
						trainFinishing = true;
				}

				if (phillyTrain.x < -4000 && trainFinishing)
					trainReset();
			}
		}
	}

	private function trainReset():Void
	{
		if (Options.save.data.distractions)
		{
			if (PlayState.instance.gf != null)
				PlayState.instance.gf.playAnim('hairFall');
			// else
			// GameplayCustomizeState.gf.playAnim('hairFall');

			layers['phillyTrain'].x = FlxG.width + 200;
			trainMoving = false;
			// trainSound.stop();
			// trainSound.time = 0;
			trainCars = 8;
			trainFinishing = false;
			startedMoving = false;
		}
	}

	private var curLight:Int = 0;

	private var fastCarCanDrive:Bool = true;

	private function resetFastCar():Void
	{
		if (Options.save.data.distractions)
		{
			var fastCar:BGSprite = layers['fastCar'];
			fastCar.x = -12600;
			fastCar.y = FlxG.random.int(140, 250);
			fastCar.velocity.x = 0;
			fastCar.visible = false;
			fastCarCanDrive = true;
		}
	}

	private function fastCarDrive():Void
	{
		if (Options.save.data.distractions)
		{
			FlxG.sound.play(Paths.getRandomSound('carPass', 0, 1), 0.7);

			layers['fastCar'].visible = true;
			layers['fastCar'].velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
			fastCarCanDrive = false;
			new FlxTimer().start(2, (tmr:FlxTimer) ->
			{
				resetFastCar();
			});
		}
	}

	private var limoKillingState:Int = 0;
	private var limoSpeed:Float = 0;

	// TODO Implement the "violence" option for this
	public function killHenchmen():Void
	{
		if (!Options.save.data.lowQuality && Options.save.data.violence && id == 'limo')
		{
			if (limoKillingState < 1)
			{
				var limoMetalPole:FlxSprite = layers['limoMetalPole'];
				var limoLight:FlxSprite = layers['limoLight'];
				var limoCorpse:FlxSprite = layers['limoCorpse'];
				var limoCorpse2:FlxSprite = layers['limoCorpse2'];

				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpse2.visible = false;
				limoKillingState = 1;

				#if FEATURE_ACHIEVEMENTS
				Achievement.henchmenDeath++;
				EngineData.save.data.henchmenDeath = Achievement.henchmenDeath;
				@:privateAccess
				var achieve:String = PlayState.instance.checkForAchievement(['roadkill_enthusiast']);
				if (achieve != null)
				{
					@:privateAccess
					PlayState.instance.startAchievement(achieve);
				}
				else
				{
					EngineData.flushSave();
				}
				#end
			}
		}
	}

	private function resetLimoKill():Void
	{
		if (id == 'limo')
		{
			var limoMetalPole:FlxSprite = layers['limoMetalPole'];
			var limoLight:FlxSprite = layers['limoLight'];
			var limoCorpse:FlxSprite = layers['limoCorpse'];
			var limoCorpse2:FlxSprite = layers['limoCorpse2'];
			limoMetalPole.x = -500;
			limoMetalPole.visible = false;
			limoLight.x = -500;
			limoLight.visible = false;
			limoCorpse.x = -500;
			limoCorpse.visible = false;
			limoCorpse2.x = -500;
			limoCorpse2.visible = false;
		}
	}

	private var tankX:Float = 400;
	private var tankSpeed:Float = FlxG.random.float(5, 7);
	private var tankAngle:Float = FlxG.random.int(-90, 45);

	private function moveTank():Void
	{
		if (!PlayState.instance.inCutscene)
		{
			tankAngle += FlxG.elapsed * tankSpeed;
			var tankRolling:FlxSprite = layers['tankRolling'];
			tankRolling.angle = tankAngle - 90 + 15;
			tankRolling.x = tankX + 1500 * Math.cos(Math.PI / 180 * (1 * tankAngle + 180));
			tankRolling.y = 1300 + 1100 * Math.sin(Math.PI / 180 * (1 * tankAngle + 180));
		}
	}
}
