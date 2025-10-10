package hscript;

import hscript.Interp.StaticInterp;
import haxe.ds.StringMap;
import hscript.Ast.Expr;
import hscript.Ast.EImportMode;
import hscript.Ast.ObjectField;
import hscript.Ast.ExprUnop;
import hscript.Ast.ExprBinop;
import hscript.Lexer.LexerOp;
import hscript.Ast.SwitchCase;
import hscript.Ast.Argument;
import hscript.Ast.VariableType;
import hscript.Lexer.LKeyword;
import hscript.Ast.ExprDef;
import hscript.Lexer.LTokenPos;
import hscript.Error.ErrorDef;
import hscript.Lexer.LToken;

class Parser {
    private var tokens:Array<LTokenPos> = [];
    private var token:Int = 0;

    private var variablesList:Array<String> = [];
    private var uniqueID:Int = 0;

    private var publicModifier:Bool = false;
    private var staticModifier:Bool = false;

    public var fileName:String = null;
    public var preprocesorValues:StringMap<Dynamic> = new StringMap<Dynamic>();
    
    public function new(?fileName:String) {
        this.fileName = fileName ?? "";
        loadBaseVariables();
    }

    public function reset() {
        tokens.resize(0);
        token = 0;

        variablesList.resize(0);
        uniqueID = 0;

        publicModifier = false;
        staticModifier = false;

        preprocesorValues.clear();
        loadBaseVariables();
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

        var exprs:Array<Expr> = [];
        while (true) {
            if (peekToken() == LTEof) break;
            parseBlock(exprs);
        }
        return create(EInfo(variablesList, if (exprs.length == 1) exprs[0] else create(EBlock(exprs))));
    }

    private function loadBaseVariables() {
        preprocesorValues.set("true", true);
        preprocesorValues.set("false", false);
    }

    private function parseExpr():Expr {
        switch (readToken()) {
            case LTPrepro(prepro): return parseNextExpr(parsePreprocess(prepro)); // #if 
            case LTOpenP:
                if (maybe(LTCloseP)) { // empty args lambda () -> {}
                    deepEnsure(LTOp(FUNCTION_ARROW));
                    var expr:Expr = parseExpr();
                    return create(EFunction([], expr, null, false, false));
                }

                inline function parseLambda(args:Array<Argument>) {
                    var args:Array<Argument> = args;

                    if (maybe(LTComma)) args = parseFunctionArgs(args);
                    else deepEnsure(LTCloseP);

                    deepEnsure(LTOp(FUNCTION_ARROW));

                    var expr:Expr = parseExpr();
                    return create(EFunction(args, expr, null, false, false));
                }
                
                var expr:Expr = parseExpr();
                switch (readToken()) {
                    case LTCloseP: return parseNextExpr(create(EParent(expr)));
                    case LTColon:
                        parseType(); // :Type

                        switch (readToken()) {
                            case LTCloseP:
                                reverseToken();
                                switch (expr.expr) {
                                    case EIdent(name): return parseLambda([new Argument(name)]);
                                    default:
                                }
                            case LTComma: 
                                reverseToken();
                                switch (expr.expr) {
                                    case EIdent(name): return parseLambda([new Argument(name)]);
                                    default:
                                }
                            default:
                        }
                    case LTComma:
                        reverseToken();
                        switch (expr.expr) {
                            case EIdent(name): return parseLambda([new Argument(name)]);
                            default:
                        }
                    case LTIdentifier(identifier):
                        if (expr == null) {
                            if (maybe(LTColon)) parseType(); // (?arg:Int)
                            return parseLambda([new Argument(variableID(identifier), true)]);
                        }

                        switch (expr.expr) {
                            case EIdent(name): return parseLambda([new Argument(name, true)]);
                            default:
                        }
                    case LTEof: return expr;
                    default:
                }

                return unexpected();
            case LTOpenCB: 
                var nextToken:LToken = readToken();
                var isObject:Bool = false;

                switch (nextToken) {
                    case LTCloseCB: return parseNextExpr(create(EObject(null))); // {} empty oject
                    case LTIdentifier(_) | LTConst(LCString(_)): // {var: AND {"var":
                        var peekToken:LToken = peekToken();
                        if (peekToken == LTColon) isObject = true;
                        reverseToken(); // revert var
                    default: reverseToken();
                }

                if (isObject) return parseObject();
                else { // parse as code block
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
                if (maybe(LTCloseBr)) // empty array []
                    return parseNextExpr(create(EArrayDecl([])));

                var testExpr:Expr = parseExpr(); // query if the [ is a map with =>

                var mapDeclaration:Bool = false;
                var values:Array<Expr> = [];

                switch (testExpr.expr) {
                    case EBinop(ARROW, left, right): 
                        mapDeclaration = true;
                        exprs.push(left);
                        values.push(right);
                    default: 
                        exprs.push(testExpr); 
                }

                switch (readToken()) {
                    case LTCloseBr:
                    case LTComma:
                        while (true) {
                            if (maybe(LTCloseBr)) break;

                            var expr:Expr = parseExpr();
                            switch (expr.expr) {
                                case EBinop(ARROW, left, right) if (mapDeclaration):
                                    exprs.push(left);
                                    values.push(right);
                                default:
                                    if (mapDeclaration) expected(LTOp(ARROW));
                                    else exprs.push(expr);
                            }

                            switch (readToken()) {
                                case LTComma:
                                case LTCloseBr: break;
                                default: unexpected(); break;
                            }
                        }
                    default: unexpected();
                }

                if (exprs.length == 1 && exprs[0] != null) {
                    var firstExpr:Expr = exprs[0];
                    switch (firstExpr.expr) {
                        case EFor(_), EForKeyValue(_), EWhile(_), EDoWhile(_):
                            var temporaryVariable:Int = variableID("__a_" + (uniqueID++));
                            var exprBlock:Expr = if (isMapComprehension(firstExpr)) {
                                create(EBlock([
                                    create(EVar(temporaryVariable, create(EMapDecl([], [])))),
                                    parseMapComprehensions(temporaryVariable, firstExpr),
                                    create(EIdent(temporaryVariable))
                                ]));
                            } else {
                                create(EBlock([
                                    create(EVar(temporaryVariable, create(EArrayDecl([])))),
                                    parseArrayComprehensions(temporaryVariable, firstExpr),
                                    create(EIdent(temporaryVariable))
                                ]));
                            }
                            return parseNextExpr(exprBlock);
                        default:
                    }
                }
                return parseNextExpr(mapDeclaration ? create(EMapDecl(exprs, values)) : create(EArrayDecl(exprs)));
            case LTOp(op):
                if (LexerOp.LEXER_TO_EXPR_UNOP.exists(op)) { // Parse unops (!, -, ~, ++, --)
                    var unop:ExprUnop = LexerOp.LEXER_TO_EXPR_UNOP.get(op);
                    if (op == SUB) { // Arithmetic Negation -123
                        var expr:Expr = parseExpr();
                        if (expr == null) return parseUnop(unop, expr);

                        return switch (expr.expr) {
                            case EConst(LCInt(int)): create(EConst(LCInt(-int)));
                            case EConst(LCFloat(int)): create(EConst(LCFloat(-int)));
                            default: parseUnop(unop, expr);
                        }
                    }
                    return parseUnop(unop, parseExpr());
                }
                return unexpected();
            case LTKeyWord(keyword): return parseNextExpr(parseKeyword(keyword));
            case LTIdentifier(identifier): return parseNextExpr(create(EIdent(variableID(identifier))));
            case LTConst(const): return parseNextExpr(create(EConst(const)));
            case LTMeta(meta):
                var args:Array<Expr> = null;
                if (maybe(LTOpenP)) args = parseParentheses();

                var expr:Expr = parseExpr();

                return create(EMeta(meta, args, expr));
            case LTQuestion: return null; // (?var) in this case do nothing.
            default: 
                unexpected();
                return null;
        }
    }

    private function parseNextExpr(prev:Expr):Expr {
        switch (readToken()) {
            case LTOp(op):
                if (op == FUNCTION_ARROW) { // single arg reinterpretation of `f -> e` , `(f) -> e`
                    switch (prev.expr) {
                        case EIdent(name), EParent(_.expr => EIdent(name)):
                            var expr:Expr = parseExpr();
                            return create(EFunction([], expr, null, false, false));
                        default: unexpected();
                    }
                }

                if (op == LexerOp.INCREMENT || op == LexerOp.DECREMENT) {
                    if (isBlock(prev) || prev.expr.match(EParent(_))) {
                        reverseToken(); // dont attach unary!!! 
                        return prev;
                    }
                    return parseNextExpr(create(EUnop(LexerOp.LEXER_TO_EXPR_UNOP.get(op), false, prev)));
                }

                var expr:Expr = parseExpr();
                return parseBinop(LexerOp.LEXER_TO_EXPR_OP.get(op), prev, expr);
            case LTDot | LTQuestionDot:
                var fieldName:String = switch (readToken()) {
                    case LTIdentifier(identifier): identifier;
                    case LTKeyWord(keyword): cast keyword;
                    default: unexpected();
                };
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
        return switch (keyword) {
            case VAR | FINAL: 
                var variableName:String = parseIdent();
                if (maybe(LTColon)) parseType(); // var:Type

                var assign:Expr = null; // var = ;
                if (maybe(LTOp(ASSIGN))) assign = parseExpr();

                create(EVar(variableID(variableName), assign, publicModifier, staticModifier));
            case IF:
                ensure(LTOpenP);
                var condition:Expr = parseExpr();
                ensure(LTCloseP);

                var expr:Expr = parseExpr();
                var elseExpr:Expr = null;

                var semic:Bool = maybe(LTSemiColon);
                if (maybe(LTKeyWord(ELSE)))
                    elseExpr = parseExpr();
                else if (semic) reverseToken();

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
                    case LTKeyWord(keyword): cast keyword;
                    default: reverseToken(); null;
                };

                ensure(LTOpenP);

                var args:Array<Argument> = parseFunctionArgs();
                if(maybe(LTColon)) parseType(); // function ():Type

                var expr:Expr = parseExpr();
                create(EFunction(args, expr, variableID(functionName), publicModifier, staticModifier));
            case RETURN:
                create(EReturn(peekToken() == LTSemiColon ? null : parseExpr()));
            case NEW:
                var className:String = parseClassName();
                var args:Array<Expr> = parseParentheses();

                create(ENew(variableID(className), args));
            case TRY:
                var expr:Expr = parseExpr();
                var varName:String = null;
                var catchExpr:Expr = null;

                if (maybe(LTKeyWord(CATCH))) {
                    ensure(LTOpenP);

                    varName = parseIdent();
                    if(maybe(LTColon)) parseType(); // e:Error

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
                    switch ([readToken(), peekToken()]) {
                        case [LTKeyWord(DEFAULT), _] | [LTKeyWord(CASE), LTIdentifier("_")]:
                            if (defaultExpr != null) unexpected();
                            if (peekToken().match(LTIdentifier(_))) parseIdent();
                            ensure(LTColon);

                            defaultExpr = getSwitchExprs();
                        case [LTKeyWord(CASE), _]:
                            var switchCase:SwitchCase = new SwitchCase([], null);
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
                        case [LTCloseCB, _]: break;
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
            case STATIC: 
                staticModifier = true;
                var modifierExpr:Expr = switch (readToken()) {
                    case LTKeyWord(PUBLIC): parseKeyword(PUBLIC);
                    case LTKeyWord(FUNCTION): parseKeyword(FUNCTION);
                    case LTKeyWord(OVERRIDE): parseKeyword(OVERRIDE);
                    case LTKeyWord(VAR): parseKeyword(VAR);
                    case LTKeyWord(FINAL): parseKeyword(FINAL);
                    default: unexpected();
                }
                staticModifier = false;
                modifierExpr;
            case PUBLIC: 
                publicModifier = true;
                var modifierExpr:Expr = switch (readToken()) {
                    case LTKeyWord(STATIC): parseKeyword(STATIC);
                    case LTKeyWord(FUNCTION): parseKeyword(FUNCTION);
                    case LTKeyWord(OVERRIDE): parseKeyword(OVERRIDE);
                    case LTKeyWord(VAR): parseKeyword(VAR);
                    case LTKeyWord(FINAL): parseKeyword(FINAL);
                    default: unexpected();
                }
                publicModifier = false;
                modifierExpr;
            case OVERRIDE:
                switch (readToken()) {
                    case LTKeyWord(PUBLIC): parseKeyword(STATIC);
                    case LTKeyWord(STATIC): parseKeyword(STATIC);
                    case LTKeyWord(FUNCTION): parseKeyword(FUNCTION);
                    case LTKeyWord(VAR): parseKeyword(VAR);
                    case LTKeyWord(FINAL): parseKeyword(FINAL);
                    default: unexpected();
                }
            case IMPORT:
                var mode:EImportMode = Normal;
                var identifiers:Array<String> = [];
                identifiers.push(parseIdent());

                while (true) {
                    switch (readToken()) {
                        case LTKeyWord(AS): 
                            var name:String = parseIdent();
                            mode = As(name);
                        case LTSemiColon: 
                            reverseToken();
                            break;
                        case LTDot: 
                            switch (readToken()) {
                                case LTIdentifier(identifier): identifiers.push(identifier);
                                case LTOp(MULT): mode = All;
                                default: unexpected(); break;
                            }
                        default: unexpected(); break;
                    }
                }

                create(EImport(identifiers.join("."), mode));
            case THROW: create(EThrow(parseExpr()));
            default: 
                // parse keywords like null and static as variables because they are used like that sometimes -lunar
                create(EIdent(variableID(cast keyword)));
        }
    }

    private function parseIdent():String {
        var token:LToken = readToken();
        switch (token) {
            case LTIdentifier(identifier): return identifier;
            default: unexpected(); return null;
        }
    }

    private function parseType():String {
        switch (readToken()) {
            case LTIdentifier(identifier):
                if (maybe(LTOp(LT))) parseClassArgs(); // Type<Arg1, Arg2>
                if (maybe(LTOp(FUNCTION_ARROW))) identifier += FUNCTION_ARROW + parseType(); // Type->Void
                return identifier;
            case LTOpenCB:
                while (true) {
                    switch (readToken()) {
                        case LTIdentifier(identifier):
                            ensure(LTColon);
                            parseType();
                        case LTComma:
                        case LTCloseCB: break;
                        default: unexpected(); break;
                    }
                }
                return null;
            default:
                unexpected();
                reverseToken();
                return null;
        }
    }

    private function parseClassName():String { // haxe.Unserializer
        var identifiers:Array<String> = [];
        identifiers.push(parseIdent());

        while (true) {
            switch (readToken()) {
                case LTDot: identifiers.push(parseIdent());
                case LTOp(LT): parseClassArgs(); // Class args
                case LTOpenP: break;
                default: unexpected(); break;
            }
        }

        return identifiers.join(".");
    }

    private inline function parseClassArgs() {
        while (true) { // Class<Arg1, Arg2>
            switch (readToken()) {
                case LTIdentifier(_) | LTComma: // do nothing
                case LTOp(GT): break; // >
                default: expected(LTOp(GT));
            }
        }
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

    private function parsePreprocess(id:String):Expr {
        switch (id) {
            case "if":
                var exprs:Array<Expr> = [];
                parsePreprocessBlock(exprs, parsePreprocessCond());
                return create(EBlock(exprs));
            case "else" | "elseif" | "end": error(EInvalidPreprocessor("Invalid #" + id));
            case "error": error(ECustom(getPreprocessError()));
            default: error(EInvalidPreprocessor("Unknown preprocessor #" + id));
        }
        return null;
    }

    private function parsePreprocessBlock(exprs:Array<Expr>, active:Bool) {
        var oldVariablesListSize:Int = variablesList.length; // same as parsePreprocessCond
        while (true) {
            switch (readToken()) {
                case LTPrepro("else"): parsePreprocessBlock(exprs, !active); break;
                case LTPrepro("elseif"): parsePreprocessBlock(exprs, parsePreprocessCond(active)); break;
                case LTPrepro("end"): break;
                case LTEof: error(EInvalidPreprocessor("Unclosed preprocessor")); break;
                default: 
                    reverseToken(); // reverse test token
                    parseBlock(active ? exprs : null);
            }
        }
        if (!active) variablesList.resize(oldVariablesListSize);
    }

    /**
     * Get rid of staticly evaluated varaibles after they have been analyzed.
     * 
     * For example:
     * 
     * variablesList: []
     * oldVariablesListSize: 0
     * 
     * #if DUSTIN_BUILD
     * 
     * variablesList: [DUSTIN_BUILD]
     * variablesListSize: 1
     * 
     * we should not keep this since it is not used at runtime,
     * so we resize the array to remove excess.
     */
    private function parsePreprocessCond(nullify:Bool = false):Bool {
        var oldVariablesListSize:Int = variablesList.length;

        var condition:Expr = parseExpr();
        var evaluation:Bool = !nullify && evalPreprocessCond(condition);

        variablesList.resize(oldVariablesListSize);

        return evaluation;
    }

    private function getPreprocessError():String {
        var oldVariablesListSize:Int = variablesList.length;
        variablesList.resize(oldVariablesListSize);

        return switch (readToken()) {
            case LTConst(const):
                switch (const) {
                    case LCString(string): string;
                    default:
                        reverseToken();
                        "Not implemented for current platform";
                }
            default:
                reverseToken();
                "Not implemented for current platform";
        };
    }

    /**
     * Staticly evaluate a preprocess condition using values from preprocesorValues.
     * 
     * For example: 
     * 
     * #if cpp
     * #if (cpp && HXCPP_DEBUG_LINK)
     * #if (haxe_ver >= 4)
     */
    private function evalPreprocessCond(expr:Expr):Dynamic {
        return switch (expr.expr) {
            case EIdent(name): preprocesorValues.get(variablesList[name]);
            case EConst(const): StaticInterp.evaluateConst(const);
            case EParent(expr): evalPreprocessCond(expr);
            case EBinop(op, left, right): StaticInterp.evaluateBinop(op, evalPreprocessCond(left), evalPreprocessCond(right));
            default: false;
        }
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
        if (right == null) return create(EBinop(op, left, right));
        return switch (right.expr) {
            case EBinop(op2, left2, right2):
                if (ExprBinop.OP_PRECEDENCE_LOOKUP[cast op] < ExprBinop.OP_PRECEDENCE_LOOKUP[cast op2] && !ExprBinop.OP_PRECEDENCE_RIGHT_ASSOCIATION[cast op])
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

    /**
     * Turns a expression (in this case map declaration) into a series of sets into temp map.
     * 
     * For example: var map:Map<String, Int> = [for (i in 0...8) Std.string(i) => i];
     * 
     * Gets turned into:
     * var __a_0 = [];
     * for (i in 0...8)
     *     __a_0.set(Std.string(i), i);
     * __a_0;
     */
    private function parseMapComprehensions(temp:VariableType, expr:Expr):Expr {
        if (expr == null) return null;
        
        return switch (expr.expr) {
            case EFor(varName, iterator, body): create(EFor(varName, iterator, parseMapComprehensions(temp, body)));
            case EForKeyValue(key, value, iterator, body): create(EForKeyValue(key, value, iterator, parseMapComprehensions(temp, body)));
            case EWhile(cond, body): create(EWhile(cond, parseMapComprehensions(temp, body)));
            case EDoWhile(cond, body): create(EDoWhile(cond, parseMapComprehensions(temp, body)));
            case EIf(cond, thenExpr, elseExpr): create(EIf(cond, parseMapComprehensions(temp, thenExpr), parseMapComprehensions(temp, elseExpr)));
            case EBlock([expr]): create(EBlock([parseMapComprehensions(temp, expr)]));
            case EParent(expr): create(EParent(parseMapComprehensions(temp, expr)));
            default: 
                switch (expr.expr) {
                    case EBinop(ARROW, left, right):
                        create(ECall(create(EField(create(EIdent(temp)), "set")), [left, right]));
                    default:
                        create(ECall(create(EField(create(EIdent(temp)), "set")), [expr, create(EIdent(variableID("null")))]));
                }
        }
    }

    private function isMapComprehension(expr:Expr):Bool {
        if (expr == null) return false;

        return switch (expr.expr) {
            case EFor(varName, iterator, body): isMapComprehension(body);
            case EForKeyValue(key, value, iterator, body): isMapComprehension(body);
            case EWhile(cond, body): isMapComprehension(body);
            case EDoWhile(cond, body): isMapComprehension(body);
            case EIf(cond, thenExpr, elseExpr) if (elseExpr == null): isMapComprehension(thenExpr);
            case EIf(cond, thenExpr, elseExpr) if (elseExpr != null): isMapComprehension(thenExpr) && isMapComprehension(elseExpr);
            case EBlock([expr]): isMapComprehension(expr);
            case EParent(expr): isMapComprehension(expr);
            case EBinop(ARROW, left, right): true;
            default: false;
        }
    }

    private function parseFunctionArgs(?args:Array<Argument>):Array<Argument> {
        args ??= [];
        if (maybe(LTCloseP)) return args;
        
        while (true) {
			var argument:Argument = new Argument(null);

            if (maybe(LTQuestion)) argument.opt = true;
            argument.name = variableID(parseIdent());

            if (maybe(LTColon)) parseType(); // var:Type

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
                default:
                    unexpected();
                    break;
            }
            ensure(LTColon);

            var expr:Expr = parseExpr();
            fields.push(new ObjectField(fieldName, expr));

            switch (readToken()) {
                case LTCloseCB: break;
                case LTComma:
                    if (readToken() == LTCloseCB) break;
                    else reverseToken();
                default: 
                    unexpected();
                    break;
            }
        }

        return parseNextExpr(create(EObject(fields)));
    }

    private function parseBlock(exprs:Array<Expr>) {
        var expr:Expr = parseExpr();
        if (exprs != null && expr != null) exprs.push(expr);

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
        return new Expr(expr, readLine());
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
		error(EUnexpected(Std.string(readTokenInPlace()), Std.string(want)));
        return null;
	}

    private function unexpected():Null<Dynamic> {
		error(EUnexpected(Std.string(readTokenInPlace())));
        return null;
	}

    private function error(err:ErrorDef) {
        var currentToken:LTokenPos = readPosition();
		throw new Error(err, currentToken.min, currentToken.max, fileName, currentToken.line+1);
	}
}