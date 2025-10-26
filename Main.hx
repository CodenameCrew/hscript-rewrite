package;

import hscript.bytecode.ByteInstruction.ByteChunk;
import haxe.Timer;
import hscript.bytecode.ByteVM;
import hscript.anaylzers.ConstEval;
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
			var a = 3.5;
			trace(a * 2);
			trace(a / 2);

		');

		trace(ExprUtils.print(expr, true));
		var oexpr = ConstEval.eval(expr);

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
		interp.reset();
		trace(ExprUtils.print(oexpr, true));
		interp.execute(oexpr);
    }
}