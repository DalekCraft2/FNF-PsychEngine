package;

import EventNote.LegacyEventNoteDef;
import Note.NoteDef;
import flixel.util.typeLimit.OneOfTwo;

typedef SectionEntry = OneOfTwo<NoteDef, LegacyEventNoteDef>;

typedef SectionDef =
{
	var sectionNotes:Array<SectionEntry>;
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

	public static inline function isEvent(entry:SectionEntry):Bool
	{
		return cast(entry, Array<Dynamic>)[1] < 0;
	}

	public function new(sectionDef:SectionDef)
	{
		notes = [];
		for (noteDef in sectionDef.sectionNotes)
		{
			var noteDef:NoteDef = noteDef;
			var strumTime:Float = noteDef.strumTime;
			var noteData:Int = noteDef.noteData;
			var sustainLength:Float = noteDef.sustainLength;
			var noteType:String = noteDef.noteType;
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
