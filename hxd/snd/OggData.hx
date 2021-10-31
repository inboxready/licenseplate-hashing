
package hxd.snd;

#if hl

private typedef OggFile = hl.Abstract<"fmt_ogg">;

class OggData extends Data {

	var bytes : haxe.io.Bytes;
	var reader : OggFile;
	var currentSample : Int;