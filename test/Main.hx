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
        var expr = parser.parseString("var t = 4 is Int; trace(t);");

		// expr = ConstEval.eval(expr);
		// expr = Unravel.eval(expr);
		// expr = Inliner.eval(expr);

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
    }
}