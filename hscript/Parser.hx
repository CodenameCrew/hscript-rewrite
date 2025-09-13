package hscript;

import hscript.Expr.SwitchCase;
import hscript.Expr.Argument;
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
        switch (readToken()) {
            case LTOpenP: parseParentheses();
            case LTCloseP: 
            case LTOpenBr:
            case LTCloseBr:
            case LTOpenCB:
            case LTCloseCB:
            case LTComma:
            case LTDot:
            case LTColon:
            case LTSemiColon:
            case LTQuestion:
            case LTOp(op):
            case LTKeyWord(keyword):
            case LTIdentifier(identifier):
            case LTConst(const):
            case LTMeta(meta):
            case LTPrepro(prepro):
            case LTEof:
        }
    }

    private inline function parseNextExpr(prev:Expr):Expr {

    }

    private inline function parseKeyword(keyword:LKeyword) {
        return switch (keyword) {
            case VAR | INLINE | FINAL: 
                var variableName:String = parseIdent();
                if(maybe(LTColon)) parseIdent(); // var:Type

                var assign:Expr = null; // var = ;
                if (maybe(LTOp(ASSIGN))) assign = parseExpr();

                create(EVar(variableID(variableName), assign, false, false));
            case IF:
                ensure(LTOpenP);
                var condition:Expr = parseExpr();
                ensure(LTCloseP);

                var expr:Expr = parseExpr();

                var elseExpr:Expr = null;
                if (maybe(LTKeyWord(ELSE)))
                    elseExpr = parseExpr();

                create(EIf(condition, expr, elseExpr));
            case WHILE:
                var condition:Expr = parseExpr();
                var expr:Expr = parseExpr();

                create(EWhile(condition, expr));
            case DO:
                var expr:Expr = parseExpr();
                deepEnsure(LTKeyWord(WHILE));
                var condition:Expr = parseExpr();

                create(EDoWhile(condition, expr));
            case FOR:
                ensure(LTOpenP);

                var key:String = parseIdent();
                var value:String = null;
                if (maybe(LTOp(ARROW))) 
                    value = parseIdent();

                deepEnsure(LTKeyWord(IN));

                var iterator:Expr = parseExpr();

                ensure(LTCloseP);

                var expr:Expr = parseExpr();
                if (value != null) 
                    create(EForKeyValue(variableID(key), variableID(value), iterator, expr));
                else 
                    create(EFor(variableID(key), iterator, expr));
            case BREAK: create(EBreak);
            case CONTINUE: create(EContinue);
            case ELSE: unexpected(LTKeyWord(keyword)); // Handled in "if" keyword parsing
            case INLINE:
                deepEnsure(LTKeyWord(FUNCTION));
                parseKeyword(FUNCTION);
            case FUNCTION:
                var functionName:String = switch (readToken()) {
                    case LTIdentifier(identifier): identifier;
                    default: reverseToken(); null;
                };

                var args:Array<Argument> = parseFunctionArgs();
                if(maybe(LTColon)) parseIdent(); // function ():Type

                var expr:Expr = parseExpr();
                create(EFunction(args, expr, variableID(functionName), false, false, false));
            case RETURN:
                create(EReturn(maybe(LTSemiColon) ? null : parseExpr()));
            case NEW:
                var className:String = parseClassName();
                var args:Array<Expr> = parseParentheses();

                create(ENew(variableID(className), args));
            case THROW:
                create(EThrow(parseExpr()));
            case TRY:
                var expr:Expr = parseExpr();
                var varName:String = null;
                var catchExpr:Expr = null;

                if (maybe(LTKeyWord(CATCH))) {
                    ensure(LTOpenP);

                    varName = parseIdent();
                    if(maybe(LTColon)) parseIdent(); // e:Error

                    ensure(LTCloseP);
                    catchExpr = parseExpr();
                }

                create(ETry(expr, variableID(varName), catchExpr));
            case SWITCH:
                var expr:Expr = parseExpr();
                var cases:Array<SwitchCase> = [];
                var defaultExpr:Expr = null;

                inline function getSwitchExprs():Expr {
                    var exprs:Array<Expr> = [];
                    while (true) {
                        switch (peekToken()) {
                            case LTKeyWord(CASE), LTKeyWord(DEFAULT), LTCloseCB: break;
                            case LTEof: break;
                            default: parseBlock(exprs);
                        }
                    }  
                    return (exprs.length == 1) ? exprs[0] : create(EBlock(exprs));
                }

                ensure(LTOpenCB);

                while (true) {
                    switch (readToken()) {
                        case LTKeyWord(CASE):
                            var switchCase:SwitchCase = {values: [], expr: null};
                            cases.push(switchCase);

                            while (true) {
                                var value:Expr = parseExpr();
                                switchCase.values.push(value);

                                switch (readToken()) {
                                    case LTComma: // Condition1 , Condition2 
                                    case LTColon: // case Condition:
                                    default: unexpected(readTokenInPlace()); break;
                                }
                            }
                            switchCase.expr = getSwitchExprs();
                        case LTKeyWord(DEFAULT):
                            if (expr != null) unexpected(readTokenInPlace());
                            ensure(LTColon);
                            
                            var exprs:Array<Expr> = [];
                            while (true) {
                                switch (peekToken()) {
                                    case LTKeyWord(CASE), LTKeyWord(DEFAULT), LTCloseCB: break;
                                    case LTEof: break;
                                    default: parseBlock(exprs);
                                }
                            }
                            defaultExpr = getSwitchExprs();
                        case LTCloseCB: break;
                        default: unexpected(readTokenInPlace());
                    }
                }

                create(ESwitch(expr, cases, defaultExpr));
            default: null;
        }
    }

    private inline function parseIdent():String {
        var token:LToken = readToken();
        switch (token) {
            case LTIdentifier(identifier): return identifier;
            default: unexpected(token); return null;
        }
    }

    private inline function parseClassName():String { // haxe.Unserializer
        var identifiers:Array<String> = [];
        identifiers.push(parseIdent());

        while (true) {
            switch (readToken()) {
                case LTDot: identifiers.push(parseIdent());
                case LTOpenP: break;
                default: unexpected(readTokenInPlace()); break;
            }
        }

        return identifiers.join(".");
    }

    private inline function parseParentheses():Array<Expr> {
        var args:Array<Expr> = [];
        if (maybe(LTCloseP)) return args;

        while (true) {
			args.push(parseExpr());
			switch (readToken()) {
				case LTComma:
                case LTCloseP: break;
				default: unexpected(readTokenInPlace()); break;
			}
		}

        return args;
    }

    private inline function parseFunctionArgs():Array<Argument> {
        var args:Array<Argument> = [];
        if (maybe(LTCloseP)) return args;

        while (true) {
			var argument:Argument = {name: null};

            argument.opt = maybe(LTQuestion);
            argument.name = parseIdent();
            if (maybe(LTOp(ASSIGN)))
                argument.value = parseExpr();

            args.push(argument);

            switch (readToken()) {
                case LTComma: 
                case LTCloseP: break;
				default: unexpected(readTokenInPlace()); break;
            }
		}

        return args;
    }

    private inline function parseBlock(exprs:Array<Expr>) {
        var expr:Expr = parseExpr();
        exprs.push(expr);

        if (isBlock(expr)) 
            switch (peekToken()) {
                case LTSemiColon | LTEof: readToken();
                default: unexpected(peekToken());
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

    private inline function isBlock(expr:Expr):Bool {
		if(expr == null) return false;
		return switch(expr.expr) {
            case EBlock(_), EObject(_), ESwitch(_): true;
            case EFunction(_,expr,_,_): isBlock(expr);
            case EVar(_, expr): expr != null ? isBlock(expr) : false;
            case EIf(_, expr1, expr2): if( expr2 != null ) isBlock(expr2) else isBlock(expr1);
            case EBinop(_, _, expr): isBlock(expr);
            case EWhile(_, expr): isBlock(expr);
            case EDoWhile(_, expr): isBlock(expr);
            case EFor(_, _, expr): isBlock(expr);
            case EReturn(expr): expr != null && isBlock(expr);
            case ETry(_, _, expr): isBlock(expr);
            case EMeta(_, _, expr): isBlock(expr);
            default: false;
		}
	}

    private inline function maybe(expected:LToken):Bool {
        var testToken:LToken = readToken();
        if (!Type.enumEq(expected, testToken)) {
            reverseToken();
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

    private inline function readTokenInPlace():LToken {
        return tokens[token].token;
    }

    private inline function peekToken():LToken {
        var token:LToken = readToken();
        reverseToken();
        return token;
    }

    private inline function reverseToken() {token--;}

    private inline function unexpected(token:LToken) {
		error(EUnexpected(Std.string(token)), exprMin, exprMax);
        return null;
	}

    private inline function error(err:ErrorDef, pmin:Int, pmax:Int) {
		throw new Error(err, pmin, pmax, origin, line);
	}
}