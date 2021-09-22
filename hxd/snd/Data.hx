
package hxd.snd;

enum SampleFormat {
	UI8;
	I16;
	F32;
}

class Data {

	public var samples(default, null) : Int;
	public var samplingRate(default, null) : Int;
	public var sampleFormat(default, null) : SampleFormat;
	public var channels(default, null) : Int;

	public var duration(get, never) : Float;

	public function isLoading() {
		return false;
	}

	public function decode( out : haxe.io.Bytes, outPos : Int, sampleStart : Int, sampleCount : Int ) : Void {
		var bpp = getBytesPerSample();
		if( sampleStart < 0 || sampleCount < 0 || outPos < 0 || outPos + sampleCount * bpp > out.length ) {

			var s = ("sampleStart = " + sampleStart);
			s += (" sampleCount = " + sampleCount);
			s += (" outPos = " + outPos);
			s += (" bpp = " + bpp);
			s += (" out.length = " + out.length);
			throw s;
		}
		if( sampleStart + sampleCount >= samples ) {
			var count = 0;
			if( sampleStart < samples ) {
				count = samples - sampleStart;
				decodeBuffer(out, outPos, sampleStart, count);
			}
			out.fill(outPos + count*bpp, (sampleCount - count) * bpp, 0);
			return;
		}
		decodeBuffer(out, outPos, sampleStart, sampleCount);
	}

	public function resample( rate : Int, format : SampleFormat, channels : Int ) : Data {
		if( sampleFormat == format && samplingRate == rate && this.channels == channels )
			return this;

		var newSamples = Math.ceil(samples * (rate / samplingRate));
		var bpp = getBytesPerSample();
		var data = haxe.io.Bytes.alloc(bpp * samples);
		decodeBuffer(data, 0, 0, samples);

		var out = haxe.io.Bytes.alloc(channels * newSamples * formatBytes(format));
		resampleBuffer(out, 0, data, 0, rate, format, channels, samples);

		var data = new WavData(null);
		data.channels = channels;
		data.samples = newSamples;
		data.sampleFormat = format;
		data.samplingRate = rate;
		@:privateAccess data.rawData = out;
		return data;