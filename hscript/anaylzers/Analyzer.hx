package hscript.anaylzers;

import hscript.Ast.Expr;
using hscript.utils.ExprUtils;

@:nullSafety(Strict) class Analyzer {
    public static function optimize(expr:Expr) {
        var shouldOptimize:Bool = true;
        var shouldConstEval:Bool = true;
        var shouldUnravel:Bool = true;
        var shouldInline:Bool = true;

        expr.iterate((expr:Null<Expr>) -> {
            if (expr != null && expr.expr != null) switch (expr.expr) {
                case EMeta("analyzer", args, _): 
                    for (i in args) {
                        switch (i.expr) {
                            case EConst(LCString(string)):
                                if (string == "none") shouldOptimize = false;
                                if (string == "noConstEval") shouldConstEval = false;
                                if (string == "noUnravel") shouldUnravel = false;
                                if (string == "noInline") shouldUnravel = false;
                            default:
                        }
                    }
                default:
            }
        });

        if (!shouldOptimize) return expr;

        if (shouldConstEval) expr = ConstEval.eval(expr);
		if (shouldUnravel) expr = Unravel.eval(expr);
		if (shouldInline) expr = Inliner.eval(expr);

        @:nullSafety(Off) {
            expr = expr.map((expr:Null<Expr>) -> {
                switch (expr.expr) {
                    case EEmpty: null;
                    default: expr;
                }
            });
        }

        return expr;
    }
}