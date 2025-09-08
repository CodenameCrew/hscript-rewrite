package hscript;

import hscript.Expr.ExprDef;
import hscript.Lexer.LTokenPos;
import hscript.Error.ErrorDef;
import hscript.Lexer.LToken;

class Parser {
    private var exprMin:Int = 0;
    private var exprMax:Int = 0;
    private var line:Int = 0;

    private var tokens:Array<LTokenPos> = [];
    private var token:Int = 0;

    private var variablesList:Array<String> = [];

    public var origin:String = null;

    public function new(?origin:String) {
        this.origin = origin ?? "";
    }

    private inline function create(expr:ExprDef) {
        return {
            expr: expr,
            min: exprMin,
            max: exprMax,
            line: line
        };
    }

    private inline function maybe(expected:LToken) {
        var testToken:LToken = readToken().token;
        if (!Type.enumEq(expected, testToken)) token--;
    }

    private inline function deepEnsure(expected:LToken) {
        var testToken:LToken = readToken().token;
        if (!Type.enumEq(expected, testToken)) unexpected(testToken);
    }

    private inline function ensure(expected:LToken) {
        var testToken:LToken = readToken().token;
        if (expected != testToken) unexpected(testToken);
    }

    private inline function readToken():LTokenPos {
        return tokens[token++];
    }

    private inline function unexpected(token:LToken) {
		error(EUnexpected(Std.string(token)), exprMin, exprMax);
	}

    private inline function error(err:ErrorDef, pmin:Int, pmax:Int) {
		throw new Error(err, pmin, pmax, origin, line);
	}
}