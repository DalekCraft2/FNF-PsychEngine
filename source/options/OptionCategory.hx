package options;

class OptionCategory extends Option
{
	public var options:Array<Option> = [];
	public var curSelected:Int = 0;

	public function addOption(opt:Option):Void
	{
		if (opt.parent != null)
		{
			opt.parent.delOption(opt);
		}
		opt.parent = this;
		options.push(opt);
	}

	public function delOption(opt:Option):Void
	{
		opt.parent = null;
		options.remove(opt);
	}

	public function new(name:String, opts:Array<Option>)
	{
		super();

		this.type = "Category";
		this.name = name;
		for (opt in opts)
		{
			addOption(opt);
		}
	}
}
