package;

import Controls;
import flixel.FlxG;
import flixel.input.gamepad.FlxGamepad;
import flixel.util.FlxSignal.FlxTypedSignal;

// import ui.DeviceManager;
// import props.Player;
class PlayerSettings
{
	public static var numPlayers(default, null):Int = 0;
	public static var numAvatars(default, null):Int = 0;
	public static var player1(default, null):PlayerSettings;
	public static var player2(default, null):PlayerSettings;

	public static final onAvatarAdd:FlxTypedSignal<(PlayerSettings) -> Void> = new FlxTypedSignal();
	public static final onAvatarRemove:FlxTypedSignal<(PlayerSettings) -> Void> = new FlxTypedSignal();

	public var id(default, null):Int;

	public final controls:Controls;

	// public var avatar:Player;
	// public var camera(get, never):PlayCamera;

	function new(id, scheme)
	{
		this.id = id;
		this.controls = new Controls('player$id', scheme);
	}

	public function setKeyboardScheme(scheme):Void
	{
		controls.setKeyboardScheme(scheme);
	}

	/* 
		public static function addAvatar(avatar:Player):PlayerSettings
		{
			var settings:PlayerSettings;

			if (player1 == null)
			{
				player1 = new PlayerSettings(0, Solo);
				++numPlayers;
			}

			if (player1.avatar == null)
				settings = player1;
			else
			{
				if (player2 == null)
				{
					if (player1.controls.keyboardScheme.match(Duo(true)))
						player2 = new PlayerSettings(1, Duo(false));
					else
						player2 = new PlayerSettings(1, None);
					++numPlayers;
				}

				if (player2.avatar == null)
					settings = player2;
				else
					throw throw 'Invalid number of players: ${numPlayers + 1}';
			}
			++numAvatars;
			settings.avatar = avatar;
			avatar.settings = settings;

			splitCameras();

			onAvatarAdd.dispatch(settings);

			return settings;
		}

		public static function removeAvatar(avatar:Player):Void
		{
			var settings:PlayerSettings;

			if (player1 != null && player1.avatar == avatar)
				settings = player1;
			else if (player2 != null && player2.avatar == avatar)
			{
				settings = player2;
				if (player1.controls.keyboardScheme.match(Duo(_)))
					player1.setKeyboardScheme(Solo);
			}
			else
				throw "Cannot remove avatar that is not for a player";

			settings.avatar = null;
			while (settings.controls.gamepadsAdded.length > 0)
			{
				final id:Float = settings.controls.gamepadsAdded.shift();
				settings.controls.removeGamepad(id);
				DeviceManager.releaseGamepad(FlxG.gamepads.getByID(id));
			}

			--numAvatars;

			splitCameras();

			onAvatarRemove.dispatch(avatar.settings);
		}

	 */
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
				throw 'Unexpected null gamepad. id:0';

			player2.controls.addDefaultGamepad(1);
		}

		// DeviceManager.init();
	}

	public static function reset():Void
	{
		player1 = null;
		player2 = null;
		numPlayers = 0;
	}
}
