
package h2d;

#if (hl && hlvideo)

enum FrameState {
	Free;
	Loading;
	Ready;
	Ended;
}

typedef Frame = {
	var pixels : hxd.Pixels;
	var state : FrameState;
	var time : Float;
}

class FrameCache {
	var frames : Array<Frame> = [];
	var readCursor = 0;
	var writeCursor = 0;
	var width : Int;
	var height : Int;

	public function new(size : Int, w : Int, h : Int) {
		width = w;
		height = h;
		frames = [];
		for(i in 0 ... size) {
			frames[i] = {
				pixels: new hxd.Pixels(w, h, haxe.io.Bytes.alloc(w * h * 4), h3d.mat.Texture.nativeFormat),
				state: Free,
				time: 0
			}
		}
	}

	public function currentFrame() : Frame {
		if( frames == null )
			return null;
		return frames[readCursor];
	}

	public function nextFrame() : Bool {
		var nextCursor = (readCursor + 1) % frames.length;
		frames[readCursor].state = Free;
		readCursor = nextCursor;
		return true;
	}

	function frameBufferSize() {
		if(writeCursor < readCursor)
			return frames.length - readCursor + writeCursor;
		else
			return writeCursor - readCursor;
	}

	public function isFull() {
		if(writeCursor < readCursor)
			return frames.length - readCursor + writeCursor >= frames.length - 1;
		else
			return writeCursor - readCursor >= frames.length - 1;
	}

	public function isEmpty() {
		return readCursor == writeCursor;
	}

	public function prepareFrame(webm : hl.video.Webm, codec : hl.video.Aom.Codec, loop : Bool) : Frame {
		if(frames[writeCursor].state != Free)
			return null;

		var savedCursor = writeCursor;
		var f = frames[writeCursor];

		var time = webm.readFrame(codec, f.pixels.bytes);
		if(time == null) {
			if(loop) {
				webm.rewind();
				time = webm.readFrame(codec, f.pixels.bytes);
			}
			else {
				f.time = 0;
				f.state = Ended;
				return f;
			}
		}
		f.time = time;
		f.state = Ready;
		writeCursor++;
		if(writeCursor >= frames.length)
			writeCursor %= frames.length;
		return f;
	}

	public function dispose() {
		for(f in frames)
			f.pixels.dispose();
	}
}

#end

/**
	A video file playback Drawable. Due to platform specifics, each target have their own limitations.

	* <span class="label">Hashlink</span>: Playback ability depends on `https://github.com/HeapsIO/hlvideo` library. It support only video with the AV1 codec packed into a WEBM container.

	* <span class="label">JavaScript</span>: HTML Video element will be used. Playback is restricted by content-security policy and browser decoder capabilities.
**/
class Video extends Drawable {

	#if (hl && hlvideo)
	var webm : hl.video.Webm;
	var codec : hl.video.Aom.Codec;
	var multithread : Bool;
	var cache : FrameCache;
	var frameCacheSize : Int = 20;
	var stopThread = false;
	#elseif js
	var v : js.html.VideoElement;
	var videoPlaying : Bool;
	var videoTimeupdate : Bool;
	var onReady : Void->Void;
	#end
	var texture : h3d.mat.Texture;
	var tile : h2d.Tile;
	var playTime : Float;
	var videoTime : Float;
	var frameReady : Bool;
	var loopVideo : Bool;

	/**
		Video width. Value is undefined until video is ready to play.
	**/
	public var videoWidth(default, null) : Int;
	/**
		Video height. Value is undefined until video is ready to play.
	**/
	public var videoHeight(default, null) : Int;
	/**
		Tells if video currently playing.
	**/
	public var playing : Bool;
	/**
		Tells current timestamp of the video.
	**/
	public var time(get, null) : Float;
	/**
		When enabled, video will loop indefinitely.
	**/
	public var loop(get, set) : Bool;

	/**
		Create a new Video instance.
		@param parent An optional parent `h2d.Object` instance to which Video adds itself if set.
		@param cacheSize <span class="label">Hashlink</span>: async precomputing up to `cache` frame. If 0, synchronized computing
	**/
	public function new(?parent) {
		super(parent);
		smooth = true;
	}

	/**
		Sent when there is an error with the decoding or playback of the video.
	**/
	public dynamic function onError( msg : String ) {
	}

	/**
		Sent when video playback is finished.
	**/
	public dynamic function onEnd() {
	}

	@:dox(hide) @:noCompletion
	public function get_time() {
		#if js
		return playing ? v.currentTime : 0;
		#else
		return playing ? haxe.Timer.stamp() - playTime : 0;
		#end
	}

	@:dox(hide) @:noCompletion
	public inline function get_loop() {
		return loopVideo;
	}

	@:dox(hide) @:noCompletion
	public function set_loop(value : Bool) : Bool {
		#if js
		loopVideo = value;
		if(v != null)
			v.loop = loopVideo;
		return loopVideo;
		#else
		return loopVideo = value;
		#end
	}

	/**
		Disposes of the currently playing Video and frees GPU memory.
	**/
	public function dispose() {
		#if (hl && hlvideo)
		if( frameCacheSize > 1 ) {
			stopThread = true;
			while(stopThread)