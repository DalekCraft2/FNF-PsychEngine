package funkin.ui;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import haxe.io.Path;

class HealthBar extends FlxSpriteGroup
{
	private static inline final DEFAULT_MIN_HEALTH:Float = 0;
	private static inline final DEFAULT_MAX_HEALTH:Float = 2;

	/**
	 * The threshold, in percent, of how close an icon must be to either end of the bar in order to change to a winning/losing icon.
	 */
	private static inline final ICON_CHANGE_THRESHOLD:Float = 30;

	public var bg:FlxSprite;
	public var bar:FlxBar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	public function new(x:Float, y:Float, player1:String, player2:String, ?instance:Dynamic, ?property:String, min:Float = DEFAULT_MIN_HEALTH,
			max:Float = DEFAULT_MAX_HEALTH, baseColor:FlxColor = 0xFFFF0000, secondaryColor:FlxColor = 0xFF66FF33)
	{
		super(x, y);

		bg = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'hud', 'healthBar'])));

		bar = new FlxBar(bg.x + 4, bg.y + 4, RIGHT_TO_LEFT, Std.int(bg.width - 8), Std.int(bg.height - 8), instance, property, min, max);
		setColors(baseColor, secondaryColor);

		iconP1 = new HealthIcon(player1, true);
		iconP1.y = bar.y - iconP1.height / 2;

		iconP2 = new HealthIcon(player2, false);
		iconP2.y = bar.y - iconP2.height / 2;

		add(bg);
		add(bar);
		add(iconP1);
		add(iconP2);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var percent:Float = bar.percent;
		var opponentPercent:Float = 100 - bar.percent;

		var ratio:Float = FlxMath.bound(1 - elapsed * 9, 0, 1);
		setIconScale(FlxMath.lerp(1, iconP1.scale.x, ratio), FlxMath.lerp(1, iconP2.scale.x, ratio));

		var iconOffset:Int = -26;

		iconP1.x = bar.x + bar.width * FlxMath.remapToRange(percent, 0, 100, 100, 0) * 0.01 + iconOffset;
		iconP2.x = bar.x + bar.width * FlxMath.remapToRange(percent, 0, 100, 100, 0) * 0.01 - iconOffset;
		iconP2.x -= iconP2.width / iconP2.scale.x;

		if (percent < ICON_CHANGE_THRESHOLD)
			iconP1.setIconMode(LOSING);
		else if (percent > 100 - ICON_CHANGE_THRESHOLD)
			iconP1.setIconMode(WINNING);
		else
			iconP1.setIconMode(NEUTRAL);

		if (opponentPercent < ICON_CHANGE_THRESHOLD)
			iconP2.setIconMode(LOSING);
		else if (opponentPercent > 100 - ICON_CHANGE_THRESHOLD)
			iconP2.setIconMode(WINNING);
		else
			iconP2.setIconMode(NEUTRAL);
	}

	public function beatHit(beat:Float):Void
	{
		setIconScale(1.2, 1.2);
	}

	public function setColors(baseColor:FlxColor, secondaryColor:FlxColor):Void
	{
		bar.createFilledBar(baseColor, secondaryColor);
		bar.updateBar();
	}

	public function setIcons(?player1:String, ?player2:String):Void
	{
		if (player1 != null)
		{
			iconP1.changeIcon(player1);
		}

		if (player2 != null)
		{
			iconP2.changeIcon(player2);
		}
	}

	public function setIconScale(iconP1Scale:Float, iconP2Scale:Float):Void
	{
		iconP1.scale.set(iconP1Scale, iconP1Scale);
		iconP2.scale.set(iconP2Scale, iconP2Scale);

		iconP1.updateHitbox();
		iconP2.updateHitbox();
	}
}
