package hscript.utils;

import haxe.io.Encoding;
import haxe.io.FPHelper;
import haxe.io.Bytes;
import haxe.io.BytesData;

/**
 * BytesInput with default little Endianness, no EOF and bounds checking, and inlining.
 */
class UnsafeBytesInput {
	var b:#if js js.lib.Uint8Array #elseif hl hl.Bytes #else BytesData #end;
	#if !flash
	var pos:Int;
	var len:Int;
	var totlen:Int;
	#end

	/** The current position in the stream in bytes. */
	public var position(get, set):Int;

	/** The length of the stream in bytes. */
	public var length(get, never):Int;

	public function new(b:Bytes, ?pos:Int, ?len:Int) {
		if (pos == null)
			pos = 0;
		if (len == null)
			len = b.length - pos;
		#if flash
		var ba = b.getData();
		ba.position = pos;
		if (len != ba.bytesAvailable) {
			// truncate
			this.b = new flash.utils.ByteArray();
			ba.readBytes(this.b, 0, len);
		} else
			this.b = ba;
		this.b.endian = flash.utils.Endian.LITTLE_ENDIAN;
		#else
		this.b = #if (js || hl) @:privateAccess b.b #else b.getData() #end;
		this.pos = pos;
		this.len = len;
		this.totlen = len;
		#end
	}

	inline function get_position():Int {
		#if flash
		return b.position;
		#else
		return pos;
		#end
	}

	inline function get_length():Int {
		#if flash
		return b.length;
		#else
		return totlen;
		#end
	}

	inline function set_position(p:Int):Int {
		if (p < 0)
			p = 0;
		else if (p > length)
			p = length;
		#if flash
		return b.position = p;
		#else
		len = totlen - p;
		return pos = p;
		#end
	}

	public inline function readByte():Int {
		#if flash
		return try b.readUnsignedByte() catch (e:Dynamic) throw new Eof();
		#else
		len--;
		#if neko
		return untyped __dollar__sget(b, pos++);
		#elseif cpp
		return untyped b[pos++];
		#elseif java
		return untyped b[pos++] & 0xFF;
		#elseif python // dodge https://github.com/HaxeFoundation/haxe/issues/5080
		var b = b[pos];
		pos++;
		return b;
		#else
		return b[pos++];
		#end
		#end
	}

	public inline function readBytes(buf:Bytes, pos:Int, len:Int):Int {
		#if flash
		var avail:Int = b.bytesAvailable;
		if (len > avail && avail > 0)
			len = avail;
		try
			b.readBytes(buf.getData(), pos, len)
		catch (e:Dynamic)
			throw new Eof();
		#elseif java
		var avail:Int = this.len;
		if (len > avail)
			len = avail;
		if (len == 0)
			throw new Eof();
		java.lang.System.arraycopy(this.b, this.pos, buf.getData(), pos, len);
		this.pos += len;
		this.len -= len;
		#elseif cs
		var avail:Int = this.len;
		if (len > avail)
			len = avail;
		if (len == 0)
			throw new Eof();
		cs.system.Array.Copy(this.b, this.pos, buf.getData(), pos, len);
		this.pos += len;
		this.len -= len;
		#else
		if (this.len < len)
			len = this.len;
		#if neko
		try
			untyped __dollar__sblit(buf.getData(), pos, b, this.pos, len)
		catch (e:Dynamic)
			throw Error.OutsideBounds;
		#elseif hl
		@:privateAccess buf.b.blit(pos, b, this.pos, len);
		#else
		var b1 = b;
		var b2 = #if js @:privateAccess buf.b #else buf.getData() #end;
		for (i in 0...len)
			b2[pos + i] = b1[this.pos + i];
		#end
		this.pos += len;
		this.len -= len;
		#end
		return len;
	}

	#if flash
	function readFloat() {
		return b.readFloat();
	}

	function readDouble() {
		return b.readDouble();
	}

	function readInt8() {
		return b.readByte();
	}

	function readInt16() {
		return b.readShort();
	}

	function readUInt16():Int {
		return b.readUnsignedShort();
	}

	function readInt32():Int {
		return b.readInt();
	}

	function readString(len:Int, ?encoding:Encoding) {
		return encoding == RawNative ? b.readMultiByte(len, "unicode") : b.readUTFBytes(len);
	}
	#else 
	public inline function readFloat():Float {
		return FPHelper.i32ToFloat(readInt32());
	}

	public inline function readDouble():Float {
		var i1 = readInt32();
		var i2 = readInt32();
		return FPHelper.i64ToDouble(i1, i2);
	}

	public inline function readInt8():Int {
		var n = readByte();
		if (n >= 128)
			return n - 256;
		return n;
	}

	public inline function readInt16():Int {
		var ch1 = readByte();
		var ch2 = readByte();
		var n = ch1 | (ch2 << 8);
		if (n & 0x8000 != 0)
			return n - 0x10000;
		return n;
	}

	public inline function readUInt16():Int {
		var ch1 = readByte();
		var ch2 = readByte();
		return ch1 | (ch2 << 8);
	}

	public inline function readInt24():Int {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		var n = ch1 | (ch2 << 8) | (ch3 << 16);
		if (n & 0x800000 != 0)
			return n - 0x1000000;
		return n;
	}

	public inline function readUInt24():Int {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		return ch1 | (ch2 << 8) | (ch3 << 16);
	}

	public inline function readInt32():Int {
		var ch1 = readByte();
		var ch2 = readByte();
		var ch3 = readByte();
		var ch4 = readByte();
		#if (php || python)
		// php will overflow integers.  Convert them back to signed 32-bit ints.
		var n = ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
		if (n & 0x80000000 != 0)
			return (n | 0x80000000);
		else
			return n;
		#elseif lua
		var n = ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
		return lua.Boot.clampInt32(n);
		#else
		return ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
		#end
	}

	public inline function readFullBytes(s:Bytes, pos:Int, len:Int):Void {
		while (len > 0) {
			var k = readBytes(s, pos, len);
			pos += k;
			len -= k;
		}
	}

	public inline function readString(len:Int, ?encoding:Encoding):String {
		var b = Bytes.alloc(len);
		readFullBytes(b, 0, len);
		#if neko
		return neko.Lib.stringReference(b);
		#else
		return b.getString(0, len, encoding);
		#end
	}
	#end
}