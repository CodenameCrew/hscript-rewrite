package;

import hscript.Ast.Expr;
import hscript.anaylzers.ConstEval;
import haxe.io.Bytes;
import hscript.utils.ExprUtils;
import hscript.utils.BytesPrinter;
import hscript.bytecode.ByteCompiler;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
			function b(f:Int) {
				trace(f);

				f++;
				if (f < 3) b(f);
			}

			b(0);
		');

		var interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);

		trace(ExprUtils.print(expr, true));

		var comp:ByteCompiler = new ByteCompiler();
		var byteCode:Bytes = comp.compile(expr);
		trace(byteCode.toHex(), byteCode.length);

		Sys.println(BytesPrinter.print(byteCode));
    }
}