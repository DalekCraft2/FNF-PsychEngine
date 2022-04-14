package;

using StringTools;

class Boyfriend extends Character
{
	public var startedDeath:Bool = false;

	public function new(x:Float, y:Float, id:String = Character.DEFAULT_CHARACTER)
	{
		super(x, y, id, true);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!debugMode && animation.curAnim != null)
		{
			if (animation.curAnim.name.startsWith('sing'))
			{
				holdTimer += elapsed;
			}
			else
				holdTimer = 0;

			if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished && !debugMode)
			{
				playAnim('idle', true, false, 10);
			}
		}
	}
}
