package ui;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.util.FlxArrayUtil;
import flixel.util.FlxColor;
import haxe.io.Bytes;
import lime.media.AudioBuffer;
import openfl.geom.Rectangle;

typedef WaveformData =
{
	left:WaveformBound,
	right:WaveformBound
}

typedef WaveformBound =
{
	min:Array<Float>,
	max:Array<Float>
}

class Waveform extends FlxSprite
{
	public var startTime:Float;
	public var endTime:Float;
	public var sound:FlxSound;

	private var wavData:WaveformData = {
		left: {min: [0], max: [0]},
		right: {min: [0], max: [0]}
	};

	@:access(flixel.system.FlxSound._sound)
	@:access(openfl.media.Sound.__buffer)
	public function updateWaveform():Void
	{
		if (sound == null)
			return;

		FlxArrayUtil.clearArray(wavData.left.min);
		FlxArrayUtil.clearArray(wavData.left.max);
		FlxArrayUtil.clearArray(wavData.right.min);
		FlxArrayUtil.clearArray(wavData.right.max);

		if (sound._sound != null && sound._sound.__buffer != null && sound._sound.__buffer.data != null)
		{
			var bytes:Bytes = sound._sound.__buffer.data.toBytes();

			wavData = waveformData(sound._sound.__buffer, bytes, startTime, endTime, 1, wavData, height);
		}
	}

	public function drawWaveform():Void
	{
		if (sound == null)
			return;

		pixels.fillRect(pixels.rect, FlxColor.TRANSPARENT);

		var halfWidth:Float = width / 2;

		var size:Float = 1;

		var leftLength:Int = (wavData.left.min.length > wavData.left.max.length ? wavData.left.min.length : wavData.left.max.length);

		var rightLength:Int = (wavData.right.min.length > wavData.right.max.length ? wavData.right.min.length : wavData.right.max.length);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		for (i in 0...length)
		{
			var leftMin:Float = FlxMath.bound((i < wavData.left.min.length ? wavData.left.min[i] : 0) * width, -halfWidth, halfWidth) / 2;
			var leftMax:Float = FlxMath.bound((i < wavData.left.max.length ? wavData.left.max[i] : 0) * width, -halfWidth, halfWidth) / 2;

			var rightMin:Float = FlxMath.bound((i < wavData.right.min.length ? wavData.right.min[i] : 0) * width, -halfWidth, halfWidth) / 2;
			var rightMax:Float = FlxMath.bound((i < wavData.right.max.length ? wavData.right.max[i] : 0) * width, -halfWidth, halfWidth) / 2;

			pixels.fillRect(new Rectangle(halfWidth - (leftMin + rightMin), i * size, (leftMin + rightMin) + (leftMax + rightMax), size), color);
		}
	}

	private function waveformData(buffer:AudioBuffer, bytes:Bytes, startTime:Float, endTime:Float, multiply:Float = 1, ?wavData:WaveformData,
			steps:Float):WaveformData
	{
		if (buffer == null || buffer.data == null)
			return {left: {min: [0], max: [0]}, right: {min: [0], max: [0]}};

		var khz:Float = buffer.sampleRate / 1000;
		var channels:Int = buffer.channels;

		var index:Int = Std.int(startTime * khz);

		var samples:Float = (endTime - startTime) * khz;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var leftMin:Float = 0;
		var leftMax:Float = 0;

		var rightMin:Float = 0;
		var rightMax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true; // samples > 17200;
		var v1:Bool = false;

		if (wavData == null)
			wavData = {left: {min: [0], max: [0]}, right: {min: [0], max: [0]}};

		while (index < (bytes.length - 1))
		{
			if (index >= 0)
			{
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2)
					byte -= 65535;

				var sample:Float = byte / 65535;

				if (sample > 0)
				{
					if (sample > leftMax)
						leftMax = sample;
				}
				else if (sample < 0)
				{
					if (sample < leftMin)
						leftMin = sample;
				}

				if (channels >= 2)
				{
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2)
						byte -= 65535;

					sample = byte / 65535;

					if (sample > 0)
					{
						if (sample > rightMax)
							rightMax = sample;
					}
					else if (sample < 0)
					{
						if (sample < rightMin)
							rightMin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow)
			{
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var leftRowMin:Float = Math.abs(leftMin) * multiply;
				var leftRowMax:Float = leftMax * multiply;

				var rightRowMin:Float = Math.abs(rightMin) * multiply;
				var rightRowMax:Float = rightMax * multiply;

				if (gotIndex > wavData.left.min.length)
					wavData.left.min.push(leftRowMin);
				else
					wavData.left.min[gotIndex - 1] = wavData.left.min[gotIndex - 1] + leftRowMin;

				if (gotIndex > wavData.left.max.length)
					wavData.left.max.push(leftRowMax);
				else
					wavData.left.max[gotIndex - 1] = wavData.left.max[gotIndex - 1] + leftRowMax;

				if (channels >= 2)
				{
					if (gotIndex > wavData.right.min.length)
						wavData.right.min.push(rightRowMin);
					else
						wavData.right.min[gotIndex - 1] = wavData.right.min[gotIndex - 1] + rightRowMin;

					if (gotIndex > wavData.right.max.length)
						wavData.right.max.push(rightRowMax);
					else
						wavData.right.max[gotIndex - 1] = wavData.right.max[gotIndex - 1] + rightRowMax;
				}
				else
				{
					if (gotIndex > wavData.right.min.length)
						wavData.right.min.push(leftRowMin);
					else
						wavData.right.min[gotIndex - 1] = wavData.right.min[gotIndex - 1] + leftRowMin;

					if (gotIndex > wavData.right.max.length)
						wavData.right.max.push(leftRowMax);
					else
						wavData.right.max[gotIndex - 1] = wavData.right.max[gotIndex - 1] + leftRowMax;
				}

				leftMin = 0;
				leftMax = 0;

				rightMin = 0;
				rightMax = 0;
			}

			index++;
			rows++;
			if (gotIndex > steps)
				break;
		}

		return wavData;
	}
}
