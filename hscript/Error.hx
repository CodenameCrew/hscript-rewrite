package hscript;

import hscript.Lexer.LToken;
import hscript.Ast.ExprUnop;
import hscript.Ast.ExprBinop;
import haxe.ds.Either;

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
			case EUnexpected(s , expected): (expected != null ? 'Unexpected token: have ${Lexer.tokenToString(s)}, want ${Lexer.tokenToString(expected)}' : 'Unexpected token: ${Lexer.tokenToString(s)}');
			case EUnterminatedString: "Unterminated string";
			case EUnterminatedComment: "Unterminated comment";
			case EInvalidPreprocessor(str): "Invalid preprocessor (" + str + ")";
			case EUnknownVariable(v): "Unknown variable: "+v;
			case EInvalidIterator(v): "Invalid iterator: "+v;
			case EInvalidOp(op): "Invalid operator: " + switch (op) {
				case Left(binop): ExprBinop.EXPR_TO_LEXER_OP.get(binop);
				case Right(unop): ExprUnop.EXPR_TO_LEXER_UNOP.get(unop);
			};
			case EInvalidAccess(f): "Invalid access to field " + f;
			case EInvalidClass(className): "Type not found " + className;
			case ECustom(msg): msg;
		};
		return (this.fileName != null && this.fileName != "" ? (this.fileName + ":") : "") + this.line + ": " + message;
	}
}

enum ErrorDef {
	EInvalidChar( c : Int );
	EUnexpected( s : LToken , ? expected : LToken );
	EUnterminatedString;
	EUnterminatedComment;
	EInvalidPreprocessor( msg : String );
	EUnknownVariable( v : String );
	EInvalidIterator( v : String );
	EInvalidOp( op : Either<ExprBinop, ExprUnop> );
	EInvalidAccess( f : String );
	EInvalidClass( className : String );
	ECustom( msg : String );
}