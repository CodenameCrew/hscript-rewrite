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
			var a = []; 
			for (i in 0...1000) a.push(i * 2 + 1 / 6); 
			if(true == true) a.push(1);
			a[0];
		');

		trace(ExprUtils.print(expr, true));
		expr = ConstEval.eval(expr);
		trace(ExprUtils.print(expr, true));

		var comp:ByteCompiler = new ByteCompiler();
		var byteCode:ByteChunk = comp.compile(expr);
		trace(byteCode, byteCode.instructions.length);

		Sys.println(BytesPrinter.print(byteCode));

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}

		Sys.println("");
		var vm:ByteVM = new ByteVM("Main.hx");
		vm.errorHandler = (error:Error) -> {Sys.println(error);}

		var time:Float = Timer.stamp();
		for (i in 0...2000)
			vm.execute(byteCode);
		trace(Timer.stamp() - time);

    }
}