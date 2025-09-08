package hscript;

import hscript.Expr.VariableType;
import hscript.Lexer.LKeyword;
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

    private inline function parseExpr():Expr {
        return null;
    }

    private inline function parseKeyword(keyword:LKeyword) {
        return switch (keyword) {
            case BREAK: create(EBreak);
            case CONTINUE: create(EContinue);
            case VAR | INLINE | FINAL: 
                var variableName:String = parseIdent(readToken());
                if(maybe(LTColon)) 
                    parseIdent(readToken()); // allow types

                var assign:Expr = null;
                if (maybe(LTOp(ASSIGN)))
                    assign = parseExpr();

                create(EVar(variableID(variableName), assign, false, false));
            default: null;
        }
    }

    private inline function parseIdent(token:LToken):String {
        switch (token) {
            case LTIdentifier(identifier): return identifier;
            default: unexpected(token); return null;
        }
    }

    private inline function variableID(string:String):VariableType {
        var varID:VariableType = variablesList.indexOf(string);
        if (varID == -1) {
            variablesList.push(string);
            return variablesList.length-1;
        } else return varID;
    }

    private inline function create(expr:ExprDef) {
        return {
            expr: expr,
            min: exprMin,
            max: exprMax,
            line: line
        };
    }

    private inline function maybe(expected:LToken):Bool {
        var testToken:LToken = readToken();
        if (!Type.enumEq(expected, testToken)) {
            token--;
            return false;
        } else return true;
    }

    private inline function deepEnsure(expected:LToken) {
        var testToken:LToken = readToken();
        if (!Type.enumEq(expected, testToken)) unexpected(testToken);
    }

    private inline function ensure(expected:LToken) {
        var testToken:LToken = readToken();
        if (expected != testToken) unexpected(testToken);
    }

    private inline function readToken():LToken {
        return tokens[token++].token;
    }

    private inline function unexpected(token:LToken) {
		error(EUnexpected(Std.string(token)), exprMin, exprMax);
	}

    private inline function error(err:ErrorDef, pmin:Int, pmax:Int) {
		throw new Error(err, pmin, pmax, origin, line);
	}
}