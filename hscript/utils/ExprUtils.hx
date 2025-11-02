package hscript.utils;

import hscript.Ast.SwitchCase;
import hscript.Ast.ObjectField;
import hscript.Ast.Argument;
import hscript.Ast.Expr;

@:nullSafety(Strict) class ExprUtils {
    /**
     * Helper to iterate through the whole Ast tree recurrively.
     * @param expr 
     * @param iter 
     */
    public static function iterate(expr:Null<Expr>, iter:Expr->Void) {
        if (expr != null) iter(expr);
        if (expr != null && expr.expr != null) switch (expr.expr) {
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
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_) | EEmpty: // Cause compilier error if these arent updated along with Ast.hx -lunar
        }
    }

    /**
     * Helper to transverse through the whole Ast tree recurrively.
     * @param expr 
     * @param iter Return false to stop going deeper, return true to keep going.
     */
    public static function transverse(expr:Null<Expr>, iter:Expr->Bool) {
        if (expr == null || !iter(expr)) return;
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
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_) | EEmpty:
        }
    }

    @:nullSafety(Off) public static function map(expr:Null<Expr>, iter:Null<Expr>->Null<Expr>):Null<Expr> {
        var mappedExpr:Expr = if (expr != null && expr.expr != null) new Expr(switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): EVar(name, if (init != null) map(init, iter) else null, isPublic, isStatic);
            case EParent(expr): EParent(map(expr, iter));
            case EBlock(exprs): EBlock([for (expr in exprs) map(expr, iter)]);
            case EField(expr, field, isSafe): EField(map(expr, iter), field, isSafe); 
            case EBinop(op, left, right): EBinop(op, map(left, iter), map(right, iter));
            case EUnop(op, isPrefix, expr): EUnop(op, isPrefix, map(expr, iter));
            case ECall(func, args): ECall(map(func, iter), [for (expr in args) map(expr, iter)]);
            case EIf(cond, thenExpr, elseExpr): EIf(map(cond, iter), map(thenExpr, iter), if (elseExpr != null) map(elseExpr, iter) else null);
            case EWhile(cond, body): EWhile(map(cond, iter), map(body, iter));
            case EFor(varName, iterator, body): EFor(varName, map(iterator, iter), map(body, iter));
            case EForKeyValue(key, value, iterator, body): EForKeyValue(key, value, map(iterator, iter), map(body, iter));
            case EFunction(args, body, name, isPublic, isStatic): EFunction([
                for (arg in args) if (arg.value != null) new Argument(arg.name, arg.opt, map(arg.value, iter)) else arg
            ], map(body, iter), name, isPublic, isStatic);
            case EReturn(expr): EReturn(if (expr != null) map(expr, iter) else null);
            case EArray(expr, index): EArray(map(expr, iter), map(index, iter));
            case EMapDecl(keys, values): EMapDecl([for (expr in keys) map(expr, iter)], [for (expr in values) map(expr, iter)]);
            case EArrayDecl(items): EArrayDecl([for (expr in items) map(expr, iter)]);
            case ENew(className, args): ENew(className, [for (expr in args) map(expr, iter)]);
            case EThrow(expr): EThrow(map(expr, iter));
            case ETry(expr, catchVar, catchExpr): ETry(map(expr, iter), catchVar, map(catchExpr, iter));
            case EObject(fields): EObject([for (field in fields) new ObjectField(field.name, map(field.expr, iter))]);
            case ETernary(cond, thenExpr, elseExpr): ETernary(map(cond, iter), map(thenExpr, iter), map(elseExpr, iter));
            case ESwitch(expr, cases, defaultExpr): ESwitch(
                map(expr, iter),
                [for (switchCase in cases) new SwitchCase([for (val in switchCase.values) map(val, iter)], map(switchCase.expr, iter))],
                if (defaultExpr != null) map(defaultExpr, iter) else null
            );
            case EDoWhile(cond, body): EDoWhile(map(cond, iter), map(body, iter));
            case EMeta(name, args, expr): EMeta(name, [for (arg in args) map(arg, iter)], map(expr, iter));
            case EInfo(info, expr): EInfo(info, map(expr, iter));
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_) | EEmpty: expr.expr; 
        }, expr.line) else null;

        var result:Null<Expr> = expr != null ? iter(expr) : null;
        return result;
    }

    /**
     * Print a Expr in a script format.
     * @param e 
     * @param pretty 
     * @return String
     */
    public static function print(e:Expr, pretty:Bool = true):String {
		var printer:Null<ExprPrinter> = new ExprPrinter(pretty ? "\t" : null);
		var output:String = printer.exprToString(e);

		printer = null;
		return output;
	}
}