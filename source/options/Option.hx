package options;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;

abstract class Option extends FlxTypedGroup<FlxSprite>
{
	public var name:String;
	public var description:String;

	public var parent:OptionCategory;
	public var allowMultiKeyInput:Bool = false;
	public var text:Alphabet;
	public var isSelected:Bool = false;

	public function new(?name:String = 'Option', ?description:String = '')
	{
		super();

		this.name = name;
		this.description = description;
	}

	public function keyPressed(key:FlxKey):Bool
	{
		// Debug.logTrace('Unset');
		return false;
	}

	public function keyReleased(key:FlxKey):Bool
	{
		// Debug.logTrace('Unset');
		return false;
	}

	public function accept():Bool
	{
		// Debug.logTrace('Unset');
		return false;
	}

	public function left():Bool
	{
		// Debug.logTrace('Unset');
		return false;
	}

	public function right():Bool
	{
		// Debug.logTrace('Unset');
		return false;
	}

	public function selected():Bool
	{
		// Debug.logTrace('Unset');
		return false;
	}

	public function deselected():Bool
	{
		// Debug.logTrace('Unset');
		return false;
	}

	public function createOptionText(curSelected:Int, optionText:FlxTypedGroup<Option>):Alphabet
	{
		remove(text);
		text = new Alphabet(0, (70 * curSelected), name, true, false);
		text.isMenuItem = true;
		add(text);
		return text;
	}

	public function updateOptionText():Void
	{
		text.changeText(name);
	}
}
