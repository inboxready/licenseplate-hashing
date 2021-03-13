package hxd;

import haxe.io.Bytes;

/**
 * Tries to provide consistent access to haxe.io.bytes from any primitive
 */
class ByteConversions{

#if flash

	public static inline function byteArrayToBytes( v: flash.utils.ByteArray ) : haxe.io.Bytes {
		return Bytes.ofData( v );
	}

	public static inline function bytesToByteArray( v: hax