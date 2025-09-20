package hscript;

import hscript.Expr.EBinop;
import hscript.Lexer.LOp;
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
    private var uniqueID:Int = 0;

    public var origin:String = null;

    public function new(?origin:String) {
        this.origin = origin ?? "";
    }

    private inline function parseExpr():Expr {
        switch (readToken()) {
            case LTOpenP: 
                if (maybe(LTCloseP)) { // empty args lambda 
                    deepEnsure(LTOp(FUNCTION_ARROW));
                    var expr:Expr = parseExpr();
                    return create(EFunction(null, expr));
                }

                inline function parseLambda(args:Array<Argument>) {
                    var args:Array<Argument> = parseFunctionArgs(args);
                    deepEnsure(LTOp(FUNCTION_ARROW));

                    var expr:Expr = parseExpr();
                    return create(EFunction(args, expr));
                }
                
                var expr:Expr = parseExpr();
                switch (readToken()) {
                    case LTCloseP: return parseNextExpr(create(EParent(expr)));
                    case LTColon:
                        parseIdent(); // ):Type

                        switch (readToken()) {
                            case LTCloseP: parseNextExpr(expr);
                            case LTComma: 
                                switch (expr.expr) {
                                    case EIdent(name): return parseLambda([{name: name}]);
                                    default:
                                }
                            default:
                        }
                    case LTComma: 
                        switch (expr.expr) {
                            case EIdent(name): return parseLambda([{name: name}]);
                            default:
                        }
                    default:
                }
            case LTOpenBr: 
                switch (readToken()) {
                    case LTCloseBr: return parseNextExpr(create(EObject(null)));
                    case LTIdentifier(identifier):
                        var peek:LToken = peekToken();

                        reverseToken(); // reverse Peek Token
                        reverseToken(); // reverse LTIdentifier

                        if (peek == LTColon) parseObject();
                    case LTConst(const):
                        switch (const) {
                            case LCString(string):
                                var peek:LToken = peekToken();

                                reverseToken(); // reverse Peek Token
                                reverseToken(); // reverse LTIdentifier
                                
                                if (peek == LTColon) parseObject();
                                reverseToken(); // reverse LTIdentifier
                            default: reverseToken(); // reverse LTConst
                        }
                    default: reverseToken(); // reverse LTOpenBr
                }

                var exprs:Array<Expr> = [];
                while (true) {
                    parseBlock(exprs);
                    if (maybe(LTCloseBr) || maybe(LTEof)) break;
                }
                return create(EBlock(exprs));
            case LTOpenCB: 
                var exprs:Array<Expr> = [];
                while (true) {
                    var expr:Expr = parseExpr();
                    exprs.push(expr);
                    switch (readToken()) {
                        case LTComma:
                        case LTCloseCB: break;
                        default:
                            unexpected(readTokenInPlace());
                            break;
                    }
                }

                if (exprs.length == 1 && exprs[0] != null) {
                    var firstExpr:Expr = exprs[0];
                    switch (firstExpr.expr) {
                        case EFor(_), EForKeyValue(_), EWhile(_), EDoWhile(_):
                            var temporaryVariable:Int = variableID("__a_" + (uniqueID++));
                            var exprBlock:Expr = create(EBlock([
                                create(EVar(temporaryVariable, create(EArrayDecl([])))),
                                parseArrayComprehensions(temporaryVariable, firstExpr),
                                create(EIdent(temporaryVariable))
                            ]));
                            return parseNextExpr(exprBlock);
                        default:
                    }
                }
                return parseNextExpr(create(EArrayDecl(exprs)));
            case LTOp(op):
                if (op == SUB) { // Arithmetic Negation -123
                    var expr:Expr = parseExpr();
                    if (expr == null) return parseUnop(op, expr);

                    return switch (expr.expr) {
                        case EConst(LCInt(int)): create(EConst(LCInt(-int)));
                        case EConst(LCFloat(int)): create(EConst(LCFloat(-int)));
                        default: parseUnop(op, expr);
                    }
                }

                if (LOp.OP_PRECEDENCE_LEFT_LOOKUP.get(op) < 0) return parseUnop(op, parseExpr());

                return unexpected(readTokenInPlace());
            case LTKeyWord(keyword): return parseNextExpr(parseKeyword(keyword));
            case LTIdentifier(identifier): return parseNextExpr(create(EIdent(identifier)));
            case LTConst(const): return parseNextExpr(create(EConst(const)));
            case LTMeta(meta):
                var args:Array<String> = parseParentheses();
                var expr:Expr = parseExpr();

                return create(EMeta(meta, args, expr));
            case LTEof:
            default: 
                unexpected(readTokenInPlace());
                return null;
        }
    }

    private inline function parseNextExpr(prev:Expr):Expr {
        switch (readToken()) {
            case LTOp(op):
                if (op == FUNCTION_ARROW) { // Single arg reinterpretation of `f -> e` , `(f) -> e`
                    switch (prev.expr) {
                        case EIdent(name), EParent(expr.expr => EIdent(name)):
                            var expr:Expr = parseExpr();
                            return EFunction(null, expr);
                        default:
                    }

                    unexpected(readTokenInPlace());
                }

                if (LOp.OP_PRECEDENCE_LOOKUP.get(op) == -1) {
                    if (isBlock(prev) || prev.expr.match(EParent(_))) {
                        reverseToken();
                        return prev;
                    }
                    return parseNextExpr(create(EUnop(op, false, prev)));
                }
                var expr:Expr = parseExpr();
                return parseBinop(op, prev, expr);
            case LTDot | LTQuestionDot:
                var fieldName:String = parseIdent();
                return parseNextExpr(create(EField(prev, fieldName, readTokenInPlace() == LTQuestionDot)));
            case LTOpenP: return parseNextExpr(create(ECall(prev, parseParentheses())));
            case LTOpenBr: // array/map access arr[0]
                var arrayIndex:Expr = parseExpr();
                ensure(LTCloseBr);

                return parseNextExpr(create(EArray(prev, arrayIndex)));
            case LTQuestion: // ternary (a == 5 ? x : y)
                var thenExpr:Expr = parseExpr();
                ensure(LTColon);
                var elseExpr:Expr = parseExpr();
                return create(ETernary(prev, thenExpr, elseExpr));
            default:
                reverseToken();
                return prev;
        }
    }

    private inline function parseKeyword(keyword:LKeyword) {
        return switch (keyword) {
            case VAR | INLINE | FINAL: 
                var variableName:String = parseIdent();
                if (maybe(LTColon)) parseIdent(); // var:Type

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

    /**
     * Make sure the higher the precedence the deeper the expression in the AST.
     * 
     * For example: lets say we are parsing the experssion 2 + 3 * 4
     * 
     * parseBinop(op, left, right)
     * op = +
     * left = 2
     * right = 3 * 4
     * 
     * switch (right)
     * right is a EBinop(op2, _, _)
     * op2 = *
     * 
     * precedence(+) < precedence(*) = restructure
     * Results in: +(2, *(3,4))
     */
    private inline function parseBinop(op:EBinop, left:Expr, right:Expr) {
        if (right == null) return create(EBinop(op, left, right));
        return switch (right.expr) {
            case EBinop(op2, left2, right2):
                var delta:Int = EBinop.OP_PRECEDENCE_LOOKUP[op] - EBinop.OP_PRECEDENCE_LOOKUP[op2];
                if (delta < 0 || (delta == 0 || !EBinop.OP_PRECEDENCE_RIGHT_ASSOCIATION.exists(op)))
                    create(EBinop(op2, parseBinop(op, left, left2), right2));
                else 
                    create(EBinop(op, left, right));
            case ETernary(cond, thenExpr, elseExpr):
                if (EBinop.OP_PRECEDENCE_RIGHT_ASSOCIATION[op])
                    create(EBinop(op, left, right));
                else
                    create(ETernary(parseBinop(op, left, cond), thenExpr, elseExpr));
            default: create(EBinop(op, left, right));
        }
    }

    /**
     * Make sure the unary operator gets attached to the right part of AST.
     * 
     * For example: -a + b; the parser sees - applied to (a + b), but it should acuttaly be (-a) + b by Haxe language rules.
     * Also: !a ? b : c; parser sees !(a ? b : c), ensure it is correct (!a) ? b : c.
     */
    private inline function parseUnop(unop:EUnop, expr:Expr):Expr {
        if (expr == null) return null;

        return switch (expr.expr) {
            case EBinop(op, left, right): create(EBinop(op, parseUnop(unop, left), right));
            case ETernary(cond, thenExpr, elseExpr): create(ETernary(parseUnop(cond), thenExpr, elseExpr));
            default: create(EUnop(unop, true, expr));
        }
    }

    /**
     * Turns a expression (in this case array declaration) into a series of pushes into temp array.
     * 
     * For example: var array:Array = [for (i in 0...8) i * 2];
     * 
     * Gets turned into:
     * var __a_0 = [];
     * for (i in 0...8)
     *     __a_0.push(i * 2);
     * __a_0;
     */
    private inline function parseArrayComprehensions(temp:VariableType, expr:Expr):Expr {
        if (expr == null) return null;
        
        return switch (expr.expr) {
            case EFor(varName, iterator, body): create(EFor(varName, iterator, parseArrayComprehensions(temp, body)));
            case EForKeyValue(key, value, iterator, body): create(EFor(key, value, iterator, parseArrayComprehensions(temp, body)));
            case EWhile(cond, body): create(EWhile(cond, parseArrayComprehensions(temp, body)));
            case EDoWhile(cond, body): create(EDoWhile(cond, parseArrayComprehensions(temp, body)));
            case EIf(cond, thenExpr, elseExpr): create(EIf(cond, parseArrayComprehensions(temp, thenExpr), parseArrayComprehensions(temp, elseExpr)));
            case EBlock([expr]): create(EBlock([parseArrayComprehensions(temp, expr)]));
            case EParent(expr): create(EParent(parseArrayComprehensions(temp, expr)));
            default: create(ECall(create(EField(create(EIdent(temp)), "push")), [expr]));
        }
    }

    private inline function parseFunctionArgs(?args:Array<Argument>):Array<Argument> {
        args ??= [];
        if (maybe(LTCloseP)) return args;

        while (true) {
			var argument:Argument = {name: null};

            argument.opt = maybe(LTQuestion);
            argument.name = parseIdent();

            if (maybe(LTColon)) parseIdent(); // var:Type

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

    private inline function parseObject():Expr {
        var fields:Array<ObjectField> = [];

        while (true) {
            var fieldName:String = null;
            switch (readToken()) {
                case LTIdentifier(identifier): fieldName = identifier;
                case LTConst(const):
                    switch (const) {
                        case LCString(string): fieldName = identifier;
                        default: unexpected(readTokenInPlace());
                    }
                case LTCloseBr: break;
                default:
                    unexpected(readTokenInPlace());
                    break;
            }
            ensure(LTColon);

            var expr:Expr = parseExpr();
            fields.push({name: fieldName, expr: expr});

            switch (readToken()) {
                case LTCloseBr: break;
                case LTComma:
                default: 
                    unexpected(readTokenInPlace());
                    break;
            }
        }

        return parseNextExpr(create(EObject(fields)));
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