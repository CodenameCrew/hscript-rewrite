package;

import hscript.bytecode.ByteVM;
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
			for (i in 0...5) {
				trace(i);
				trace(i + 4);
			}
		');

		var interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);

		trace(ExprUtils.print(expr, true));

		var comp:ByteCompiler = new ByteCompiler();
		var byteCode:Bytes = comp.compile(expr);
		trace(byteCode.toHex(), byteCode.length);

		Sys.println(BytesPrinter.print(byteCode));

		Sys.println("");
		var vm:ByteVM = new ByteVM("Main.hx");
		vm.errorHandler = (error:Error) -> {Sys.println(error);}
		vm.execute(byteCode);
    }
}