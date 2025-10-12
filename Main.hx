package;

import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            static function newFunkinTypeText(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true) {
                trace(X);
            }
        ');

        var parser2 = new Parser();
        var expr2 = parser2.parseString('
            newFunkinTypeText(540, 490, 670, "hawk tuah", 40);

            var obj = {
            	regexMatch: (str:String, regex:EReg) -> {    
                    var matches:Array<String> = [];
                    while (regex.match(str)) {
                        matches.push(regex.matched(1));
                        str = regex.matchedRight();
                    }
                
                    return matches;
                }
            };

        ');

        ExprPrinter.print(expr2);


        var interp = new Interp("Main.hx");
        interp.execute(expr);
        var interp2 = new Interp("Main.hx");
        interp2.execute(expr2);

        // var func = StaticInterp.staticVariables.get("newFunkinTypeText");
        // func(540, 490, 670, "hawk tuah", 40);
    }
}

class ExprPrinter {
    public static function print(e:Expr, indent:Int = 0):Void {
        if (e == null) return;
        var pad = StringTools.lpad("", "  ", indent); // 2-space indentation

        switch (e.expr) {
            case EConst(c):
                trace(pad + "EConst(" + c + ")");

            case EIdent(name):
                trace(pad + "EIdent(" + name + ")");

            case EVar(name, init, isPublic, isStatic):
                trace(pad + 'EVar(' + name + ', public=' + isPublic + ', static=' + isStatic + ')');
                if (init != null) print(init, indent + 1);

            case EParent(expr):
                trace(pad + "EParent(");
                print(expr, indent + 1);
                trace(pad + ")");

            case EBlock(exprs):
                trace(pad + "EBlock {");
                for (x in exprs) print(x, indent + 1);
                trace(pad + "}");

            case EField(expr, field, isSafe):
                trace(pad + "EField(" + field + ", safe=" + isSafe + ")");
                print(expr, indent + 1);

            case EBinop(op, left, right):
                trace(pad + "EBinop(" + op + ")");
                print(left, indent + 1);
                print(right, indent + 1);

            case EUnop(op, isPrefix, expr):
                trace(pad + "EUnop(" + op + ", prefix=" + isPrefix + ")");
                print(expr, indent + 1);

            case ECall(func, args):
                trace(pad + "ECall(");
                print(func, indent + 1);
                for (a in args) print(a, indent + 1);
                trace(pad + ")");

            case EIf(cond, thenExpr, elseExpr):
                trace(pad + "EIf(");
                print(cond, indent + 1);
                print(thenExpr, indent + 1);
                if (elseExpr != null) print(elseExpr, indent + 1);
                trace(pad + ")");

            case EWhile(cond, body):
                trace(pad + "EWhile(");
                print(cond, indent + 1);
                print(body, indent + 1);
                trace(pad + ")");

            case EFor(varName, iterator, body):
                trace(pad + "EFor(" + varName + ")");
                print(iterator, indent + 1);
                print(body, indent + 1);

            case EForKeyValue(key, value, iterator, body):
                trace(pad + "EForKeyValue(" + key + ", " + value + ")");
                print(iterator, indent + 1);
                print(body, indent + 1);

            case EBreak:
                trace(pad + "EBreak");

            case EContinue:
                trace(pad + "EContinue");

            case EFunction(args, body, name, isPublic, isStatic):
                trace(pad + 'EFunction(' + name + ', public=' + isPublic + ', static=' + isStatic + ')');
                for (a in args)
                    trace(pad + "  Arg(" + a.name + ", default=" + a.value + ")");
                print(body, indent + 1);

            case EReturn(expr):
                trace(pad + "EReturn");
                if (expr != null) print(expr, indent + 1);

            case EArray(expr, index):
                trace(pad + "EArray");
                print(expr, indent + 1);
                print(index, indent + 1);

            case EMapDecl(keys, values):
                trace(pad + "EMapDecl {");
                for (i in 0...keys.length) {
                    trace(pad + "  Key:");
                    print(keys[i], indent + 2);
                    trace(pad + "  Value:");
                    print(values[i], indent + 2);
                }
                trace(pad + "}");

            case EArrayDecl(items):
                trace(pad + "EArrayDecl [");
                for (x in items) print(x, indent + 1);
                trace(pad + "]");

            case ENew(className, args):
                trace(pad + "ENew(" + className + ")");
                for (a in args) print(a, indent + 1);

            case EThrow(expr):
                trace(pad + "EThrow");
                print(expr, indent + 1);

            case ETry(expr, catchVar, catchExpr):
                trace(pad + "ETry(catch " + catchVar + ")");
                print(expr, indent + 1);
                print(catchExpr, indent + 1);

            case EObject(fields):
                trace(pad + "EObject {");
                for (f in fields) {
                    trace(pad + "  Field: " + f.name);
                    print(f.expr, indent + 2);
                }
                trace(pad + "}");

            case ETernary(cond, thenExpr, elseExpr):
                trace(pad + "ETernary");
                print(cond, indent + 1);
                print(thenExpr, indent + 1);
                print(elseExpr, indent + 1);

            case ESwitch(expr, cases, defaultExpr):
                trace(pad + "ESwitch(");
                print(expr, indent + 1);
                for (c in cases) {
                    trace(pad + "  Case:");
                    for (v in c.values) print(v, indent + 2);
                    print(c.expr, indent + 2);
                }
                if (defaultExpr != null) {
                    trace(pad + "  Default:");
                    print(defaultExpr, indent + 2);
                }
                trace(pad + ")");

            case EDoWhile(cond, body):
                trace(pad + "EDoWhile(");
                print(body, indent + 1);
                print(cond, indent + 1);
                trace(pad + ")");

            case EMeta(name, args, expr):
                trace(pad + "EMeta(@" + name + ")");
                for (a in args) print(a, indent + 1);
                print(expr, indent + 1);

            case EImport(path, mode):
                trace(pad + "EImport(" + path + ", mode=" + mode + ")");

            case EInfo(info, expr):
                trace(pad + "EInfo(" + info + ")");
                print(expr, indent + 1);
        }
    }

}