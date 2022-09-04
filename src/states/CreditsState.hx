package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.typeLimit.OneOfTwo;
import haxe.io.Path;
import ui.Alphabet;
import ui.AttachedSprite;
import util.CoolUtil;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

// Idea for credits JSON format, using CreditDef (minus the modDirectory field):
// "sections": [
// 	{
// 		"title": "lorem ipsum whatever",
// 		"credits": [
// 			{
// 				"name": "blah",
// 				"icon": "blah2",
// 				"description": "was an example for a potential json format",
// 				"link": "www.com",
// 				"color": "0xFF00FF00"
// 			}
// 		]
// 	}
// ]

typedef CreditWrapper =
{
	sections:Array<CreditSection>
}

typedef CreditSection =
{
	title:String,
	credits:Array<CreditDef>
}

typedef CreditDef =
{
	name:String,
	icon:String,
	description:String,
	link:String,
	color:String,
	modDirectory:String
	// ^^^ I'm planning to remove this field
}

class Credit
{
	public var name:String;
	public var icon:String;
	public var description:String;
	public var link:String;
	public var color:FlxColor;
	public var modDirectory:String;

	public function new(name:String, icon:String, description:String, link:String, color:OneOfTwo<FlxColor, String>, modDirectory:String)
	{
		this.name = name;
		this.icon = icon;
		this.description = description;
		this.link = link;
		if (color is Int)
		{
			this.color = color;
		}
		else
		{
			this.color = FlxColor.fromString(color);
		}
		this.modDirectory = modDirectory;
	}
}

// FIXME When a credits file has no title, the mod directory does not change
class CreditsState extends MusicBeatState implements ListMenu
{
	private static final OFFSET:Float = -75;

	private var curSelected:Int = -1;

	private var grpCredits:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<AttachedSprite> = [];
	private var credits:Array<CreditDef> = [];

	private var bg:FlxSprite;
	private var descText:FlxText;
	private var intendedColor:Int;
	private var colorTween:FlxTween;
	private var descBox:AttachedSprite;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('In the Menus');
		#end

		bg = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'main', 'backgrounds', 'menuDesat'])));
		add(bg);
		bg.screenCenter();

		grpCredits = new FlxTypedGroup();
		add(grpCredits);

		var modsAdded:Array<String> = [];

		var directories:Array<String> = Paths.getDirectoryLoadOrder();
		for (directory in directories)
		{
			if (modsAdded.contains(directory))
				continue;

			var creditsFile:String = Path.join([directory, Path.withExtension(Path.join(['data', 'credits']), Paths.TEXT_EXT)]);

			if (Paths.exists(creditsFile))
			{
				var firstArray:Array<String> = CoolUtil.listFromTextFile(creditsFile);
				for (line in firstArray)
				{
					var arr:Array<String> = line.replace('\\n', '\n').split('::');
					credits.push({
						name: arr[0],
						icon: arr[1],
						description: arr[2],
						link: arr[3],
						color: arr[4],
						modDirectory: directory
					});
				}
			}
			modsAdded.push(directory);
		}

		for (i => credit in credits)
		{
			var isSelectable:Bool = !unselectableCheck(i);
			var optionText:Alphabet = new Alphabet(0, 70 * i, credit.name, !isSelectable, false);

			optionText.isMenuItem = true;
			optionText.screenCenter(X);
			optionText.yAdd -= 70;
			if (isSelectable)
			{
				optionText.x -= 70;
			}
			optionText.forceX = optionText.x;
			optionText.targetY = i;
			grpCredits.add(optionText);
			if (isSelectable)
			{
				if (credit.modDirectory != null)
				{
					Paths.currentModDirectory = credit.modDirectory;
				}
				var icon:AttachedSprite = new AttachedSprite(Path.join(['ui', 'credits', 'icons', credit.icon]));
				icon.xAdd = optionText.width + 10;
				icon.sprTracker = optionText;
				// using a FlxGroup is too much fuss!
				iconArray.push(icon);
				add(icon);
				Paths.currentModDirectory = '';
				if (curSelected == -1)
					curSelected = i;
			}
		}
		descBox = new AttachedSprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.xAdd = -10;
		descBox.yAdd = -10;
		descBox.alphaMult = 0.6;
		descBox.alpha = 0.6;
		add(descBox);
		descText = new FlxText(50, FlxG.height + OFFSET - 25, 1180, 32);
		descText.setFormat(Paths.font('vcr.ttf'), descText.size, FlxColor.WHITE, CENTER);
		descText.scrollFactor.set();
		descBox.sprTracker = descText;
		add(descText);
		if (!unselectableCheck(curSelected))
			bg.color = getCurrentBGColor();
		intendedColor = bg.color;
		changeSelection();
	}

	private var quitting:Bool = false;
	private var holdTime:Float = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
		}

		if (!quitting)
		{
			if (credits.length > 1)
			{
				var shiftMult:Int = 1;
				if (FlxG.keys.pressed.SHIFT)
					shiftMult = 3;

				var upP:Bool = controls.UI_UP_P;
				var downP:Bool = controls.UI_DOWN_P;

				if (upP)
				{
					changeSelection(-1 * shiftMult);
					holdTime = 0;
				}
				if (downP)
				{
					changeSelection(1 * shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}

				if (FlxG.mouse.wheel != 0)
				{
					changeSelection(-FlxG.mouse.wheel * shiftMult);
				}
			}

			if (controls.ACCEPT)
			{
				if (credits.length > 0)
				{
					FlxG.openURL(credits[curSelected].link);
				}
			}
			if (controls.BACK)
			{
				if (colorTween != null)
				{
					colorTween.cancel();
				}
				persistentUpdate = false;
				FlxG.sound.play(Paths.getSound('cancelMenu'));
				FlxG.switchState(new MainMenuState());
				quitting = true;
			}
		}

		for (item in grpCredits)
		{
			if (!item.isBold)
			{
				var lerpVal:Float = FlxMath.bound(elapsed * 12, 0, 1);
				if (item.targetY == 0)
				{
					var lastX:Float = item.x;
					item.screenCenter(X);
					item.x = FlxMath.lerp(lastX, item.x - 70, lerpVal);
					item.forceX = item.x;
				}
				else
				{
					item.x = FlxMath.lerp(item.x, 200 + -40 * Math.abs(item.targetY), lerpVal);
					item.forceX = item.x;
				}
			}
		}
	}

	private var moveTween:FlxTween;

	private function changeSelection(change:Int = 0):Void
	{
		if (credits.length > 0)
		{
			// do
			// {
			curSelected = FlxMath.wrap(curSelected + change, 0, credits.length - 1);
			// }
			// while (unselectableCheck(curSelected));

			var newColor:Int = getCurrentBGColor();
			if (newColor != intendedColor)
			{
				if (colorTween != null)
				{
					colorTween.cancel();
				}
				intendedColor = newColor;
				colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
					onComplete: (twn:FlxTween) ->
					{
						colorTween = null;
					}
				});
			}

			for (i => item in grpCredits.members)
			{
				item.targetY = i - curSelected;

				if (!unselectableCheck(i - 1))
				{
					item.alpha = 0.6;
					if (item.targetY == 0)
					{
						item.alpha = 1;
					}
				}
			}

			descText.text = credits[curSelected].description;
			descText.y = FlxG.height - descText.height + OFFSET - 60;

			if (moveTween != null)
				moveTween.cancel();
			moveTween = FlxTween.tween(descText, {y: descText.y + 75}, 0.25, {ease: FlxEase.sineOut});

			descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
			descBox.updateHitbox();

			if (change != 0)
				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
		}
	}

	private function getCurrentBGColor():Int
	{
		var bgColor:String = credits[curSelected].color;
		if (!bgColor.startsWith('0x'))
		{
			bgColor = '0xFF$bgColor';
		}
		return Std.parseInt(bgColor);
	}

	private function unselectableCheck(num:Int):Bool
	{
		var credit:CreditDef = credits[num];
		if (credit != null)
		{
			return credit.icon == null && credit.description == null && credit.link == null && credit.color == null;
		}
		else
		{
			return false;
		}
	}
}
