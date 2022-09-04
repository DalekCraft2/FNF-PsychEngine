package;

interface MusicBeatable
{
	private var curStep:Int;
	private var curBeat:Int;

	// private var curBar:Int;
	public function stepHit(step:Int):Void;

	public function beatHit(beat:Int):Void;
	// public function barHit(bar:Int):Void;
}
