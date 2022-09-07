package funkin;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.states.PlayState;
import funkin.states.substates.GameOverSubState;
import funkin.util.XYStruct.CoordStruct;
import haxe.io.Path;

using StringTools;

typedef StageDef =
{
	background:Array<SpriteDef>,
	groups:Array<GroupDef>,
	foreground:Array<SpriteDef>,
	objectOrder:Array<String>,
	playerPosition:CoordStruct,
	gfPosition:CoordStruct,
	opponentPosition:CoordStruct,
	playerCameraOffset:CoordStruct,
	gfCameraOffset:CoordStruct,
	opponentCameraOffset:CoordStruct,
	?hideGirlfriend:Bool,
	?cameraZoom:Float,
	?cameraSpeed:Float,
	?isPixelStage:Bool,
	?danceRate:Int
}

typedef GroupDef =
{
	name:String,
	// ?className:String,
	objects:Array<SpriteDef>
}

typedef SpriteDef =
{
	name:String,
	key:String,
	// Layer: 0 = in front of GF, 1 = in front of Opponent, 2 = in front of Player
	?layer:Int,
	?distraction:Bool,
	?condition:String,
	?className:String,
	?classCtorArgs:Array<Any>,
	?animations:Array<SpriteAnimationDef>,
	?initAnim:String,
	?active:Bool,
	?alpha:Float,
	?visible:Bool,
	?flipX:Bool,
	?flipY:Bool,
	?position:CoordStruct,
	?scrollFactor:CoordStruct,
	// graphicScale and graphicSize are mutually exclusive
	?graphicScale:CoordStruct,
	?graphicSize:CoordStruct,
	?antialiasing:Bool,
	?rotation:Int
	// TODO ^^^ What is this used for?
}

typedef SpriteAnimationDef =
{
	name:String,
	prefix:String,
	?indices:Array<Int>,
	frameRate:Int,
	?loop:Bool
}

// TODO Make this an FlxGroup, like Andromeda
class Stage
{
	public static final DEFAULT_PLAYER_POSITION:FlxPoint = FlxPoint.get(770, 100);
	public static final DEFAULT_OPPONENT_POSITION:FlxPoint = FlxPoint.get(100, 100);
	public static final DEFAULT_GIRLFRIEND_POSITION:FlxPoint = FlxPoint.get(400, 130);

	/**
	 * The internal name of the stage, as used in the file system.
	 */
	public var id:String;

	public var cameraZoom:Float = 0.9;
	public var cameraSpeed:Float = 1;
	public var isPixelStage:Bool = false;
	public var playerPosition:FlxPoint = DEFAULT_PLAYER_POSITION.copyTo(FlxPoint.get());
	public var opponentPosition:FlxPoint = DEFAULT_OPPONENT_POSITION.copyTo(FlxPoint.get());
	public var gfPosition:FlxPoint = DEFAULT_GIRLFRIEND_POSITION.copyTo(FlxPoint.get());
	public var hideGirlfriend:Bool = false;
	public var playerCameraOffset:FlxPoint = FlxPoint.get();
	public var opponentCameraOffset:FlxPoint = FlxPoint.get();
	public var gfCameraOffset:FlxPoint = FlxPoint.get();

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
	 * How often the sprites in `animatedLayers` will dance, measured in "Beats per dance".
	 */
	public var danceRate:Float = 1;

	/**
	 * Add BGs on stage startup, load BG in by using "backgrounds.push(bgVar);"
	 * Layering algorithm for noobs: Everything loads by the method of "On Top", example: You load wall first(Every other added BG layers on it), then you load road(comes on top of wall and doesn't clip through it), then loading street lights(comes on top of wall and road)
	 */
	public var backgrounds:Array<FlxBasic> = [];

	/**
	 * Store BGs here to use them later (for example with slowBacks, using your custom stage event or to adjust position in stage debug menu(press 8 while in PlayState with debug build of the game))
	 */
	public var layers:Map<String, FlxSprite> = [];

	/**
	 * Store Groups
	 */
	public var groups:Map<String, FlxTypedGroup<FlxSprite>> = [];

	/**
	 * Store animated backgrounds and make them play animation(Animation must be named "idle"!! Else use groups/layers and script it in stepHit/beatHit function of this file!!)
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

	// TODO Make a static function for creating stages instead of using the constructor
	public function new(id:String)
	{
		this.id = id;
		var stageDef:StageDef = Paths.getJson(Path.join(['stages', id]));
		if (stageDef == null)
		{
			Debug.logError('Could not find stage data for stage "$id"');
			return;
		}
		if (stageDef.cameraZoom != null && stageDef.cameraZoom > 0)
			cameraZoom = stageDef.cameraZoom;
		if (stageDef.cameraSpeed != null && stageDef.cameraSpeed > 0)
			cameraSpeed = stageDef.cameraSpeed;
		if (stageDef.isPixelStage != null)
			isPixelStage = stageDef.isPixelStage;
		if (stageDef.playerPosition != null)
			playerPosition.set(stageDef.playerPosition.x, stageDef.playerPosition.y);
		if (stageDef.opponentPosition != null)
			opponentPosition.set(stageDef.opponentPosition.x, stageDef.opponentPosition.y);
		if (stageDef.gfPosition != null)
			gfPosition.set(stageDef.gfPosition.x, stageDef.gfPosition.y);
		if (stageDef.hideGirlfriend != null)
			hideGirlfriend = stageDef.hideGirlfriend;
		if (stageDef.playerCameraOffset != null)
			playerCameraOffset.set(stageDef.playerCameraOffset.x, stageDef.playerCameraOffset.y);
		if (stageDef.opponentCameraOffset != null)
			opponentCameraOffset.set(stageDef.opponentCameraOffset.x, stageDef.opponentCameraOffset.y);
		if (stageDef.gfCameraOffset != null)
			gfCameraOffset.set(stageDef.gfCameraOffset.x, stageDef.gfCameraOffset.y);
		if (stageDef.danceRate != null)
			danceRate = stageDef.danceRate;

		if (Options.profile.noStage)
			return;

		if (stageDef.groups != null)
		{
			for (groupDef in stageDef.groups)
			{
				var group:FlxTypedGroup<FlxSprite> = createGroupFromStruct(groupDef);
				for (spriteDef in groupDef.objects)
				{
					var sprite:FlxSprite = createSpriteFromStruct(spriteDef);
					if (spriteDef.distraction && !Options.profile.distractions)
					{
						continue;
					}
					if (sprite.animation.exists('idle'))
					{
						animatedLayers.push(sprite);
					}
					layers[spriteDef.name] = sprite;
					if (stageDef.objectOrder == null || stageDef.objectOrder.length == 0)
					{
						backgrounds.push(sprite);
					}
					group.add(sprite);
				}
				groups[groupDef.name] = group;
			}
		}

		if (stageDef.background != null)
		{
			for (spriteDef in stageDef.background)
			{
				var sprite:FlxSprite = createSpriteFromStruct(spriteDef);
				if (spriteDef.distraction && !Options.profile.distractions)
				{
					continue;
				}
				if (sprite.animation.exists('idle'))
				{
					animatedLayers.push(sprite);
				}
				layers[spriteDef.name] = sprite;
				if (stageDef.objectOrder == null || stageDef.objectOrder.length == 0)
				{
					backgrounds.push(sprite);
				}
			}
		}

		if (stageDef.objectOrder != null)
		{
			for (objectName in stageDef.objectOrder)
			{
				if (layers.exists(objectName))
				{
					var sprite:FlxSprite = layers[objectName];
					backgrounds.push(sprite);
				}
				else if (groups.exists(objectName))
				{
					var group:FlxTypedGroup<FlxSprite> = groups[objectName];
					backgrounds.push(group);
				}
			}
		}

		if (stageDef.foreground != null)
		{
			for (spriteDef in stageDef.foreground)
			{
				var sprite:FlxSprite = createSpriteFromStruct(spriteDef);
				if (spriteDef.distraction && !Options.profile.distractions)
				{
					continue;
				}
				if (sprite.animation.exists('idle'))
				{
					animatedLayers.push(sprite);
				}
				layers[spriteDef.name] = sprite;
				foregrounds[spriteDef.layer].push(sprite);
			}
		}

		switch (id)
		{
			case 'philly':
				trainSound = new FlxSound().loadEmbedded(Paths.getSound('train_passes'));
				Paths.precacheSound('train_passes');

				var blammedLightsBlack:FlxSprite = new FlxSprite(FlxG.width * -0.5,
					FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				blammedLightsBlack.visible = false;
				blammedLightsBlack.antialiasing = Options.profile.globalAntialiasing;
				layers['blammedLightsBlack'] = blammedLightsBlack;
				backgrounds.push(blammedLightsBlack);

				var phillyWindowEvent:FlxSprite = new FlxSprite(-10, 0).loadGraphic(Paths.getGraphic(Path.join(['stages', 'philly', 'window'])));
				phillyWindowEvent.scrollFactor.set(0.3, 0.3);
				phillyWindowEvent.scale.set(0.85, 0.85);
				phillyWindowEvent.updateHitbox();
				phillyWindowEvent.visible = false;
				phillyWindowEvent.antialiasing = Options.profile.globalAntialiasing;
				layers['phillyWindowEvent'] = phillyWindowEvent;
				backgrounds.push(phillyWindowEvent);

				var phillyGlowGradient:PhillyGlow.PhillyGlowGradient = new PhillyGlow.PhillyGlowGradient(-400,
					225); // This shit was refusing to properly load FlxGradient so fuck it
				// TODO Fix the above Psych stuff
				phillyGlowGradient.visible = false;
				phillyGlowGradient.antialiasing = Options.profile.globalAntialiasing;
				layers['phillyGlowGradient'] = phillyGlowGradient;
				backgrounds.push(phillyGlowGradient);

				Paths.precacheGraphic(Path.join(['stages', 'philly', 'particle']));
				var phillyGlowParticles:FlxTypedGroup<PhillyGlow.PhillyGlowParticle> = new FlxTypedGroup();
				phillyGlowParticles.visible = false;
				groups['phillyGlowParticles'] = cast phillyGlowParticles;
				backgrounds.push(phillyGlowParticles);

			case 'limo':
				// PRECACHE SOUND
				Paths.precacheSound('dancerdeath');

				resetLimoKill();
				resetFastCar();

			case 'school' | 'schoolEvil':
				GameOverSubState.deathSoundName = 'fnf_loss_sfx-pixel';
				GameOverSubState.loopSoundName = 'gameOver-pixel';
				GameOverSubState.endSoundName = 'gameOverEnd-pixel';
				GameOverSubState.characterName = 'bf-pixel-dead';
			case 'tank':
				var tankClouds:FlxSprite = layers['tankClouds'];
				if (tankClouds != null)
				{
					tankClouds.setPosition(FlxG.random.int(-700, -100), FlxG.random.int(-20, 20));
					tankClouds.velocity.x = FlxG.random.float(5, 15);
				}

				moveTank();
		}
	}

	private function createGroupFromStruct(groupDef:GroupDef):FlxTypedGroup<FlxSprite>
	{
		// TODO How the hell does Myth use a variable for a generic in a constructor?
		// var theClass:Class<Any>;
		// if (groupDef.className != null && groupDef.className != '')
		// {
		// 	theClass = Type.resolveClass(groupDef.className);
		// }
		// else
		// {
		// 	theClass = FlxSprite;
		// }

		var group:FlxTypedGroup<FlxSprite> = new FlxTypedGroup();

		return group;
	}

	private function createSpriteFromStruct(spriteDef:SpriteDef):FlxSprite
	{
		var x:Float = spriteDef.position == null ? 0 : spriteDef.position.x;
		var y:Float = spriteDef.position == null ? 0 : spriteDef.position.y;

		var sprite:FlxSprite;
		if (spriteDef.className != null && spriteDef.className != '')
		{
			var ctorArgs:Array<Any> = spriteDef.classCtorArgs == null ? [] : spriteDef.classCtorArgs;
			var theClass:Class<Any> = Type.resolveClass(spriteDef.className);
			sprite = Type.createInstance(theClass, ctorArgs);
		}
		else
		{
			sprite = new FlxSprite(x, y);
			if (spriteDef.animations != null && spriteDef.animations.length > 0)
			{
				sprite.frames = Paths.getFrames(spriteDef.key, AUTO);

				if (spriteDef.animations != null)
				{
					for (anim in spriteDef.animations)
					{
						var animName:String = anim.name;
						var animPrefix:String = anim.prefix;
						var animFrameRate:Int = anim.frameRate;
						var animLoop:Bool = anim.loop;
						var animIndices:Array<Int> = anim.indices;
						if (animIndices != null && animIndices.length > 0)
						{
							if (animPrefix != null && animPrefix != '')
							{
								sprite.animation.addByIndices(animName, animPrefix, animIndices, '', animFrameRate, animLoop);
							}
							else
							{
								sprite.animation.add(animName, animIndices, animFrameRate, animLoop);
							}
						}
						else
						{
							sprite.animation.addByPrefix(animName, animPrefix, animFrameRate, animLoop);
						}
					}

					if (spriteDef.initAnim != null) // ... (which it shouldn't, usually)
					{
						sprite.animation.play(spriteDef.initAnim);
					}
				}
			}
			else if (spriteDef.key != null)
			{
				sprite.loadGraphic(Paths.getGraphic(spriteDef.key));
			}
		}

		if (spriteDef.graphicScale != null)
		{
			var scaleX:Float = spriteDef.graphicScale.x;
			var scaleY:Float = spriteDef.graphicScale.y;
			sprite.scale.set(scaleX, scaleY);
			sprite.updateHitbox();
		}
		else if (spriteDef.graphicSize != null)
		{
			var sizeX:Float = spriteDef.graphicSize.x;
			var sizeY:Float = spriteDef.graphicSize.y;
			sprite.setGraphicSize(Std.int(sizeX), Std.int(sizeY));
			sprite.updateHitbox();
		}

		var scrollX:Float = spriteDef.scrollFactor == null ? 1 : spriteDef.scrollFactor.x;
		var scrollY:Float = spriteDef.scrollFactor == null ? 1 : spriteDef.scrollFactor.y;
		sprite.scrollFactor.set(scrollX, scrollY);

		var flipX:Bool = spriteDef.flipX == null ? false : spriteDef.flipX;
		sprite.flipX = flipX;

		var flipY:Bool = spriteDef.flipY == null ? false : spriteDef.flipY;
		sprite.flipY = flipY;

		var antialiasing:Bool = spriteDef.antialiasing == null ? true : spriteDef.antialiasing;
		if (antialiasing)
		{
			antialiasing = Options.profile.globalAntialiasing;
		}
		sprite.antialiasing = antialiasing;

		var visible:Bool = spriteDef.visible == null ? true : spriteDef.visible;
		sprite.visible = visible;

		var alpha:Float = spriteDef.alpha == null ? 1 : spriteDef.alpha;
		sprite.alpha = alpha;

		sprite.updateHitbox();

		var active:Bool = spriteDef.active == null ? true : spriteDef.active;
		sprite.active = active;

		return sprite;
	}

	// For the mall boppers' "hey" animation
	// TODO I might need to rework this again because of this new Stage system
	public var heyTimer:Float;

	public function update(elapsed:Float):Void
	{
		if (!Options.profile.noStage)
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
					var phillyWindow:FlxSprite = layers['phillyWindow'];
					phillyWindow.alpha -= (Conductor.beatLength / TimingConstants.MILLISECONDS_PER_SECOND) * elapsed * 1.5;

					var phillyGlowParticles:FlxTypedGroup<PhillyGlow.PhillyGlowParticle> = cast groups['phillyGlowParticles'];

					if (phillyGlowParticles != null)
					{
						var i:Int = phillyGlowParticles.members.length - 1;
						while (i > 0)
						{
							var particle:PhillyGlow.PhillyGlowParticle = phillyGlowParticles.members[i];
							if (particle.alpha < 0)
							{
								particle.kill();
								phillyGlowParticles.remove(particle, true);
								particle.destroy();
							}
							--i;
						}
					}
				case 'limo':
					if (!Options.profile.lowQuality)
					{
						var bgLimo:FlxSprite = layers['bgLimo'];
						var limoMetalPole:FlxSprite = layers['limoMetalPole'];
						var limoLight:FlxSprite = layers['limoLight'];
						var limoCorpse:FlxSprite = layers['limoCorpse'];
						var limoCorpse2:FlxSprite = layers['limoCorpse2'];
						var grpLimoParticles:FlxTypedGroup<FlxSprite> = groups['grpLimoParticles'];
						var grpLimoDancers:FlxTypedGroup<BackgroundDancer> = cast groups['grpLimoDancers'];

						if (limoMetalPole != null && limoLight != null && limoCorpse != null && limoCorpse2 != null && grpLimoParticles != null)
						{
							grpLimoParticles.forEach((spr:FlxSprite) ->
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
													var particle:FlxSprite = new FlxSprite(dancer.x + 200, dancer.y);
													particle.frames = Paths.getFrames(Path.join(['stages', 'limo', 'gore', 'noooooo']));
													particle.animation.addByPrefix('idle', 'hench leg spin${diffStr}PINK', 24, false);
													particle.animation.play('idle');
													particle.scrollFactor.set(0.4, 0.4);
													grpLimoParticles.add(particle);
													var particle:FlxSprite = new FlxSprite(dancer.x + 160, dancer.y + 200);
													particle.frames = Paths.getFrames(Path.join(['stages', 'limo', 'gore', 'noooooo']));
													particle.animation.addByPrefix('idle', 'hench arm spin${diffStr}PINK', 24, false);
													particle.animation.play('idle');
													particle.scrollFactor.set(0.4, 0.4);
													grpLimoParticles.add(particle);
													var particle:FlxSprite = new FlxSprite(dancer.x, dancer.y + 50);
													particle.frames = Paths.getFrames(Path.join(['stages', 'limo', 'gore', 'noooooo']));
													particle.animation.addByPrefix('idle', 'hench head spin${diffStr}PINK', 24, false);
													particle.animation.play('idle');
													particle.scrollFactor.set(0.4, 0.4);
													grpLimoParticles.add(particle);

													var particle:FlxSprite = new FlxSprite(dancer.x - 110, dancer.y + 20);
													particle.frames = Paths.getFrames(Path.join(['stages', 'limo', 'gore', 'stupidBlood']));
													particle.animation.addByPrefix('idle', 'blood', 24, false);
													particle.animation.play('idle');
													particle.scrollFactor.set(0.4, 0.4);
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
					}
				case 'mall':
					var bottomBoppers:FlxSprite = layers['bottomBoppers'];
					if (bottomBoppers != null)
					{
						if (heyTimer > 0)
						{
							heyTimer -= elapsed;
							if (heyTimer <= 0)
							{
								bottomBoppers.animation.play('idle');
								heyTimer = 0;
							}
						}
					}
				case 'schoolEvil':
					var bgGhouls:FlxSprite = layers['bgGhouls'];
					if (bgGhouls != null)
					{
						if (!Options.profile.lowQuality && bgGhouls.animation.finished)
						{
							bgGhouls.visible = false;
						}
					}
				case 'tank':
					moveTank();
			}
		}
	}

	public function stepHit(step:Int):Void
	{
		if (!Options.profile.noStage)
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
		if (beat % danceRate == 0 && Options.profile.distractions && animatedLayers.length > 0)
		{
			for (bg in animatedLayers)
			{
				bg.animation.play('idle', true);
			}
		}

		if (!Options.profile.noStage)
		{
			switch (id)
			{
				case 'halloween':
					if (FlxG.random.bool(Conductor.tempo > 320 ? 100 : 10) && beat > lightningStrikeBeat + lightningOffset)
					{
						if (Options.profile.distractions)
						{
							lightningStrike(beat);
						}
					}
				case 'philly':
					if (Options.profile.distractions)
					{
						if (!trainMoving)
							trainCooldown += 1;
					}

					if (beat % 8 == 4 && FlxG.random.bool(Conductor.tempo > 320 ? 150 : 30) && !trainMoving && trainCooldown > 8)
					{
						if (Options.profile.distractions)
						{
							trainCooldown = FlxG.random.int(-4, 0);
							trainStart();
						}
					}
				case 'limo':
					if (Options.profile.distractions)
					{
						var grpLimoDancers:FlxTypedGroup<BackgroundDancer> = cast groups['grpLimoDancers'];
						if (grpLimoDancers != null)
						{
							grpLimoDancers.forEach((dancer:BackgroundDancer) ->
							{
								dancer.dance();
							});
						}

						if (FlxG.random.bool(10) && fastCarCanDrive)
							fastCarDrive();
					}
				case 'mall':
					if (heyTimer <= 0)
					{
						var bottomBoppers:FlxSprite = layers['bottomBoppers'];
						if (bottomBoppers != null)
							bottomBoppers.animation.play('idle');
					}
				case 'school':
					if (Options.profile.distractions)
					{
						var bgGirls:BackgroundGirls = cast layers['bgGirls'];
						if (bgGirls != null)
							bgGirls.dance();
					}
			}
		}
	}

	public function barHit(bar:Int):Void
	{
		if (!Options.profile.noStage)
		{
			switch (id)
			{
				case 'philly':
					if (Options.profile.distractions)
					{
						var phillyWindow:FlxSprite = layers['phillyWindow'];
						if (phillyWindow != null)
						{
							curLight = FlxG.random.int(0, PlayState.PHILLY_LIGHTS_COLORS.length - 1, [curLight]);
							phillyWindow.color = PlayState.PHILLY_LIGHTS_COLORS[curLight];
							phillyWindow.alpha = 1;
						}
					}
			}
		}
	}

	// Variables and Functions for Stages
	private var lightningStrikeBeat:Int = 0;
	private var lightningOffset:Int = 8;

	private function lightningStrike(beat:Int):Void
	{
		FlxG.sound.play(Paths.getRandomSound('thunder_', 1, 2));
		var halloweenBG:FlxSprite = layers['halloweenBG'];
		if (halloweenBG != null)
			halloweenBG.animation.play('lightning');

		lightningStrikeBeat = beat;
		lightningOffset = FlxG.random.int(8, 24);

		if (PlayState.instance.boyfriend != null)
		{
			PlayState.instance.boyfriend.playAnim('scared', true);
			PlayState.instance.gf.playAnim('scared', true);
		}
		// else
		// {
		// 	GameplayCustomizeState.boyfriend.playAnim('scared', true);
		// 	GameplayCustomizeState.gf.playAnim('scared', true);
		// }
	}

	private var trainMoving:Bool = false;
	private var trainFrameTiming:Float = 0;

	private var trainCars:Int = 8;
	private var trainFinishing:Bool = false;
	private var trainCooldown:Int = 0;
	private var trainSound:FlxSound;

	private function trainStart():Void
	{
		if (Options.profile.distractions)
		{
			trainMoving = true;
			trainSound.play(true);
		}
	}

	private var startedMoving:Bool = false;

	private function updateTrainPos():Void
	{
		if (Options.profile.distractions)
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
				var phillyTrain:FlxSprite = layers['phillyTrain'];
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
		if (Options.profile.distractions)
		{
			if (PlayState.instance.gf != null)
			{
				PlayState.instance.gf.playAnim('hairFall');
			}
			// else
			// {
			// 	GameplayCustomizeState.gf.playAnim('hairFall');
			// }

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
		if (Options.profile.distractions)
		{
			var fastCar:FlxSprite = layers['fastCar'];
			fastCar.x = -12600;
			fastCar.y = FlxG.random.int(140, 250);
			fastCar.velocity.x = 0;
			fastCar.visible = false;
			fastCarCanDrive = true;
		}
	}

	private function fastCarDrive():Void
	{
		if (Options.profile.distractions)
		{
			FlxG.sound.play(Paths.getRandomSound('carPass', 0, 1), 0.7);

			var fastCar:FlxSprite = layers['fastCar'];
			fastCar.visible = true;
			fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
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
		if (!Options.profile.lowQuality && Options.profile.violence && id == 'limo')
		{
			if (limoKillingState < 1)
			{
				var limoMetalPole:FlxSprite = layers['limoMetalPole'];
				if (limoMetalPole != null)
				{
					limoMetalPole.x = -400;
					limoMetalPole.visible = true;
				}
				var limoLight:FlxSprite = layers['limoLight'];
				if (limoLight != null)
				{
					limoLight.visible = true;
				}
				var limoCorpse:FlxSprite = layers['limoCorpse'];
				if (limoCorpse != null)
				{
					limoCorpse.visible = false;
				}
				var limoCorpse2:FlxSprite = layers['limoCorpse2'];
				if (limoCorpse2 != null)
				{
					limoCorpse2.visible = false;
				}

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
			if (limoMetalPole != null)
			{
				limoMetalPole.x = -500;
				limoMetalPole.visible = false;
			}

			var limoLight:FlxSprite = layers['limoLight'];
			if (limoLight != null)
			{
				limoLight.x = -500;
				limoLight.visible = false;
			}

			var limoCorpse:FlxSprite = layers['limoCorpse'];
			if (limoCorpse != null)
			{
				limoCorpse.x = -500;
				limoCorpse.visible = false;
			}

			var limoCorpse2:FlxSprite = layers['limoCorpse2'];
			if (limoCorpse2 != null)
			{
				limoCorpse2.x = -500;
				limoCorpse2.visible = false;
			}
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
