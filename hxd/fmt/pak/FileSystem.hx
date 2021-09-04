package hxd.fmt.pak;
import hxd.fs.FileEntry;
#if air3
import hxd.impl.Air3File;
#elseif (sys || nodejs)
import sys.io.File;
import sys.io.FileInput;
typedef FileSeekMode = sys.io.FileSeek;
#else
enum FileSeekMode {
	SeekBegin;
	SeekEnd;
	SeedCurrent;
}
class FileInput extends haxe.io.BytesInput {
	public function seek( pos : Int, seekMode : FileSeekMode ) {
		switch( seekMode ) {
		case SeekBegin:
			this.position = pos;
		case SeekEnd:
			this.position = this.length - pos;
		case SeedCurrent:
			this.position += pos;
		}
	}

	public function tell() {
		return this.position;
	}
}
#end

class FileSeek {
	#if (hl && hl_ver >= version("1.12.0"))
	@:hlNative("std","file_seek2") static function seek2( f : sys.io.File.FileHandle, pos : Float, cur : Int ) : Bool { return false; }
	#end

	public static function seek( f : FileInput, pos : Float, mode : FileSeekMode ) {
		#if (hl && hl_ver >= version("1.12.0"))
		if( !seek2(@:privateAccess f.__f,pos,mode.getIndex()) )
			throw haxe.io.Error.Custom("seek2 failure()");
		#else
		if( pos > 0x7FFFFFFF ) throw haxe.io.Error.Custom("seek out of bounds");
		f.seek(Std.int(pos),mode);
		#end
	}
}

@:allow(hxd.fmt.pak.FileSystem)
@:access(hxd.fmt.pak.FileSystem)
private class PakEntry extends FileEntry {

	var fs : FileSystem;
	var parent : PakEntry;
	var file : Data.File;
	var pakFile : Int;
	var subs : Array<PakEntry>;
	var relPath : String;

	public function new(fs, parent, f, p) {
		this.fs = fs;
		this.file = f;
		this.pakFile = p;
		this.parent = parent;
		name = file.name;
		if( f.isDirectory ) subs = [];
	}

	override function get_path() {
		if( relPath != null )
			return relPath;
		relPath = parent == null ? "<root>" : (parent.parent == null ? name : parent.path + "/" + name);
		return relPath;
	}

	override function get_size() {
		return file.dataSize;
	}

	override function get_isDirectory() {
		return file.isDirectory;
	}

	function setPos() {
		var pak = fs.getFile(pakFile);
		FileSeek.seek(pak,file.dataPosition, SeekBegin);
	}

	override function getBytes() {
		setPos();
		fs.totalReadBytes += file.dataSize;
		fs.totalReadCount++;
		var pak = fs.getFile(pakFile);
		return pak.read(file.dataSize);
	}

	override function readBytes( out : haxe.io.Bytes, outPos : Int, pos : Int, len : Int ) : Int {
		var pak = fs.getFile(pakFile);
		FileSeek.seek(pak,file.dataPosition + pos, SeekBegin);
		if( pos + len > file.dataSize )
			len = file.dataSize - pos;
		var tot = 0;
		while( len > 0 ) {
			var k = pak.readBytes(out, outPos, len);
			if( k <= 0 ) break;
			len -= k;
			outPos += k;
			tot += k;
			fs.totalReadBytes += k;
			fs.totalReadCount++;
		}
		return tot;
	}

	override function exists( name : String ) {
		if( subs != null )
			for( c in subs )
				if( c.name == name )
					return true;
		return false;
	}

	override function get( name : String ) : FileEntry {
		if( subs != null )
			for( c in subs )
				if( c.name == name )
					return c;
		return null;
	}

	override function iterator() {
		return new hxd.impl.ArrayIterator<FileEntry>(cast subs);
	}

	override function loadBitmap( onLoaded ) {
		#if flash
		if( openedBytes != null ) throw "Must close() before loadBitmap";
		open();
		var old = openedBytes;
		var loader = new flash.display.Loader();
		loader.contentLoaderInfo.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e:flash.events.IOErrorEvent) {
			throw Std.string(e) + " while loading " + path;
		});
		loader.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE, function(_) {
			if( openedBytes == null ) {
				openedBytes = old;
				close();
			}
			var content : flash.display.Bitmap = cast loader.content;
			onLoaded(new hxd.fs.LoadedBitmap(content.bitmapData));
			loader.unload();
		});
		var ctx = new flash.system.LoaderContext();
		ctx.imageDecodingPolicy = ON_LOAD;
		loader.loadBytes(openedBytes.getData(), ctx);
		openedBytes = null;
		#else
