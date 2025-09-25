package hscript;

import hscript.Expr.ObjectField;
import hscript.Expr.EUnop as ExprUnop;
import hscript.Expr.EBinop as ExprBinop;
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
    private var tokens:Array<LTokenPos> = [];
    private var token:Int = 0;

    private var variablesList:Array<String> = [];
    private var uniqueID:Int = 0;

    public var origin:String = null;
    
    #if HSCRIPT_VERBOSE_PARSER
    private var recursionDepth:Int = 0;
    private var maxRecursionDepth:Int = 0;
    #end

    public function new(?origin:String) {
        this.origin = origin ?? "";
    }

    /**
     * Parses a string into a AST to run in a interperter.
     * @param string input string
     * @return Expr output AST
     */
    public function parseString(string:String):Expr {
        return parse(Lexer.tokenize(string));
    }

    /**
     * Parses a list of tokens into a AST to run in a interperter.
     * @param tokens input tokens 
     * @return Expr output AST
     */
    public function parse(tokens:Array<LTokenPos>):Expr {
        if (tokens == null || tokens.length == 0)
            return create(EInfo(null, create(EBlock([]))));
        
        this.tokens = tokens;

        #if HSCRIPT_VERBOSE_PARSER
        trace('Starting parse with ${tokens.length} tokens');
        recursionDepth = 0;
        maxRecursionDepth = 100;
        #end

        var exprs:Array<Expr> = [];
        while (true) {
            if (peekToken() == LTEof) break;
            parseBlock(exprs);
        }
        return create(EInfo(variablesList, if (exprs.length == 1) exprs[0] else create(EBlock(exprs))));
    }

    private function parseExpr():Expr {
        #if HSCRIPT_VERBOSE_PARSER
        recursionDepth++;
        if (recursionDepth > maxRecursionDepth) {
            maxRecursionDepth = recursionDepth;
            trace('MAX RECURSION DEPTH: $maxRecursionDepth at token $token/${tokens.length} ${readTokenInPlace()}');
            error(ECustom("Stack overflow"));
        }
        trace('parseExpr() depth: $recursionDepth, token: $token/${tokens.length} ${readTokenInPlace()}');
        #end
        
        switch (readToken()) {
            case LTOpenP: 
                if (maybe(LTCloseP)) { // empty args lambda 
                    deepEnsure(LTOp(FUNCTION_ARROW));
                    var expr:Expr = parseExpr();
                    return create(EFunction(null, expr));
                }

                inline function parseLambda(args:Array<Argument>) {
                    var args:Array<Argument> = args;

                    if (maybe(LTComma)) args = parseFunctionArgs(args);
                    else deepEnsure(LTCloseP);

                    deepEnsure(LTOp(FUNCTION_ARROW));

                    var expr:Expr = parseExpr();
                    return create(EFunction(args, expr));
                }
                
                var expr:Expr = parseExpr();
                switch (readToken()) {
                    case LTCloseP: return parseNextExpr(create(EParent(expr)));
                    case LTColon:
                        parseIdent(); // :Type

                        switch (readToken()) {
                            case LTCloseP:
                                reverseToken();
                                switch (expr.expr) {
                                    case EIdent(name): return parseLambda([{name: name}]);
                                    default:
                                }
                            case LTComma: 
                                reverseToken();
                                switch (expr.expr) {
                                    case EIdent(name): return parseLambda([{name: name}]);
                                    default:
                                }
                            default:
                        }
                    case LTComma:
                        reverseToken();
                        switch (expr.expr) {
                            case EIdent(name): return parseLambda([{name: name}]);
                            default:
                        }
                    case LTIdentifier(identifier):
                        if (expr == null) {
                            if (maybe(LTColon)) parseIdent(); // (?arg:Int)
                            return parseLambda([{name: variableID(identifier), opt: true}]);
                        }

                        switch (expr.expr) {
                            case EIdent(name): return parseLambda([{name: name, opt: true}]);
                            default:
                        }
                    case LTEof: return expr;
                    default:
                }

                return unexpected();
            case LTOpenCB: 
                var nextToken:LToken = readTokenInPlace();
                var isObject:Bool = false;

                if (nextToken == LTCloseCB) { // Empty object {}
                    readToken();
                    return parseNextExpr(create(EObject(null)));
                } else if (nextToken.match(LTIdentifier(_))) { // {var:
                    var peekToken:LToken = peekToken();
                    if (peekToken == LTColon) isObject = true;
                } else if (nextToken.match(LTConst(LCString(_)))) { // {"var":
                    var peekToken:LToken = peekToken();
                    if (peekToken == LTColon) isObject = true;
                }

                if (isObject) 
                    return parseObject();
                else { // Parse as code block
                    var exprs:Array<Expr> = [];
                    while (true) {
                        if (peekToken() == LTCloseCB || peekToken() == LTEof) break;
                        parseBlock(exprs);
                    }
                    ensure(LTCloseCB);
                    return create(EBlock(exprs));
                }
            case LTOpenBr: 
                var exprs:Array<Expr> = [];
                while (true) {
                    var expr:Expr = parseExpr();
                    exprs.push(expr);
                    switch (readToken()) {
                        case LTComma:
                        case LTCloseBr: break;
                        default:
                            unexpected();
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
                var unop:ExprUnop = LOp.LEXER_TO_EXPR_UNOP.get(op);
                if (op == SUB) { // Arithmetic Negation -123
                    var expr:Expr = parseExpr();
                    if (expr == null) return parseUnop(unop, expr);

                    return switch (expr.expr) {
                        case EConst(LCInt(int)): create(EConst(LCInt(-int)));
                        case EConst(LCFloat(int)): create(EConst(LCFloat(-int)));
                        default: parseUnop(unop, expr);
                    }
                }

                if (ExprBinop.OP_PRECEDENCE_LOOKUP[cast unop] < 0) return parseUnop(unop, parseExpr());

                return unexpected();
            case LTKeyWord(keyword): return parseNextExpr(parseKeyword(keyword));
            case LTIdentifier(identifier): return parseNextExpr(create(EIdent(variableID(identifier))));
            case LTConst(const): return parseNextExpr(create(EConst(const)));
            case LTMeta(meta):
                var args:Array<Expr> = parseParentheses();
                var expr:Expr = parseExpr();

                return create(EMeta(meta, args, expr));
            case LTQuestion: return null; // (?var) in this case do nothing.
            default: 
                unexpected();
                return null;
        }
    }

    private function parseNextExpr(prev:Expr):Expr {
        #if HSCRIPT_VERBOSE_PARSER
        recursionDepth++;
        trace('parseNextExpr() called at token: $token, prev: ${prev.expr}');
        #end

        switch (readToken()) {
            case LTOp(op):
                #if HSCRIPT_VERBOSE_PARSER
                trace('parseNextExpr LTOp: op $op');
                #end
                var exprOp = LOp.LEXER_TO_EXPR_OP.get(op);
                #if HSCRIPT_VERBOSE_PARSER
                trace('Mapped exprOp: $exprOp');
                #end
                var precedence = ExprBinop.OP_PRECEDENCE_LOOKUP[cast exprOp];
                #if HSCRIPT_VERBOSE_PARSER
                trace('Precedence: $precedence');
                #end

                if (op == FUNCTION_ARROW) { // Single arg reinterpretation of `f -> e` , `(f) -> e`
                    switch (prev.expr) {
                        case EIdent(name), EParent(_.expr => EIdent(name)):
                            var expr:Expr = parseExpr();
                            return create(EFunction(null, expr));
                        default:
                    }

                    unexpected();
                }

                if (precedence == -1) {
                    #if HSCRIPT_VERBOSE_PARSER
                    trace('Precedence is -1, trying unary path');
                    #end
                    var unop = LOp.LEXER_TO_EXPR_UNOP.get(op);
                    #if HSCRIPT_VERBOSE_PARSER
                    trace('Unary op: $unop');
                    #end
                    if (isBlock(prev) || prev.expr.match(EParent(_))) {
                        reverseToken();
                        return prev;
                    }
                    return parseNextExpr(create(EUnop(unop, false, prev)));
                }

                var expr:Expr = parseExpr();
                return parseBinop(LOp.LEXER_TO_EXPR_OP.get(op), prev, expr);
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

    @:haxe.warning("-WUnusedPattern") // get rid of (WUnusedPattern) This case is unused on INLINE case
    private function parseKeyword(keyword:LKeyword) {
        #if HSCRIPT_VERBOSE_PARSER
        trace('parseKeyword($keyword) at token: $token');
        var startToken = token;
        #end
        #if HSCRIPT_VERBOSE_PARSER var res = #else return #end switch (keyword) {
            case VAR | FINAL: 
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
            case ELSE: unexpected(); // Handled in "if" keyword parsing
            case INLINE:
                deepEnsure(LTKeyWord(FUNCTION));
                parseKeyword(FUNCTION);
            case FUNCTION:
                var functionName:String = switch (readToken()) {
                    case LTIdentifier(identifier): identifier;
                    default: reverseToken(); null;
                };

                ensure(LTOpenP);

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
                                    case LTColon: break; // case Condition:
                                    default: unexpected(); break;
                                }
                            }
                            switchCase.expr = getSwitchExprs();
                        case LTKeyWord(DEFAULT):
                            if (expr != null) unexpected();
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
                        default: unexpected();
                    }
                }

                var filteredCases:Array<SwitchCase> = [];
                for (switchCase in cases) {
                    if (switchCase.values.length <= 0) continue;
                    switch (switchCase.expr.expr) {
                        case EBlock([]): continue;
                        default:
                    }
                    filteredCases.push(switchCase);
                }

                create(ESwitch(expr, filteredCases, defaultExpr));
            default: null;
        }

        #if HSCRIPT_VERBOSE_PARSER
        trace('parseKeyword($keyword) finished at token: $token (advanced ${token - startToken} tokens)');
        return res;
        #end
    }

    private function parseIdent():String {
        var token:LToken = readToken();
        switch (token) {
            case LTIdentifier(identifier): return identifier;
            default: unexpected(); return null;
        }
    }

    private function parseClassName():String { // haxe.Unserializer
        var identifiers:Array<String> = [];
        identifiers.push(parseIdent());

        while (true) {
            switch (readToken()) {
                case LTDot: identifiers.push(parseIdent());
                case LTOpenP: break;
                default: unexpected(); break;
            }
        }

        return identifiers.join(".");
    }

    private function parseParentheses():Array<Expr> {
        var args:Array<Expr> = [];
        if (maybe(LTCloseP)) return args;

        while (true) {
			args.push(parseExpr());
			switch (readToken()) {
				case LTComma:
                case LTCloseP: break;
				default: unexpected(); break;
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
    private function parseBinop(op:ExprBinop, left:Expr, right:Expr) {
        #if HSCRIPT_VERBOSE_PARSER
        trace('parseBinop() depth: $recursionDepth, op: $op, token: $token/${tokens.length}');
        trace('leftExpr: $left, rightExpr: $right');
        #end
        if (right == null) return create(EBinop(op, left, right));
        return switch (right.expr) {
            case EBinop(op2, left2, right2):
                var delta:Int = ExprBinop.OP_PRECEDENCE_LOOKUP[cast op] - ExprBinop.OP_PRECEDENCE_LOOKUP[cast op2];
                if (delta < 0 || (delta == 0 || ExprBinop.OP_PRECEDENCE_RIGHT_ASSOCIATION.indexOf(cast op) == -1))
                    create(EBinop(op2, parseBinop(op, left, left2), right2));
                else 
                    create(EBinop(op, left, right));
            case ETernary(cond, thenExpr, elseExpr):
                if (ExprBinop.OP_PRECEDENCE_RIGHT_ASSOCIATION[cast op])
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
    private function parseUnop(unop:ExprUnop, expr:Expr):Expr {
        #if HSCRIPT_VERBOSE_PARSER
        trace('parseUnop() depth: $recursionDepth, unop: $unop, token: $token/${tokens.length}');
        #end
        if (expr == null) return null;

        return switch (expr.expr) {
            case EBinop(op, left, right): create(EBinop(op, parseUnop(unop, left), right));
            case ETernary(cond, thenExpr, elseExpr): create(ETernary(parseUnop(unop, cond), thenExpr, elseExpr));
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
    private function parseArrayComprehensions(temp:VariableType, expr:Expr):Expr {
        if (expr == null) return null;
        
        return switch (expr.expr) {
            case EFor(varName, iterator, body): create(EFor(varName, iterator, parseArrayComprehensions(temp, body)));
            case EForKeyValue(key, value, iterator, body): create(EForKeyValue(key, value, iterator, parseArrayComprehensions(temp, body)));
            case EWhile(cond, body): create(EWhile(cond, parseArrayComprehensions(temp, body)));
            case EDoWhile(cond, body): create(EDoWhile(cond, parseArrayComprehensions(temp, body)));
            case EIf(cond, thenExpr, elseExpr): create(EIf(cond, parseArrayComprehensions(temp, thenExpr), parseArrayComprehensions(temp, elseExpr)));
            case EBlock([expr]): create(EBlock([parseArrayComprehensions(temp, expr)]));
            case EParent(expr): create(EParent(parseArrayComprehensions(temp, expr)));
            default: create(ECall(create(EField(create(EIdent(temp)), "push")), [expr]));
        }
    }

    private function parseFunctionArgs(?args:Array<Argument>):Array<Argument> {
        args ??= [];
        if (maybe(LTCloseP)) return args;
        
        while (true) {
			var argument:Argument = {name: null};

            if (maybe(LTQuestion)) argument.opt = true;
            argument.name = variableID(parseIdent());

            if (maybe(LTColon)) parseIdent(); // var:Type

            if (maybe(LTOp(ASSIGN)))
                argument.value = parseExpr();

            args.push(argument);

            switch (readToken()) {
                case LTComma: 
                case LTCloseP: break;
				default: unexpected(); break;
            }
		}

        return args;
    }

    private function parseObject():Expr {
        var fields:Array<ObjectField> = [];

        while (true) {
            var fieldName:String = null;
            switch (readToken()) {
                case LTIdentifier(identifier): fieldName = identifier;
                case LTConst(const):
                    switch (const) {
                        case LCString(string): fieldName = string;
                        default: unexpected();
                    }
                case LTCloseBr: break;
                default:
                    unexpected();
                    break;
            }
            ensure(LTColon);

            var expr:Expr = parseExpr();
            fields.push({name: fieldName, expr: expr});

            switch (readToken()) {
                case LTCloseBr: break;
                case LTComma:
                default: 
                    unexpected();
                    break;
            }
        }

        return parseNextExpr(create(EObject(fields)));
    }

    private function parseBlock(exprs:Array<Expr>) {
        var expr:Expr = parseExpr();
        if (expr != null) exprs.push(expr);

        var testToken:LToken = readToken();
        if (testToken != LTSemiColon && testToken != LTEof)
            if (isBlock(expr)) reverseToken();
            else expected(LTSemiColon);
    }

    private function variableID(string:String):VariableType {
        if (string == null) return -1;

        var varID:VariableType = variablesList.indexOf(string);
        if (varID == -1) {
            variablesList.push(string);
            return variablesList.length-1;
        } else return varID;
    }

    private function create(expr:ExprDef):Expr {
        return {
            expr: expr,
            line: readLine()
        };
    }

    private function isBlock(expr:Expr):Bool {
		if(expr == null) return false;
		return switch(expr.expr) {
            case EBlock(_), EObject(_), ESwitch(_): true;
            case EFunction(_,expr,_,_): isBlock(expr);
            case EVar(_, expr): expr != null ? isBlock(expr) : false;
            case EIf(_, expr1, expr2): if( expr2 != null ) isBlock(expr2) else isBlock(expr1);
            case EUnop(_, isPrefix, expr): !isPrefix && isBlock(expr);
            case EBinop(_, _, expr): isBlock(expr);
            case EWhile(_, expr): isBlock(expr);
            case EDoWhile(_, expr): isBlock(expr);
            case EFor(_, _, expr): isBlock(expr);
            case EForKeyValue(_, _, expr, _): isBlock(expr);
            case EReturn(expr): expr != null && isBlock(expr);
            case ETry(_, _, expr): isBlock(expr);
            case EMeta(_, _, expr): isBlock(expr);
            default: false;
		}
	}

    private function maybe(expected:LToken):Bool {
        var testToken:LToken = readToken();
        if (!Type.enumEq(expected, testToken)) {
            reverseToken();
            return false;
        } else return true;
    }

    private function deepEnsure(expectedToken:LToken) {
        var testToken:LToken = readToken();
        if (!Type.enumEq(expectedToken, testToken)) expected(expectedToken);
    }

    private function ensure(expectedToken:LToken) {
        var testToken:LToken = readToken();
        if (expectedToken != testToken) expected(expectedToken);
    }

    private inline function readToken():LToken {
        if (token >= tokens.length) return LTEof;
        return tokens[token++].token;
    }

    private inline function readTokenInPlace():LToken {
        if (token - 1 < 0 ||  token - 1 >= tokens.length) return LTEof;
        return tokens[token-1].token;
    }

    private inline function peekToken():LToken {
        if (token >= tokens.length) return LTEof;
        return tokens[token].token;
    }

    private inline function reverseToken() {
        if (token > 0) token--;
        else token = 0;
    }

    private inline function readPosition():LTokenPos {
        if (token - 1 < 0 ||  token - 1 >= tokens.length) return {token: LTEof, min: 0, max: 0, line: 0};
        return tokens[token-1];
    }

    private inline function readLine():Int {
        if (token - 1 < 0 ||  token - 1 >= tokens.length) return 0;
        return tokens[token-1].line;
    }

    private function expected(want:LToken) {
        var currentToken:LTokenPos = readPosition();
		error(EUnexpected(Std.string(currentToken.token), Std.string(want)), currentToken.min, currentToken.max, currentToken.line);
        return null;
	}

    private function unexpected() {
        var currentToken:LTokenPos = readPosition();
		error(EUnexpected(Std.string(currentToken.token)), currentToken.min, currentToken.max, currentToken.line);
        return null;
	}

    private function error(err:ErrorDef, pmin:Int, pmax:Int, line:Int) {
		throw new Error(err, pmin, pmax, origin, line);
	}
}