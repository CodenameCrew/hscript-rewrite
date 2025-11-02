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

@:nullSafety(Strict) class ConstEval {
    public static function eval(expr:Expr, vars:VariableInfo = null):Expr {
        if (expr == null) return guarantee(null);
        return new Expr(switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): EVar(name, if (init != null) eval(init, vars) else null, isPublic, isStatic);
            case EParent(expr): guarantee(expr != null ? eval(expr, vars) : null).expr;
            case EBlock(exprs): EBlock([for (expr in exprs) guarantee(expr != null ? eval(expr, vars) : null)].filter((expr:Expr) -> {return !expr.expr.match(EEmpty);}));
            case EWhile(cond, body): EWhile(guarantee(cond != null ? eval(cond, vars) : null), guarantee(body != null ? eval(body, vars) : null));
            case EFor(varName, iterator, body): EFor(varName, guarantee(iterator != null ? eval(iterator, vars) : null), guarantee(body != null ? eval(body, vars) : null));
            case EForKeyValue(key, value, iterator, body): EForKeyValue(key, value, guarantee(iterator != null ? eval(iterator, vars) : null), guarantee(body != null ? eval(body, vars) : null));
            case EFunction(args, body, name, isPublic, isStatic): EFunction([
                for (arg in args) if (arg.value != null) new Argument(arg.name, arg.opt, eval(arg.value, vars)) else arg
            ], guarantee(body != null ? eval(body, vars) : null), name, isPublic, isStatic);
            case EReturn(expr): EReturn(if (expr != null) eval(expr, vars) else null);
            case EArray(expr, index): EArray(guarantee(expr != null ? eval(expr, vars) : null), guarantee(index != null ? eval(index, vars) : null));
            case EMapDecl(keys, values): EMapDecl([for (expr in keys) guarantee(expr != null ? eval(expr, vars) : null)], [for (expr in values) guarantee(expr != null ? eval(expr, vars) : null)]);
            case EArrayDecl(items): EArrayDecl([for (expr in items) guarantee(expr != null ? eval(expr, vars) : null)]);
            case EThrow(expr): EThrow(guarantee(expr != null ? eval(expr, vars) : null));
            case ETry(expr, catchVar, catchExpr): ETry(guarantee(expr != null ? eval(expr, vars) : null), catchVar, guarantee(catchExpr != null ? eval(catchExpr, vars) : null));
            case EObject(fields): EObject([for (field in fields) new ObjectField(field.name, guarantee(field.expr != null ? eval(field.expr, vars) : null))]);
            case ESwitch(expr, cases, defaultExpr): ESwitch(
                guarantee(expr != null ? eval(expr, vars) : null),
                [for (switchCase in cases) new SwitchCase([for (val in switchCase.values) guarantee(val != null ? eval(val, vars) : null)], guarantee(eval(switchCase.expr, vars)))],
                if (defaultExpr != null) eval(defaultExpr, vars) else null
            );
            case EDoWhile(cond, body): EDoWhile(guarantee(cond != null ? eval(cond, vars) : null), guarantee(body != null ? eval(body, vars) : null));
            case EMeta(name, args, expr): EMeta(name, [for (arg in args) guarantee(arg != null ? eval(arg, vars) : null)], guarantee(expr != null ? eval(expr, vars) : null));
            case EInfo(info, expr): EInfo(info, guarantee(expr != null ? eval(expr, info) : null));
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_) | EEmpty: expr.expr; 
            case ENew(className, args): 
                var mapIndexes:Array<Int> = vars == null ? [] : [
                    vars.indexOf("StringMap"),
                    vars.indexOf("IntMap"),
                    vars.indexOf("EnumValueMap"),
                    vars.indexOf("ObjectMap"),
                    vars.indexOf("Map")
                ];

                for (mapIndex in mapIndexes)
                    if (mapIndex != -1 && className == mapIndex)
                        return new Expr(EMapDecl([], []), expr.line);

                ENew(className, [for (expr in args) guarantee(expr != null ? eval(expr, vars) : null)]);
            case EUnop(op, isPrefix, expr):
                var optimizedExpr:Null<Expr> = expr != null ? eval(expr, vars) : null;
                var exprConst:Null<LConst> = optimizedExpr != null ? exprToConst(optimizedExpr) : null;

                if (optimizedExpr != null && exprConst != null && isPrefix) {
                    switch (op) {
                        case NEG: return new Expr(EConst(dynamicToConst(-StaticInterp.evaluateConst(exprConst))), optimizedExpr.line);
                        case NEG_BIT: return new Expr(EConst(dynamicToConst(~StaticInterp.evaluateConst(exprConst))), optimizedExpr.line);
                        case NOT: return new Expr(EConst(dynamicToConst(!StaticInterp.evaluateConst(exprConst))), optimizedExpr.line);
                        default:
                    }
                }
                EUnop(op, isPrefix, expr);
            case EIf(cond, thenExpr, elseExpr): 
                var optimizedCond:Null<Expr> = cond != null ? eval(cond, vars) : null;
                var condConst:Null<LConst> = optimizedCond != null ? exprToConst(optimizedCond) : null;
 
                if (condConst != null) 
                    switch (condConst) {
                        case LCBool(true):
                            var body:Null<Expr> = thenExpr != null ? eval(thenExpr, vars) : null;
                            return switch (guarantee(body).expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: guarantee(body);}
                        default:
                            var elseBody:Null<Expr> = if (elseExpr != null) eval(elseExpr, vars) else null;
                            return elseBody == null ? guarantee(null) : switch (elseBody.expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: elseBody;}
                    }

                EIf(guarantee(optimizedCond), guarantee(thenExpr != null ? eval(thenExpr, vars) : null), guarantee(if (elseExpr != null) eval(elseExpr, vars) else null));
            case ETernary(cond, thenExpr, elseExpr):
                var optimizedCond:Null<Expr> = cond != null ? eval(cond, vars) : null;
                var condConst:Null<LConst> = optimizedCond != null ? exprToConst(optimizedCond) : null;
 
                if (condConst != null) 
                    switch (condConst) {
                        case LCBool(true):
                            var body:Null<Expr> = thenExpr != null ? eval(thenExpr, vars) : null;
                            return switch (guarantee(body).expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: guarantee(body);}
                        default:
                            var elseBody:Null<Expr> = elseExpr != null ? eval(elseExpr, vars) : null;
                            return switch (guarantee(elseBody).expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: guarantee(elseBody);}
                    }

                ETernary(guarantee(optimizedCond), guarantee(thenExpr != null ? eval(thenExpr, vars) : null), guarantee(elseExpr != null ? eval(elseExpr, vars) : null));
            case EField(expr, field, isSafe):
                var optimizedExpr:Null<Expr> = eval(expr, vars);

                var mathIndex:Int = vars != null ? vars.indexOf("Math"): -1;
                if (optimizedExpr != null) switch (optimizedExpr.expr) {
                    case EConst(LCString(string)):
                        switch (field) {
                            case "length": return new Expr(EConst(LCInt(string.length)), optimizedExpr.line);
                            case "code" if (string.length == 1): 
                                var ret:Null<Int> = string.charCodeAt(0);
                                if (ret == null) return new Expr(EConst(LCNull), optimizedExpr.line);
                                else return new Expr(EConst(LCInt(ret)), optimizedExpr.line);
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

                EField(guarantee(optimizedExpr), field, isSafe);
            case ECall(func, args):
                var optimizedFunc:Null<Expr> = func != null ? eval(func, vars) : null;
                var optimizedArgs:Array<Null<Expr>> = [for (arg in args) arg != null ? eval(arg, vars) : null];

                var mathIndex:Int = vars == null ? -1 : vars.indexOf("Math");
                if (optimizedFunc != null && optimizedFunc.expr != null) switch (optimizedFunc.expr) {
                    case EField(_.expr => EConst(LCString(string)), field, _):
                        var argsConsts:Array<Null<LConst>> = [for (expr in optimizedArgs) expr != null ? exprToConst(expr) : null];
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
                        var argsConsts:Array<Null<LConst>> = [for (expr in optimizedArgs) expr != null ? exprToConst(expr) : null];

                        inline function twoArgMathEval<T1, T2>(v1:T1, v2: T2):Null<Expr> {
                            return switch (field) {
                                case "atan2": new Expr(EConst(LCFloat(Math.atan2(cast v1, cast v2))), optimizedFunc.line);
                                case "max": new Expr(EConst(LCFloat(Math.max(cast v1, cast v2))), optimizedFunc.line);
                                case "min": new Expr(EConst(LCFloat(Math.min(cast v1, cast v2))), optimizedFunc.line);
                                case "pow": new Expr(EConst(LCFloat(Math.pow(cast v1, cast v2))), optimizedFunc.line);
                                default: null;
                            }
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
                                var evalExpr:Null<Expr> = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            case [LCFloat(v1), LCInt(v2)]:
                                var evalExpr:Null<Expr> = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            case [LCInt(v1), LCFloat(v2)]:
                                var evalExpr:Null<Expr> = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            case [LCFloat(v1), LCFloat(v2)]:
                                var evalExpr:Null<Expr> = twoArgMathEval(v1, v2);
                                if (evalExpr != null) return evalExpr;
                            case [null] | [null, null]:
                            default:
                        }
                    default:
                }

                ECall(guarantee(optimizedFunc), [for (arg in optimizedArgs) guarantee(arg)]);
            case EBinop(op, left, right):
                var leftOptimized:Null<Expr> = left != null ? eval(left, vars) : null;
                var rightOptimized:Null<Expr> = right != null ? eval(right, vars) : null;

                var leftConst:Null<LConst> = leftOptimized != null ? exprToConst(leftOptimized) : null;
                var rightConst:Null<LConst> = rightOptimized != null ? exprToConst(rightOptimized) : null;

                if (leftConst != null && rightConst != null && !op.isAssign() && op != INTERVAL) {
                    var leftValue:Dynamic = StaticInterp.evaluateConst(leftConst);
                    var rightValue:Dynamic = StaticInterp.evaluateConst(rightConst);

                    return new Expr(EConst(dynamicToConst(StaticInterp.evaluateBinop(op, leftValue, rightValue))), left.line);
                }

                EBinop(op, guarantee(leftOptimized), guarantee(rightOptimized));
        }, expr.line);
    }

    public static function exprToConst(expr:Expr):Null<LConst> {
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

    public static inline function guarantee(expr:Null<Expr>):Expr {
        return expr != null ? expr : new Expr(EEmpty, 0);
    }
}