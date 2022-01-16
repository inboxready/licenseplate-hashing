package hxd.snd.webaudio;
#if (js && !useal)

import hxd.snd.webaudio.AudioTypes;
import hxd.snd.Driver.DriverFeature;
import js.html.audio.*;

class Driver implements hxd.snd.Driver {

	public var ctx : AudioContext;
	public var masterGain(get, nev