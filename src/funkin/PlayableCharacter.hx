package funkin;

using StringTools;

class PlayableCharacter extends Character
{
	public var startedDeath:Bool = false;

	public function new(?x:Float = 0, ?y:Float = 0, id:String = Character.DEFAULT_CHARACTER)
	{
		super(x, y, id, true);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!debugMode && animation.curAnim != null)
		{
			if (animation.name.startsWith('sing'))
			{
				holdTimer += elapsed;
			}
			else
				holdTimer = 0;

			if (animation.name.endsWith('miss') && animation.finished && !debugMode)
			{
				playAnim('idle', true, false, 10);
			}
		}
	}
}
