package;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepad;
import flixel.util.FlxSignal.FlxTypedSignal;

class PlayerSettings
{
	public static var numPlayers(default, null):Int = 0;
	public static var player1(default, null):PlayerSettings;
	public static var player2(default, null):PlayerSettings;

	public var id(default, null):Int;

	public final controls:Controls;

	private function new(id, scheme)
	{
		this.id = id;
		this.controls = new Controls('player$id', scheme);
	}

	public function setKeyboardScheme(scheme):Void
	{
		controls.setKeyboardScheme(scheme);
	}

	public static function init():Void
	{
		if (player1 == null)
		{
			player1 = new PlayerSettings(0, CUSTOM);
			++numPlayers;
		}

		var numGamepads:Int = FlxG.gamepads.numActiveGamepads;
		if (numGamepads > 0)
		{
			var gamepad:FlxGamepad = FlxG.gamepads.getByID(0);
			if (gamepad == null)
				throw 'Unexpected null gamepad. id:0';

			player1.controls.addDefaultGamepad(0);
		}

		if (numGamepads > 1)
		{
			if (player2 == null)
			{
				player2 = new PlayerSettings(1, NONE);
				++numPlayers;
			}

			var gamepad:FlxGamepad = FlxG.gamepads.getByID(1);
			if (gamepad == null)
				throw 'Unexpected null gamepad. id:1';

			player2.controls.addDefaultGamepad(1);
		}
	}

	public static function reset():Void
	{
		player1 = null;
		player2 = null;
		numPlayers = 0;
	}
}
