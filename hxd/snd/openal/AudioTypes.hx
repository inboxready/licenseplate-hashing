package hxd.snd.openal;

#if hlopenal
import openal.AL.Source;
import openal.AL.Buffer;
typedef AL = openal.AL;
typedef EFX = openal.EFX;
#else
import hxd.snd.openal.Emulator;
typedef AL = Emulator;
#end

class BufferHandle {
	public var inst : Buffer;
	public var isEnd : Bool;
	public function new() { }
}

class SourceHandle {
	public var inst           : Source;
	public var sampleOffset   : Int;
	public var playing        : Bool;
	var nextAuxiliarySend     : Int