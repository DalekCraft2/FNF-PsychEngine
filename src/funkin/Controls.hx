package funkin;

import flixel.FlxG;
import flixel.input.FlxInput.FlxInputState;
import flixel.input.actions.FlxAction.FlxActionDigital;
import flixel.input.actions.FlxActionInput;
import flixel.input.actions.FlxActionManager;
import flixel.input.actions.FlxActionSet;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

enum abstract Action(String) to String from String
{
	public var UI_UP:Action = 'ui_up';
	public var UI_LEFT:Action = 'ui_left';
	public var UI_RIGHT:Action = 'ui_right';
	public var UI_DOWN:Action = 'ui_down';
	public var UI_UP_P:Action = 'ui_up-press';
	public var UI_LEFT_P:Action = 'ui_left-press';
	public var UI_RIGHT_P:Action = 'ui_right-press';
	public var UI_DOWN_P:Action = 'ui_down-press';
	public var UI_UP_R:Action = 'ui_up-release';
	public var UI_LEFT_R:Action = 'ui_left-release';
	public var UI_RIGHT_R:Action = 'ui_right-release';
	public var UI_DOWN_R:Action = 'ui_down-release';
	public var NOTE_UP:Action = 'note_up';
	public var NOTE_LEFT:Action = 'note_left';
	public var NOTE_RIGHT:Action = 'note_right';
	public var NOTE_DOWN:Action = 'note_down';
	public var NOTE_UP_P:Action = 'note_up-press';
	public var NOTE_LEFT_P:Action = 'note_left-press';
	public var NOTE_RIGHT_P:Action = 'note_right-press';
	public var NOTE_DOWN_P:Action = 'note_down-press';
	public var NOTE_UP_R:Action = 'note_up-release';
	public var NOTE_LEFT_R:Action = 'note_left-release';
	public var NOTE_RIGHT_R:Action = 'note_right-release';
	public var NOTE_DOWN_R:Action = 'note_down-release';
	public var ACCEPT:Action = 'accept';
	public var BACK:Action = 'back';
	public var PAUSE:Action = 'pause';
	public var RESET:Action = 'reset';
}

enum Device
{
	KEYS;
	GAMEPAD(id:Int);
}

/**
 * Since, in many cases multiple actions should use similar keys, we don't want the
 * rebinding UI to list every action. ActionBinders are what the user percieves as
 * an input so, for instance, they can't set jump-press and jump-release to different keys.
 */
enum Control
{
	UI_UP;
	UI_LEFT;
	UI_RIGHT;
	UI_DOWN;
	NOTE_UP;
	NOTE_LEFT;
	NOTE_RIGHT;
	NOTE_DOWN;
	RESET;
	ACCEPT;
	BACK;
	PAUSE;
}

enum KeyboardScheme
{
	SOLO;
	DUO(first:Bool);
	NONE;
	CUSTOM;
}

/**
 * A list of actions that a player would invoke via some input device.
 * Uses FlxActions to funnel various inputs to a single action.
 */
class Controls extends FlxActionSet
{
	private var _ui_up:FlxActionDigital = new FlxActionDigital(Action.UI_UP);
	private var _ui_left:FlxActionDigital = new FlxActionDigital(Action.UI_LEFT);
	private var _ui_right:FlxActionDigital = new FlxActionDigital(Action.UI_RIGHT);
	private var _ui_down:FlxActionDigital = new FlxActionDigital(Action.UI_DOWN);
	private var _ui_upP:FlxActionDigital = new FlxActionDigital(Action.UI_UP_P);
	private var _ui_leftP:FlxActionDigital = new FlxActionDigital(Action.UI_LEFT_P);
	private var _ui_rightP:FlxActionDigital = new FlxActionDigital(Action.UI_RIGHT_P);
	private var _ui_downP:FlxActionDigital = new FlxActionDigital(Action.UI_DOWN_P);
	private var _ui_upR:FlxActionDigital = new FlxActionDigital(Action.UI_UP_R);
	private var _ui_leftR:FlxActionDigital = new FlxActionDigital(Action.UI_LEFT_R);
	private var _ui_rightR:FlxActionDigital = new FlxActionDigital(Action.UI_RIGHT_R);
	private var _ui_downR:FlxActionDigital = new FlxActionDigital(Action.UI_DOWN_R);
	private var _note_up:FlxActionDigital = new FlxActionDigital(Action.NOTE_UP);
	private var _note_left:FlxActionDigital = new FlxActionDigital(Action.NOTE_LEFT);
	private var _note_right:FlxActionDigital = new FlxActionDigital(Action.NOTE_RIGHT);
	private var _note_down:FlxActionDigital = new FlxActionDigital(Action.NOTE_DOWN);
	private var _note_upP:FlxActionDigital = new FlxActionDigital(Action.NOTE_UP_P);
	private var _note_leftP:FlxActionDigital = new FlxActionDigital(Action.NOTE_LEFT_P);
	private var _note_rightP:FlxActionDigital = new FlxActionDigital(Action.NOTE_RIGHT_P);
	private var _note_downP:FlxActionDigital = new FlxActionDigital(Action.NOTE_DOWN_P);
	private var _note_upR:FlxActionDigital = new FlxActionDigital(Action.NOTE_UP_R);
	private var _note_leftR:FlxActionDigital = new FlxActionDigital(Action.NOTE_LEFT_R);
	private var _note_rightR:FlxActionDigital = new FlxActionDigital(Action.NOTE_RIGHT_R);
	private var _note_downR:FlxActionDigital = new FlxActionDigital(Action.NOTE_DOWN_R);
	private var _accept:FlxActionDigital = new FlxActionDigital(Action.ACCEPT);
	private var _back:FlxActionDigital = new FlxActionDigital(Action.BACK);
	private var _pause:FlxActionDigital = new FlxActionDigital(Action.PAUSE);
	private var _reset:FlxActionDigital = new FlxActionDigital(Action.RESET);

	private var byName:Map<String, FlxActionDigital> = [];

	public var gamepadsAdded:Array<Int> = [];
	public var keyboardScheme:KeyboardScheme = NONE;

	public var UI_UP(get, never):Bool;

	private inline function get_UI_UP():Bool
		return _ui_up.check();

	public var UI_LEFT(get, never):Bool;

	private inline function get_UI_LEFT():Bool
		return _ui_left.check();

	public var UI_RIGHT(get, never):Bool;

	private inline function get_UI_RIGHT():Bool
		return _ui_right.check();

	public var UI_DOWN(get, never):Bool;

	private inline function get_UI_DOWN():Bool
		return _ui_down.check();

	public var UI_UP_P(get, never):Bool;

	private inline function get_UI_UP_P():Bool
		return _ui_upP.check();

	public var UI_LEFT_P(get, never):Bool;

	private inline function get_UI_LEFT_P():Bool
		return _ui_leftP.check();

	public var UI_RIGHT_P(get, never):Bool;

	private inline function get_UI_RIGHT_P():Bool
		return _ui_rightP.check();

	public var UI_DOWN_P(get, never):Bool;

	private inline function get_UI_DOWN_P():Bool
		return _ui_downP.check();

	public var UI_UP_R(get, never):Bool;

	private inline function get_UI_UP_R():Bool
		return _ui_upR.check();

	public var UI_LEFT_R(get, never):Bool;

	private inline function get_UI_LEFT_R():Bool
		return _ui_leftR.check();

	public var UI_RIGHT_R(get, never):Bool;

	private inline function get_UI_RIGHT_R():Bool
		return _ui_rightR.check();

	public var UI_DOWN_R(get, never):Bool;

	private inline function get_UI_DOWN_R():Bool
		return _ui_downR.check();

	public var NOTE_UP(get, never):Bool;

	private inline function get_NOTE_UP():Bool
		return _note_up.check();

	public var NOTE_LEFT(get, never):Bool;

	private inline function get_NOTE_LEFT():Bool
		return _note_left.check();

	public var NOTE_RIGHT(get, never):Bool;

	private inline function get_NOTE_RIGHT():Bool
		return _note_right.check();

	public var NOTE_DOWN(get, never):Bool;

	private inline function get_NOTE_DOWN():Bool
		return _note_down.check();

	public var NOTE_UP_P(get, never):Bool;

	private inline function get_NOTE_UP_P():Bool
		return _note_upP.check();

	public var NOTE_LEFT_P(get, never):Bool;

	private inline function get_NOTE_LEFT_P():Bool
		return _note_leftP.check();

	public var NOTE_RIGHT_P(get, never):Bool;

	private inline function get_NOTE_RIGHT_P():Bool
		return _note_rightP.check();

	public var NOTE_DOWN_P(get, never):Bool;

	private inline function get_NOTE_DOWN_P():Bool
		return _note_downP.check();

	public var NOTE_UP_R(get, never):Bool;

	private inline function get_NOTE_UP_R():Bool
		return _note_upR.check();

	public var NOTE_LEFT_R(get, never):Bool;

	private inline function get_NOTE_LEFT_R():Bool
		return _note_leftR.check();

	public var NOTE_RIGHT_R(get, never):Bool;

	private inline function get_NOTE_RIGHT_R():Bool
		return _note_rightR.check();

	public var NOTE_DOWN_R(get, never):Bool;

	private inline function get_NOTE_DOWN_R():Bool
		return _note_downR.check();

	public var ACCEPT(get, never):Bool;

	private inline function get_ACCEPT():Bool
		return _accept.check();

	public var BACK(get, never):Bool;

	private inline function get_BACK():Bool
		return _back.check();

	public var PAUSE(get, never):Bool;

	private inline function get_PAUSE():Bool
		return _pause.check();

	public var RESET(get, never):Bool;

	private inline function get_RESET():Bool
		return _reset.check();

	public function new(name:String, scheme:KeyboardScheme = NONE)
	{
		super(name);

		add(_ui_up);
		add(_ui_left);
		add(_ui_right);
		add(_ui_down);
		add(_ui_upP);
		add(_ui_leftP);
		add(_ui_rightP);
		add(_ui_downP);
		add(_ui_upR);
		add(_ui_leftR);
		add(_ui_rightR);
		add(_ui_downR);
		add(_note_up);
		add(_note_left);
		add(_note_right);
		add(_note_down);
		add(_note_upP);
		add(_note_leftP);
		add(_note_rightP);
		add(_note_downP);
		add(_note_upR);
		add(_note_leftR);
		add(_note_rightR);
		add(_note_downR);
		add(_accept);
		add(_back);
		add(_pause);
		add(_reset);

		for (action in digitalActions)
			byName[action.name] = action;

		setKeyboardScheme(scheme, false);
	}

	public function checkByName(name:Action):Bool
	{
		#if debug
		if (!byName.exists(name))
			throw 'Invalid name: $name';
		#end
		return byName[name].check();
	}

	public function getDialogueName(action:FlxActionDigital):String
	{
		var input:FlxActionInput = action.inputs[0];
		return switch input.device
		{
			case KEYBOARD: return '[${(input.inputID : FlxKey)}]';
			case GAMEPAD: return '(${(input.inputID : FlxGamepadInputID)})';
			case device: throw 'unhandled device: $device';
		}
	}

	public function getDialogueNameFromToken(token:String):String
	{
		return getDialogueName(getActionFromControl(Control.createByName(token.toUpperCase())));
	}

	private function getActionFromControl(control:Control):FlxActionDigital
	{
		return switch (control)
		{
			case UI_UP: _ui_up;
			case UI_DOWN: _ui_down;
			case UI_LEFT: _ui_left;
			case UI_RIGHT: _ui_right;
			case NOTE_UP: _note_up;
			case NOTE_DOWN: _note_down;
			case NOTE_LEFT: _note_left;
			case NOTE_RIGHT: _note_right;
			case ACCEPT: _accept;
			case BACK: _back;
			case PAUSE: _pause;
			case RESET: _reset;
		}
	}

	private static function init():Void
	{
		var actions:FlxActionManager = new FlxActionManager();
		FlxG.inputs.add(actions);
	}

	/**
	 * Calls a function passing each action bound by the specified control
	 * @param control
	 * @param func
	 */
	private function forEachBound(control:Control, func:(action:FlxActionDigital, state:FlxInputState) -> Void):Void
	{
		switch (control)
		{
			case UI_UP:
				func(_ui_up, PRESSED);
				func(_ui_upP, JUST_PRESSED);
				func(_ui_upR, JUST_RELEASED);
			case UI_LEFT:
				func(_ui_left, PRESSED);
				func(_ui_leftP, JUST_PRESSED);
				func(_ui_leftR, JUST_RELEASED);
			case UI_RIGHT:
				func(_ui_right, PRESSED);
				func(_ui_rightP, JUST_PRESSED);
				func(_ui_rightR, JUST_RELEASED);
			case UI_DOWN:
				func(_ui_down, PRESSED);
				func(_ui_downP, JUST_PRESSED);
				func(_ui_downR, JUST_RELEASED);
			case NOTE_UP:
				func(_note_up, PRESSED);
				func(_note_upP, JUST_PRESSED);
				func(_note_upR, JUST_RELEASED);
			case NOTE_LEFT:
				func(_note_left, PRESSED);
				func(_note_leftP, JUST_PRESSED);
				func(_note_leftR, JUST_RELEASED);
			case NOTE_RIGHT:
				func(_note_right, PRESSED);
				func(_note_rightP, JUST_PRESSED);
				func(_note_rightR, JUST_RELEASED);
			case NOTE_DOWN:
				func(_note_down, PRESSED);
				func(_note_downP, JUST_PRESSED);
				func(_note_downR, JUST_RELEASED);
			case ACCEPT:
				func(_accept, JUST_PRESSED);
			case BACK:
				func(_back, JUST_PRESSED);
			case PAUSE:
				func(_pause, JUST_PRESSED);
			case RESET:
				func(_reset, JUST_PRESSED);
		}
	}

	public function replaceBinding(control:Control, device:Device, ?toAdd:Int, ?toRemove:Int):Void
	{
		if (toAdd == toRemove)
			return;

		switch (device)
		{
			case KEYS:
				if (toRemove != null)
					unbindKeys(control, [toRemove]);
				if (toAdd != null)
					bindKeys(control, [toAdd]);

			case GAMEPAD(id):
				if (toRemove != null)
					unbindButtons(control, id, [toRemove]);
				if (toAdd != null)
					bindButtons(control, id, [toAdd]);
		}
	}

	public function copyFrom(controls:Controls, ?device:Device):Void
	{
		for (action in controls.byName)
		{
			for (input in action.inputs)
			{
				if (device == null || isDevice(input, device))
					action.add(cast input);
			}
		}

		switch (device)
		{
			case null:
				// add all
				for (gamepad in controls.gamepadsAdded)
					if (!gamepadsAdded.contains(gamepad))
						gamepadsAdded.push(gamepad);

				mergeKeyboardScheme(controls.keyboardScheme);

			case GAMEPAD(id):
				gamepadsAdded.push(id);
			case KEYS:
				mergeKeyboardScheme(controls.keyboardScheme);
		}
	}

	public inline function copyTo(controls:Controls, ?device:Device):Void
	{
		controls.copyFrom(this, device);
	}

	private function mergeKeyboardScheme(scheme:KeyboardScheme):Void
	{
		if (scheme != NONE)
		{
			switch (keyboardScheme)
			{
				case NONE:
					keyboardScheme = scheme;
				default:
					keyboardScheme = CUSTOM;
			}
		}
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function bindKeys(control:Control, keys:Array<FlxKey>):Void
	{
		var copyKeys:Array<FlxKey> = keys.copy();
		for (copyKey in copyKeys)
		{
			if (copyKey == NONE)
				copyKeys.remove(copyKey);
		}

		inline forEachBound(control, (action:FlxActionDigital, state:FlxInputState) -> addKeys(action, copyKeys, state));
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function unbindKeys(control:Control, keys:Array<FlxKey>):Void
	{
		var copyKeys:Array<FlxKey> = keys.copy();
		for (copyKey in copyKeys)
		{
			if (copyKey == NONE)
				copyKeys.remove(copyKey);
		}

		inline forEachBound(control, (action:FlxActionDigital, state:FlxInputState) -> removeKeys(action, copyKeys));
	}

	private static inline function addKeys(action:FlxActionDigital, keys:Array<FlxKey>, state:FlxInputState):Void
	{
		for (key in keys)
			if (key != NONE)
				action.addKey(key, state);
	}

	private static function removeKeys(action:FlxActionDigital, keys:Array<FlxKey>):Void
	{
		var i:Int = action.inputs.length - 1;
		while (i >= 0)
		{
			var input:FlxActionInput = action.inputs[i];
			if (input.device == KEYBOARD && keys.contains(input.inputID))
				action.remove(input);
			i--;
		}
	}

	public function setKeyboardScheme(scheme:KeyboardScheme, reset:Bool = true):Void
	{
		if (reset)
			removeKeyboard();

		keyboardScheme = scheme;
		var keyBinds:Map<String, Array<FlxKey>> = Options.profile.keyBinds;

		switch (scheme)
		{
			case SOLO:
				inline bindKeys(Control.NOTE_LEFT, [A, LEFT]);
				inline bindKeys(Control.NOTE_DOWN, [S, DOWN]);
				inline bindKeys(Control.NOTE_UP, [W, UP]);
				inline bindKeys(Control.NOTE_RIGHT, [D, RIGHT]);

				inline bindKeys(Control.UI_LEFT, [A, LEFT]);
				inline bindKeys(Control.UI_DOWN, [S, DOWN]);
				inline bindKeys(Control.UI_UP, [W, UP]);
				inline bindKeys(Control.UI_RIGHT, [D, RIGHT]);

				inline bindKeys(Control.ACCEPT, [SPACE, ENTER]);
				inline bindKeys(Control.BACK, [BACKSPACE, ESCAPE]);
				inline bindKeys(Control.PAUSE, [ENTER, ESCAPE]);
				inline bindKeys(Control.RESET, [R]);
			case DUO(true):
				inline bindKeys(Control.NOTE_LEFT, [A]);
				inline bindKeys(Control.NOTE_DOWN, [S]);
				inline bindKeys(Control.NOTE_UP, [W]);
				inline bindKeys(Control.NOTE_RIGHT, [D]);

				inline bindKeys(Control.UI_LEFT, [A]);
				inline bindKeys(Control.UI_DOWN, [S]);
				inline bindKeys(Control.UI_UP, [W]);
				inline bindKeys(Control.UI_RIGHT, [D]);

				inline bindKeys(Control.ACCEPT, [G, Z]);
				inline bindKeys(Control.BACK, [H, X]);
				inline bindKeys(Control.PAUSE, [ONE]);
				inline bindKeys(Control.RESET, [R]);
			case DUO(false):
				inline bindKeys(Control.NOTE_LEFT, [LEFT]);
				inline bindKeys(Control.NOTE_DOWN, [DOWN]);
				inline bindKeys(Control.NOTE_UP, [UP]);
				inline bindKeys(Control.NOTE_RIGHT, [RIGHT]);

				inline bindKeys(Control.UI_LEFT, [LEFT]);
				inline bindKeys(Control.UI_DOWN, [DOWN]);
				inline bindKeys(Control.UI_UP, [UP]);
				inline bindKeys(Control.UI_RIGHT, [RIGHT]);

				inline bindKeys(Control.ACCEPT, [O]);
				inline bindKeys(Control.BACK, [P]);
				inline bindKeys(Control.PAUSE, [ENTER]);
				inline bindKeys(Control.RESET, [BACKSPACE]);
			case NONE: // nothing
			case CUSTOM:
				inline bindKeys(Control.NOTE_LEFT, keyBinds.get('note_left'));
				inline bindKeys(Control.NOTE_DOWN, keyBinds.get('note_down'));
				inline bindKeys(Control.NOTE_UP, keyBinds.get('note_up'));
				inline bindKeys(Control.NOTE_RIGHT, keyBinds.get('note_right'));

				inline bindKeys(Control.UI_LEFT, keyBinds.get('ui_left'));
				inline bindKeys(Control.UI_DOWN, keyBinds.get('ui_down'));
				inline bindKeys(Control.UI_UP, keyBinds.get('ui_up'));
				inline bindKeys(Control.UI_RIGHT, keyBinds.get('ui_right'));

				inline bindKeys(Control.ACCEPT, keyBinds.get('accept'));
				inline bindKeys(Control.BACK, keyBinds.get('back'));
				inline bindKeys(Control.PAUSE, keyBinds.get('pause'));
				inline bindKeys(Control.RESET, keyBinds.get('reset'));
		}
	}

	private function removeKeyboard():Void
	{
		for (action in this.digitalActions)
		{
			var i:Int = action.inputs.length - 1;
			while (i >= 0)
			{
				var input:FlxActionInput = action.inputs[i];
				if (input.device == KEYBOARD)
					action.remove(input);
				i--;
			}
		}
	}

	public function addGamepad(id:Int, ?buttonMap:Map<Control, Array<FlxGamepadInputID>>):Void
	{
		gamepadsAdded.push(id);

		for (control => buttons in buttonMap)
		inline bindButtons(control, id, buttons);
	}

	private inline function addGamepadLiteral(id:Int, ?buttonMap:Map<Control, Array<FlxGamepadInputID>>):Void
	{
		gamepadsAdded.push(id);

		for (control => buttons in buttonMap)
		inline bindButtons(control, id, buttons);
	}

	public function removeGamepad(deviceID:Int = FlxInputDeviceID.ALL):Void
	{
		for (action in this.digitalActions)
		{
			var i:Int = action.inputs.length - 1;
			while (i >= 0)
			{
				var input:FlxActionInput = action.inputs[i];
				if (input.device == GAMEPAD && (deviceID == FlxInputDeviceID.ALL || input.deviceID == deviceID))
					action.remove(input);
				i--;
			}
		}

		gamepadsAdded.remove(deviceID);
	}

	public function addDefaultGamepad(id:Int):Void
	{
		#if switch
		addGamepadLiteral(id, [
			// Swap A and B for Switch
			Control.ACCEPT => [B, START],
			Control.BACK => [A],
			Control.UI_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP],
			Control.UI_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN],
			Control.UI_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT],
			Control.UI_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT],
			Control.NOTE_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP, X],
			Control.NOTE_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN, B],
			Control.NOTE_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT, Y],
			Control.NOTE_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT, A],
			Control.PAUSE => [START],
			Control.RESET => [8],
		]);
		#else
		addGamepadLiteral(id, [
			Control.ACCEPT => [A, START],
			Control.BACK => [B],
			Control.UI_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP],
			Control.UI_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
			Control.UI_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
			Control.UI_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
			Control.NOTE_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP, Y],
			Control.NOTE_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN, A],
			Control.NOTE_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT, X],
			Control.NOTE_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT, B],
			Control.PAUSE => [START],
			Control.RESET => [8]
		]);
		#end
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function bindButtons(control:Control, id:Int, buttons:Array<FlxGamepadInputID>):Void
	{
		inline forEachBound(control, (action:FlxActionDigital, state:FlxInputState) -> addButtons(action, buttons, state, id));
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function unbindButtons(control:Control, gamepadID:Int, buttons:Array<FlxGamepadInputID>):Void
	{
		inline forEachBound(control, (action:FlxActionDigital, state:FlxInputState) -> removeButtons(action, gamepadID, buttons));
	}

	private static inline function addButtons(action:FlxActionDigital, buttons:Array<FlxGamepadInputID>, state:FlxInputState, id:Int):Void
	{
		for (button in buttons)
			action.addGamepad(button, state, id);
	}

	private static function removeButtons(action:FlxActionDigital, gamepadID:Int, buttons:Array<FlxGamepadInputID>):Void
	{
		var i:Int = action.inputs.length - 1;
		while (i >= 0)
		{
			var input:FlxActionInput = action.inputs[i];
			if (isGamepad(input, gamepadID) && buttons.contains(input.inputID))
				action.remove(input);
			i--;
		}
	}

	public function getInputsFor(control:Control, device:Device, ?list:Array<Int>):Array<Int>
	{
		if (list == null)
			list = [];

		switch (device)
		{
			case KEYS:
				for (input in getActionFromControl(control).inputs)
				{
					if (input.device == KEYBOARD)
						list.push(input.inputID);
				}
			case GAMEPAD(id):
				for (input in getActionFromControl(control).inputs)
				{
					if (input.deviceID == id)
						list.push(input.inputID);
				}
		}
		return list;
	}

	public function removeDevice(device:Device):Void
	{
		switch (device)
		{
			case KEYS:
				setKeyboardScheme(NONE);
			case GAMEPAD(id):
				removeGamepad(id);
		}
	}

	private static function isDevice(input:FlxActionInput, device:Device):Bool
	{
		return switch (device)
		{
			case KEYS: input.device == KEYBOARD;
			case GAMEPAD(id): isGamepad(input, id);
		}
	}

	private static inline function isGamepad(input:FlxActionInput, deviceID:Int):Bool
	{
		return input.device == GAMEPAD && (deviceID == FlxInputDeviceID.ALL || input.deviceID == deviceID);
	}
}
