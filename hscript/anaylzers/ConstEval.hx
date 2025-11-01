package hscript.anaylzers;

import hscript.Ast.VariableInfo;
import hscript.Ast.SwitchCase;
import hscript.Ast.ObjectField;
import hscript.Ast.Argument;
import hscript.Lexer.LConst;
import hscript.Interp.StaticInterp;
import hscript.Ast.Expr;
import hscript.Ast.ExprDef;

using hscript.utils.ExprUtils;
using hscript.Ast.ExprBinop;

class ConstEval {
    public static function eval(expr:Expr, vars:VariableInfo = null):Expr {
        return new Expr(switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): EVar(name, if (init != null) eval(init, vars) else null, isPublic, isStatic);
            case EParent(expr): eval(expr, vars).expr;
            case EBlock(exprs): EBlock([for (expr in exprs) eval(expr, vars)].filter((expr:Expr) -> {return expr != null;}));
            case EWhile(cond, body): EWhile(eval(cond, vars), eval(body, vars));
            case EFor(varName, iterator, body): EFor(varName, eval(iterator, vars), eval(body, vars));
            case EForKeyValue(key, value, iterator, body): EForKeyValue(key, value, eval(iterator, vars), eval(body, vars));
            case EFunction(args, body, name, isPublic, isStatic): EFunction([
                for (arg in args) if (arg.value != null) new Argument(arg.name, arg.opt, eval(arg.value, vars)) else arg
            ], eval(body, vars), name, isPublic, isStatic);
            case EReturn(expr): EReturn(if (expr != null) eval(expr, vars) else null);
            case EArray(expr, index): EArray(eval(expr, vars), eval(index, vars));
            case EMapDecl(keys, values): EMapDecl([for (expr in keys) eval(expr, vars)], [for (expr in values) eval(expr, vars)]);
            case EArrayDecl(items): EArrayDecl([for (expr in items) eval(expr, vars)]);
            case ENew(className, args): ENew(className, [for (expr in args) eval(expr, vars)]);
            case EThrow(expr): EThrow(eval(expr, vars));
            case ETry(expr, catchVar, catchExpr): ETry(eval(expr, vars), catchVar, eval(catchExpr, vars));
            case EObject(fields): EObject([for (field in fields) new ObjectField(field.name, eval(field.expr, vars))]);
            case ESwitch(expr, cases, defaultExpr): ESwitch(
                eval(expr, vars),
                [for (switchCase in cases) new SwitchCase([for (val in switchCase.values) eval(val, vars)], eval(switchCase.expr, vars))],
                if (defaultExpr != null) eval(defaultExpr, vars) else null
            );
            case EDoWhile(cond, body): EDoWhile(eval(cond, vars), eval(body, vars));
            case EMeta(name, args, expr): EMeta(name, [for (arg in args) eval(arg, vars)], eval(expr, vars));
            case EInfo(info, expr): EInfo(info, eval(expr, info));
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_): expr.expr; 
            case EUnop(op, isPrefix, expr):
                var optimizedExpr:Expr = eval(expr, vars);
                var exprConst:LConst = exprToConst(optimizedExpr);

                if (exprConst != null && isPrefix) {
                    switch (op) {
                        case NEG: return new Expr(EConst(dynamicToConst(-StaticInterp.evaluateConst(exprConst))), optimizedExpr.line);
                        case NEG_BIT: return new Expr(EConst(dynamicToConst(~StaticInterp.evaluateConst(exprConst))), optimizedExpr.line);
                        case NOT: return new Expr(EConst(dynamicToConst(!StaticInterp.evaluateConst(exprConst))), optimizedExpr.line);
                        default:
                    }
                }
                EUnop(op, isPrefix, expr);
            case EIf(cond, thenExpr, elseExpr): 
                var optimizedCond:Expr = eval(cond, vars);
                var condConst:LConst = exprToConst(optimizedCond);
 
                if (condConst != null) 
                    switch (condConst) {
                        case LCBool(true):
                            var body:Expr = eval(thenExpr, vars);
                            return switch (body.expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: body;}
                        default:
                            var elseBody:Expr = if (elseExpr != null) eval(elseExpr, vars) else null;
                            return elseBody == null ? null : switch (elseBody.expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: elseBody;}
                    }

                EIf(optimizedCond, eval(thenExpr, vars), if (elseExpr != null) eval(elseExpr, vars) else null);
            case ETernary(cond, thenExpr, elseExpr):
                var optimizedCond:Expr = eval(cond, vars);
                var condConst:LConst = exprToConst(optimizedCond);
 
                if (condConst != null) 
                    switch (condConst) {
                        case LCBool(true):
                            var body:Expr = eval(thenExpr, vars);
                            return switch (body.expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: body;}
                        default:
                            var elseBody:Expr = eval(elseExpr, vars);
                            return elseBody == null ? null : switch (elseBody.expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: elseBody;}
                    }

                ETernary(optimizedCond, eval(thenExpr, vars), eval(elseExpr, vars));
            case EField(expr, field, isSafe):
                var optimizedExpr:Expr = eval(expr, vars);

                var mathIndex:Int = vars.indexOf("Math");
                switch (optimizedExpr.expr) {
                    case EConst(LCString(string)):
                        switch (field) {
                            case "length": return new Expr(EConst(LCInt(string.length)), optimizedExpr.line);
                            case "code" if (string.length == 1): return new Expr(EConst(LCInt(string.charCodeAt(0))), optimizedExpr.line);
                            default:
                        }
                    case EIdent(mathIndex) if (mathIndex != -1):
                        switch (field) {
                            case "POSITIVE_INFINITY": return new Expr(EConst(LCFloat(Math.POSITIVE_INFINITY)), optimizedExpr.line);
                            case "NEGATIVE_INFINITY": return new Expr(EConst(LCFloat(Math.NEGATIVE_INFINITY)), optimizedExpr.line);
                            case "NaN": return new Expr(EConst(LCFloat(Math.NaN)), optimizedExpr.line);
                            case "PI": return new Expr(EConst(LCFloat(Math.PI)), optimizedExpr.line);
                        }
                    default:
                }

                EField(optimizedExpr, field, isSafe);
            case ECall(func, args):
                var optimizedFunc:Expr = eval(func, vars);
                var optimizedArgs:Array<Expr> = [for (arg in args) eval(arg, vars)];

                var mathIndex:Int = vars.indexOf("Math");
                switch (optimizedFunc.expr) {
                    case EField(_.expr => EConst(LCString(string)), field, _):
                        var argsConsts:Array<LConst> = [for (expr in optimizedArgs) exprToConst(expr)];
                        switch (argsConsts) {
                            case []:
                                switch (field) {
                                    case "toLowerCase": return new Expr(EConst(LCString(string.toLowerCase())), optimizedFunc.line);
                                    case "toString": return new Expr(EConst(LCString(string.toString())), optimizedFunc.line);
                                    case "toUpperCase": return new Expr(EConst(LCString(string.toUpperCase())), optimizedFunc.line);
                                }
                            case [LCInt(intarg)]:
                                switch (field) {
                                    case "charAt": return new Expr(EConst(LCString(string.charAt(intarg))), optimizedFunc.line);
                                    case "charCodeAt": 
                                        var ret:Null<Int> = string.charCodeAt(intarg);

                                        if (ret == null) return new Expr(EConst(LCNull), optimizedFunc.line);
                                        else new Expr(EConst(LCInt(ret)), optimizedFunc.line);
                                    default:
                                }
                            case [LCString(stringarg)]:
                                switch (field) {
                                    case "split": 
                                        var array:Array<Expr> = [for (s in string.split(stringarg)) new Expr(EConst(LCString(s)), optimizedFunc.line)];
                                        return new Expr(EArrayDecl(array), optimizedFunc.line);
                                }
                            case [LCInt(intarg1), LCInt(intarg2)]:
                                switch (field) {
                                    case "substr": return new Expr(EConst(LCString(string.substr(intarg1, intarg2))), optimizedFunc.line);
                                    case "substring": return new Expr(EConst(LCString(string.substring(intarg1, intarg2))), optimizedFunc.line);
                                }
                            case [LCString(stringarg), LCInt(intarg)]:
                                switch (field) {
                                    case "indexOf": return new Expr(EConst(LCInt(string.indexOf(stringarg, intarg))), optimizedFunc.line);
                                    case "lastIndexOf": return new Expr(EConst(LCInt(string.lastIndexOf(stringarg, intarg))), optimizedFunc.line);
                                }
                            case [LCString(stringarg), null]:
                                switch (field) {
                                    case "indexOf": return new Expr(EConst(LCInt(string.indexOf(stringarg))), optimizedFunc.line);
                                    case "lastIndexOf": return new Expr(EConst(LCInt(string.lastIndexOf(stringarg))), optimizedFunc.line);
                                }
                            
                            default:
                        }
                    case EField(_.expr => EIdent(mathIndex), field, _) if (mathIndex != -1):
                        var argsConsts:Array<LConst> = [for (expr in optimizedArgs) exprToConst(expr)];

                        function twoArgMathEval<T1, T2>(v1:T1, v2: T2) {
                            switch (field) {
                                case "atan2": return new Expr(EConst(LCFloat(Math.atan2(cast v1, cast v2))), optimizedFunc.line);
                                case "max": return new Expr(EConst(LCFloat(Math.max(cast v1, cast v2))), optimizedFunc.line);
                                case "min": return new Expr(EConst(LCFloat(Math.min(cast v1, cast v2))), optimizedFunc.line);
                                case "pow": return new Expr(EConst(LCFloat(Math.pow(cast v1, cast v2))), optimizedFunc.line);
                            }
                            return null;
                        }

                        switch (argsConsts) {
                            case [LCInt(v)]:
                                switch (field) {
                                    case "abs": return new Expr(EConst(LCFloat(Math.abs(v))), optimizedFunc.line);
                                    case "acos": return new Expr(EConst(LCFloat(Math.acos(v))), optimizedFunc.line);
                                    case "asin": return new Expr(EConst(LCFloat(Math.asin(v))), optimizedFunc.line);
                                    case "atan": return new Expr(EConst(LCFloat(Math.atan(v))), optimizedFunc.line);
                                    case "cos": return new Expr(EConst(LCFloat(Math.cos(v))), optimizedFunc.line);
                                    case "exp": return new Expr(EConst(LCFloat(Math.exp(v))), optimizedFunc.line);
                                    case "isFinite": return new Expr(EConst(LCBool(Math.isFinite(v))), optimizedFunc.line);
                                    case "isNaN": return new Expr(EConst(LCBool(Math.isNaN(v))), optimizedFunc.line);
                                    case "log": return new Expr(EConst(LCFloat(Math.log(v))), optimizedFunc.line);
                                    case "sin": return new Expr(EConst(LCFloat(Math.sin(v))), optimizedFunc.line);
                                    case "sqrt": return new Expr(EConst(LCFloat(Math.sqrt(v))), optimizedFunc.line);
                                    case "tan": return new Expr(EConst(LCFloat(Math.tan(v))), optimizedFunc.line);
                                }
                            case [LCFloat(v)]:
                                switch (field) {
                                    case "abs": return new Expr(EConst(LCFloat(Math.abs(v))), optimizedFunc.line);
                                    case "acos": return new Expr(EConst(LCFloat(Math.acos(v))), optimizedFunc.line);
                                    case "asin": return new Expr(EConst(LCFloat(Math.asin(v))), optimizedFunc.line);
                                    case "atan": return new Expr(EConst(LCFloat(Math.atan(v))), optimizedFunc.line);
                                    case "ceil": return new Expr(EConst(LCFloat(Math.ceil(v))), optimizedFunc.line);
                                    case "cos": return new Expr(EConst(LCFloat(Math.cos(v))), optimizedFunc.line);
                                    case "exp": return new Expr(EConst(LCFloat(Math.exp(v))), optimizedFunc.line);
                                    case "fceil": return new Expr(EConst(LCFloat(Math.fceil(v))), optimizedFunc.line);
                                    case "ffloor": return new Expr(EConst(LCFloat(Math.ffloor(v))), optimizedFunc.line);
                                    case "floor": return new Expr(EConst(LCFloat(Math.floor(v))), optimizedFunc.line);
                                    case "fround": return new Expr(EConst(LCFloat(Math.fround(v))), optimizedFunc.line);
                                    case "isFinite": return new Expr(EConst(LCBool(Math.isFinite(v))), optimizedFunc.line);
                                    case "isNaN": return new Expr(EConst(LCBool(Math.isNaN(v))), optimizedFunc.line);
                                    case "log": return new Expr(EConst(LCFloat(Math.log(v))), optimizedFunc.line);
                                    case "round": return new Expr(EConst(LCFloat(Math.round(v))), optimizedFunc.line);
                                    case "sin": return new Expr(EConst(LCFloat(Math.sin(v))), optimizedFunc.line);
                                    case "sqrt": return new Expr(EConst(LCFloat(Math.sqrt(v))), optimizedFunc.line);
                                    case "tan": return new Expr(EConst(LCFloat(Math.tan(v))), optimizedFunc.line);
                                }
                            case [LCInt(v1), LCInt(v2)]: // yes this is the best way to do this, no i dont like it -lunar
                                var evalExpr:Expr = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            case [LCFloat(v1), LCInt(v2)]:
                                var evalExpr:Expr = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            case [LCInt(v1), LCFloat(v2)]:
                                var evalExpr:Expr = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            case [LCFloat(v1), LCFloat(v2)]:
                                var evalExpr:Expr = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            default:
                        }
                    default:
                }

                ECall(optimizedFunc, optimizedArgs);
            case EBinop(op, left, right):
                var leftOptimized:Expr = eval(left, vars);
                var rightOptimized:Expr = eval(right, vars);

                var leftConst:LConst = exprToConst(leftOptimized);
                var rightConst:LConst = exprToConst(rightOptimized);

                if (leftConst != null && rightConst != null && !op.isAssign() && op != INTERVAL) {
                    var leftValue:Dynamic = StaticInterp.evaluateConst(leftConst);
                    var rightValue:Dynamic = StaticInterp.evaluateConst(rightConst);

                    return new Expr(EConst(dynamicToConst(StaticInterp.evaluateBinop(op, leftValue, rightValue))), left.line);
                }

                EBinop(op, leftOptimized, rightOptimized);
        }, expr.line);
    }

    public static function exprToConst(expr:Expr):LConst {
        return switch (expr.expr) {
            case EConst(c): c;
            default: null;
        }
    }

    public static function dynamicToConst(value:Dynamic):LConst {
        return switch (Type.typeof(value)) {
            case TInt: LCInt(value);
            case TBool: LCBool(value);
            case TFloat: LCFloat(value);
            case TClass(String): LCString(value);
            case TNull: LCNull;
            default: throw "Unknown type of constant: " + Type.typeof(value);
        }
    }

    public static function constToInt(const:LConst):Int {
        return switch (const) {
            case LCInt(int): int;
            default: 0;
        }
    }

    /**
     * ! SCRAPPED BECAUSE I FORGOT HSCRIPT IS DYNAMIC
     * 
     * Turn a multi/div by a power of 2 into a bitshift.
     * We can check both sides for mult for some reason I can't remb I learned it in 2nd grade??? -lunar
     * 
     * For example: a / 2 to a >> 1
     * For example: a a * 2 into a << 1 
    if (rightConst != null || leftConst != null) {
        switch (op) {
            case DIV:
                var divInt:Int = constToInt(rightConst ?? LCInt(0));
                if (isPowerOf2(divInt)) { 
                    var divRoot:Int = Std.int(Math.pow(divInt, 1 / 2));
                    if (divRoot <= SAFE_BITSHIFT_RANGE) return new Expr(EBinop(SHR, left, new Expr(EConst(LCInt(divRoot)), expr.line)), expr.line);
                }
            case MULT:
                var multInt:Int = rightConst != null ? constToInt(rightConst) : constToInt(leftConst);
                if (isPowerOf2(multInt)) {
                    var multRoot:Int = Std.int(Math.pow(multInt, 1 / 2));
                    if (multRoot <= SAFE_BITSHIFT_RANGE) return new Expr(EBinop(SHL, rightConst != null ? left : right, new Expr(EConst(LCInt(multRoot)), expr.line)), expr.line);
                }
            default:
        }
    }

    public static final SAFE_BITSHIFT_RANGE:Int = 30; // safe zone for 32 bit signed ints 

    // https://stackoverflow.com/questions/600293/how-to-check-if-a-number-is-a-power-of-2
    public static function isPowerOf2(value:Int):Bool {
        return (value != 0) && ((value & (value - 1)) == 0);
    }
    */
}