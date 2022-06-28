package;

import Note.NoteDef;

typedef Section =
{
	var startTime:Float;
	var endTime:Float;
	var sectionNotes:Array<NoteDef>;
	var lengthInSteps:Int;
	@:deprecated
	var ?typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	// TODO What if we just had two variables for each character's alt animation, and, instead of a boolean, they were suffixes for the animation names?
	// TODO Integrate these two variables more
	var ?CPUAltAnim:Bool;
	var ?playerAltAnim:Bool;
	// Myth Engine moment
	var ?CPUPrimaryAltAnim:Bool;
	var ?CPUSecondaryAltAnim:Bool;
	var ?playerPrimaryAltAnim:Bool;
	var ?playerSecondaryAltAnim:Bool;
}
