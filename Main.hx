package;

import hscript.Expr;
import haxe.CallStack;
import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            var expr = parser.parseString("function test(cool, awesome:Int, ?b) {trace('hi');v=3*4;} trace(awesome);");
            trace(ExprPrinter.printExpr(expr));
        } catch (e:Dynamic) {
            trace(e);
            trace(CallStack.toString(CallStack.exceptionStack()));
        }
    }
}

// Shat out by chatGPT in 2 seconds 
class ExprPrinter {
    public static function printExpr(e:Expr, indent:Int = 0):String {
        var pad = StringTools.lpad("", " ", indent);
        return switch (e.expr) {
            case EConst(c):
                pad + "Const(" + Std.string(c) + ")";
            case EIdent(name):
                pad + "Ident(" + name + ")";
            case EVar(name, init, isPublic, isStatic):
                pad + 'Var($name'
                    + (init != null ? " = " + printExpr(init, indent + 2) : "")
                    + (isPublic == true ? " public" : "")
                    + (isStatic == true ? " static" : "")
                    + ")";
            case EParent(expr):
                pad + "Parent(\n" + printExpr(expr, indent + 2) + "\n" + pad + ")";
            case EBlock(exprs):
                pad + "Block[\n" + exprs.map(e -> printExpr(e, indent + 2)).join(",\n") + "\n" + pad + "]";
            case EField(expr, field, safe):
                pad + "Field(" + printExpr(expr, indent + 2) + "." + field + (safe == true ? "?" : "") + ")";
            case EBinop(op, left, right):
                pad + "Binop(" + Std.string(op) + ",\n"
                    + printExpr(left, indent + 2) + ",\n"
                    + printExpr(right, indent + 2) + ")";
            case EUnop(op, isPrefix, expr):
                pad + "Unop(" + Std.string(op) + (isPrefix ? " prefix" : " postfix") + ", " + printExpr(expr, indent + 2) + ")";
            case ECall(func, args):
                pad + "Call(\n" + printExpr(func, indent + 2)
                    + ", args=[" + args.map(a -> printExpr(a, indent + 2)).join(", ") + "])";
            case EIf(cond, thenExpr, elseExpr):
                pad + "If(\n" + printExpr(cond, indent + 2)
                    + ",\n" + printExpr(thenExpr, indent + 2)
                    + (elseExpr != null ? ",\n" + printExpr(elseExpr, indent + 2) : "")
                    + ")";
            case EWhile(cond, body):
                pad + "While(\n" + printExpr(cond, indent + 2) + ",\n" + printExpr(body, indent + 2) + ")";
            case EFor(varName, iterator, body):
                pad + "For(" + varName + " in " + printExpr(iterator, indent + 2) + ",\n" + printExpr(body, indent + 2) + ")";
            case EForKeyValue(k, v, it, body):
                pad + "ForKeyValue(" + k + " => " + v + " in " + printExpr(it, indent + 2) + ",\n" + printExpr(body, indent + 2) + ")";
            case EBreak:
                pad + "Break";
            case EContinue:
                pad + "Continue";
            case EFunction(args, body, name, isPublic, isStatic, isOverride):
                pad + "Function(" + (name != null ? name : -1)
                    + ", args=[" + args.map(a -> a.name + ":").join(", ") + "]"
                    + (isPublic == true ? " public" : "")
                    + (isStatic == true ? " static" : "")
                    + (isOverride == true ? " override" : "")
                    + ",\n" + printExpr(body, indent + 2) + ")";
            case EReturn(expr):
                pad + "Return(" + (expr != null ? printExpr(expr, indent + 2) : "") + ")";
            case EArray(e, i):
                pad + "ArrayAccess(" + printExpr(e, indent + 2) + "[" + printExpr(i, indent + 2) + "])";
            case EMapDecl(keys, values):
                pad + "MapDecl(" + [for (i in 0...keys.length) printExpr(keys[i]) + "=>" + printExpr(values[i])].join(", ") + ")";
            case EArrayDecl(items):
                pad + "ArrayDecl([" + items.map(i -> printExpr(i, indent + 2)).join(", ") + "])";
            case ENew(className, args):
                pad + "New(" + className + "(" + args.map(a -> printExpr(a, indent + 2)).join(", ") + "))";
            case EThrow(expr):
                pad + "Throw(" + printExpr(expr, indent + 2) + ")";
            case ETry(expr, v, catchExpr):
                pad + "Try(\n" + printExpr(expr, indent + 2) + ", catch " + v + " => " + printExpr(catchExpr, indent + 2) + ")";
            case EObject(fields):
                pad + "Object{" + fields.map(f -> f.name + ":" + printExpr(f.expr, indent + 2)).join(", ") + "}";
            case ETernary(cond, thenExpr, elseExpr):
                pad + "Ternary(" + printExpr(cond, indent + 2) + " ? " + printExpr(thenExpr, indent + 2) + " : " + printExpr(elseExpr, indent + 2) + ")";
            case ESwitch(expr, cases, defaultExpr):
                pad + "Switch(" + printExpr(expr, indent + 2)
                    + ", cases=[" + cases.map(c -> printExpr(c.expr, indent + 2) + " -> " + printExpr(c.expr, indent + 2)).join(", ") + "]"
                    + (defaultExpr != null ? ", default=" + printExpr(defaultExpr, indent + 2) : "")
                    + ")";
            case EDoWhile(cond, body):
                pad + "DoWhile(\n" + printExpr(body, indent + 2) + ", while " + printExpr(cond, indent + 2) + ")";
            case EMeta(name, args, expr):
                pad + "Meta(@" + name + "(" + args.map(a -> printExpr(a, indent + 2)).join(", ") + "),\n" + printExpr(expr, indent + 2) + ")";
            case EImport(path, mode):
                pad + "Import(" + path + ", " + Std.string(mode) + ")";
            case EInfo(info, expr):
                pad + "Info(" + Std.string(info) + ", " + printExpr(expr, indent + 2) + ")";
        }
    }
}
