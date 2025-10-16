package hscript.utils;

import hscript.Ast.SwitchCase;
import hscript.Ast.ObjectField;
import hscript.Ast.Argument;
import hscript.Ast.ExprDef;
import hscript.Ast.Expr;

class ExprUtils {
    /**
     * Helper to iterate through the whole Ast tree recurrively.
     * @param expr 
     * @param iter 
     */
    public static function iterate(expr:Expr, iter:Expr->Void) {
        iter(expr);
        switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): if (init != null) iterate(init, iter);
            case EParent(expr): iterate(expr, iter);
            case EBlock(exprs): for (expr in exprs) iterate(expr, iter);
            case EField(expr, field, isSafe): iterate(expr, iter);
            case EBinop(op, left, right): iterate(left, iter); iterate(right, iter);
            case EUnop(op, isPrefix, expr): iterate(expr, iter);
            case ECall(func, args): iterate(func, iter); for (expr in args) iterate(expr, iter);
            case EIf(cond, thenExpr, elseExpr): iterate(cond, iter); iterate(thenExpr, iter); iterate(elseExpr, iter);
            case EWhile(cond, body): iterate(cond, iter); iterate(body, iter);
            case EFor(varName, iterator, body): iterate(iterator, iter); iterate(body, iter);
            case EForKeyValue(key, value, iterator, body): iterate(iterator, iter); iterate(body, iter);
            case EFunction(args, body, name, isPublic, isStatic): for (arg in args) {iterate(arg.value, iter);} iterate(body, iter);
            case EReturn(expr): if (expr != null) iterate(expr, iter);
            case EArray(expr, index): iterate(expr, iter); iterate(index, iter);
            case EMapDecl(keys, values): for (expr in keys) {iterate(expr, iter);} for (expr in values) {iterate(expr, iter);}
            case EArrayDecl(items): for (expr in items) iterate(expr, iter);
            case ENew(className, args): for (expr in args) iterate(expr, iter);
            case EThrow(expr): iterate(expr, iter);
            case ETry(expr, catchVar, catchExpr): iterate(expr, iter); iterate(catchExpr, iter);
            case EObject(fields): for (field in fields) iterate(field.expr, iter);
            case ETernary(cond, thenExpr, elseExpr): iterate(cond, iter); iterate(thenExpr, iter); iterate(elseExpr, iter);
            case ESwitch(expr, cases, defaultExpr): iterate(expr, iter); for (switchCase in cases) {for (val in switchCase.values) {iterate(val, iter);} iterate(switchCase.expr, iter);} iterate(defaultExpr, iter);
            case EDoWhile(cond, body): iterate(cond, iter); iterate(body, iter);
            case EMeta(name, args, expr): for (arg in args) {iterate(arg, iter);} iterate(expr, iter);
            case EInfo(info, expr): iterate(expr, iter);
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_): // Cause compilier error if these arent updated along with Ast.hx -lunar
        }
    }

    /**
     * Helper to transverse through the whole Ast tree recurrively.
     * @param expr 
     * @param iter Return false to stop going deeper, return true to keep going.
     */
    public static function transverse(expr:Expr, iter:Expr->Bool) {
        if (!iter(expr)) return;
        switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): if (init != null) transverse(init, iter);
            case EParent(expr): transverse(expr, iter);
            case EBlock(exprs): for (expr in exprs) transverse(expr, iter);
            case EField(expr, field, isSafe): transverse(expr, iter);
            case EBinop(op, left, right): transverse(left, iter); transverse(right, iter);
            case EUnop(op, isPrefix, expr): transverse(expr, iter);
            case ECall(func, args): transverse(func, iter); for (expr in args) transverse(expr, iter);
            case EIf(cond, thenExpr, elseExpr): transverse(cond, iter); transverse(thenExpr, iter); transverse(elseExpr, iter);
            case EWhile(cond, body): transverse(cond, iter); transverse(body, iter);
            case EFor(varName, iterator, body): transverse(iterator, iter); transverse(body, iter);
            case EForKeyValue(key, value, iterator, body): transverse(iterator, iter); transverse(body, iter);
            case EFunction(args, body, name, isPublic, isStatic): for (arg in args) {transverse(arg.value, iter);} transverse(body, iter);
            case EReturn(expr): if (expr != null) transverse(expr, iter);
            case EArray(expr, index): transverse(expr, iter); transverse(index, iter);
            case EMapDecl(keys, values): for (expr in keys) {transverse(expr, iter);} for (expr in values) {transverse(expr, iter);}
            case EArrayDecl(items): for (expr in items) transverse(expr, iter);
            case ENew(className, args): for (expr in args) transverse(expr, iter);
            case EThrow(expr): transverse(expr, iter);
            case ETry(expr, catchVar, catchExpr): transverse(expr, iter); transverse(catchExpr, iter);
            case EObject(fields): for (field in fields) transverse(field.expr, iter);
            case ETernary(cond, thenExpr, elseExpr): transverse(cond, iter); transverse(thenExpr, iter); transverse(elseExpr, iter);
            case ESwitch(expr, cases, defaultExpr): transverse(expr, iter); for (switchCase in cases) {for (val in switchCase.values) {transverse(val, iter);} transverse(switchCase.expr, iter);} transverse(defaultExpr, iter);
            case EDoWhile(cond, body): transverse(cond, iter); transverse(body, iter);
            case EMeta(name, args, expr): for (arg in args) {transverse(arg, iter);} transverse(expr, iter);
            case EInfo(info, expr): transverse(expr, iter);
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_):
        }
    }

    public static function map(expr:Expr, iter:Expr->Expr):Expr { 
        return new Expr(switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): EVar(name, if (init != null) iter(init) else null, isPublic, isStatic);
            case EParent(expr): EParent(iter(expr));
            case EBlock(exprs): EBlock([for (expr in exprs) iter(expr)]);
            case EField(expr, field, isSafe): EField(iter(expr), field, isSafe); 
            case EBinop(op, left, right): EBinop(op, iter(left), iter(right));
            case EUnop(op, isPrefix, expr): EUnop(op, isPrefix, iter(expr));
            case ECall(func, args): ECall(iter(func), [for (expr in args) iter(expr)]);
            case EIf(cond, thenExpr, elseExpr): EIf(iter(cond), iter(thenExpr), if (elseExpr != null) iter(elseExpr) else null);
            case EWhile(cond, body): EWhile(iter(cond), iter(body));
            case EFor(varName, iterator, body): EFor(varName, iter(iterator), iter(body));
            case EForKeyValue(key, value, iterator, body): EForKeyValue(key, value, iter(iterator), iter(body));
            case EFunction(args, body, name, isPublic, isStatic): EFunction([
                for (arg in args) if (arg.value != null) new Argument(arg.name, arg.opt, iter(arg.value)) else arg
            ], iter(body), name, isPublic, isStatic);
            case EReturn(expr): EReturn(if (expr != null) iter(expr) else null);
            case EArray(expr, index): EArray(iter(expr), iter(index));
            case EMapDecl(keys, values): EMapDecl([for (expr in keys) iter(expr)], [for (expr in values) iter(expr)]);
            case EArrayDecl(items): EArrayDecl([for (expr in items) iter(expr)]);
            case ENew(className, args): ENew(className, [for (expr in args) iter(expr)]);
            case EThrow(expr): EThrow(iter(expr));
            case ETry(expr, catchVar, catchExpr): ETry(iter(expr), catchVar, iter(catchExpr));
            case EObject(fields): EObject([for (field in fields) new ObjectField(field.name, iter(field.expr))]);
            case ETernary(cond, thenExpr, elseExpr): ETernary(iter(cond), iter(thenExpr), iter(elseExpr));
            case ESwitch(expr, cases, defaultExpr): ESwitch(
                iter(expr),
                [for (switchCase in cases) new SwitchCase([for (val in switchCase.values) iter(val)], iter(switchCase.expr))],
                if (defaultExpr != null) iter(defaultExpr) else null
            );
            case EDoWhile(cond, body): EDoWhile(iter(cond), iter(body));
            case EMeta(name, args, expr): EMeta(name, [for (arg in args) iter(arg)], iter(expr));
            case EInfo(info, expr): EInfo(info, iter(expr));
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_): expr.expr; 
        }, expr.line);
    }
}