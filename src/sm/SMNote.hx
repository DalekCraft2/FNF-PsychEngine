package sm;

#if FEATURE_STEPMANIA
class SMNote
{
	public var data:String;
	public var lane:Int;

	public function new(data:String, lane:Int)
	{
		this.data = data;
		this.lane = lane;
	}
}
#end
