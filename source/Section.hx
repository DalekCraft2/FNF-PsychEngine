package;

typedef SectionData =
{
	var sectionNotes:Array<Array<Dynamic>>;
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
	public var notes:Array<Note> = [];
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
		notes = [];
		for (noteArray in sectionData.sectionNotes)
		{
			var strumTime:Float = noteArray[0];
			var noteData:Int = noteArray[1];
			var sustainLength:Float = noteArray[2];
			var noteType:String = noteArray[3];
			var note:Note = new Note(strumTime, noteData);
			note.sustainLength = sustainLength;
			note.noteType = noteType;
			notes.push(note);
		};
		lengthInSteps = sectionData.lengthInSteps;
		typeOfSection = sectionData.typeOfSection;
		mustHitSection = sectionData.mustHitSection;
		gfSection = sectionData.gfSection;
	}
}
