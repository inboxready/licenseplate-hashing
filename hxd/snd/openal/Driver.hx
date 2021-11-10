package hxd.snd.openal;

import hxd.snd.openal.AudioTypes;
import hxd.snd.Driver.DriverFeature;

#if hlopenal
import openal.AL;
import openal.ALC;
import openal.EFX;
#else
import hxd.snd.openal.Emulator;
#end

class Driver implements hxd.snd.Driver {
	public var device   (default, null) : Device;
	public var context  (default, null) : Context;
	public var maxAuxiliarySends(default, null) : Int;

	var tmpBytes : haxe.io.Bytes;

	public function new() {
		tmpBytes = haxe.io.Bytes.alloc(4 * 3 * 2);
		device   = ALC.openDevice(null);
		context  = ALC.createContext(device, null);

		ALC.makeContextCurrent(context);
		ALC.loadExtensions(device);
		AL.loadExtensions();

		// query maximum number of auxiliary sends
		var bytes = getTmpBytes(4);
		ALC.getIntegerv(device, EFX.MAX_AUXILIARY_SENDS, 1, bytes);
		maxAuxiliarySends = bytes.getInt32(0);

		if (AL.getError() != AL.NO_ERROR)
			throw "could not init openAL Driver";
	}

	public function hasFeature( f : DriverFeature ) {
		return switch( f ) {
		case MasterVolume: #if (hl || js) true #els