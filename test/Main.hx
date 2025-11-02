package;

import sys.io.File;
import hscript.anaylzers.Inliner;
import hscript.anaylzers.Unravel;
import hscript.anaylzers.ConstEval;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
		parser.preprocesorValues.set("cpp", true);
        var expr = parser.parseString("
		#if cpp
			trace(2);
		#end
		");

		trace(hscript.anaylzers.Analyzer.optimize(expr).print());

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
    }
}