package;

typedef SectionData =
{
	var sectionNotes:Array<Dynamic>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
}

class Section
{
	public var notes:Array<Dynamic> = [];
	public var lengthInSteps:Int = 16;
	public var typeOfSection:Int = 0;
	public var mustHitSection:Bool = true;
	public var gfSection:Bool = false;

	/**
	 *	Copies the first section into the second section!
	 */
	public static var COPYCAT:Int = 0;

	public function new(sectionData:SectionData)
	{
		notes = sectionData.sectionNotes;
		lengthInSteps = sectionData.lengthInSteps;
		typeOfSection = sectionData.typeOfSection;
		mustHitSection = sectionData.mustHitSection;
		gfSection = sectionData.gfSection;
	}
}
