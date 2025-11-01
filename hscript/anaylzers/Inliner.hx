package hscript.anaylzers;

import hscript.Ast.Argument;
import hscript.Ast.ObjectField;
import hscript.Ast.SwitchCase;
import hscript.Ast.VariableInfo;
import hscript.Ast.Expr;

using hscript.utils.ExprUtils;

class Inliner {
    public static function eval(expr:Expr, vars:VariableInfo = null):Expr {
        return new Expr(switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): EVar(name, if (init != null) eval(init, vars) else null, isPublic, isStatic);
            case EParent(expr): EParent(eval(expr, vars));
            case EBlock(exprs): EBlock([for (expr in exprs) eval(expr, vars)].filter((expr:Expr) -> {return expr != null;}));
            case EField(expr, field, isSafe): EField(eval(expr, vars), field, isSafe); 
            case ECall(func, args): ECall(eval(func, vars), [for (expr in args) eval(expr, vars)]);
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
            case EUnop(op, isPrefix, expr): EUnop(op, isPrefix, eval(expr, vars));
            case EIf(cond, thenExpr, elseExpr): EIf(eval(cond, vars), eval(thenExpr, vars), elseExpr != null ? eval(elseExpr, vars) : null);
            case ETernary(cond, thenExpr, elseExpr): ETernary(eval(cond, vars), eval(thenExpr, vars), eval(elseExpr, vars));
            case EBinop(op, left, right): EBinop(op, eval(left, vars), eval(right, vars));
        }, expr.line);
    }
}