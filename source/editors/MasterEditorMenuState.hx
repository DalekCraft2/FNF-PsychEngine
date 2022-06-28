package editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import ui.Alphabet;

using StringTools;

#if FEATURE_MODS
import flixel.text.FlxText;
#end
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class MasterEditorMenuState extends MusicBeatState
{
	private var options:Array<String> = [
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Character Editor',
		'Chart Editor'
	];
	private var curSelected:Int = 0;
	private var grpTexts:FlxTypedGroup<Alphabet>;

	#if FEATURE_MODS
	private var directories:Array<String> = [];
	private var curDirectory:Int = 0;
	private var directoryTxt:FlxText;
	#end

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('Editors Main Menu');
		#end

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.tempo = TitleState.titleDef.bpm;
		}

		FlxG.camera.bgColor = FlxColor.BLACK;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpTexts = new FlxTypedGroup();
		add(grpTexts);

		for (i in 0...options.length)
		{
			var text:Alphabet = new Alphabet(0, (70 * i) + 30, options[i], true, false);
			text.isMenuItem = true;
			text.targetY = i;
			grpTexts.add(text);
		}

		#if FEATURE_MODS
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, 32);
		directoryTxt.setFormat(Paths.font('vcr.ttf'), directoryTxt.size, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);

		for (folder in Paths.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Paths.currentModDirectory);
		if (found > -1)
			curDirectory = found;
		changeDirectory();
		#end
		changeSelection();

		FlxG.mouse.visible = false;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}
		#if FEATURE_MODS
		if (controls.UI_LEFT_P)
		{
			changeDirectory(-1);
		}
		if (controls.UI_RIGHT_P)
		{
			changeDirectory(1);
		}
		#end

		if (controls.BACK)
		{
			persistentUpdate = false;
			FlxG.switchState(new MainMenuState());
		}

		if (controls.ACCEPT)
		{
			persistentUpdate = false;
			switch (options[curSelected])
			{
				case 'Character Editor':
					LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
				case 'Week Editor':
					FlxG.switchState(new WeekEditorState());
				case 'Menu Character Editor':
					FlxG.switchState(new MenuCharacterEditorState());
				case 'Dialogue Portrait Editor':
					LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
				case 'Dialogue Editor':
					LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
				case 'Chart Editor': // felt it would be cool maybe
					LoadingState.loadAndSwitchState(new ChartEditorState(), false);
			}
			FlxG.sound.music.stop();
			#if PRELOAD_ALL
			FreeplayState.destroyFreeplayVocals();
			#end
		}

		for (i => item in grpTexts.members)
		{
			item.targetY = i - curSelected;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}

	private function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;
	}

	#if FEATURE_MODS
	private function changeDirectory(change:Int = 0):Void
	{
		curDirectory += change;

		if (curDirectory < 0)
			curDirectory = directories.length - 1;
		if (curDirectory >= directories.length)
			curDirectory = 0;

		Week.setDirectoryFromWeek();
		if (directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Paths.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ${Paths.currentModDirectory} >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();

		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
	}
	#end
}
