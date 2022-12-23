
class Video extends hxd.App {

	var video : h2d.Video;
	var tf : h2d.Text;

	override function init() {
		tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		video = new h2d.Video(s2d);
		video.onError = function(e) {
			tf.text = e;
			tf.textColor = 0xFF0000;
		};
		function start() {
			#if hl
			video.load("testVideo.avi");
			#elseif js
			video.load("testVideo.mp4");
			#end
		}
		video.onEnd = start;
		start();
	}

	override function update(dt:Float) {
	