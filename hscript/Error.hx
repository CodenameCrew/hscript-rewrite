package hscript;

class Error {
	public var e:ErrorDef;
	public var min:Int;
	public var max:Int;
	public var origin:String;
	public var line:Int;

	public function new(e:ErrorDef, min:Int, max:Int, origin:String, line:Int) {
		this.e = e;
		this.min = min;
		this.max = max;
		this.origin = origin;
		this.line = line;
	}
}

enum ErrorDef {
	EInvalidChar( c : Int );
	EUnexpected( s : String );
	EUnterminatedString;
	EUnterminatedComment;
	EInvalidPreprocessor( msg : String );
	EUnknownVariable( v : String );
	EInvalidIterator( v : String );
	EInvalidOp( op : String );
	EInvalidAccess( f : String );
	ECustom( msg : String );
}