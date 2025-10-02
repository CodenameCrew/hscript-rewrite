package hscript;

class Error {
	public var e:ErrorDef;
	public var min:Int;
	public var max:Int;
	public var fileName:String;
	public var line:Int;

	public function new(e:ErrorDef, ?min:Int, ?max:Int, ?fileName:String, ?line:Int) {
		this.e = e;
		this.min = min;
		this.max = max;
		this.fileName = fileName;
		this.line = line;
	}

	public function toString():String {
		var message:String = switch( this.e ) {
			case EInvalidChar(c): "Invalid character: '"+(StringTools.isEof(c) ? "EOF" : String.fromCharCode(c))+"' ("+c+")";
			case EUnexpected(s , expected): (expected != null ? 'Unexpected token: have $s, want $expected' : "Unexpected token: \""+s+"\"");
			case EUnterminatedString: "Unterminated string";
			case EUnterminatedComment: "Unterminated comment";
			case EInvalidPreprocessor(str): "Invalid preprocessor (" + str + ")";
			case EUnknownVariable(v): "Unknown variable: "+v;
			case EInvalidIterator(v): "Invalid iterator: "+v;
			case EInvalidOp(op): "Invalid operator: "+op;
			case EInvalidAccess(f): "Invalid access to field " + f;
			case EInvalidClass(className): "Type not found " + className;
			case ECustom(msg): msg;
		};
		return (this.fileName != null && this.fileName != "" ? (this.fileName + ":") : "") + this.line + ": " + message;
	}
}

enum ErrorDef {
	EInvalidChar( c : Int );
	EUnexpected( s : String , ? expected : String );
	EUnterminatedString;
	EUnterminatedComment;
	EInvalidPreprocessor( msg : String );
	EUnknownVariable( v : String );
	EInvalidIterator( v : String );
	EInvalidOp( op : Dynamic );
	EInvalidAccess( f : String );
	EInvalidClass( className : String );
	ECustom( msg : String );
}