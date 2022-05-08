package;

import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxGraphicAsset;
import haxe.io.Path;

using StringTools;

class HealthIcon extends FlxSprite
{
	/**
	 * The icon ID used in case the requested icon is missing.
	 */
	public static inline final DEFAULT_ICON:String = 'bf';

	public var sprTracker:FlxSprite;
	public var hasWinningIcon:Bool = false;

	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = DEFAULT_ICON, isPlayer:Bool = false)
	{
		super();

		isOldIcon = (char == 'bf-old');
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}

	override public function updateHitbox():Void
	{
		super.updateHitbox();

		offset.x = iconOffsets[0];
		offset.y = iconOffsets[1];
	}

	private var iconOffsets:Array<Float> = [0, 0];

	public function changeIcon(char:String):Void
	{
		if (this.char != char)
		{
			var iconPath:String = Path.join(['icons', char]);
			if (!Paths.exists(Paths.image(iconPath), IMAGE))
				iconPath = Path.join(['icons', 'icon-$char']); // Legacy support
			if (!Paths.exists(Paths.image(iconPath), IMAGE))
			{
				Debug.logError('Could not find character icon with ID "$char"; using default');
				iconPath = Path.join(['icons', 'face']); // Prevents crash from missing icon
			}
			var file:FlxGraphicAsset = Paths.getGraphic(iconPath);

			loadGraphic(file, true, 150, 150);
			iconOffsets[0] = (width - 150) / 2;
			iconOffsets[1] = (width - 150) / 2;
			updateHitbox();

			hasWinningIcon = (animation.frames == 3);

			if (hasWinningIcon)
				animation.add(char, [0, 1, 2], 0, false, isPlayer);
			else
				animation.add(char, [0, 1], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			antialiasing = Options.save.data.globalAntialiasing;
			if (char.endsWith('-pixel'))
			{
				antialiasing = false;
			}
		}
	}

	public function getCharacter():String
	{
		return char;
	}
}
