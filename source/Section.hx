package;

typedef SectionDef =
{
	var sectionNotes:Array<Array<Dynamic>>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	// TODO Integrate these two variables more
	var ?CPUAltAnim:Bool;
	var ?playerAltAnim:Bool;
	// Myth Engine moment
	var ?CPUPrimaryAltAnim:Bool;
	var ?CPUSecondaryAltAnim:Bool;
	var ?playerPrimaryAltAnim:Bool;
	var ?playerSecondaryAltAnim:Bool;
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
	public static final COPYCAT:Int = 0;

	public function new(sectionDef:SectionDef)
	{
		notes = [];
		for (noteArray in sectionDef.sectionNotes)
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
		lengthInSteps = sectionDef.lengthInSteps;
		typeOfSection = sectionDef.typeOfSection;
		mustHitSection = sectionDef.mustHitSection;
		gfSection = sectionDef.gfSection;
	}
}
