package;

import flixel.FlxSprite;
import haxe.Json;
import openfl.utils.Assets;
#if FEATURE_MODS
import sys.FileSystem;
import sys.io.File;
#end

typedef MenuCharacterData =
{
	var image:String;
	var scale:Float;
	var position:Array<Int>;
	var idle_anim:String;
	var confirm_anim:String;
	var flipX:Bool;
}

class MenuCharacter extends FlxSprite
{
	public var character:String;
	public var hasConfirmAnimation:Bool = false;

	private static final DEFAULT_CHARACTER:String = 'bf';

	public function new(x:Float, character:String = 'bf')
	{
		super(x);

		changeCharacter(character);
	}

	public function changeCharacter(?character:String = 'bf'):Void
	{
		if (character == null)
			character = '';
		if (character == this.character)
			return;

		this.character = character;
		antialiasing = Options.save.data.globalAntialiasing;
		visible = true;

		var dontPlayAnim:Bool = false;
		scale.set(1, 1);
		updateHitbox();

		hasConfirmAnimation = false;
		switch (character)
		{
			case '':
				visible = false;
				dontPlayAnim = true;
			default:
				var characterPath:String = 'menucharacters/$character';

				var menuCharacterData:MenuCharacterData = Paths.getJson(characterPath);
				if (menuCharacterData == null)
				{
					menuCharacterData = Paths.getJson('menucharacters/$DEFAULT_CHARACTER');
				}

				frames = Paths.getSparrowAtlas('menucharacters/${menuCharacterData.image}');
				animation.addByPrefix('idle', menuCharacterData.idle_anim, 24);

				var confirmAnim:String = menuCharacterData.confirm_anim;
				if (confirmAnim != null && confirmAnim != menuCharacterData.idle_anim)
				{
					animation.addByPrefix('confirm', confirmAnim, 24, false);
					if (animation.getByName('confirm') != null) // check for invalid animation
						hasConfirmAnimation = true;
				}

				flipX = (menuCharacterData.flipX == true);

				if (menuCharacterData.scale != 1)
				{
					scale.set(menuCharacterData.scale, menuCharacterData.scale);
					updateHitbox();
				}
				offset.set(menuCharacterData.position[0], menuCharacterData.position[1]);
				animation.play('idle');
		}
	}
}
