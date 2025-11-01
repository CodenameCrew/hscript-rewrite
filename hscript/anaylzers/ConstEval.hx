package hscript.anaylzers;

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
    public static function eval(expr:Expr):Expr {
        return new Expr(switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): EVar(name, if (init != null) eval(init) else null, isPublic, isStatic);
            case EParent(expr): EParent(eval(expr));
            case EBlock(exprs): EBlock([for (expr in exprs) eval(expr)].filter((expr:Expr) -> {return expr != null;}));
            case EField(expr, field, isSafe): EField(eval(expr), field, isSafe); 
            case ECall(func, args): ECall(eval(func), [for (expr in args) eval(expr)]);
            case EWhile(cond, body): EWhile(eval(cond), eval(body));
            case EFor(varName, iterator, body): EFor(varName, eval(iterator), eval(body));
            case EForKeyValue(key, value, iterator, body): EForKeyValue(key, value, eval(iterator), eval(body));
            case EFunction(args, body, name, isPublic, isStatic): EFunction([
                for (arg in args) if (arg.value != null) new Argument(arg.name, arg.opt, eval(arg.value)) else arg
            ], eval(body), name, isPublic, isStatic);
            case EReturn(expr): EReturn(if (expr != null) eval(expr) else null);
            case EArray(expr, index): EArray(eval(expr), eval(index));
            case EMapDecl(keys, values): EMapDecl([for (expr in keys) eval(expr)], [for (expr in values) eval(expr)]);
            case EArrayDecl(items): EArrayDecl([for (expr in items) eval(expr)]);
            case ENew(className, args): ENew(className, [for (expr in args) eval(expr)]);
            case EThrow(expr): EThrow(eval(expr));
            case ETry(expr, catchVar, catchExpr): ETry(eval(expr), catchVar, eval(catchExpr));
            case EObject(fields): EObject([for (field in fields) new ObjectField(field.name, eval(field.expr))]);
            case ETernary(cond, thenExpr, elseExpr): ETernary(eval(cond), eval(thenExpr), eval(elseExpr));
            case ESwitch(expr, cases, defaultExpr): ESwitch(
                eval(expr),
                [for (switchCase in cases) new SwitchCase([for (val in switchCase.values) eval(val)], eval(switchCase.expr))],
                if (defaultExpr != null) eval(defaultExpr) else null
            );
            case EDoWhile(cond, body): EDoWhile(eval(cond), eval(body));
            case EMeta(name, args, expr): EMeta(name, [for (arg in args) eval(arg)], eval(expr));
            case EInfo(info, expr): EInfo(info, eval(expr));
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_): expr.expr; 
            case EUnop(op, isPrefix, expr):
                var optimizedExpr:Expr = eval(expr);
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
                var optimizedCond:Expr = eval(cond);
                var condConst:LConst = exprToConst(optimizedCond);
 
                if (condConst != null) 
                    switch (condConst) {
                        case LCBool(true):
                            var body:Expr = eval(thenExpr);
                            return switch (body.expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: body;}
                        default:
                            var elseBody:Expr = if (elseExpr != null) eval(elseExpr) else null;
                            return elseBody == null ? null : switch (elseBody.expr) {case EBlock(exprs) if (exprs.length == 1): exprs[0]; default: elseBody;}
                    }

                EIf(optimizedCond, eval(thenExpr), if (elseExpr != null) eval(elseExpr) else null);
            case EBinop(op, left, right):
                var leftOptimized:Expr = eval(left);
                var rightOptimized:Expr = eval(right);

                var leftConst:LConst = exprToConst(leftOptimized);
                var rightConst:LConst = exprToConst(rightOptimized);

                if (leftConst != null && rightConst != null && !op.isAssign() && op != INTERVAL) {
                    var leftValue:Dynamic = StaticInterp.evaluateConst(leftConst);
                    var rightValue:Dynamic = StaticInterp.evaluateConst(rightConst);

                    return new Expr(EConst(dynamicToConst(StaticInterp.evaluateBinop(op, leftValue, rightValue))), left.line);
                }

                /**
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
                 */

                EBinop(op, leftOptimized, rightOptimized);
        }, expr.line);
    }

    public static function exprToConst(expr:Expr):LConst {
        return switch (expr.expr) {
            case EConst(c): c;
            case EParent(expr): exprToConst(expr);
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

    public static final SAFE_BITSHIFT_RANGE:Int = 30; // safe zone for 32 bit signed ints 

    // https://stackoverflow.com/questions/600293/how-to-check-if-a-number-is-a-power-of-2
    public static function isPowerOf2(value:Int):Bool {
        return (value != 0) && ((value & (value - 1)) == 0);
    }
}