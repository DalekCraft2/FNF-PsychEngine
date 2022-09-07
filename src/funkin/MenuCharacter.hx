package funkin;

import flixel.FlxSprite;
import haxe.io.Path;

typedef MenuCharacterDef =
{
	image:String,
	?scale:Float,
	?position:Array<Float>,
	idleAnim:String,
	confirmAnim:String,
	?flipX:Bool,
	?loopIdle:Bool,
	?dances:Bool,
	?danceLeftIndices:Array<Int>,
	?danceRightIndices:Array<Int>,
}

class MenuCharacter extends FlxSprite
{
	/**
	 * The menu character ID used in case the requested menu character is missing.
	 */
	public static inline final DEFAULT_MENU_CHARACTER:String = 'bf';

	public var id:String;

	public var idleAnim:String = '';
	public var confirmAnim:String = '';
	public var loopIdle:Bool = false;
	public var dances:Bool = false;

	private var danceLeftIndices:Array<Int> = [];
	private var danceRightIndices:Array<Int> = [];
	private var dancingLeft:Bool = false;

	private var hasConfirmAnimation:Bool = false;

	public function new(x:Float, id:String = DEFAULT_MENU_CHARACTER)
	{
		super(x);

		changeCharacter(id);
	}

	public function changeCharacter(id:String = DEFAULT_MENU_CHARACTER):Void
	{
		if (id == this.id)
			return;

		this.id = id;
		antialiasing = Options.profile.globalAntialiasing;
		visible = true;

		scale.set(1, 1);
		updateHitbox();

		hasConfirmAnimation = false;
		switch (id)
		{
			case '':
				visible = false;
			default:
				var menuCharacterDef:MenuCharacterDef = Paths.getJson(Path.join(['menu_characters', id]));
				if (menuCharacterDef == null)
				{
					Debug.logError('Could not find menu character data for menu character "$id"; using default');
					menuCharacterDef = Paths.getJson(Path.join(['menu_characters', DEFAULT_MENU_CHARACTER]));
				}

				frames = Paths.getFrames(Path.join(['ui', 'story', 'menu_characters', menuCharacterDef.image]));

				if (menuCharacterDef.idleAnim != null)
				{
					idleAnim = menuCharacterDef.idleAnim;
				}

				if (menuCharacterDef.confirmAnim != null)
				{
					confirmAnim = menuCharacterDef.confirmAnim;
				}

				if (menuCharacterDef.flipX != null)
				{
					flipX = menuCharacterDef.flipX;
				}

				if (menuCharacterDef.scale != null)
				{
					scale.set(menuCharacterDef.scale, menuCharacterDef.scale);
					updateHitbox();
				}

				if (menuCharacterDef.position != null)
				{
					offset.set(menuCharacterDef.position[0], menuCharacterDef.position[1]);
				}

				if (menuCharacterDef.loopIdle != null)
				{
					loopIdle = menuCharacterDef.loopIdle;
				}
				else
				{
					loopIdle = false;
				}

				if (menuCharacterDef.dances != null)
				{
					dances = menuCharacterDef.dances;
				}
				else
				{
					dances = false;
				}

				if (dances)
				{
					if (menuCharacterDef.danceLeftIndices != null)
					{
						danceLeftIndices = menuCharacterDef.danceLeftIndices;
					}
					else
					{
						danceLeftIndices = [];
					}
					if (menuCharacterDef.danceRightIndices != null)
					{
						danceRightIndices = menuCharacterDef.danceRightIndices;
					}
					else
					{
						danceRightIndices = [];
					}

					animation.addByIndices('danceLeft', idleAnim, danceLeftIndices, '', 24, false);
					animation.addByIndices('danceRight', idleAnim, danceRightIndices, '', 24, false);
				}
				else
				{
					animation.addByPrefix('idle', idleAnim, 24, loopIdle);
				}
				if (confirmAnim != null && confirmAnim != idleAnim)
				{
					animation.addByPrefix('confirm', confirmAnim, 24, false);
				}

				if (loopIdle)
				{
					animation.play('idle');
				}
				else
				{
					bopHead(true);
				}
		}
	}

	public function bopHead(lastFrame:Bool = false):Void
	{
		if (dances)
		{
			dancingLeft = !dancingLeft;

			if (dancingLeft)
				animation.play('danceLeft', true);
			else
				animation.play('danceRight', true);
		}
		else if (id == '')
		{
			// Don't try to play an animation on an invisible character.
			return;
		}
		else
		{
			if (loopIdle)
				return;

			// doesn't dance so we do da normal animation
			if (animation.name == 'confirm')
				return;
			animation.play('idle', true);
		}
		if (lastFrame)
		{
			animation.finish();
		}
	}

	public function playConfirmAnim():Void
	{
		if (animation.exists('confirm'))
			animation.play('confirm');
	}
}
