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
			var a = []; 
			for (i in 0...1000) a.push(i * 2 + 1 / 6); 
			if(true == true) a.push(1);
			if(2 == true && true || false) a.push(1);
			a[0];
		');

		trace(ExprUtils.print(expr, true));
		expr = ConstEval.eval(expr);
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