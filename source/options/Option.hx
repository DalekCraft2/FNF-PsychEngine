package options;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;

class Option extends FlxTypedGroup<FlxSprite>
{
	public var type:String = "Option";
	public var parent:OptionCategory;
	public var name:String = "Option";
	public var description:String = "";
	public var allowMultiKeyInput:Bool = false;
	public var text:Alphabet;
	public var isSelected:Bool = false;

	public function new(?name:String)
	{
		super();
		this.type = "Option";
		if (name != null)
		{
			this.name = name;
		}
	}

	public function keyPressed(key:FlxKey):Bool
	{
		// Debug.logTrace("Unset");
		return false;
	}

	public function keyReleased(key:FlxKey):Bool
	{
		// Debug.logTrace("Unset");
		return false;
	}

	public function accept():Bool
	{
		// Debug.logTrace("Unset");
		return false;
	}

	public function right():Bool
	{
		// Debug.logTrace("Unset");
		return false;
	}

	public function left():Bool
	{
		// Debug.logTrace("Unset");
		return false;
	}

	public function selected():Bool
	{
		// Debug.logTrace("Unset");
		return false;
	}

	public function deselected():Bool
	{
		// Debug.logTrace("Unset");
		return false;
	}

	public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		if (text == null)
		{
			remove(text);
			text = new Alphabet(0, (70 * curSelected), name, true, false);
			text.isMenuItem = true;
			add(text);
		}
		else
		{
			text.changeText(name);
		}
		return text;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
	}
}
