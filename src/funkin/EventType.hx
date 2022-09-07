package funkin;

typedef EditorEventType =
{
	name:String,
	description:String
}

// TODO Use this
typedef EventType =
{
	name:String,
	description:String,
	args:Array<EventArgument>,
	// offset:Float // For events like Kill Henchmen, which occur 280 ms early (not sure whether this should be in here, though)
}

typedef EventArgument =
{
	name:String,
	description:String
	// Potential valueType field, for putting "Int/String/Float/etc."?
}
