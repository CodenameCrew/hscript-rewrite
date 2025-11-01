package;

import hscript.anaylzers.Unravel;
import hscript.anaylzers.ConstEval;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
			Math.sin(3);
			var a = Math.pow(2, 2);
			Math.PI;
		");

		trace(expr.print());

		expr = ConstEval.eval(expr);
		expr = Unravel.eval(expr);

		trace(expr.print());

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
    }
}