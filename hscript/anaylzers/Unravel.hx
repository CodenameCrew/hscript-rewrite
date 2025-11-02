package hscript.anaylzers;

import hscript.Ast.SwitchCase;
import hscript.Ast.ObjectField;
import hscript.Ast.Argument;
import hscript.Ast.Expr;

using hscript.utils.ExprUtils;

@:nullSafety(Strict) class Unravel {
    public static final SAFE_FOR_UNLOOP:Int = 128;

    public static function eval(expr:Expr):Expr {
        return new Expr(switch (expr.expr) {
            case EVar(name, init, isPublic, isStatic): EVar(name, if (init != null) eval(init) else null, isPublic, isStatic);
            case EParent(expr): EParent(eval(expr));
            case EBlock(exprs): 
                if (exprs.length == 1 && exprs[0] != null) return exprs[0];

                // Stop code after returns from being in the AST
                var optimizedExprs:Array<Expr> = [];
                for (expr in exprs) {
                    var optimizedExpr:Expr = eval(expr);
                    optimizedExprs.push(optimizedExpr);
                    switch (optimizedExpr.expr) {
                        case EReturn(null): optimizedExprs.pop(); break;
                        case EReturn(expr): break;
                        default:
                    }
                }

                // Unroll blocks to stop recurrsion
                var unrolledExprs:Array<Expr> = [];
                for (expr in optimizedExprs) {
                    var declaresVariables:Bool = false;
                    expr.iterate((expr:Expr) -> {
                        switch (expr.expr) {
                            case EVar(_, _, isPublic, isStatic) | EFunction(_, _, _, isPublic, isStatic): 
                                if ((isPublic == null ? true : !isPublic) && (isStatic == null ? true : !isStatic)) declaresVariables = true;
                            case EImport(path, mode): declaresVariables = true;
                            default: // does not declare any variables in the current scope, safe!
                        }
                    });

                    if (declaresVariables)
                        unrolledExprs.push(expr);
                    else {
                        switch (expr.expr) {
                            case EBlock(exprs): for (expr in exprs) unrolledExprs.push(expr);
                            default: unrolledExprs.push(expr);
                        } 
                    }
                }

                // lastly check for dead branches with filter
                EBlock(unrolledExprs.filter((expr:Expr) -> {return expr != null;}));
            case EField(expr, field, isSafe): EField(eval(expr), field, isSafe); 
            case ECall(func, args): ECall(eval(func), [for (expr in args) eval(expr)]);
            case EWhile(cond, body): EWhile(eval(cond), eval(body));
            case EFor(varName, iterator, body): 
                var optimizedIterator:Expr = eval(iterator);
                var optimizedBody:Expr = eval(body);

                switch (optimizedIterator.expr) {
                    case EBinop(INTERVAL, _.expr => EConst(LCInt(leftInt)), _.expr => EConst(LCInt(rightInt))):
                        if (rightInt > leftInt && rightInt-leftInt <= SAFE_FOR_UNLOOP) { // don't mess with it unless its valid
                            var unrolledLoops:Array<Expr> = [];
                            for (i in leftInt...rightInt) {
                                var newBody:Expr = optimizedBody.map((bodyExpr:Null<Expr>) -> {
                                    return if (bodyExpr != null && bodyExpr.expr != null) new Expr(switch (bodyExpr.expr) {
                                        case EIdent(name) if (name == varName): EConst(LCInt(i));
                                        default: bodyExpr.expr;
                                    }, bodyExpr.line) else null;
                                });
                                unrolledLoops.push(eval(newBody));
                            }
                            return new Expr(EBlock(unrolledLoops), expr.line);
                        }
                        EFor(varName, optimizedIterator, optimizedBody);
                    default: EFor(varName, optimizedIterator, optimizedBody);
                }
                
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
            case ESwitch(expr, cases, defaultExpr): ESwitch(
                eval(expr),
                [for (switchCase in cases) new SwitchCase([for (val in switchCase.values) eval(val)], eval(switchCase.expr))],
                if (defaultExpr != null) eval(defaultExpr) else null
            );
            case EDoWhile(cond, body): EDoWhile(eval(cond), eval(body));
            case EMeta(name, args, expr): EMeta(name, [for (arg in args) eval(arg)], eval(expr));
            case EInfo(info, expr): EInfo(info, eval(expr));
            case EBreak | EConst(_) | EContinue | EIdent(_) | EImport(_) | EEmpty: expr.expr; 
            case EUnop(op, isPrefix, expr): EUnop(op, isPrefix, eval(expr));
            case EIf(cond, thenExpr, elseExpr): EIf(eval(cond), eval(thenExpr), elseExpr != null ? eval(elseExpr) : null);
            case ETernary(cond, thenExpr, elseExpr): ETernary(eval(cond), eval(thenExpr), eval(elseExpr));
            case EBinop(op, left, right): EBinop(op, eval(left), eval(right));
        }, expr.line);
    }

    public static inline function guarantee(expr:Null<Expr>):Expr {
        return expr != null ? expr : new Expr(EEmpty, 0);
    }
}