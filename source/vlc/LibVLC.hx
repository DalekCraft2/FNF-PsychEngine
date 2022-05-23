package vlc;

#if cpp
import cpp.Pointer;
import cpp.UInt8;

/**
 * @author Tommy S
 */
// This metadata is for when the build directory is export/release or export/debug or export/final etc.
// @:buildXml('<include name="../../../../source/vlc/LibVLCBuild.xml" />')
// This metadata is for when the build directory is the default (bin)
@:buildXml('<include name="./../../../source/vlc/LibVLCBuild.xml" />')
@:include('LibVLC.h')
// @:keep
@:structAccess
extern class LibVLC
{
	// Trying to access members of this will make the program not compile so I had to make methods for getting and setting values in it
	// public var flags:Array<Int>;
	public function new();

	public function setPath(path:String):Void;

	@:overload(function():Void
	{
	})
	public function play(path:String):Void;

	@:overload(function():Void
	{
	})
	public function playInWindow(path:String):Void;

	public function stop():Void;

	public function pause():Void;

	public function resume():Void;

	public function togglePause():Void;

	public function getFullscreen():Bool;

	public function setFullscreen(fullscreen:Bool):Void;

	public function getLength():Float;

	public function getWidth():Int;

	public function getHeight():Int;

	public function isPlaying():Bool;

	public function isSeekable():Bool;

	public function getVolume():Float;

	public function setVolume(volume:Float):Void;

	public function getTime():Int;

	public function setTime(time:Int):Void;

	public function getPosition():Float;

	public function setPosition(position:Float):Void;

	public function getRepeats():Int;

	public function setRepeats(repeats:Int):Void;

	public function useHWacceleration(hwAcc:Bool):Void;

	public function getPixelData():Pointer<UInt8>;

	public function getFPS():Float;

	public function nextFrame():Void;

	public function hasVout():Bool;

	public function getFlag(index:Int): /*Float*/ Dynamic;

	public function setFlag(index:Int, value: /*Float*/ Dynamic):Void;
}
#end
