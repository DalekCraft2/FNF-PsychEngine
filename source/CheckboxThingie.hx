package;

import flixel.FlxSprite;

class CheckboxThingie extends FlxSprite
{
	public var sprTracker:FlxSprite;
	public var daValue(default, set):Bool;
	public var copyAlpha:Bool = true;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;

	public function new(x:Float = 0, y:Float = 0, ?checked = false)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('checkbox');
		animation.addByPrefix("unchecked", "unchecked", 24, false);
		animation.addByPrefix("unchecking", "unchecking", 24, false);
		animation.addByPrefix("checking", "checking", 24, false);
		animation.addByPrefix("checked", "checked", 24, false);

		antialiasing = Options.save.data.globalAntialiasing;
		setGraphicSize(Std.int(0.9 * width));
		updateHitbox();

		animationFinished(checked ? 'checking' : 'unchecking');
		animation.finishCallback = animationFinished;
		daValue = checked;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x - 130 + offsetX, sprTracker.y + 30 + offsetY);
			if (copyAlpha)
			{
				alpha = sprTracker.alpha;
			}
		}
	}

	private function set_daValue(check:Bool):Bool
	{
		if (check)
		{
			if (animation.curAnim.name != 'checked' && animation.curAnim.name != 'checking')
			{
				animation.play('checking', true);
				offset.set(34, 25);
			}
		}
		else if (animation.curAnim.name != 'unchecked' && animation.curAnim.name != 'unchecking')
		{
			animation.play("unchecking", true);
			offset.set(25, 28);
		}
		return check;
	}

	private function animationFinished(name:String):Void
	{
		switch (name)
		{
			case 'checking':
				animation.play('checked', true);
				offset.set(3, 12);

			case 'unchecking':
				animation.play('unchecked', true);
				offset.set(0, 2);
		}
	}
}
