package funkin.states.substates;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.io.Path;

class GameOverSubState extends MusicBeatSubState
{
	public static var instance:GameOverSubState;

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	public static var tempo:Int = 100;

	public var boyfriend:PlayableCharacter;

	private var camFollow:FlxPoint;
	private var camFollowPos:FlxObject;
	private var updateCamera:Bool = false;
	private var bfX:Float;
	private var bfY:Float;

	public static function resetVariables():Void
	{
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		tempo = 100;
	}

	public function new(x:Float, y:Float)
	{
		super();

		bfX = x;
		bfY = y;
	}

	override public function create():Void
	{
		super.create();

		instance = this;

		#if FEATURE_SCRIPTS
		PlayState.instance.setOnScripts('inGameOver', true);
		#end

		Conductor.songPosition = 0;

		boyfriend = new PlayableCharacter(bfX, bfY, characterName);
		boyfriend.x += boyfriend.position.x;
		boyfriend.y += boyfriend.position.y;
		add(boyfriend);

		camFollow = new FlxPoint(boyfriend.getGraphicMidpoint().x, boyfriend.getGraphicMidpoint().y);

		FlxG.sound.play(Paths.getSound(deathSoundName));
		Conductor.tempo = tempo;
		camera.scroll.set();
		camera.target = null;

		boyfriend.playAnim('firstDeath');

		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowPos.setPosition(camera.scroll.x + (camera.width / 2), camera.scroll.y + (camera.height / 2));
		add(camFollowPos);

		#if FEATURE_SCRIPTS
		PlayState.instance.callOnScripts('onGameOverStart', []);
		#end
	}

	private var isFollowingAlready:Bool = false;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if FEATURE_SCRIPTS
		PlayState.instance.callOnScripts('onUpdate', [elapsed]);
		#end
		if (updateCamera)
		{
			var lerpVal:Float = FlxMath.bound(elapsed * 0.6, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		}

		if (controls.ACCEPT)
		{
			endBullshit();
		}

		if (controls.BACK)
		{
			FlxG.sound.music.stop();
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;

			if (PlayState.isStoryMode)
				FlxG.switchState(new StoryMenuState());
			else
				FlxG.switchState(new FreeplayState());

			PlayState.loadRep = false;
			PlayState.stageTesting = false;
			#if FEATURE_SCRIPTS
			PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
			#end
		}

		if (boyfriend.animation.name == 'firstDeath')
		{
			if (boyfriend.animation.frameIndex >= 12 && !isFollowingAlready)
			{
				camera.follow(camFollowPos, LOCKON, 1);
				updateCamera = true;
				isFollowingAlready = true;
			}

			if (boyfriend.animation.finished && !boyfriend.startedDeath)
			{
				coolStartDeath();
				boyfriend.startedDeath = true;
			}
		}

		if (FlxG.sound.music.playing)
		{
			Conductor.songPosition = FlxG.sound.music.time;
		}
		#if FEATURE_SCRIPTS
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	override public function destroy():Void
	{
		super.destroy();

		instance = null;
	}

	override public function beatHit(beat:Int):Void
	{
		super.beatHit(beat);

		if (boyfriend.startedDeath && !isEnding)
		{
			boyfriend.playAnim('deathLoop', true);
		}
	}

	private var isEnding:Bool = false;

	private function coolStartDeath(volume:Float = 1):Void
	{
		FlxG.sound.playMusic(Paths.getMusic(loopSoundName), volume);

		if (PlayState.song.id == 'ugh' || PlayState.song.id == 'guns' || PlayState.song.id == 'stress')
		{
			// Jeff death sounds
			FlxG.sound.play(Paths.getRandomSound(Path.join(['jeffGameover', 'jeffGameover-']), 0, 25));
		}
	}

	private function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;
			boyfriend.playAnim('deathConfirm', true);
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.getMusic(endSoundName)); // FIXME The Vessel song has taught me that audio can be used to crash the game if the source is null
			new FlxTimer().start(0.7, (tmr:FlxTimer) ->
			{
				camera.fade(FlxColor.BLACK, 2, false, () ->
				{
					FlxG.resetState();
					PlayState.stageTesting = false;
				});
			});
			#if FEATURE_SCRIPTS
			PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
			#end
		}
	}
}
