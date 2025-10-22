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
            case EBlock(exprs): EBlock([for (expr in exprs) eval(expr)]);
            case EField(expr, field, isSafe): EField(eval(expr), field, isSafe); 
            case EUnop(op, isPrefix, expr): EUnop(op, isPrefix, eval(expr));
            case ECall(func, args): ECall(eval(func), [for (expr in args) eval(expr)]);
            case EIf(cond, thenExpr, elseExpr): EIf(eval(cond), eval(thenExpr), if (elseExpr != null) eval(elseExpr) else null);
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
            case EBinop(op, left, right):
                var leftConst:LConst = exprToConst(eval(left));
                var rightConst:LConst = exprToConst(eval(right));
                if (leftConst != null && rightConst != null) {
                    var leftValue:Dynamic = StaticInterp.evaluateConst(leftConst);
                    var rightValue:Dynamic = StaticInterp.evaluateConst(rightConst);

                    if (!op.isAssign()) 
                        return new Expr(EConst(dynamicToConst(StaticInterp.evaluateBinop(op, leftValue, rightValue))), left.line);
                }
                expr.expr;
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
}