package states.substates;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.io.Path;
import openfl.geom.Rectangle;

/**
 * @author 
 */
class PromptSubState extends MusicBeatSubState
{
	public var acceptCallback:() -> Void;
	public var declineCallback:() -> Void;

	private var promptText:String;
	private var selected:Int = 0;
	private var acceptText:String;
	private var declineText:String;
	private var acceptOnDefault:Bool;
	private var buttonAccept:FlxButton;
	private var buttonDecline:FlxButton;

	// private var buttons:FlxSprite;
	private static final CORNER_SIZE:Int = 10;

	public function new(promptText:String = '', defaultSelected:Int = 0, acceptCallback:() -> Void, declineCallback:() -> Void, acceptOnDefault:Bool = false,
			acceptText:String = 'OK', declineText:String = 'CANCEL')
	{
		super();

		selected = defaultSelected;
		this.acceptCallback = acceptCallback;
		this.declineCallback = declineCallback;
		this.promptText = promptText;
		this.acceptOnDefault = acceptOnDefault;
		this.acceptText = acceptText;
		this.declineText = declineText;
	}

	override public function create():Void
	{
		super.create();

		if (acceptOnDefault)
		{
			if (acceptCallback != null)
				acceptCallback();
			close();
		}
		else
		{
			var panelbg:FlxSprite = new FlxSprite(0, 0);
			panelbg.loadGraphic(Paths.getGraphic(Path.join(['ui', 'prompt', 'prompt_bg'])));
			panelbg.updateHitbox();
			panelbg.screenCenter();
			panelbg.scrollFactor.set();
			add(panelbg);

			var panel:FlxSprite = new FlxSprite(0, 0);
			makeSelectorGraphic(panel, 300, 150, 0xFF999999);
			panel.screenCenter();
			panel.scrollFactor.set();
			add(panel);

			buttonAccept = new FlxButton(0, 0, acceptText, () ->
			{
				if (acceptCallback != null)
					acceptCallback();
				close();
			});
			buttonAccept.screenCenter();
			buttonAccept.scrollFactor.set();
			buttonAccept.x -= buttonAccept.width / 1.5;
			buttonAccept.y = panel.y + panel.height - 30;
			add(buttonAccept);

			buttonDecline = new FlxButton(0, 0, declineText, () ->
			{
				if (declineCallback != null)
					declineCallback();
				close();
			});
			buttonDecline.screenCenter();
			buttonDecline.scrollFactor.set();
			buttonDecline.x += buttonDecline.width / 1.5;
			buttonDecline.y = panel.y + panel.height - 30;
			add(buttonDecline);

			var textshit:FlxText = new FlxText(buttonDecline.width * 2, panel.y, 300, promptText, 16);
			textshit.alignment = CENTER;
			textshit.screenCenter();
			textshit.scrollFactor.set();
			add(textshit);

			/*
				buttons = new FlxSprite(0, 0);
				buttons.frames = Paths.getFrames(Path.join(['ui', 'prompt', 'prompt_buttons']));
				buttons.animation.addByPrefix('button0', 'buttons0000');
				buttons.animation.addByPrefix('button1', 'buttons0001');
				buttons.animation.play('button0');
				buttons.screenCenter();
				buttons.scrollFactor.set();
				buttons.y = panel.y + panel.height - 30;
				add(buttons);
			 */
		}
	}

	/*
		override public function update(elapsed:Float):Void
		{
			super.update(elapsed);

			if (!acceptOnDefault)
			{
				if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
				{
					if (selected == 0)
					{
						selected = 1;
					}
					else
					{
						selected = 0;
					}
					FlxG.sound.play(Paths.getSound('scrollMenu'));
					buttons.animation.play('button$selected');
				}
				buttonAccept.color.brightness = 0.5;
				buttonDecline.color.brightness = 0.5;
				if (selected == 0)
					buttonAccept.color.brightness = 0.9;
				if (selected == 1)
					buttonDecline.color.brightness = 0.9;
				if (controls.ACCEPT)
				{
					if (selected == 0)
					{
						FlxG.sound.play(Paths.getSound('confirmMenu'));
						if (acceptCallback != null)
							acceptCallback();
					}
					else
					{
						FlxG.sound.play(Paths.getSound('cancelMenu'));
						if (declineCallback != null)
							declineCallback();
					}
					close();
				}
			}
		}
	 */
	private function makeSelectorGraphic(panel:FlxSprite, width:Int, height:Int, color:FlxColor):Void
	{
		panel.makeGraphic(width, height, color);
		panel.pixels.fillRect(new Rectangle(0, 190, panel.width, 5), FlxColor.BLACK);

		// Why did i do this? Because i'm a lmao stupid, of course
		// also i wanted to understand better how fillRect works so i did this shit lol???
		panel.pixels.fillRect(new Rectangle(0, 0, CORNER_SIZE, CORNER_SIZE), FlxColor.TRANSPARENT); // top left
		drawCircleCornerOnSelector(panel, false, false, color);
		panel.pixels.fillRect(new Rectangle(panel.width - CORNER_SIZE, 0, CORNER_SIZE, CORNER_SIZE), FlxColor.TRANSPARENT); // top right
		drawCircleCornerOnSelector(panel, true, false, color);
		panel.pixels.fillRect(new Rectangle(0, panel.height - CORNER_SIZE, CORNER_SIZE, CORNER_SIZE), FlxColor.TRANSPARENT); // bottom left
		drawCircleCornerOnSelector(panel, false, true, color);
		panel.pixels.fillRect(new Rectangle(panel.width - CORNER_SIZE, panel.height - CORNER_SIZE, CORNER_SIZE, CORNER_SIZE),
			FlxColor.TRANSPARENT); // bottom right
		drawCircleCornerOnSelector(panel, true, true, color);
	}

	private function drawCircleCornerOnSelector(panel:FlxSprite, flipX:Bool, flipY:Bool, color:FlxColor):Void
	{
		var antiX:Float = (panel.width - CORNER_SIZE);
		var antiY:Float = flipY ? (panel.height - 1) : 0;
		if (flipY)
			antiY -= 2;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 1), Math.abs(antiY - 8), 10, 3), color);
		if (flipY)
			antiY += 1;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 2), Math.abs(antiY - 6), 9, 2), color);
		if (flipY)
			antiY += 1;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 3), Math.abs(antiY - 5), 8, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 4), Math.abs(antiY - 4), 7, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 5), Math.abs(antiY - 3), 6, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 6), Math.abs(antiY - 2), 5, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 8), Math.abs(antiY - 1), 3, 1), color);
	}
}
