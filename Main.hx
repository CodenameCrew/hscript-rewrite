package;

import hscript.Ast.ExprBinop;
import hscript.Ast.Expr;
import hscript.Ast.IHScriptCustomBehaviour;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            MusicBeatState.skipTransIn = MusicBeatState.skipTransOut = true;
            FlxG.camera.flash(0xFFFFFFFF);
        ');

        var object = new Object();
        var interp = new Interp("Main.hx");
        interp.variables.set("MusicBeatState", {skipTransIn: false, skipTransOut:false});
        interp.variables.set("FlxG", {camera: {flash: (int:Int, time:Float) -> {trace(int);}}});
        trace(interp.execute(expr));
    }
}

class Object implements IHScriptCustomBehaviour {
    public var x:Float = 3;
    public function new() {}

    public function hset(name:String, value:Dynamic):Dynamic {trace(name, value); return name;};
	public function hget(name:String):Dynamic {trace(name); return name;};
}

class ExprPrinter {
    public static function print(e:Expr, indent:Int = 0):String {
        var pad = StringTools.lpad("", " ", indent);
        return switch (e.expr) {
            case EConst(c): pad + 'EConst($c)';
            case EIdent(name): pad + 'EIdent(${name})';
            case EVar(name, init, isPublic, isStatic):
                pad + 'EVar(${name}' +
                    (init != null ? ', init=' + print(init, indent + 2) : '') +
                    (isPublic == true ? ', public' : '') +
                    (isStatic == true ? ', static' : '') + ')';
            case EParent(expr): pad + 'EParent(\n' + print(expr, indent + 2) + '\n$pad)';
            case EBlock(exprs):
                pad + 'EBlock[\n' +
                exprs.map(e2 -> print(e2, indent + 2)).join(',\n') + '\n$pad]';
            case EField(expr, field, isSafe):
                pad + 'EField(' + print(expr, indent + 2) + ', field=' + field + (isSafe == true ? ', safe' : '') + ')';
            case EBinop(op, left, right):
                pad + 'EBinop($op,\n' + print(left, indent + 2) + ',\n' + print(right, indent + 2) + '\n$pad)';
            case EUnop(op, isPrefix, expr):
                pad + 'EUnop($op, prefix=$isPrefix,\n' + print(expr, indent + 2) + '\n$pad)';
            case ECall(func, args):
                pad + 'ECall(' + print(func, indent + 2) + ', args=[' +
                    args.map(a -> print(a, indent + 2)).join(', ') + '])';
            case EIf(cond, thenExpr, elseExpr):
                pad + 'EIf(\n' + print(cond, indent + 2) + ',\n' +
                    print(thenExpr, indent + 2) +
                    (elseExpr != null ? ',\n' + print(elseExpr, indent + 2) : '') + '\n$pad)';
            case EWhile(cond, body):
                pad + 'EWhile(\n' + print(cond, indent + 2) + ',\n' + print(body, indent + 2) + '\n$pad)';
            case EReturn(expr): pad + 'EReturn(' + (expr != null ? print(expr, indent + 2) : 'null') + ')';
            case EArray(expr, index):
                pad + 'EArray(' + print(expr, indent + 2) + ', ' + print(index, indent + 2) + ')';
            case EArrayDecl(items):
                pad + 'EArrayDecl[' + items.map(i -> print(i, indent + 2)).join(', ') + ']';
            case EMapDecl(keys, values):
                pad + 'EMapDecl[\n' +
                [for (i in 0...keys.length) pad + '  ${print(keys[i], indent + 2)} -> ${print(values[i], indent + 2)}'].join(',\n') +
                '\n$pad]';
            case EFunction(args, body, name, isPublic, isStatic):
                pad + 'EFunction(name=${name}, args=' + args.length +
                    ', body=\n' + print(body, indent + 2) + '\n$pad)';
            case EInfo(info, expr):
                pad + 'EInfo(info=' + info + ',\n' + print(expr, indent + 2) + '\n$pad)';
            case EBreak: pad + 'EBreak';
            case EContinue: pad + 'EContinue';
            default: pad + Std.string(e.expr); // fallback for unhandled variants
        };
    }
}