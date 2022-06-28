package;

interface MusicBeatable
{
	private var curStep:Int;
	private var curBeat:Int;

	public function stepHit(step:Int):Void;

	public function beatHit(beat:Int):Void;
}
