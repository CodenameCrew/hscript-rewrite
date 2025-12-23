package;

import haxe.Timer;
import hscript.bytecode.ByteInstruction.ByteChunk;
import hscript.anaylzers.Analyzer;
import hscript.bytecode.ByteCompiler;
import hscript.bytecode.ByteVM;
import hscript.utils.BytesPrinter;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
			var a = []; 
			for (i in 0...1000) a.push(i * 2 + 1 / 6); 
			if(true == true) a.push(1);
			a[0];
		");

		// expr = Analyzer.optimize(expr);

        var compiler:ByteCompiler = new ByteCompiler();
        var bytes:ByteChunk = compiler.compile(expr);

        var vm = new ByteVM("Main.hx");

        var time:Float = Timer.stamp();
		for (i in 0...2000)
			vm.execute(bytes);
		trace(Timer.stamp() - time);


		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}

        var time:Float = Timer.stamp();
		for (i in 0...2000)
			interp.execute(expr);
		trace(Timer.stamp() - time);
    }
}