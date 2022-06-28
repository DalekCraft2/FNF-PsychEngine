package flixel.addons.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.interfaces.IFlxUIClickable;
import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.addons.ui.interfaces.IHasParams;
import flixel.math.FlxMath;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxStringUtil;
import openfl.geom.Rectangle;

/**
 * @author larsiusprime
 */
class FlxUIDropDownMenu extends FlxUIGroup implements IFlxUIWidget implements IFlxUIClickable implements IHasParams
{
	private var selection:Int = 0;

	public var skipButtonUpdate(default, set):Bool;

	private function set_skipButtonUpdate(b:Bool):Bool
	{
		skipButtonUpdate = b;
		header.button.skipButtonUpdate = b;
		return b;
	}

	public var selectedId(get, set):String;
	public var selectedLabel(get, set):String;

	private var _selectedId:String;
	private var _selectedLabel:String;

	private function get_selectedId():String
	{
		return _selectedId;
	}

	private function set_selectedId(str:String):String
	{
		if (_selectedId == str)
			return str;

		var i:Int = 0;
		for (btn in list)
		{
			if (btn != null && btn.name == str)
			{
				var item:FlxUIButton = list[i];
				_selectedId = str;
				if (item.label != null)
				{
					_selectedLabel = item.label.text;
					header.text.text = item.label.text;
				}
				else
				{
					_selectedLabel = '';
					header.text.text = '';
				}
				return str;
			}
			i++;
		}
		return str;
	}

	private function get_selectedLabel():String
	{
		return _selectedLabel;
	}

	private function set_selectedLabel(str:String):String
	{
		if (_selectedLabel == str)
			return str;

		var i:Int = 0;
		for (btn in list)
		{
			if (btn.label.text == str)
			{
				var item:FlxUIButton = list[i];
				_selectedId = item.name;
				_selectedLabel = str;
				header.text.text = str;
				return str;
			}
			i++;
		}
		return str;
	}

	/**
	 * The header of this dropdown menu.
	 */
	public var header:FlxUIDropDownHeader;

	/**
	 * The list of items that is shown when the toggle button is clicked.
	 */
	public var list:Array<FlxUIButton> = [];

	/**
	 * The background for the list.
	 */
	public var dropPanel:FlxUI9SliceSprite;

	public var params(default, set):Array<Dynamic>;

	private function set_params(p:Array<Dynamic>):Array<Dynamic>
	{
		params = p;
		return params;
	}

	public var dropDirection(default, set):FlxUIDropDownMenuDropDirection = Down;

	private function set_dropDirection(dropDirection:FlxUIDropDownMenuDropDirection):FlxUIDropDownMenuDropDirection
	{
		this.dropDirection = dropDirection;
		updateButtonPositions();
		return dropDirection;
	}

	public static inline final CLICK_EVENT:String = 'click_dropdown';

	public var callback:String->Void;

	// private var _ui_control_callback:(Bool, FlxUIDropDownMenu) -> Void;

	/**
	 * This creates a new dropdown menu.
	 *
	 * @param	x					x position of the dropdown menu
	 * @param	y					y position of the dropdown menu
	 * @param	dataList			The data to be displayed
	 * @param	callback			Optional Callback
	 * @param	header				The header of this dropdown menu
	 * @param	dropPanel			Optional 9-slice-background for actual drop down menu
	 * @param	buttonList			Optional list of buttons to be used for the corresponding entry in DataList
	 * @param	uiControlCallback	Used internally by FlxUI
	 */
	public function new(x:Float = 0, y:Float = 0, dataList:Array<StrNameLabel>, ?callback:String->Void, ?header:FlxUIDropDownHeader,
			?dropPanel:FlxUI9SliceSprite, ?buttonList:Array<FlxUIButton>, ?uiControlCallback:Bool->FlxUIDropDownMenu->Void)
	{
		super(x, y);
		this.callback = callback;
		this.header = header;
		this.dropPanel = dropPanel;

		if (this.header == null)
			this.header = new FlxUIDropDownHeader();

		if (this.dropPanel == null)
		{
			var rect:Rectangle = new Rectangle(0, 0, this.header.background.width, this.header.background.height);
			this.dropPanel = new FlxUI9SliceSprite(0, 0, FlxUIAssets.IMG_BOX, rect, [1, 1, 14, 14]);
		}

		if (dataList != null)
		{
			for (i in 0...dataList.length)
			{
				var data:StrNameLabel = dataList[i];
				list.push(makeListButton(i, data.label, data.name));
			}
			selectSomething(dataList[0].name, dataList[0].label);
		}
		else if (buttonList != null)
		{
			for (btn in buttonList)
			{
				list.push(btn);
				btn.resize(this.header.background.width, this.header.background.height);
				btn.x = 1;
			}
		}
		updateButtonPositions();

		this.dropPanel.resize(this.header.background.width, getPanelHeight());
		this.dropPanel.visible = false;
		add(this.dropPanel);

		for (btn in list)
		{
			add(btn);
			btn.visible = false;
		}

		// _ui_control_callback = UIControlCallback;
		this.header.button.onUp.callback = onDropdown;
		add(this.header);
	}

	private function updateButtonPositions():Void
	{
		var buttonHeight:Float = header.background.height;
		dropPanel.y = header.background.y;
		if (dropsUp())
			dropPanel.y -= getPanelHeight();
		else
			dropPanel.y += buttonHeight;

		var offset:Float = dropPanel.y;
		for (button in list)
		{
			button.y = offset;
			offset += buttonHeight;

			button.y -= buttonHeight * selection;

			if (button.y < dropPanel.y)
				button.alpha = 0;
			else
				button.alpha = 1;
		}
		/*
			for (button in list)
				button.y -= buttonHeight * selection;
			for (button in list)
			{
				if (button.y < dropPanel.y)
					button.alpha = 0;
				else
					button.alpha = 1;
			}
		 */
	}

	override private function set_visible(value:Bool):Bool
	{
		var vDropPanel:Bool = dropPanel.visible;
		var vButtons:Array<Bool> = [];
		for (entry in list)
		{
			if (entry != null)
			{
				vButtons.push(entry.visible);
			}
			else
			{
				vButtons.push(false);
			}
		}
		super.set_visible(value);
		dropPanel.visible = vDropPanel;
		for (i in 0...list.length)
		{
			var entry:FlxUIButton = list[i];
			if (entry != null)
			{
				entry.visible = vButtons[i];
			}
		}
		return value;
	}

	private function dropsUp():Bool
	{
		return dropDirection == Up || (dropDirection == Automatic && exceedsHeight());
	}

	private function exceedsHeight():Bool
	{
		return y + getPanelHeight() + header.background.height > FlxG.height;
	}

	private function getPanelHeight():Float
	{
		return list.length * header.background.height;
	}

	/**
	 * Change the contents with a new data list
	 * Replaces the old content with the new content
	 */
	public function setData(dataList:Array<StrNameLabel>):Void
	{
		var i:Int = 0;

		if (dataList != null)
		{
			for (data in dataList)
			{
				var recycled:Bool = false;
				if (list != null)
				{
					if (i <= list.length - 1)
					{ // If buttons exist, try to re-use them
						var btn:FlxUIButton = list[i];
						if (btn != null)
						{
							btn.label.text = data.label; // Set the label
							list[i].name = data.name; // Replace the name
							recycled = true; // we successfully recycled it
						}
					}
				}
				else
				{
					list = [];
				}
				if (!recycled)
				{ // If we couldn't recycle a button, make a fresh one
					var t:FlxUIButton = makeListButton(i, data.label, data.name);
					list.push(t);
					add(t);
					t.visible = false;
				}
				i++;
			}

			// Remove excess buttons:
			if (list.length > dataList.length)
			{ // we have more entries in the original set
				for (j in dataList.length...list.length)
				{ // start counting from end of list
					var b:FlxUIButton = list.pop(); // remove last button on list
					b.visible = false;
					b.active = false;
					remove(b, true); // remove from widget
					b.destroy(); // destroy it
					b = null;
				}
			}

			selectSomething(dataList[0].name, dataList[0].label);
		}

		dropPanel.resize(header.background.width, getPanelHeight());
		updateButtonPositions();
	}

	private function selectSomething(name:String, label:String):Void
	{
		header.text.text = label;
		selectedId = name;
		selectedLabel = label;
	}

	private function makeListButton(i:Int, label:String, name:String):FlxUIButton
	{
		var t:FlxUIButton = new FlxUIButton(0, 0, label);
		t.broadcastToFlxUI = false;
		t.onUp.callback = onClickItem.bind(i);

		t.name = name;

		t.loadGraphicSlice9([FlxUIAssets.IMG_INVIS, FlxUIAssets.IMG_HILIGHT, FlxUIAssets.IMG_HILIGHT], Std.int(header.background.width),
			Std.int(header.background.height), [[1, 1, 3, 3], [1, 1, 3, 3], [1, 1, 3, 3]], FlxUI9SliceSprite.TILE_NONE);
		t.labelOffsets[FlxButton.PRESSED].y -= 1; // turn off the 1-pixel depress on click

		t.up_color = FlxColor.BLACK;
		t.over_color = FlxColor.WHITE;
		t.down_color = FlxColor.WHITE;

		t.resize(header.background.width - 2, header.background.height - 1);

		t.label.alignment = 'left';
		t.autoCenterLabel();
		t.x = 1;

		for (offset in t.labelOffsets)
		{
			offset.x += 2;
		}

		return t;
	}

	/*
		public function setUIControlCallback(uiControlCallback:(Bool, FlxUIDropDownMenu) -> Void):Void
		{
			_ui_control_callback = uiControlCallback;
		}
	 */
	public function changeLabelByIndex(i:Int, newLabel:String):Void
	{
		var btn:FlxUIButton = getBtnByIndex(i);
		if (btn != null && btn.label != null)
		{
			btn.label.text = newLabel;
		}
	}

	public function changeLabelById(name:String, newLabel:String):Void
	{
		var btn:FlxUIButton = getBtnById(name);
		if (btn != null && btn.label != null)
		{
			btn.label.text = newLabel;
		}
	}

	public function getBtnByIndex(i:Int):FlxUIButton
	{
		if (i >= 0 && i < list.length)
		{
			return list[i];
		}
		return null;
	}

	public function getBtnById(name:String):FlxUIButton
	{
		for (btn in list)
		{
			if (btn.name == name)
			{
				return btn;
			}
		}
		return null;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if FLX_MOUSE
		if (dropPanel.visible)
		{
			if (!FlxG.mouse.overlaps(this))
			{
				if (FlxG.mouse.justPressed)
				{
					showList(false);
				}
			}
			else
			{
				if (list.length > 1)
				{
					if (FlxG.mouse.wheel > 0 || FlxG.keys.justPressed.UP)
					{
						selection = Std.int(FlxMath.bound(selection - 1, 0, list.length - 1));
						updateButtonPositions();
					}
					if (FlxG.mouse.wheel < 0 || FlxG.keys.justPressed.DOWN)
					{
						selection = Std.int(FlxMath.bound(selection + 1, 0, list.length - 1));
						updateButtonPositions();
					}
				}
			}
		}
		#end
	}

	override public function destroy():Void
	{
		super.destroy();

		dropPanel = FlxDestroyUtil.destroy(dropPanel);

		list = FlxDestroyUtil.destroyArray(list);
		// _ui_control_callback = null;
		callback = null;
	}

	private function showList(b:Bool):Void
	{
		for (button in list)
		{
			button.visible = b;
			button.active = b;
		}

		dropPanel.visible = b;

		FlxUI.forceFocus(b, this); // avoid overlaps
	}

	private function onDropdown():Void
	{
		(dropPanel.visible) ? showList(false) : showList(true);
	}

	private function onClickItem(i:Int):Void
	{
		var item:FlxUIButton = list[i];
		selectSomething(item.name, item.label.text);
		showList(false);

		if (callback != null)
		{
			callback(item.name);
		}

		if (broadcastToFlxUI)
		{
			FlxUI.event(CLICK_EVENT, this, item.name, params);
		}
	}

	/**
	 * Helper function to easily create a data list for a dropdown menu from an array of strings.
	 *
	 * @param	stringArray		The strings to use as data - used for both label and string ID.
	 * @param	useIndexID		Whether to use the integer index of the current string as ID.
	 * @return	The StrIDLabel array ready to be used in FlxUIDropDownMenu's constructor
	 */
	public static function makeStrIdLabelArray(stringArray:Array<String>, useIndexID:Bool = false):Array<StrNameLabel>
	{
		var strIdArray:Array<StrNameLabel> = [];
		for (i in 0...stringArray.length)
		{
			var id:String = stringArray[i];
			if (useIndexID)
			{
				id = Std.string(i);
			}
			strIdArray[i] = new StrNameLabel(id, stringArray[i]);
		}
		return strIdArray;
	}
}

/**
 * Header for a FlxUIDropDownMenu
 */
class FlxUIDropDownHeader extends FlxUIGroup
{
	/**
	 * The background of the header.
	 */
	public var background:FlxSprite;

	/**
	 * The text that displays the currently selected item.
	 */
	public var text:FlxUIText;

	/**
	 * The button that toggles the visibility of the dropdown panel.
	 */
	public var button:FlxUISpriteButton;

	/**
	 * Creates a new dropdown header to be used in a FlxUIDropDownMenu.
	 *
	 * @param	width	Width of the dropdown - only relevant when no back sprite was specified
	 * @param	back	Optional sprite to be placed in the background
	 * @param 	text	Optional text that displays the current value
	 * @param	button	Optional button that toggles the dropdown list
	 */
	public function new(width:Int = 120, ?background:FlxSprite, ?text:FlxUIText, ?button:FlxUISpriteButton)
	{
		super();

		this.background = background;
		this.text = text;
		this.button = button;

		// Background
		if (this.background == null)
		{
			this.background = new FlxUI9SliceSprite(0, 0, FlxUIAssets.IMG_BOX, new Rectangle(0, 0, width, 20), [1, 1, 14, 14]);
		}

		// Button
		if (this.button == null)
		{
			this.button = new FlxUISpriteButton(0, 0, new FlxSprite(0, 0, FlxUIAssets.IMG_DROPDOWN));
			this.button.loadGraphicSlice9([FlxUIAssets.IMG_BUTTON_THIN], 80, 20, [FlxStringUtil.toIntArray(FlxUIAssets.SLICE9_BUTTON)],
				FlxUI9SliceSprite.TILE_NONE, -1, false, FlxUIAssets.IMG_BUTTON_SIZE, FlxUIAssets.IMG_BUTTON_SIZE);
		}
		this.button.resize(this.background.height, this.background.height);
		this.button.x = this.background.x + this.background.width - this.button.width;

		// Reposition and resize the button hitbox so the whole header is clickable
		this.button.width = width;
		this.button.offset.x -= (width - this.button.frameWidth);
		this.button.x = offset.x;
		this.button.label.offset.x += this.button.offset.x;

		// Text
		if (this.text == null)
		{
			this.text = new FlxUIText(0, 0, this.background.width);
		}
		this.text.setPosition(2, 4);
		this.text.color = FlxColor.BLACK;

		add(this.background);
		add(this.button);
		add(this.text);
	}

	override public function destroy():Void
	{
		super.destroy();

		background = FlxDestroyUtil.destroy(background);
		text = FlxDestroyUtil.destroy(text);
		button = FlxDestroyUtil.destroy(button);
	}
}

enum FlxUIDropDownMenuDropDirection
{
	Automatic;
	Down;
	Up;
}
