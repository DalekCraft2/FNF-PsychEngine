package;

import chart.container.Event.EventGroup;
import flixel.FlxSprite;

class EventSprite extends FlxSprite
{
	public var data:EventGroup;
	public var strumTime:Float = 0;
	public var beat:Float = 0;

	public var type:String = '';
	public var value1:String = '';
	public var value2:String = '';

	/**
	 * How many events were in the EventGroup this Event came from.
	 */
	public var events:Int = 0;

	public function new(data:EventGroup)
	{
		super();

		this.data = data;

		loadGraphic(Paths.getGraphic('eventArrow'));
	}
}
