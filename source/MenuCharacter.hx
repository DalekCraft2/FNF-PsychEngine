package;

import flixel.FlxSprite;
import haxe.io.Path;

typedef MenuCharacterData =
{
	var image:String;
	var ?scale:Float;
	var ?position:Array<Int>;
	var idleAnim:String;
	var confirmAnim:String;
	var ?flipX:Bool;
	var ?loopIdle:Bool;
	var ?dances:Bool;
	var ?danceLeftIndices:Array<Int>;
	var ?danceRightIndices:Array<Int>;
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
		antialiasing = Options.save.data.globalAntialiasing;
		visible = true;

		scale.set(1, 1);
		updateHitbox();

		hasConfirmAnimation = false;
		switch (id)
		{
			case '':
				visible = false;
			default:
				var menuCharacterData:MenuCharacterData = Paths.getJson(Path.join(['menucharacters', id]));
				if (menuCharacterData == null)
				{
					Debug.logError('Could not find menu character data for menu character "$id"; using default');
					menuCharacterData = Paths.getJson(Path.join(['menucharacters', DEFAULT_MENU_CHARACTER]));
				}

				frames = Paths.getSparrowAtlas('menucharacters/${menuCharacterData.image}');

				if (menuCharacterData.idleAnim != null)
				{
					idleAnim = menuCharacterData.idleAnim;
				}
				else
				{
					idleAnim = '';
				}

				if (menuCharacterData.confirmAnim != null)
				{
					confirmAnim = menuCharacterData.confirmAnim;
				}
				else
				{
					confirmAnim = '';
				}

				if (menuCharacterData.flipX != null)
				{
					flipX = menuCharacterData.flipX;
				}
				else
				{
					flipX = false;
				}

				if (menuCharacterData.scale != null)
				{
					scale.set(menuCharacterData.scale, menuCharacterData.scale);
					updateHitbox();
				}
				else
				{
					scale.set(1, 1);
				}

				if (menuCharacterData.position != null)
				{
					offset.set(menuCharacterData.position[0], menuCharacterData.position[1]);
				}
				else
				{
					offset.set();
				}

				if (menuCharacterData.loopIdle != null)
				{
					loopIdle = menuCharacterData.loopIdle;
				}
				else
				{
					loopIdle = false;
				}

				if (menuCharacterData.dances != null)
				{
					dances = menuCharacterData.dances;
				}
				else
				{
					dances = false;
				}

				if (dances)
				{
					if (menuCharacterData.danceLeftIndices != null)
					{
						danceLeftIndices = menuCharacterData.danceLeftIndices;
					}
					else
					{
						danceLeftIndices = [];
					}
					if (menuCharacterData.danceRightIndices != null)
					{
						danceRightIndices = menuCharacterData.danceRightIndices;
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
