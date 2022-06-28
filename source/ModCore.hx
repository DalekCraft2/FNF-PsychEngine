package;

#if polymod
import lime.utils.Bytes;
import polymod.Polymod;
import polymod.backends.OpenFLBackend;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.format.ParseRules;

/**
 * Okay now this is epic.
 */
class ModCore
{
	/**
	 * The current API version.
	 * Must be formatted in Semantic Versioning v2; <MAJOR>.<MINOR>.<PATCH>.
	 * 
	 * Remember to increment the major version if you make breaking changes to mods!
	 */
	private static final API_VERSION:String = '0.1.0';

	private static final MOD_DIRECTORY:String = 'mods';

	public static function initialize():Void
	{
		Debug.logInfo('Initializing ModCore...');
		loadModsById(getModIds());
	}

	public static function loadModsById(ids:Array<String>):Void
	{
		Debug.logInfo('Attempting to load ${ids.length} mods...');
		var loadedModList:Array<ModMetadata> = Polymod.init({
			// Root directory for all mods.
			modRoot: MOD_DIRECTORY,
			// The directories for one or more mods to load.
			dirs: ids,
			// Framework being used to load assets. We're using a CUSTOM one which extends the OpenFL one.
			framework: CUSTOM,
			// framework: OPENFL,
			// The current version of our API.
			apiVersion: API_VERSION,
			// Call this function any time an error occurs.
			errorCallback: onPolymodError,
			// Enforce semantic version patterns for each mod.
			// modVersions: null,
			// A map telling Polymod what the asset type is for unfamiliar file extensions.
			// extensionMap: [],

			frameworkParams: buildFrameworkParams(),

			// Use a custom backend so we can get a picture of what's going on,
			// or even override behavior ourselves.
			customBackend: ModCoreBackend,

			// List of filenames to ignore in mods. Use the default list to ignore the metadata file, etc.
			ignoredFiles: Polymod.getDefaultIgnoreList(),

			// Parsing rules for various data formats.
			parseRules: buildParseRules(),
		});

		Debug.logInfo('Mod loading complete. We loaded ${loadedModList.length} / ${ids.length} mods.');

		for (mod in loadedModList)
			Debug.logTrace('  * ${mod.title} v${mod.modVersion} [${mod.id}]');

		var fileList:Array<String> = Polymod.listModFiles('IMAGE');
		Debug.logInfo('Installed mods have replaced ${fileList.length} images.');
		for (item in fileList)
			Debug.logTrace('  * $item');

		fileList = Polymod.listModFiles('TEXT');
		Debug.logInfo('Installed mods have replaced ${fileList.length} text files.');
		for (item in fileList)
			Debug.logTrace('  * $item');

		fileList = Polymod.listModFiles('MUSIC');
		Debug.logInfo('Installed mods have replaced ${fileList.length} music files.');
		for (item in fileList)
			Debug.logTrace('  * $item');

		fileList = Polymod.listModFiles('SOUND');
		Debug.logInfo('Installed mods have replaced ${fileList.length} sound files.');
		for (item in fileList)
			Debug.logTrace('  * $item');
	}

	private static function getModIds():Array<String>
	{
		#if FEATURE_MODS
		// TODO Find a way to sort these based on the modList.txt file
		Debug.logInfo('Scanning the mods folder...');
		var modMetadataArray:Array<ModMetadata> = Polymod.scan(MOD_DIRECTORY);
		Debug.logInfo('Found ${modMetadataArray.length} mods when scanning.');
		var modIds:Array<String> = [for (modMetadata in modMetadataArray) modMetadata.id];
		return modIds;
		#else
		return [];
		#end
	}

	private static function buildParseRules():ParseRules
	{
		var output:ParseRules = ParseRules.getDefault();
		// Ensure TXT files have merge support.
		output.addType(Paths.TEXT_EXT, TextFileFormat.LINES);

		// You can specify the format of a specific file, with file extension.
		// output.addFile(Path.withExtension('data/introText', Paths.TEXT_EXT), TextFileFormat.LINES)
		return output;
	}

	private static inline function buildFrameworkParams():FrameworkParams
	{
		return {
			assetLibraryPaths: ['default' => './', // ./preload
				'sm' => './sm']
		}
	}

	private static function onPolymodError(error:PolymodError):Void
	{
		// Perform an action based on the error code.
		switch (error.code)
		{
			// case "parse_mod_version":
			// case "parse_api_version":
			// case "parse_mod_api_version":
			// case "missing_mod":
			// case "missing_meta":
			// case "missing_icon":
			// case "version_conflict_mod":
			// case "version_conflict_api":
			// case "version_prerelease_api":
			// case "param_mod_version":
			// case "framework_autodetect":
			// case "framework_init":
			// case "undefined_custom_backend":
			// case "failed_create_backend":
			// case "merge_error":
			// case "append_error":
			default:
				// Log the message based on its severity.
				switch (error.severity)
				{
					case NOTICE:
						Debug.logInfo(error.message, null);
					case WARNING:
						Debug.logWarn(error.message, null);
					case ERROR:
						Debug.logError(error.message, null);
				}
		}
	}
}

class ModCoreBackend extends OpenFLBackend
{
	public function new()
	{
		super();
		Debug.logTrace('Initialized custom asset loader backend.');
	}

	override public function clearCache()
	{
		super.clearCache();
		Debug.logWarn('Custom asset cache has been cleared.');
	}

	override public function exists(id:String):Bool
	{
		Debug.logTrace('Call to ModCoreBackend: exists($id)');
		return super.exists(id);
	}

	override public function getBytes(id:String):Bytes
	{
		Debug.logTrace('Call to ModCoreBackend: getBytes($id)');
		return super.getBytes(id);
	}

	override public function getText(id:String):String
	{
		Debug.logTrace('Call to ModCoreBackend: getText($id)');
		return super.getText(id);
	}

	// TODO Check whether this can be changed to "?type:PolymodAssetType"
	override public function list(type:PolymodAssetType = null):Array<String>
	{
		Debug.logTrace('Listing assets in custom asset cache ($type).');
		return super.list(type);
	}
}
#end
