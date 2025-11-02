package;

import hscript.anaylzers.Analyzer;
import hscript.anaylzers.Inliner;
import hscript.anaylzers.Unravel;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
			var a = 2;
			trace(a ??= 34);
		");

		expr = Analyzer.optimize(expr);
		trace(expr.print());

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
    }
}