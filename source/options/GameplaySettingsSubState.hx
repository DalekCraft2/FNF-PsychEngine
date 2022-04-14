package options;

import options.Options;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	override public function create():Void
	{
		super.create();

		title = 'Gameplay Settings';
		rpcTitle = 'Gameplay Settings Menu'; // for Discord Rich Presence

		var option:Option = new BooleanOption('controllerMode', 'Controller Mode',
			'Check this if you want to play with\na controller instead of using your Keyboard.');
		addOption(option);

		option = new BooleanOption('downScroll', 'Downscroll', 'If checked, notes go Down instead of Up, simple enough.');
		addOption(option);

		option = new BooleanOption('middleScroll', 'Middlescroll', 'If checked, your notes get centered.');
		addOption(option);

		option = new BooleanOption('ghostTapping', 'Ghost Tapping',
			'If checked, you won\'t get misses from pressing keys\nwhile there are no notes able to be hit.');
		addOption(option);

		option = new BooleanOption('noReset', 'Disable Reset Button', 'If checked, pressing Reset won\'t do anything.');
		addOption(option);

		option = new FloatOption('hitsoundVolume', 'Hitsound Volume', 'Funny notes does "Tick!" when you hit them.', 0.1, 0, 1, '%');
		option.scrollSpeed = 1.6;
		option.decimals = 1;
		addOption(option);

		option = new IntegerOption('ratingOffset', 'Rating Offset',
			'Changes how late/early you have to hit for a "Sick!"\nHigher values mean you have to hit later.', 1, -30, 30, 'ms');
		option.scrollSpeed = 20;
		addOption(option);

		option = new IntegerOption('sickWindow', 'Sick! Hit Window', 'Changes the amount of time you have\nfor hitting a "Sick!" in milliseconds.', 1, 15, 45,
			'ms');
		option.scrollSpeed = 15;
		addOption(option);

		option = new IntegerOption('goodWindow', 'Good Hit Window', 'Changes the amount of time you have\nfor hitting a "Good" in milliseconds.', 1, 15, 90,
			'ms');
		option.scrollSpeed = 30;
		addOption(option);

		option = new IntegerOption('badWindow', 'Bad Hit Window', 'Changes the amount of time you have\nfor hitting a "Bad" in milliseconds.', 1, 15, 135,
			'ms');
		option.scrollSpeed = 60;
		addOption(option);

		option = new FloatOption('safeFrames', 'Safe Frames', 'Changes how many frames you have for\nhitting a note earlier or late.', 0.1, 2, 10);
		option.scrollSpeed = 5;
		addOption(option);
	}
}
