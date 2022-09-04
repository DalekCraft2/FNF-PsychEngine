package vlc;

#if cpp
import cpp.Pointer;
import cpp.UInt8;

/**
 * @author Tommy Svensson
 */
@:buildXml('<include name="./../../../src/vlc/LibVLCBuild.xml" />')
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

	public function getLength():Int;

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

	public function getPixelData():Pointer<UInt8>;

	public function nextFrame():Void;

	public function getVOutCount():Int;

	public function getFlag(index:Int):Float;

	public function setFlag(index:Int, value:Float):Void;
}
#end
